// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../contracts/AdvantageAsymmetryCampaign.sol";
import "./mocks/MockERC20.sol";

/// @notice Day 3 scope only: bounded recurring patronage (start/claim/cancel), accrual and
///         cutoff correctness, cross-accounting isolation from contribution/refund/bond
///         state, and cross-stream/cross-campaign isolation.
///
///         Day 1 and Day 2 behaviour is covered by their own suites and is not duplicated
///         here except where a patronage assertion depends on it.
contract AdvantageAsymmetryCampaignDay3Test is Test {
    AdvantageAsymmetryCampaign campaign;
    MockERC20 token;

    address verifier = address(this); // deployer == owner == verifier for this prototype
    address penaltySink = address(0xBEEF);
    address creator = address(0xC12EA702);
    address supporterA = address(0xA1);
    address supporterB = address(0xB2);
    address stranger = address(0x5747);

    uint256 constant GOAL = 100 ether;
    uint256 constant BOND = 10 ether;
    uint256 constant MILESTONE_1 = 40 ether;
    uint256 constant MILESTONE_2 = 60 ether;

    function setUp() public {
        token = new MockERC20();
        campaign = new AdvantageAsymmetryCampaign(address(token), penaltySink);

        address[5] memory funded = [creator, supporterA, supporterB, stranger, penaltySink];
        for (uint256 i = 0; i < funded.length; i++) {
            token.mint(funded[i], 10_000 ether);
            vm.prank(funded[i]);
            token.approve(address(campaign), type(uint256).max);
        }
        vm.prank(verifier);
        token.approve(address(campaign), type(uint256).max);
    }

    // ---------- helpers ----------

    function _twoMilestoneDescriptions() internal pure returns (string[] memory d) {
        d = new string[](2);
        d[0] = "Milestone 1";
        d[1] = "Milestone 2";
    }

    function _twoMilestoneAmounts() internal pure returns (uint256[] memory a) {
        a = new uint256[](2);
        a[0] = MILESTONE_1;
        a[1] = MILESTONE_2;
    }

    function _createActiveCampaign() internal returns (uint256 campaignId) {
        vm.prank(creator);
        campaignId = campaign.createCampaign(
            GOAL,
            BOND,
            _twoMilestoneDescriptions(),
            _twoMilestoneAmounts(),
            block.timestamp + 7 days,
            block.timestamp + 37 days
        );
        vm.prank(supporterA);
        campaign.contribute(campaignId, GOAL); // fully funds -> Active
    }

    function _createFundingCampaign() internal returns (uint256 campaignId) {
        vm.prank(creator);
        campaignId = campaign.createCampaign(
            GOAL,
            BOND,
            _twoMilestoneDescriptions(),
            _twoMilestoneAmounts(),
            block.timestamp + 7 days,
            block.timestamp + 37 days
        );
    }

    function _statusOf(uint256 campaignId) internal view returns (AdvantageAsymmetryCampaign.CampaignStatus status) {
        (,,,,,,,,, status,,,) = campaign.getCampaign(campaignId);
    }

    function _totalContributedOf(uint256 campaignId) internal view returns (uint256 v) {
        (,,, v,,,,,,,,,) = campaign.getCampaign(campaignId);
    }

    function _contributorCountOf(uint256 campaignId) internal view returns (uint256) {
        return campaign.getContributorCount(campaignId);
    }

    function _pool(uint256 campaignId) internal view returns (uint256 refundPool) {
        (, refundPool,,,,,) = campaign.getRefundAccounting(campaignId);
    }

    function _stream(uint256 campaignId, address supporter)
        internal
        view
        returns (
            uint256 deposit,
            uint256 rate,
            uint256 startTime,
            uint256 claimed,
            bool cancelled,
            uint256 cancelledAt,
            uint256 accrued,
            uint256 creatorClaimable,
            uint256 supporterRecoverable
        )
    {
        return campaign.getPatronageStream(campaignId, supporter);
    }

    function _startStream(uint256 campaignId, address supporter, uint256 deposit, uint256 rate) internal {
        vm.prank(supporter);
        campaign.startPatronage(campaignId, deposit, rate);
    }

    function _failByFundingExpiry(uint256 campaignId, uint256 fundingDeadline) internal {
        vm.warp(fundingDeadline);
        campaign.triggerFundingExpiry(campaignId);
    }

    // ==================== STARTING PATRONAGE ====================

    function test_startPatronage_onActiveCampaign_succeeds() public {
        uint256 campaignId = _createActiveCampaign();

        vm.expectEmit(true, true, false, true);
        emit AdvantageAsymmetryCampaign.PatronageStarted(campaignId, supporterB, 100 ether, 3, block.timestamp);
        _startStream(campaignId, supporterB, 100 ether, 3);

        (uint256 deposit, uint256 rate, uint256 startTime, uint256 claimed, bool cancelled,,,,) =
            _stream(campaignId, supporterB);
        assertEq(deposit, 100 ether);
        assertEq(rate, 3);
        assertEq(startTime, block.timestamp);
        assertEq(claimed, 0);
        assertFalse(cancelled);
    }

    function test_startPatronage_revertsDuringFunding() public {
        uint256 campaignId = _createFundingCampaign();

        vm.prank(supporterB);
        vm.expectRevert("campaign not active");
        campaign.startPatronage(campaignId, 100 ether, 1);
    }

    function test_startPatronage_revertsAfterFailed() public {
        uint256 campaignId = _createFundingCampaign();
        _failByFundingExpiry(campaignId, block.timestamp + 7 days);

        vm.prank(supporterB);
        vm.expectRevert("campaign not active");
        campaign.startPatronage(campaignId, 100 ether, 1);
    }

    function test_startPatronage_revertsAfterSucceeded() public {
        uint256 campaignId = _createActiveCampaign();
        vm.prank(creator);
        campaign.submitMilestone(campaignId, 0, "ipfs://1");
        campaign.approveMilestone(campaignId, 0);
        vm.prank(creator);
        campaign.submitMilestone(campaignId, 1, "ipfs://2");
        campaign.approveMilestone(campaignId, 1); // Succeeded

        vm.prank(supporterB);
        vm.expectRevert("campaign not active");
        campaign.startPatronage(campaignId, 100 ether, 1);
    }

    function test_startPatronage_revertsOnZeroDeposit() public {
        uint256 campaignId = _createActiveCampaign();
        vm.prank(supporterB);
        vm.expectRevert("deposit must be > 0");
        campaign.startPatronage(campaignId, 0, 1);
    }

    function test_startPatronage_revertsOnZeroRate() public {
        uint256 campaignId = _createActiveCampaign();
        vm.prank(supporterB);
        vm.expectRevert("rate must be > 0");
        campaign.startPatronage(campaignId, 100 ether, 0);
    }

    /// @notice Section 7.9: "rate is explicitly bounded by the deposit." A rate exceeding
    ///         the deposit would let the creator's entitlement exceed what was ever escrowed
    ///         within a single second, which is exactly what the deposit cap exists to
    ///         prevent -- reject it at creation rather than relying on the accrual cap alone.
    function test_startPatronage_revertsWhenRateExceedsDeposit() public {
        uint256 campaignId = _createActiveCampaign();
        vm.prank(supporterB);
        vm.expectRevert("rate exceeds deposit");
        campaign.startPatronage(campaignId, 100, 101);
    }

    /// @notice Boundary check: rate == deposit is the maximum allowed, not rejected.
    function test_startPatronage_allowsRateEqualToDeposit() public {
        uint256 campaignId = _createActiveCampaign();
        _startStream(campaignId, supporterB, 100, 100);
        (uint256 deposit, uint256 rate,,,,,,,) = _stream(campaignId, supporterB);
        assertEq(deposit, 100);
        assertEq(rate, 100);
    }

    function test_startPatronage_revertsForCreator() public {
        uint256 campaignId = _createActiveCampaign();
        vm.prank(creator);
        vm.expectRevert("creator cannot patronise own campaign");
        campaign.startPatronage(campaignId, 100 ether, 1);
    }

    function test_startPatronage_revertsForVerifier() public {
        uint256 campaignId = _createActiveCampaign();
        vm.expectRevert("verifier cannot patronise");
        campaign.startPatronage(campaignId, 100 ether, 1);
    }

    function test_startPatronage_revertsForPenaltySink() public {
        uint256 campaignId = _createActiveCampaign();
        vm.prank(penaltySink);
        vm.expectRevert("penalty sink cannot patronise");
        campaign.startPatronage(campaignId, 100 ether, 1);
    }

    function test_startPatronage_allowsNonContributorExternalWallet() public {
        uint256 campaignId = _createActiveCampaign();
        // stranger never contributed during funding at all
        assertEq(campaign.contributions(campaignId, stranger), 0);

        _startStream(campaignId, stranger, 50 ether, 2);
        (uint256 deposit,,,,,,,,) = _stream(campaignId, stranger);
        assertEq(deposit, 50 ether);
    }

    function test_startPatronage_revertsOnDuplicateStream() public {
        uint256 campaignId = _createActiveCampaign();
        _startStream(campaignId, supporterB, 50 ether, 2);

        vm.prank(supporterB);
        vm.expectRevert("existing patronage stream");
        campaign.startPatronage(campaignId, 10 ether, 1);
    }

    function test_startPatronage_sameSupporterDifferentCampaigns_independent() public {
        uint256 campaignId1 = _createActiveCampaign();
        uint256 campaignId2 = _createActiveCampaign();

        _startStream(campaignId1, supporterB, 40 ether, 2);
        _startStream(campaignId2, supporterB, 90 ether, 5);

        (uint256 d1,,,,,,,,) = _stream(campaignId1, supporterB);
        (uint256 d2,,,,,,,,) = _stream(campaignId2, supporterB);
        assertEq(d1, 40 ether);
        assertEq(d2, 90 ether);
    }

    function test_startPatronage_transfersExactDeposit() public {
        uint256 campaignId = _createActiveCampaign();
        uint256 supporterBalBefore = token.balanceOf(supporterB);
        uint256 contractBalBefore = token.balanceOf(address(campaign));

        _startStream(campaignId, supporterB, 77 ether, 4);

        assertEq(token.balanceOf(supporterB), supporterBalBefore - 77 ether);
        assertEq(token.balanceOf(address(campaign)), contractBalBefore + 77 ether);
    }

    /// @notice Regression test: getPatronageStream() must return a zero snapshot for a
    ///         wallet that has never opened a stream, rather than reverting. Before the fix,
    ///         an empty slot has deposit == 0 and ratePerSecond == 0, and falling through to
    ///         _accruedPatronage() would divide by ratePerSecond and panic.
    function test_getPatronageStream_nonexistentStream_returnsZeroSnapshot_doesNotRevert() public {
        uint256 campaignId = _createActiveCampaign();

        // stranger has never called startPatronage on this campaign at all.
        (
            uint256 deposit,
            uint256 rate,
            uint256 startTime,
            uint256 claimed,
            bool cancelled,
            uint256 cancelledAt,
            uint256 accrued,
            uint256 creatorClaimable,
            uint256 supporterRecoverable
        ) = _stream(campaignId, stranger); // must NOT revert

        assertEq(deposit, 0);
        assertEq(rate, 0);
        assertEq(startTime, 0);
        assertEq(claimed, 0);
        assertFalse(cancelled);
        assertEq(cancelledAt, 0);
        assertEq(accrued, 0);
        assertEq(creatorClaimable, 0);
        assertEq(supporterRecoverable, 0);

        assertFalse(campaign.hasPatronageStream(campaignId, stranger));
        assertEq(campaign.claimablePatronage(campaignId, stranger), 0, "claimablePatronage must also not revert");
    }

    /// @notice Same regression, but after time has passed and on a campaign that has since
    ///         failed, to confirm the zero-snapshot branch is checked before any cutoff or
    ///         accrual logic runs, for every campaign state.
    function test_getPatronageStream_nonexistentStream_stillSafeAfterFailure() public {
        uint256 campaignId = _createFundingCampaign();
        _failByFundingExpiry(campaignId, block.timestamp + 7 days);

        (uint256 deposit,,,,,,,,) = _stream(campaignId, stranger); // must NOT revert
        assertEq(deposit, 0);
    }

    function test_startPatronage_revertsWhenPaused() public {
        uint256 campaignId = _createActiveCampaign();
        campaign.pause();
        vm.prank(supporterB);
        vm.expectRevert();
        campaign.startPatronage(campaignId, 10 ether, 1);
    }

    function test_startPatronage_revertsOnNonexistentCampaign() public {
        vm.prank(supporterB);
        vm.expectRevert("campaign does not exist");
        campaign.startPatronage(999, 10 ether, 1);
    }

    // ==================== ACCOUNTING SEPARATION AT START ====================

    function test_startPatronage_doesNotAlterContributionOrRefundAccounting() public {
        uint256 campaignId = _createActiveCampaign();
        uint256 contributedBefore = _totalContributedOf(campaignId);
        uint256 countBefore = _contributorCountOf(campaignId);

        _startStream(campaignId, supporterB, 60 ether, 3);

        assertEq(_totalContributedOf(campaignId), contributedBefore, "totalContributed unaffected by patronage");
        assertEq(_contributorCountOf(campaignId), countBefore, "contributorCount unaffected by patronage");
        assertEq(campaign.contributions(campaignId, supporterB), 0, "patronage is not a campaign contribution");
    }

    // ==================== ACCRUAL CALCULATION ====================

    function test_accrual_zeroImmediatelyAtStart() public {
        uint256 campaignId = _createActiveCampaign();
        _startStream(campaignId, supporterB, 100 ether, 3);

        assertEq(campaign.claimablePatronage(campaignId, supporterB), 0);
    }

    function test_accrual_linearAfterKnownElapsedTime() public {
        uint256 campaignId = _createActiveCampaign();
        _startStream(campaignId, supporterB, 100 ether, 3);

        skip(10);
        assertEq(campaign.claimablePatronage(campaignId, supporterB), 30);
    }

    function test_accrual_neverExceedsDeposit() public {
        uint256 campaignId = _createActiveCampaign();
        _startStream(campaignId, supporterB, 100, 3);

        skip(1000); // 3000 > 100
        (,,,,,, uint256 accrued,,) = _stream(campaignId, supporterB);
        assertEq(accrued, 100, "capped at deposit");
    }

    function test_accrual_adversariallyLargeElapsed_noOverflow() public {
        uint256 campaignId = _createActiveCampaign();
        _startStream(campaignId, supporterB, 1_000 ether, 1);

        vm.warp(type(uint256).max - 1); // enormous elapsed
        (,,,,,, uint256 accrued,,) = _stream(campaignId, supporterB);
        assertEq(accrued, 1_000 ether, "must not overflow, must cap at deposit");
    }

    /// @notice With ratePerSecond now bounded by deposit at creation (Section 7.9), the
    ///         adversarial case shifts from "rate exceeds deposit" (no longer constructible)
    ///         to "rate equals the maximum allowed value, deposit itself very large" -- the
    ///         multiplication in _accruedPatronage() must still never overflow or exceed
    ///         deposit even at that ceiling.
    function test_accrual_maximalAllowedRate_noOverflowAndCappedAtDeposit() public {
        uint256 campaignId = _createActiveCampaign();
        uint256 deposit = type(uint128).max; // very large but valid deposit
        token.mint(supporterB, deposit);
        vm.prank(supporterB);
        token.approve(address(campaign), deposit);
        _startStream(campaignId, supporterB, deposit, deposit); // rate == deposit, the ceiling

        skip(2); // elapsed=2, naive elapsed*rate would overflow well past deposit
        (,,,,,, uint256 accrued,,) = _stream(campaignId, supporterB);
        assertEq(accrued, deposit, "must not overflow, must cap at deposit");
    }

    function testFuzz_accrual_neverExceedsDeposit(uint256 deposit, uint256 rate, uint256 elapsed) public {
        deposit = bound(deposit, 1, type(uint128).max);
        rate = bound(rate, 1, deposit); // Section 7.9: rate must be <= deposit
        elapsed = bound(elapsed, 0, type(uint256).max - block.timestamp - 1);

        uint256 campaignId = _createActiveCampaign();
        token.mint(supporterB, deposit);
        vm.prank(supporterB);
        token.approve(address(campaign), deposit);
        _startStream(campaignId, supporterB, deposit, rate);

        skip(elapsed);
        (,,,,,, uint256 accrued,,) = _stream(campaignId, supporterB);
        assertLe(accrued, deposit, "0 <= accrued <= deposit");
    }

    // ==================== CREATOR CLAIMS ====================

    function test_claimPatronage_onlyCreator() public {
        uint256 campaignId = _createActiveCampaign();
        _startStream(campaignId, supporterB, 100 ether, 3);
        skip(10);

        vm.prank(supporterB);
        vm.expectRevert("only creator claims");
        campaign.claimPatronage(campaignId, supporterB);
    }

    function test_claimPatronage_cannotClaimMoreThanAccrued() public {
        uint256 campaignId = _createActiveCampaign();
        _startStream(campaignId, supporterB, 100, 3);
        skip(10); // accrued 30

        uint256 creatorBalBefore = token.balanceOf(creator);
        vm.prank(creator);
        campaign.claimPatronage(campaignId, supporterB);
        assertEq(token.balanceOf(creator), creatorBalBefore + 30);

        // Nothing further accrued in the same block -> nothing claimable.
        vm.prank(creator);
        vm.expectRevert("nothing to claim");
        campaign.claimPatronage(campaignId, supporterB);
    }

    function test_claimPatronage_repeatedClaims_payOnlyIncrementalAccrual() public {
        uint256 campaignId = _createActiveCampaign();
        _startStream(campaignId, supporterB, 100, 3);

        skip(10); // accrued 30
        uint256 got1 = _claimAndReturn(campaignId, supporterB);
        assertEq(got1, 30);

        skip(5); // total accrued 45
        uint256 got2 = _claimAndReturn(campaignId, supporterB);
        assertEq(got2, 15, "only the incremental 15, not the full 45 again");

        (,,, uint256 claimed,,,,,) = _stream(campaignId, supporterB);
        assertEq(claimed, 45);
    }

    function test_claimPatronage_aggregateNeverExceedsDeposit() public {
        uint256 campaignId = _createActiveCampaign();
        _startStream(campaignId, supporterB, 100, 3);

        skip(1000); // way past full accrual
        uint256 got = _claimAndReturn(campaignId, supporterB);
        assertEq(got, 100);

        vm.prank(creator);
        vm.expectRevert("nothing to claim");
        campaign.claimPatronage(campaignId, supporterB);

        (,,, uint256 claimed,,,,,) = _stream(campaignId, supporterB);
        assertEq(claimed, 100, "claimed never exceeds deposit");
    }

    function test_claimPatronage_revertsWhenNothingClaimable() public {
        uint256 campaignId = _createActiveCampaign();
        _startStream(campaignId, supporterB, 100, 3);
        // no time has passed
        vm.prank(creator);
        vm.expectRevert("nothing to claim");
        campaign.claimPatronage(campaignId, supporterB);
    }

    function test_claimPatronage_revertsOnNoStream() public {
        uint256 campaignId = _createActiveCampaign();
        vm.prank(creator);
        vm.expectRevert("no patronage stream");
        campaign.claimPatronage(campaignId, supporterB);
    }

    function test_claimPatronage_revertsWhenPaused() public {
        uint256 campaignId = _createActiveCampaign();
        _startStream(campaignId, supporterB, 100, 3);
        skip(10);
        campaign.pause();

        vm.prank(creator);
        vm.expectRevert();
        campaign.claimPatronage(campaignId, supporterB);
    }

    function _claimAndReturn(uint256 campaignId, address supporter) internal returns (uint256 received) {
        uint256 before = token.balanceOf(creator);
        vm.prank(creator);
        campaign.claimPatronage(campaignId, supporter);
        received = token.balanceOf(creator) - before;
    }

    // ==================== CANCELLATION ====================

    function test_cancelPatronage_worksWhilePaused() public {
        uint256 campaignId = _createActiveCampaign();
        _startStream(campaignId, supporterB, 100, 3);
        skip(10);
        campaign.pause();

        vm.prank(supporterB);
        campaign.cancelPatronage(campaignId); // must NOT revert
        (,,,, bool cancelled,,,,) = _stream(campaignId, supporterB);
        assertTrue(cancelled);
    }

    function test_cancelPatronage_activeCampaign_paysAccruedRefundsUnaccrued() public {
        uint256 campaignId = _createActiveCampaign();
        _startStream(campaignId, supporterB, 100, 3);
        skip(10); // accrued 30

        uint256 creatorBalBefore = token.balanceOf(creator);
        uint256 supporterBalBefore = token.balanceOf(supporterB);

        vm.prank(supporterB);
        campaign.cancelPatronage(campaignId);

        assertEq(token.balanceOf(creator), creatorBalBefore + 30, "creator receives accrued");
        assertEq(token.balanceOf(supporterB), supporterBalBefore + 70, "supporter recovers unaccrued");
    }

    function test_cancelPatronage_afterPartialClaim_settlesOnlyRemainingAccrued() public {
        uint256 campaignId = _createActiveCampaign();
        _startStream(campaignId, supporterB, 100, 3);

        skip(10); // accrued 30
        vm.prank(creator);
        campaign.claimPatronage(campaignId, supporterB); // creator takes 30, claimed=30

        skip(5); // total accrued 45
        uint256 creatorBalBefore = token.balanceOf(creator);
        uint256 supporterBalBefore = token.balanceOf(supporterB);

        vm.prank(supporterB);
        campaign.cancelPatronage(campaignId);

        assertEq(token.balanceOf(creator), creatorBalBefore + 15, "only the unclaimed remainder (45-30)");
        assertEq(token.balanceOf(supporterB), supporterBalBefore + 55, "unaccrued portion (100-45)");
    }

    function test_cancelPatronage_cannotHappenTwice() public {
        uint256 campaignId = _createActiveCampaign();
        _startStream(campaignId, supporterB, 100, 3);
        skip(10);

        vm.prank(supporterB);
        campaign.cancelPatronage(campaignId);

        vm.prank(supporterB);
        vm.expectRevert("stream already cancelled");
        campaign.cancelPatronage(campaignId);
    }

    function test_cancelPatronage_onlyBySupporter() public {
        uint256 campaignId = _createActiveCampaign();
        _startStream(campaignId, supporterB, 100, 3);

        // Someone else has no stream for this campaign at all.
        vm.prank(stranger);
        vm.expectRevert("no patronage stream");
        campaign.cancelPatronage(campaignId);
    }

    function test_creatorCannotClaimAfterCancellation() public {
        uint256 campaignId = _createActiveCampaign();
        _startStream(campaignId, supporterB, 100, 3);
        skip(10);

        vm.prank(supporterB);
        campaign.cancelPatronage(campaignId);

        vm.expectRevert("stream cancelled");
        vm.prank(creator);
        campaign.claimPatronage(campaignId, supporterB);
    }

    function test_fullyAccruedCancellation_returnsZeroToSupporter_doesNotOverpayCreator() public {
        uint256 campaignId = _createActiveCampaign();
        _startStream(campaignId, supporterB, 100, 3);
        skip(1000); // fully accrued

        uint256 creatorBalBefore = token.balanceOf(creator);
        uint256 supporterBalBefore = token.balanceOf(supporterB);

        vm.prank(supporterB);
        campaign.cancelPatronage(campaignId);

        assertEq(token.balanceOf(creator), creatorBalBefore + 100, "creator gets the full deposit");
        assertEq(token.balanceOf(supporterB), supporterBalBefore, "supporter gets nothing back");
    }

    /// @notice Direct regression test for the V0 cancellation-stranding bug: cancelling
    ///         must never leave accrued-but-unclaimed creator entitlement unreachable.
    function test_regression_V0CancellationStrandingBug_doesNotReproduce() public {
        uint256 campaignId = _createActiveCampaign();
        _startStream(campaignId, supporterB, 100, 3);
        skip(10); // accrued 30, nothing claimed yet

        uint256 creatorBalBefore = token.balanceOf(creator);
        vm.prank(supporterB);
        campaign.cancelPatronage(campaignId);

        // In V0: cancellation would have refunded only the unaccrued portion (70), marked
        // cancelled, and claimablePatronage() would then return 0 forever -- stranding the
        // 30 units of legitimately accrued creator entitlement inside the contract with no
        // way to reach it. V1.1 must have already paid it out atomically during cancellation.
        assertEq(token.balanceOf(creator), creatorBalBefore + 30, "accrued entitlement paid during cancellation");
        (,,, uint256 claimed, bool cancelled,, uint256 accrued, uint256 creatorClaimable,) =
            _stream(campaignId, supporterB);
        assertTrue(cancelled);
        assertEq(claimed, 30);
        assertEq(accrued, 30);
        assertEq(creatorClaimable, 0, "nothing left unreachable");

        // And a post-cancellation creator claim attempt correctly reverts rather than
        // silently returning 0 forever -- the entitlement is gone because it was PAID, not
        // because it is stuck.
        vm.expectRevert("stream cancelled");
        vm.prank(creator);
        campaign.claimPatronage(campaignId, supporterB);
    }

    // ==================== MANUAL SANITY CASE (100 / rate 3) ====================

    /// @notice Reproduction of the brief's scenario faithful to the actual API: deposit=100,
    ///         rate=3/sec. claimPatronage() is intentionally claim-all -- it always pays the
    ///         full currently-claimable amount, not an arbitrary caller-chosen sub-amount --
    ///         so this exercises the real entry point rather than an illustrative partial
    ///         claim the ABI does not support.
    ///
    ///         At t=10: accrued=30, creator claims the full 30 (claimed=30).
    ///         At t=15: total accrued=45. Supporter cancels: creatorDue = 45-30 = 15,
    ///         supporterRefund = 100-45 = 55.
    ///         Conservation: 30 (already claimed) + 15 (cancellation) + 55 (refund) = 100.
    function test_manualSanity_100deposit_3rate_claimThenCancel() public {
        uint256 campaignId = _createActiveCampaign();
        _startStream(campaignId, supporterB, 100, 3);

        skip(10); // accrued = 30
        (,,,,,, uint256 accruedAt10,,) = _stream(campaignId, supporterB);
        assertEq(accruedAt10, 30);

        uint256 creatorBalBefore = token.balanceOf(creator);
        vm.prank(creator);
        campaign.claimPatronage(campaignId, supporterB); // creator claims the full 30 accrued
        assertEq(token.balanceOf(creator), creatorBalBefore + 30);

        skip(5); // additional 5s -> total elapsed 15, accrued 45
        (,,,,,, uint256 accruedAt15,,) = _stream(campaignId, supporterB);
        assertEq(accruedAt15, 45);

        uint256 creatorBalBeforeCancel = token.balanceOf(creator);
        uint256 supporterBalBeforeCancel = token.balanceOf(supporterB);

        vm.prank(supporterB);
        campaign.cancelPatronage(campaignId);

        uint256 creatorReceivedOnCancel = token.balanceOf(creator) - creatorBalBeforeCancel;
        uint256 supporterRefund = token.balanceOf(supporterB) - supporterBalBeforeCancel;

        assertEq(creatorReceivedOnCancel, 15, "45 accrued - 30 already claimed = 15");
        assertEq(supporterRefund, 55, "100 deposit - 45 accrued = 55");
        assertEq(30 + creatorReceivedOnCancel + supporterRefund, 100, "30 + 15 + 55 == 100");
    }

    /// @notice Failure variant of the manual sanity case: same stream, campaign fails at
    ///         second 12 (accrued freezes at 12*3=36), then time advances to second 100 --
    ///         accrued must remain frozen at 36.
    function test_manualSanity_failureVariant_freezesAt12Seconds() public {
        uint256 campaignId = _createActiveCampaign();
        _startStream(campaignId, supporterB, 1_000, 3); // large deposit so the cap never binds

        skip(12); // 12 seconds since stream start

        // Fail the campaign at exactly second 12 via milestone rejection (creator submitted,
        // verifier rejects) so failureTimestamp == streamStart + 12.
        vm.prank(creator);
        campaign.submitMilestone(campaignId, 0, "ipfs://m1");
        campaign.rejectMilestone(campaignId, 0);
        assertEq(uint8(_statusOf(campaignId)), uint8(AdvantageAsymmetryCampaign.CampaignStatus.Failed));

        (,,,,,, uint256 accruedAt12,,) = _stream(campaignId, supporterB);
        assertEq(accruedAt12, 36, "12 * 3 = 36 at the moment of failure");

        // Warp far beyond failure: 88 more seconds reaches streamStart + 100 in total.
        skip(88);
        (,,,,,, uint256 accruedAt100,,) = _stream(campaignId, supporterB);
        assertEq(accruedAt100, 36, "frozen at the failure cutoff, not 100*3=300 and not re-derived");
        assertEq(campaign.claimablePatronage(campaignId, supporterB), 36);
    }

    // ==================== FAILURE FREEZES ACCRUAL ====================

    function test_failure_freezesAccrualExactlyAtFailureTimestamp() public {
        uint256 campaignId = _createActiveCampaign();
        _startStream(campaignId, supporterB, 1_000, 3);

        skip(20);
        vm.prank(creator);
        campaign.submitMilestone(campaignId, 0, "ipfs://m1");
        campaign.rejectMilestone(campaignId, 0); // fails 20 seconds after stream start

        (,,,,,, uint256 accrued,,) = _stream(campaignId, supporterB);
        assertEq(accrued, 60); // 20*3
    }

    function test_failure_warpingFarBeyond_doesNotIncreaseClaimable() public {
        uint256 campaignId = _createActiveCampaign();
        _startStream(campaignId, supporterB, 1_000, 3);
        skip(20);
        vm.prank(creator);
        campaign.submitMilestone(campaignId, 0, "ipfs://m1");
        campaign.rejectMilestone(campaignId, 0);

        uint256 claimableRightAfter = campaign.claimablePatronage(campaignId, supporterB);
        skip(365 days);
        uint256 claimableMuchLater = campaign.claimablePatronage(campaignId, supporterB);

        assertEq(claimableRightAfter, claimableMuchLater, "must not increase after failure");
        assertEq(claimableMuchLater, 60);
    }

    function test_cancellationAfterFailure_paysOnlyPreFailureAccrued() public {
        uint256 campaignId = _createActiveCampaign();
        _startStream(campaignId, supporterB, 1_000, 3);
        skip(20);
        vm.prank(creator);
        campaign.submitMilestone(campaignId, 0, "ipfs://m1");
        campaign.rejectMilestone(campaignId, 0); // fails, accrued frozen at 60

        skip(365 days); // long after failure

        uint256 creatorBalBefore = token.balanceOf(creator);
        uint256 supporterBalBefore = token.balanceOf(supporterB);

        vm.prank(supporterB);
        campaign.cancelPatronage(campaignId);

        assertEq(token.balanceOf(creator), creatorBalBefore + 60, "only pre-failure accrued value");
        assertEq(token.balanceOf(supporterB), supporterBalBefore + 940, "1000 - 60 unaccrued/post-failure balance");
    }

    function test_creatorCanClaimPreFailureAccrual_afterFailure_whenNotPaused() public {
        uint256 campaignId = _createActiveCampaign();
        _startStream(campaignId, supporterB, 1_000, 3);
        skip(20);
        vm.prank(creator);
        campaign.submitMilestone(campaignId, 0, "ipfs://m1");
        campaign.rejectMilestone(campaignId, 0); // fails, accrued frozen at 60

        uint256 creatorBalBefore = token.balanceOf(creator);
        vm.prank(creator);
        campaign.claimPatronage(campaignId, supporterB); // not paused -> must succeed
        assertEq(token.balanceOf(creator), creatorBalBefore + 60);
    }

    // ==================== SUCCESS DOES NOT FREEZE ====================

    function test_success_doesNotFreezeExistingStream() public {
        uint256 campaignId = _createActiveCampaign();
        _startStream(campaignId, supporterB, 1_000, 3);
        skip(10);

        vm.prank(creator);
        campaign.submitMilestone(campaignId, 0, "ipfs://1");
        campaign.approveMilestone(campaignId, 0);
        vm.prank(creator);
        campaign.submitMilestone(campaignId, 1, "ipfs://2");
        campaign.approveMilestone(campaignId, 1); // Succeeded
        assertEq(uint8(_statusOf(campaignId)), uint8(AdvantageAsymmetryCampaign.CampaignStatus.Succeeded));

        (,,,,,, uint256 accruedAtSuccess,,) = _stream(campaignId, supporterB);
        assertEq(accruedAtSuccess, 30); // 10*3, still ticking at the moment of success

        skip(10); // 10 more seconds AFTER success
        (,,,,,, uint256 accruedAfter,,) = _stream(campaignId, supporterB);
        assertEq(accruedAfter, 60, "continues accruing after success, unlike failure");
    }

    function test_success_noNewStreamMayBegin() public {
        uint256 campaignId = _createActiveCampaign();
        vm.prank(creator);
        campaign.submitMilestone(campaignId, 0, "ipfs://1");
        campaign.approveMilestone(campaignId, 0);
        vm.prank(creator);
        campaign.submitMilestone(campaignId, 1, "ipfs://2");
        campaign.approveMilestone(campaignId, 1); // Succeeded

        vm.prank(supporterB);
        vm.expectRevert("campaign not active");
        campaign.startPatronage(campaignId, 10 ether, 1);
    }

    // ==================== FULL LIFECYCLE ACROSS SUCCESS ====================

    function test_fullLifecycle_claimAfterSuccess_thenCancelLater() public {
        uint256 campaignId = _createActiveCampaign();
        _startStream(campaignId, supporterB, 1_000, 3);
        skip(10); // accrued 30

        vm.prank(creator);
        campaign.submitMilestone(campaignId, 0, "ipfs://1");
        campaign.approveMilestone(campaignId, 0);
        vm.prank(creator);
        campaign.submitMilestone(campaignId, 1, "ipfs://2");
        campaign.approveMilestone(campaignId, 1); // Succeeded

        uint256 creatorBalBefore = token.balanceOf(creator);
        vm.prank(creator);
        campaign.claimPatronage(campaignId, supporterB); // settles the 30 post-success
        assertEq(token.balanceOf(creator), creatorBalBefore + 30);

        skip(90); // 90 more seconds -> total elapsed 100, accrued 300
        uint256 creatorBalBefore2 = token.balanceOf(creator);
        uint256 supporterBalBefore2 = token.balanceOf(supporterB);

        vm.prank(supporterB);
        campaign.cancelPatronage(campaignId);

        // accrued at cancel = elapsed(100)*3 = 300; already claimed 30 -> creatorDue 270;
        // supporterRefund = 1000 - 300 = 700.
        assertEq(token.balanceOf(creator), creatorBalBefore2 + 270);
        assertEq(token.balanceOf(supporterB), supporterBalBefore2 + 700);
    }

    // ==================== CROSS-ACCOUNTING ISOLATION ====================

    function test_patronageCannotAlterRefundPoolOrAccounting() public {
        uint256 campaignId = _createActiveCampaign();
        vm.prank(creator);
        campaign.submitMilestone(campaignId, 0, "ipfs://1");
        campaign.approveMilestone(campaignId, 0); // 40 released

        // Open, partially accrue, and claim a patronage stream on this same campaign.
        _startStream(campaignId, supporterB, 500, 5);
        skip(4);
        vm.prank(creator);
        campaign.claimPatronage(campaignId, supporterB); // creator receives 20 patronage units

        // Now fail the campaign and confirm refund accounting is exactly what Day 2 alone
        // would have produced -- patronage activity must not have touched it.
        vm.prank(creator);
        campaign.submitMilestone(campaignId, 1, "ipfs://2");
        campaign.rejectMilestone(campaignId, 1);

        assertEq(_pool(campaignId), GOAL - MILESTONE_1, "refundPool unaffected by patronage claim");
        assertEq(_totalContributedOf(campaignId), GOAL, "totalContributed unaffected by patronage");

        uint256 supporterABalBefore = token.balanceOf(supporterA);
        vm.prank(supporterA);
        campaign.claimRefund(campaignId);
        assertEq(
            token.balanceOf(supporterA), supporterABalBefore + (GOAL - MILESTONE_1), "full pool, patronage-independent"
        );
    }

    function test_refundOperationsCannotAlterPatronageStreamAccounting() public {
        uint256 campaignId = _createActiveCampaign();
        _startStream(campaignId, supporterB, 500, 5);
        skip(4); // accrued 20

        vm.prank(creator);
        campaign.submitMilestone(campaignId, 0, "ipfs://1");
        campaign.rejectMilestone(campaignId, 0); // fails; refund pool becomes claimable

        (,,,,,, uint256 accruedBeforeRefundClaim,,) = _stream(campaignId, supporterB);

        vm.prank(supporterA);
        campaign.claimRefund(campaignId); // supporter refund claim happens

        (,,,,,, uint256 accruedAfterRefundClaim,,) = _stream(campaignId, supporterB);
        assertEq(accruedAfterRefundClaim, accruedBeforeRefundClaim, "refund claim does not touch patronage stream");
    }

    function test_patronageInCampaignA_doesNotAffectCampaignB() public {
        uint256 idA = _createActiveCampaign();
        uint256 idB = _createActiveCampaign();

        _startStream(idA, supporterB, 100, 3);
        _startStream(idB, supporterB, 200, 7);

        skip(10);

        (,,,,,, uint256 accA,,) = _stream(idA, supporterB);
        (,,,,,, uint256 accB,,) = _stream(idB, supporterB);
        assertEq(accA, 30);
        assertEq(accB, 70);

        vm.prank(supporterB);
        campaign.cancelPatronage(idA);

        (,,,, bool cancelledA,,,,) = _stream(idA, supporterB);
        (,,,, bool cancelledB,,,,) = _stream(idB, supporterB);
        assertTrue(cancelledA);
        assertFalse(cancelledB, "cancelling A's stream must not touch B's stream");

        assertEq(campaign.claimablePatronage(idB, supporterB), 70, "B unaffected by A's cancellation");
    }

    function test_supporterAStream_cannotAffectSupporterBStream() public {
        uint256 campaignId = _createActiveCampaign();
        _startStream(campaignId, supporterB, 100, 3);
        _startStream(campaignId, stranger, 200, 5);

        skip(10);
        (,,,,,, uint256 accB,,) = _stream(campaignId, supporterB);
        (,,,,,, uint256 accStranger,,) = _stream(campaignId, stranger);
        assertEq(accB, 30);
        assertEq(accStranger, 50);

        vm.prank(supporterB);
        campaign.cancelPatronage(campaignId);

        (,,,,,, uint256 accStrangerAfter,,) = _stream(campaignId, stranger);
        assertEq(accStrangerAfter, 50, "supporterB cancelling must not affect stranger's stream");
        assertEq(campaign.claimablePatronage(campaignId, stranger), 50);
    }

    // ==================== FUZZ / PROPERTY TESTS ====================

    function testFuzz_claimedNeverExceedsAccruedNeverExceedsDeposit(
        uint256 deposit,
        uint256 rate,
        uint256 elapsed1,
        uint256 elapsed2
    ) public {
        deposit = bound(deposit, 1, type(uint128).max);
        rate = bound(rate, 1, deposit); // Section 7.9: rate must be <= deposit
        elapsed1 = bound(elapsed1, 0, 1e12);
        elapsed2 = bound(elapsed2, 0, 1e12);

        uint256 campaignId = _createActiveCampaign();
        token.mint(supporterB, deposit);
        vm.prank(supporterB);
        token.approve(address(campaign), deposit);
        _startStream(campaignId, supporterB, deposit, rate);

        skip(elapsed1);
        (,,,,,, uint256 accrued1,,) = _stream(campaignId, supporterB);
        assertLe(accrued1, deposit);
        if (accrued1 > 0) {
            vm.prank(creator);
            campaign.claimPatronage(campaignId, supporterB);
        }
        (,,, uint256 claimed1,,,,,) = _stream(campaignId, supporterB);
        assertLe(claimed1, deposit);

        skip(elapsed2);
        (,,,,,, uint256 accrued2,,) = _stream(campaignId, supporterB);
        assertLe(accrued2, deposit);
        assertGe(accrued2, accrued1, "accrual is monotonic non-decreasing while live");
    }

    function testFuzz_cancellationConservation(
        uint256 deposit,
        uint256 rate,
        uint256 elapsedBeforeClaim,
        uint256 elapsedBeforeCancel
    ) public {
        deposit = bound(deposit, 1, type(uint128).max);
        rate = bound(rate, 1, deposit); // Section 7.9: rate must be <= deposit
        elapsedBeforeClaim = bound(elapsedBeforeClaim, 0, 1e9);
        elapsedBeforeCancel = bound(elapsedBeforeCancel, 0, 1e9);

        uint256 campaignId = _createActiveCampaign();
        token.mint(supporterB, deposit);
        vm.prank(supporterB);
        token.approve(address(campaign), deposit);
        _startStream(campaignId, supporterB, deposit, rate);

        uint256 cumulativeCreatorReceipts;

        skip(elapsedBeforeClaim);
        uint256 claimable = campaign.claimablePatronage(campaignId, supporterB);
        if (claimable > 0) {
            uint256 before = token.balanceOf(creator);
            vm.prank(creator);
            campaign.claimPatronage(campaignId, supporterB);
            cumulativeCreatorReceipts += token.balanceOf(creator) - before;
        }

        skip(elapsedBeforeCancel);

        uint256 creatorBefore = token.balanceOf(creator);
        uint256 supporterBefore = token.balanceOf(supporterB);
        vm.prank(supporterB);
        campaign.cancelPatronage(campaignId);
        cumulativeCreatorReceipts += token.balanceOf(creator) - creatorBefore;
        uint256 supporterRefund = token.balanceOf(supporterB) - supporterBefore;

        assertEq(cumulativeCreatorReceipts + supporterRefund, deposit, "conservation: receipts + refund == deposit");
    }

    function testFuzz_overflowResistance_timeRateCombinations(uint256 deposit, uint256 rate, uint256 elapsed) public {
        deposit = bound(deposit, 1, type(uint256).max / 2);
        rate = bound(rate, 1, deposit); // Section 7.9: rate must be <= deposit
        elapsed = bound(elapsed, 0, type(uint256).max / 2);

        uint256 campaignId = _createActiveCampaign();
        token.mint(supporterB, deposit);
        vm.prank(supporterB);
        token.approve(address(campaign), deposit);
        _startStream(campaignId, supporterB, deposit, rate);

        // Must not revert (no overflow) regardless of how large elapsed/rate are, and must
        // stay within [0, deposit].
        skip(elapsed);
        uint256 accrued = campaign.claimablePatronage(campaignId, supporterB);
        assertLe(accrued, deposit);
    }
}
