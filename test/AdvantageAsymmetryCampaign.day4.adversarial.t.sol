// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../contracts/AdvantageAsymmetryCampaign.sol";
import "./mocks/MockERC20.sol";
import "./mocks/HostileTokens.sol";

/// @notice Day 4 targeted adversarial tests. Complements the stateful invariant suite with
///         deliberately invalid/unauthorised actions, cross-campaign interference attempts,
///         pause/exit checks, reentrancy probing, and explicit token-model boundary tests.
contract AdvantageAsymmetryCampaignDay4AdversarialTest is Test {
    AdvantageAsymmetryCampaign campaign;
    MockERC20 token;

    address verifier = address(this);
    address penaltySink = address(0xBEEF);
    address creatorA = address(0xCA);
    address creatorB = address(0xCB);
    address supporter1 = address(0x51);
    address supporter2 = address(0x52);
    address outsider = address(0x0177);

    uint256 constant GOAL = 100 ether;
    uint256 constant BOND = 10 ether;

    function setUp() public {
        token = new MockERC20();
        campaign = new AdvantageAsymmetryCampaign(address(token), penaltySink);

        address[6] memory funded = [creatorA, creatorB, supporter1, supporter2, outsider, penaltySink];
        for (uint256 i = 0; i < funded.length; i++) {
            token.mint(funded[i], 10_000 ether);
            vm.prank(funded[i]);
            token.approve(address(campaign), type(uint256).max);
        }
        token.mint(verifier, 10_000 ether);
        token.approve(address(campaign), type(uint256).max);
    }

    // ---------- helpers ----------

    function _descs() internal pure returns (string[] memory d) {
        d = new string[](2);
        d[0] = "m1";
        d[1] = "m2";
    }

    function _amts() internal pure returns (uint256[] memory a) {
        a = new uint256[](2);
        a[0] = 40 ether;
        a[1] = 60 ether;
    }

    function _create(address creator) internal returns (uint256 id) {
        vm.prank(creator);
        id = campaign.createCampaign(GOAL, BOND, _descs(), _amts(), block.timestamp + 7 days, block.timestamp + 37 days);
    }

    function _createActive(address creator) internal returns (uint256 id) {
        id = _create(creator);
        vm.prank(supporter1);
        campaign.contribute(id, 60 ether);
        vm.prank(supporter2);
        campaign.contribute(id, 40 ether);
    }

    function _status(uint256 id) internal view returns (AdvantageAsymmetryCampaign.CampaignStatus s) {
        (,,,,,,,,, s,,,) = campaign.getCampaign(id);
    }

    function _totalContributed(uint256 id) internal view returns (uint256 v) {
        (,,, v,,,,,,,,,) = campaign.getCampaign(id);
    }

    function _totalReleased(uint256 id) internal view returns (uint256 v) {
        (,,,, v,,,,,,,,) = campaign.getCampaign(id);
    }

    function _bondOutcome(uint256 id) internal view returns (AdvantageAsymmetryCampaign.BondOutcome o) {
        (,,,,,,,,,,, o,) = campaign.getCampaign(id);
    }

    function _refundPool(uint256 id) internal view returns (uint256 v) {
        (, v,,,,,) = campaign.getRefundAccounting(id);
    }

    // ==================== ACCESS CONTROL / ROLE SEPARATION ====================

    function test_noArbitraryOwnerWithdrawal_exists() public {
        _createActive(creatorA);
        uint256 locked = token.balanceOf(address(campaign));
        assertGt(locked, 0);

        // The owner/verifier has pause/unpause/approve/reject only. There is deliberately no
        // withdraw/sweep/rescue entry point; the only owner-callable functions that move
        // tokens are milestone approval (pays the creator, a fixed pre-agreed amount) and
        // rejection (slashes the bond to the immutable sink). Neither can be directed at an
        // arbitrary recipient or amount.
        vm.prank(verifier);
        campaign.pause();
        vm.prank(verifier);
        campaign.unpause();

        assertEq(token.balanceOf(address(campaign)), locked, "owner actions moved no user funds");
        assertEq(token.balanceOf(verifier), 10_000 ether, "verifier balance unchanged");
    }

    function test_verifierCannotBecomePenaltySink_viaOwnershipMove() public {
        vm.expectRevert("verifier is fixed for this deployment");
        campaign.transferOwnership(penaltySink);
        assertEq(campaign.owner(), verifier);
        assertEq(campaign.penaltySink(), penaltySink);
    }

    function test_creatorCannotBecomeVerifier_viaOwnershipMove() public {
        vm.expectRevert("verifier is fixed for this deployment");
        campaign.transferOwnership(creatorA);
        assertEq(campaign.owner(), verifier);
    }

    function test_ownershipRenunciationDisabled_cannotOrphanVerifierRole() public {
        vm.expectRevert("verifier is fixed for this deployment");
        campaign.renounceOwnership();
        assertEq(campaign.owner(), verifier, "verifier role cannot be orphaned");
    }

    function test_outsiderCannotApproveRejectOrPause() public {
        uint256 id = _createActive(creatorA);
        vm.prank(creatorA);
        campaign.submitMilestone(id, 0, "ipfs://m1");

        vm.prank(outsider);
        vm.expectRevert();
        campaign.approveMilestone(id, 0);

        vm.prank(outsider);
        vm.expectRevert();
        campaign.rejectMilestone(id, 0);

        vm.prank(outsider);
        vm.expectRevert();
        campaign.pause();
    }

    function test_creatorCannotApproveOwnMilestone() public {
        uint256 id = _createActive(creatorA);
        vm.prank(creatorA);
        campaign.submitMilestone(id, 0, "ipfs://m1");

        vm.prank(creatorA);
        vm.expectRevert();
        campaign.approveMilestone(id, 0);
    }

    function test_nonCreatorCannotSubmitMilestone() public {
        uint256 id = _createActive(creatorA);

        vm.prank(outsider);
        vm.expectRevert("only creator");
        campaign.submitMilestone(id, 0, "ipfs://x");

        // Nor can the creator of a DIFFERENT campaign.
        vm.prank(creatorB);
        vm.expectRevert("only creator");
        campaign.submitMilestone(id, 0, "ipfs://x");
    }

    function test_onlyStreamSupporterCanCancel_andOnlyCreatorCanClaim() public {
        uint256 id = _createActive(creatorA);
        vm.prank(supporter1);
        campaign.startPatronage(id, 100, 3);
        skip(10);

        // Another supporter with no stream on this campaign cannot cancel it.
        vm.prank(supporter2);
        vm.expectRevert("no patronage stream");
        campaign.cancelPatronage(id);

        // A different campaign's creator cannot claim this stream.
        vm.prank(creatorB);
        vm.expectRevert("only creator claims");
        campaign.claimPatronage(id, supporter1);

        // The verifier cannot claim it either.
        vm.expectRevert("only creator claims");
        campaign.claimPatronage(id, supporter1);
    }

    function test_crossCampaignCreatorCannotDrainAnotherCampaignsStream() public {
        uint256 idA = _createActive(creatorA);
        uint256 idB = _createActive(creatorB);

        vm.prank(supporter1);
        campaign.startPatronage(idA, 1000, 5);
        skip(20);

        uint256 creatorBBefore = token.balanceOf(creatorB);
        vm.prank(creatorB);
        vm.expectRevert("only creator claims");
        campaign.claimPatronage(idA, supporter1);
        assertEq(token.balanceOf(creatorB), creatorBBefore, "no value leaked to the other creator");

        // And campaign B's own stream state is untouched.
        assertFalse(campaign.hasPatronageStream(idB, supporter1));
    }

    // ==================== CROSS-CAMPAIGN ISOLATION ====================

    /// @notice A succeeds while B fails, in the same block sequence, with patronage and
    ///         refunds live on both. Neither campaign's accounting may bleed into the other.
    function test_isolation_ASucceedsWhileBFails_withPatronageAndRefunds() public {
        uint256 idA = _createActive(creatorA);
        uint256 idB = _createActive(creatorB);

        // Streams on both.
        vm.prank(supporter1);
        campaign.startPatronage(idA, 1000, 5);
        vm.prank(supporter2);
        campaign.startPatronage(idB, 2000, 7);
        skip(10);

        // A runs to Succeeded.
        vm.prank(creatorA);
        campaign.submitMilestone(idA, 0, "ipfs://a1");
        campaign.approveMilestone(idA, 0);
        vm.prank(creatorA);
        campaign.submitMilestone(idA, 1, "ipfs://a2");
        campaign.approveMilestone(idA, 1);

        // B fails by rejection after one release.
        vm.prank(creatorB);
        campaign.submitMilestone(idB, 0, "ipfs://b1");
        campaign.approveMilestone(idB, 0);
        vm.prank(creatorB);
        campaign.submitMilestone(idB, 1, "ipfs://b2");
        campaign.rejectMilestone(idB, 1);

        assertEq(uint8(_status(idA)), uint8(AdvantageAsymmetryCampaign.CampaignStatus.Succeeded));
        assertEq(uint8(_status(idB)), uint8(AdvantageAsymmetryCampaign.CampaignStatus.Failed));
        assertEq(uint8(_bondOutcome(idA)), uint8(AdvantageAsymmetryCampaign.BondOutcome.Returned));
        assertEq(uint8(_bondOutcome(idB)), uint8(AdvantageAsymmetryCampaign.BondOutcome.Slashed));

        // A has no refund accounting at all; B's is exactly its own numbers.
        (,,,,,, bool aInit) = campaign.getRefundAccounting(idA);
        assertFalse(aInit, "succeeded campaign must not initialise refunds");
        assertEq(_refundPool(idB), GOAL - 40 ether);

        // Refund claims on B leave A untouched.
        uint256 aContributed = _totalContributed(idA);
        uint256 aReleased = _totalReleased(idA);
        vm.prank(supporter1);
        campaign.claimRefund(idB);
        vm.prank(supporter2);
        campaign.claimRefund(idB);
        assertEq(_totalContributed(idA), aContributed, "A totalContributed altered by B refunds");
        assertEq(_totalReleased(idA), aReleased, "A totalReleased altered by B refunds");

        // Patronage on A still accrues (A succeeded -> live clock); B's froze at failure.
        skip(10);
        assertGt(campaign.claimablePatronage(idA, supporter1), 0, "A stream should still accrue after success");
        uint256 bClaimable = campaign.claimablePatronage(idB, supporter2);
        skip(365 days);
        assertEq(campaign.claimablePatronage(idB, supporter2), bClaimable, "B stream must stay frozen at failure");
    }

    function test_isolation_refundInOneCampaignCannotConsumePatronageFunds() public {
        uint256 idA = _createActive(creatorA);

        // A large patronage deposit sits in the same contract balance as the refund pool.
        vm.prank(outsider);
        campaign.startPatronage(idA, 5000 ether, 1 ether);

        // Fail the campaign with nothing released: refundPool == GOAL.
        vm.prank(creatorA);
        campaign.submitMilestone(idA, 0, "ipfs://m1");
        campaign.rejectMilestone(idA, 0);
        assertEq(_refundPool(idA), GOAL);

        // Both supporters claim their full entitlement; the pool must cap at GOAL and must
        // not be able to reach into the patronage deposit sharing the same balance.
        uint256 s1 = token.balanceOf(supporter1);
        uint256 s2 = token.balanceOf(supporter2);
        vm.prank(supporter1);
        campaign.claimRefund(idA);
        vm.prank(supporter2);
        campaign.claimRefund(idA);
        uint256 paid = (token.balanceOf(supporter1) - s1) + (token.balanceOf(supporter2) - s2);
        assertEq(paid, GOAL, "refunds must total exactly the pool, never touching patronage");

        // The patron can still fully recover their unaccrued deposit afterwards.
        uint256 before = token.balanceOf(outsider);
        vm.prank(outsider);
        campaign.cancelPatronage(idA);
        assertGt(token.balanceOf(outsider) - before, 0, "patron still recoverable after refunds drained the pool");
    }

    function test_isolation_sameWalletDifferentRolesAcrossCampaigns() public {
        // creatorA creates campaign A, and separately patronises campaign B as a supporter.
        uint256 idA = _createActive(creatorA);
        uint256 idB = _createActive(creatorB);

        vm.prank(creatorA);
        campaign.startPatronage(idB, 500, 5); // permitted: not B's creator
        assertTrue(campaign.hasPatronageStream(idB, creatorA));

        // But still cannot patronise their own campaign.
        vm.prank(creatorA);
        vm.expectRevert("creator cannot patronise own campaign");
        campaign.startPatronage(idA, 500, 5);

        // Nor contribute to their own campaign (checked here in a multi-campaign context).
        uint256 idC = _create(creatorA);
        vm.prank(creatorA);
        vm.expectRevert("creator cannot contribute");
        campaign.contribute(idC, 1 ether);
    }

    // ==================== PAUSE / EXIT ====================

    function test_pauseCannotCreateIndefiniteFundLock_refundPathStaysOpen() public {
        uint256 id = _createActive(creatorA);
        vm.prank(creatorA);
        campaign.submitMilestone(id, 0, "ipfs://m1");
        campaign.rejectMilestone(id, 0); // Failed, refunds available

        campaign.pause();

        // Supporters can still exit while paused.
        uint256 before1 = token.balanceOf(supporter1);
        vm.prank(supporter1);
        campaign.claimRefund(id);
        assertGt(token.balanceOf(supporter1), before1, "refund must remain available while paused");
    }

    function test_pauseCannotCreateIndefiniteFundLock_patronageCancellationStaysOpen() public {
        uint256 id = _createActive(creatorA);
        vm.prank(supporter1);
        campaign.startPatronage(id, 1000, 5);
        skip(10);

        campaign.pause();

        uint256 before = token.balanceOf(supporter1);
        vm.prank(supporter1);
        campaign.cancelPatronage(id);
        assertGt(token.balanceOf(supporter1), before, "cancellation must remain available while paused");
    }

    function test_pauseCannotBlockExpiryTriggers() public {
        uint256 idFunding = _create(creatorA);
        vm.prank(supporter1);
        campaign.contribute(idFunding, 10 ether); // underfunded

        uint256 idActive = _createActive(creatorB);

        campaign.pause();
        skip(8 days); // past funding deadline
        campaign.triggerFundingExpiry(idFunding); // must not revert
        assertEq(uint8(_status(idFunding)), uint8(AdvantageAsymmetryCampaign.CampaignStatus.Failed));

        skip(40 days); // past execution deadline
        campaign.triggerExecutionExpiry(idActive); // must not revert
        assertEq(uint8(_status(idActive)), uint8(AdvantageAsymmetryCampaign.CampaignStatus.Failed));
    }

    function test_pauseBlocksAllNewRiskAndDiscretionaryRelease() public {
        uint256 id = _createActive(creatorA);
        vm.prank(creatorA);
        campaign.submitMilestone(id, 0, "ipfs://m1");

        campaign.pause();

        vm.prank(creatorB);
        vm.expectRevert();
        campaign.createCampaign(GOAL, BOND, _descs(), _amts(), block.timestamp + 7 days, block.timestamp + 37 days);

        vm.expectRevert();
        campaign.approveMilestone(id, 0);

        vm.expectRevert();
        campaign.rejectMilestone(id, 0);

        vm.prank(supporter1);
        vm.expectRevert();
        campaign.startPatronage(id, 100, 3);
    }

    function test_pauseAllowsMilestoneEvidenceSubmission() public {
        uint256 id = _createActive(creatorA);
        campaign.pause();

        // Approved design decision: evidence submission moves no funds.
        vm.prank(creatorA);
        campaign.submitMilestone(id, 0, "ipfs://evidence-while-paused");
        AdvantageAsymmetryCampaign.Milestone memory m = campaign.getMilestone(id, 0);
        assertEq(uint8(m.status), uint8(AdvantageAsymmetryCampaign.MilestoneStatus.Submitted));
    }

    // ==================== EXECUTION DEADLINE BOUNDARY (RE-ATTACK) ====================

    function test_executionDeadlineBoundary_isExactAndExclusive() public {
        uint256 id = _createActive(creatorA);
        (,,,,,,, uint256 executionDeadline,,,,,) = campaign.getCampaign(id);

        vm.warp(executionDeadline - 1);
        vm.prank(creatorA);
        campaign.submitMilestone(id, 0, "ipfs://in-time"); // last permitted second

        vm.warp(executionDeadline);
        // Every discretionary path is now closed...
        vm.prank(creatorA);
        vm.expectRevert("execution deadline has passed");
        campaign.submitMilestone(id, 1, "ipfs://late");

        vm.expectRevert("execution deadline has passed");
        campaign.approveMilestone(id, 0);

        vm.expectRevert("execution deadline has passed");
        campaign.rejectMilestone(id, 0);

        // ...leaving exactly one resolution path, which returns the bond because the
        // creator's submission was timely.
        campaign.triggerExecutionExpiry(id);
        assertEq(uint8(_bondOutcome(id)), uint8(AdvantageAsymmetryCampaign.BondOutcome.Returned));
    }

    // ==================== REENTRANCY PROBE ====================

    function test_reentrancy_hostileTokenCannotReenterFundMovingPaths() public {
        ReentrantToken hostile = new ReentrantToken();
        AdvantageAsymmetryCampaign victim = new AdvantageAsymmetryCampaign(address(hostile), penaltySink);
        ReentrancyAttacker attacker = new ReentrancyAttacker(victim, hostile);

        hostile.mint(address(attacker), 10_000 ether);
        hostile.mint(supporter1, 10_000 ether);
        attacker.approveAll();
        vm.prank(supporter1);
        hostile.approve(address(victim), type(uint256).max);

        // Attacker is a campaign creator; every token movement re-enters the contract.
        uint256 id = attacker.createCampaign();
        hostile.setHook(address(attacker));
        hostile.setHookEnabled(true);

        vm.prank(supporter1);
        victim.contribute(id, GOAL); // -> Active

        attacker.submit(id, 0);
        attacker.armReentry(id);

        // The milestone release pays the attacker, whose callback tries to re-enter.
        // nonReentrant must make every re-entry attempt fail, while the outer call succeeds.
        victim.approveMilestone(id, 0);

        assertGt(attacker.reentryAttempts(), 0, "probe did not actually fire (test would be vacuous)");
        assertEq(attacker.reentrySuccesses(), 0, "a reentrant call succeeded");

        // Accounting is exactly as if no callback existed.
        (,,,, uint256 released,,,,,,,,) = victim.getCampaign(id);
        assertEq(released, 40 ether, "released amount corrupted by reentrancy");
    }

    // ==================== TOKEN-MODEL LIMITATIONS (DOCUMENTED, NOT FIXED) ====================

    /// @notice Unsolicited direct transfers create SURPLUS, not insolvency. This is exactly
    ///         why the general invariant is `balance >= liabilities` rather than equality.
    ///         Supported: the surplus is simply unreachable, harming nobody.
    function test_tokenModel_unsolicitedDirectTransfer_createsHarmlessSurplus() public {
        uint256 id = _createActive(creatorA);
        uint256 before = token.balanceOf(address(campaign));

        vm.prank(outsider);
        token.transfer(address(campaign), 777 ether); // donation nobody asked for

        assertEq(token.balanceOf(address(campaign)), before + 777 ether);

        // All normal flows continue to work and pay exactly the accounted amounts.
        vm.prank(creatorA);
        campaign.submitMilestone(id, 0, "ipfs://m1");
        uint256 creatorBefore = token.balanceOf(creatorA);
        campaign.approveMilestone(id, 0);
        assertEq(token.balanceOf(creatorA) - creatorBefore, 40 ether, "surplus must not inflate a release");
    }

    /// @notice Fee-on-transfer tokens are OUTSIDE the supported model. This test documents
    ///         the mismatch rather than working around it: the contract credits the amount
    ///         it asked for, but a smaller amount actually arrives, so the contract would
    ///         become under-collateralised. The intended asset (AUDD / testnet USDC) is not
    ///         fee-on-transfer, so no code change is made; this is recorded as an explicit
    ///         deployment constraint.
    function test_tokenModel_feeOnTransfer_isUnsupported_documented() public {
        FeeOnTransferToken fee = new FeeOnTransferToken();
        AdvantageAsymmetryCampaign feeCampaign = new AdvantageAsymmetryCampaign(address(fee), penaltySink);

        fee.mint(creatorA, 10_000 ether);
        fee.mint(supporter1, 10_000 ether);
        vm.prank(creatorA);
        fee.approve(address(feeCampaign), type(uint256).max);
        vm.prank(supporter1);
        fee.approve(address(feeCampaign), type(uint256).max);

        vm.prank(creatorA);
        uint256 id = feeCampaign.createCampaign(
            GOAL, BOND, _descs(), _amts(), block.timestamp + 7 days, block.timestamp + 37 days
        );

        vm.prank(supporter1);
        feeCampaign.contribute(id, GOAL);

        // Accounting says goal is fully funded...
        (,,, uint256 contributed,,,,,,,,,) = feeCampaign.getCampaign(id);
        assertEq(contributed, GOAL, "contract credits the requested amount");

        // ...but the tokens that actually arrived are less, by the transfer fee.
        uint256 actual = fee.balanceOf(address(feeCampaign));
        assertLt(actual, GOAL + BOND, "fee-on-transfer leaves the contract under-collateralised");

        // Recorded, deliberately not worked around: a fee-on-transfer asset must not be used
        // as the deployment token for this contract.
    }
}

/// @dev Attacker used only by the reentrancy probe. On every token movement it tries to
///      re-enter several fund-moving entry points and records whether any succeeded.
contract ReentrancyAttacker {
    AdvantageAsymmetryCampaign public victim;
    ReentrantToken public token;

    bool public armed;
    uint256 public armedCampaignId;
    uint256 public reentryAttempts;
    uint256 public reentrySuccesses;

    constructor(AdvantageAsymmetryCampaign _victim, ReentrantToken _token) {
        victim = _victim;
        token = _token;
    }

    function approveAll() external {
        token.approve(address(victim), type(uint256).max);
    }

    function createCampaign() external returns (uint256) {
        string[] memory d = new string[](2);
        d[0] = "m1";
        d[1] = "m2";
        uint256[] memory a = new uint256[](2);
        a[0] = 40 ether;
        a[1] = 60 ether;
        return victim.createCampaign(100 ether, 10 ether, d, a, block.timestamp + 7 days, block.timestamp + 37 days);
    }

    function submit(uint256 id, uint256 idx) external {
        victim.submitMilestone(id, idx, "ipfs://evidence");
    }

    function armReentry(uint256 id) external {
        armed = true;
        armedCampaignId = id;
    }

    function onTokenMoved() external {
        if (!armed) return;
        armed = false; // one-shot, so the probe cannot recurse forever

        uint256 id = armedCampaignId;

        // Try several fund-moving / state-moving paths that a reentrancy would target.
        reentryAttempts++;
        try victim.claimRefund(id) {
            reentrySuccesses++;
        } catch {}

        reentryAttempts++;
        try victim.cancelPatronage(id) {
            reentrySuccesses++;
        } catch {}

        reentryAttempts++;
        try victim.triggerExecutionExpiry(id) {
            reentrySuccesses++;
        } catch {}

        reentryAttempts++;
        try victim.startPatronage(id, 1, 1) {
            reentrySuccesses++;
        } catch {}
    }
}
