// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../contracts/AdvantageAsymmetryCampaign.sol";
import "./mocks/MockERC20.sol";

/// @notice Day 2 scope only: supporter refund accounting and its economic invariants.
///         Day 1 behaviour is covered by AdvantageAsymmetryCampaign.day1.t.sol and is not
///         duplicated here except where a refund assertion depends on it.
///
///         Patronage remains out of scope (Day 3).
contract AdvantageAsymmetryCampaignDay2Test is Test {
    AdvantageAsymmetryCampaign campaign;
    MockERC20 token;

    address verifier = address(this); // deployer == owner == verifier for this prototype
    address penaltySink = address(0xBEEF);
    address creator = address(0xC12EA702);
    address supporterA = address(0xA1);
    address supporterB = address(0xB2);
    address supporterC = address(0xC3);
    address supporterD = address(0xD4);
    address stranger = address(0x5747);

    uint256 constant GOAL = 100 ether;
    uint256 constant BOND = 10 ether;
    uint256 constant MILESTONE_1 = 40 ether;
    uint256 constant MILESTONE_2 = 60 ether;

    function setUp() public {
        token = new MockERC20();
        campaign = new AdvantageAsymmetryCampaign(address(token), penaltySink);

        address[5] memory funded = [creator, supporterA, supporterB, supporterC, supporterD];
        for (uint256 i = 0; i < funded.length; i++) {
            token.mint(funded[i], 10_000 ether);
            vm.prank(funded[i]);
            token.approve(address(campaign), type(uint256).max);
        }
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

    function _createDefaultCampaign()
        internal
        returns (uint256 campaignId, uint256 fundingDeadline, uint256 executionDeadline)
    {
        fundingDeadline = block.timestamp + 7 days;
        executionDeadline = fundingDeadline + 30 days;
        vm.prank(creator);
        campaignId = campaign.createCampaign(
            GOAL, BOND, _twoMilestoneDescriptions(), _twoMilestoneAmounts(), fundingDeadline, executionDeadline
        );
    }

    /// @dev Creates a campaign whose goal equals `goal`, split across `parts` milestones of
    ///      caller-supplied sizes. Used where the 40/60 default split is the wrong shape.
    function _createCampaignWith(uint256 goal, uint256[] memory milestoneAmounts)
        internal
        returns (uint256 campaignId, uint256 fundingDeadline, uint256 executionDeadline)
    {
        string[] memory d = new string[](milestoneAmounts.length);
        for (uint256 i = 0; i < milestoneAmounts.length; i++) {
            d[i] = "m";
        }
        fundingDeadline = block.timestamp + 7 days;
        executionDeadline = fundingDeadline + 30 days;
        vm.prank(creator);
        campaignId = campaign.createCampaign(goal, BOND, d, milestoneAmounts, fundingDeadline, executionDeadline);
    }

    function _statusOf(uint256 campaignId) internal view returns (AdvantageAsymmetryCampaign.CampaignStatus status) {
        (,,,,,,,,, status,,,) = campaign.getCampaign(campaignId);
    }

    function _totalContributedOf(uint256 campaignId) internal view returns (uint256 totalContributed) {
        (,,, totalContributed,,,,,,,,,) = campaign.getCampaign(campaignId);
    }

    function _totalReleasedOf(uint256 campaignId) internal view returns (uint256 totalReleased) {
        (,,,, totalReleased,,,,,,,,) = campaign.getCampaign(campaignId);
    }

    function _bondOutcomeOf(uint256 campaignId) internal view returns (AdvantageAsymmetryCampaign.BondOutcome outcome) {
        (,,,,,,,,,,, outcome,) = campaign.getCampaign(campaignId);
    }

    function _pool(uint256 campaignId) internal view returns (uint256 refundPool) {
        (, refundPool,,,,,) = campaign.getRefundAccounting(campaignId);
    }

    function _denominator(uint256 campaignId) internal view returns (uint256 refundDenominator) {
        (refundDenominator,,,,,,) = campaign.getRefundAccounting(campaignId);
    }

    function _totalRefunded(uint256 campaignId) internal view returns (uint256 totalRefunded) {
        (,, totalRefunded,,,,) = campaign.getRefundAccounting(campaignId);
    }

    function _claimCount(uint256 campaignId) internal view returns (uint256 refundClaimCount) {
        (,,,,, refundClaimCount,) = campaign.getRefundAccounting(campaignId);
    }

    function _snapshotContributorCount(uint256 campaignId) internal view returns (uint256 contributorCount) {
        (,,,, contributorCount,,) = campaign.getRefundAccounting(campaignId);
    }

    /// @dev Fully funds `campaignId` from the supplied supporters/amounts (must sum to goal).
    function _fund(uint256 campaignId, address[] memory supporters, uint256[] memory amounts) internal {
        for (uint256 i = 0; i < supporters.length; i++) {
            vm.prank(supporters[i]);
            campaign.contribute(campaignId, amounts[i]);
        }
    }

    /// @dev Funds to goal, releases milestone 1, then fails the campaign by rejecting
    ///      milestone 2. Leaves refundPool == goal - MILESTONE_1.
    function _failAfterFirstMilestoneRelease(uint256 campaignId) internal {
        vm.prank(creator);
        campaign.submitMilestone(campaignId, 0, "ipfs://m1");
        campaign.approveMilestone(campaignId, 0);
        vm.prank(creator);
        campaign.submitMilestone(campaignId, 1, "ipfs://m2");
        campaign.rejectMilestone(campaignId, 1);
    }

    function _claim(uint256 campaignId, address who) internal returns (uint256 received) {
        uint256 before = token.balanceOf(who);
        vm.prank(who);
        campaign.claimRefund(campaignId);
        received = token.balanceOf(who) - before;
    }

    // ==================== SNAPSHOT INITIALISATION, ALL FAILURE PATHS ====================

    function test_snapshot_underfundedExpiry_poolEqualsContributed() public {
        (uint256 campaignId, uint256 fundingDeadline,) = _createDefaultCampaign();
        vm.prank(supporterA);
        campaign.contribute(campaignId, 30 ether);
        vm.prank(supporterB);
        campaign.contribute(campaignId, 20 ether);

        vm.warp(fundingDeadline);
        campaign.triggerFundingExpiry(campaignId);

        assertEq(_totalReleasedOf(campaignId), 0, "nothing released on an underfunded campaign");
        assertEq(_denominator(campaignId), 50 ether);
        assertEq(_pool(campaignId), 50 ether, "refundPool == totalContributed when nothing released");
        assertEq(_snapshotContributorCount(campaignId), 2);
    }

    function test_snapshot_milestoneRejection_poolExcludesReleased() public {
        (uint256 campaignId,,) = _createDefaultCampaign();
        address[] memory s = new address[](2);
        s[0] = supporterA;
        s[1] = supporterB;
        uint256[] memory a = new uint256[](2);
        a[0] = 60 ether;
        a[1] = 40 ether;
        _fund(campaignId, s, a);

        _failAfterFirstMilestoneRelease(campaignId);

        assertEq(_denominator(campaignId), GOAL, "denominator is historical contributions, not the remainder");
        assertEq(_pool(campaignId), GOAL - MILESTONE_1);
    }

    function test_snapshot_creatorExecutionExpiry_initialised() public {
        (uint256 campaignId,, uint256 executionDeadline) = _createDefaultCampaign();
        address[] memory s = new address[](2);
        s[0] = supporterA;
        s[1] = supporterB;
        uint256[] memory a = new uint256[](2);
        a[0] = 70 ether;
        a[1] = 30 ether;
        _fund(campaignId, s, a);

        vm.warp(executionDeadline);
        campaign.triggerExecutionExpiry(campaignId); // creator never submitted -> slash

        (,,,,,, bool initialized) = campaign.getRefundAccounting(campaignId);
        assertTrue(initialized);
        assertEq(_pool(campaignId), GOAL, "no milestone released, so the whole pool refunds");
        assertEq(uint8(_bondOutcomeOf(campaignId)), uint8(AdvantageAsymmetryCampaign.BondOutcome.Slashed));
    }

    function test_snapshot_verifierReviewExpiry_initialised() public {
        (uint256 campaignId,, uint256 executionDeadline) = _createDefaultCampaign();
        address[] memory s = new address[](2);
        s[0] = supporterA;
        s[1] = supporterB;
        uint256[] memory a = new uint256[](2);
        a[0] = 70 ether;
        a[1] = 30 ether;
        _fund(campaignId, s, a);

        vm.prank(creator);
        campaign.submitMilestone(campaignId, 0, "ipfs://m1"); // timely, verifier never rules
        vm.warp(executionDeadline);
        campaign.triggerExecutionExpiry(campaignId);

        (,,,,,, bool initialized) = campaign.getRefundAccounting(campaignId);
        assertTrue(initialized);
        assertEq(_pool(campaignId), GOAL);
        assertEq(uint8(_bondOutcomeOf(campaignId)), uint8(AdvantageAsymmetryCampaign.BondOutcome.Returned));
    }

    function test_snapshot_zeroContributions_noDivisionByZero() public {
        (uint256 campaignId, uint256 fundingDeadline,) = _createDefaultCampaign();
        vm.warp(fundingDeadline);
        campaign.triggerFundingExpiry(campaignId); // must not revert with zero contributions

        assertEq(_denominator(campaignId), 0);
        assertEq(_pool(campaignId), 0);
        assertEq(_snapshotContributorCount(campaignId), 0);

        // Nobody can claim, and attempting to does not divide by zero -- it fails the
        // contribution check first.
        vm.prank(supporterA);
        vm.expectRevert("no contribution to refund");
        campaign.claimRefund(campaignId);
    }

    function test_snapshot_multipleContributionsFromOneWallet_countAsOneContributor() public {
        (uint256 campaignId, uint256 fundingDeadline,) = _createDefaultCampaign();
        vm.startPrank(supporterA);
        campaign.contribute(campaignId, 10 ether);
        campaign.contribute(campaignId, 10 ether);
        campaign.contribute(campaignId, 10 ether);
        campaign.contribute(campaignId, 10 ether);
        campaign.contribute(campaignId, 10 ether);
        vm.stopPrank();

        assertEq(campaign.getContributorCount(campaignId), 1, "five contributions, one wallet");
        assertEq(campaign.contributions(campaignId, supporterA), 50 ether);

        vm.warp(fundingDeadline);
        campaign.triggerFundingExpiry(campaignId);
        assertEq(_snapshotContributorCount(campaignId), 1);

        // As the sole contributor they are also the final claimant and take the whole pool.
        assertEq(_claim(campaignId, supporterA), 50 ether);
        assertEq(_totalRefunded(campaignId), _pool(campaignId));
    }

    // ==================== BASIC REFUND FLOWS ====================

    function test_completeRefund_afterUnderfundedFailure() public {
        (uint256 campaignId, uint256 fundingDeadline,) = _createDefaultCampaign();
        vm.prank(supporterA);
        campaign.contribute(campaignId, 30 ether);
        vm.prank(supporterB);
        campaign.contribute(campaignId, 20 ether);
        vm.warp(fundingDeadline);
        campaign.triggerFundingExpiry(campaignId);

        assertEq(_claim(campaignId, supporterA), 30 ether, "underfunded refund is 1:1");
        assertEq(_claim(campaignId, supporterB), 20 ether);
        assertEq(_totalRefunded(campaignId), 50 ether);
        assertEq(_totalRefunded(campaignId), _pool(campaignId));
    }

    function test_partialRefund_afterOneMilestoneReleased() public {
        (uint256 campaignId,,) = _createDefaultCampaign();
        address[] memory s = new address[](2);
        s[0] = supporterA;
        s[1] = supporterB;
        uint256[] memory a = new uint256[](2);
        a[0] = 50 ether;
        a[1] = 50 ether;
        _fund(campaignId, s, a);
        _failAfterFirstMilestoneRelease(campaignId); // 40 released, pool == 60

        assertEq(_pool(campaignId), 60 ether);
        // Each holds half the historical denominator -> half of the 60 pool.
        assertEq(_claim(campaignId, supporterA), 30 ether);
        assertEq(_claim(campaignId, supporterB), 30 ether);
        assertEq(_totalRefunded(campaignId), 60 ether);
    }

    function test_partialRefund_afterMultipleMilestoneReleases() public {
        // Three milestones of 30/30/40 so two can be released before failure.
        uint256[] memory amts = new uint256[](3);
        amts[0] = 30 ether;
        amts[1] = 30 ether;
        amts[2] = 40 ether;
        (uint256 campaignId,,) = _createCampaignWith(GOAL, amts);

        address[] memory s = new address[](2);
        s[0] = supporterA;
        s[1] = supporterB;
        uint256[] memory a = new uint256[](2);
        a[0] = 50 ether;
        a[1] = 50 ether;
        _fund(campaignId, s, a);

        vm.prank(creator);
        campaign.submitMilestone(campaignId, 0, "ipfs://m1");
        campaign.approveMilestone(campaignId, 0);
        vm.prank(creator);
        campaign.submitMilestone(campaignId, 1, "ipfs://m2");
        campaign.approveMilestone(campaignId, 1);
        vm.prank(creator);
        campaign.submitMilestone(campaignId, 2, "ipfs://m3");
        campaign.rejectMilestone(campaignId, 2);

        assertEq(_totalReleasedOf(campaignId), 60 ether);
        assertEq(_pool(campaignId), 40 ether, "two releases removed from the refundable pool");
        assertEq(_claim(campaignId, supporterA), 20 ether);
        assertEq(_claim(campaignId, supporterB), 20 ether);
        assertEq(_totalRefunded(campaignId), 40 ether);
    }

    function test_releasedFunds_neverReappearInPool() public {
        (uint256 campaignId,,) = _createDefaultCampaign();
        address[] memory s = new address[](2);
        s[0] = supporterA;
        s[1] = supporterB;
        uint256[] memory a = new uint256[](2);
        a[0] = 50 ether;
        a[1] = 50 ether;
        _fund(campaignId, s, a);
        _failAfterFirstMilestoneRelease(campaignId);

        uint256 creatorBalAfterRelease = token.balanceOf(creator);
        _claim(campaignId, supporterA);
        _claim(campaignId, supporterB);

        // Pool never exceeded contributed-minus-released, and the creator keeps the release.
        assertEq(_totalRefunded(campaignId), GOAL - MILESTONE_1);
        assertEq(token.balanceOf(creator), creatorBalAfterRelease, "released milestone funds are not clawed back");
    }

    // ==================== CLAIM ORDER INDEPENDENCE ====================

    function test_twoSupporters_orderAB() public {
        (uint256 campaignId,,) = _createDefaultCampaign();
        address[] memory s = new address[](2);
        s[0] = supporterA;
        s[1] = supporterB;
        uint256[] memory a = new uint256[](2);
        a[0] = 70 ether;
        a[1] = 30 ether;
        _fund(campaignId, s, a);
        _failAfterFirstMilestoneRelease(campaignId); // pool 60, denom 100

        uint256 gotA = _claim(campaignId, supporterA);
        uint256 gotB = _claim(campaignId, supporterB);

        assertEq(gotA, 42 ether); // 70 * 60 / 100
        assertEq(gotB, 18 ether); // 30 * 60 / 100
        assertEq(gotA + gotB, _pool(campaignId));
    }

    function test_twoSupporters_orderBA_identicalEntitlements() public {
        (uint256 campaignId,,) = _createDefaultCampaign();
        address[] memory s = new address[](2);
        s[0] = supporterA;
        s[1] = supporterB;
        uint256[] memory a = new uint256[](2);
        a[0] = 70 ether;
        a[1] = 30 ether;
        _fund(campaignId, s, a);
        _failAfterFirstMilestoneRelease(campaignId);

        uint256 gotB = _claim(campaignId, supporterB);
        uint256 gotA = _claim(campaignId, supporterA);

        // Exactly the same numbers as the A->B ordering: these divide evenly, so there is
        // no residue for order to move around.
        assertEq(gotA, 42 ether);
        assertEq(gotB, 18 ether);
        assertEq(gotA + gotB, _pool(campaignId));
    }

    /// @dev Runs the 41/37/22 manual reconciliation scenario under a fuzzed permutation of
    ///      the three claim orders, asserting the invariant that holds across all of them.
    function testFuzz_threeSupporters_allClaimPermutations(uint8 permSeed) public {
        uint8 perm = uint8(bound(permSeed, 0, 5));

        (uint256 campaignId, uint256 fundingDeadline,) = _createDefaultCampaign();
        vm.prank(supporterA);
        campaign.contribute(campaignId, 41 ether);
        vm.prank(supporterB);
        campaign.contribute(campaignId, 37 ether);
        vm.prank(supporterC);
        campaign.contribute(campaignId, 22 ether);
        // 41+37+22 == 100 == goal, so the campaign is Active; fundingDeadline unused here.
        fundingDeadline;

        _failAfterFirstMilestoneRelease(campaignId); // 40 released -> pool 60, denom 100

        address[3] memory order;
        if (perm == 0) order = [supporterA, supporterB, supporterC];
        else if (perm == 1) order = [supporterA, supporterC, supporterB];
        else if (perm == 2) order = [supporterB, supporterA, supporterC];
        else if (perm == 3) order = [supporterB, supporterC, supporterA];
        else if (perm == 4) order = [supporterC, supporterA, supporterB];
        else order = [supporterC, supporterB, supporterA];

        uint256 pool = _pool(campaignId);
        uint256 paid;
        for (uint256 i = 0; i < 3; i++) {
            paid += _claim(campaignId, order[i]);
            assertLe(_totalRefunded(campaignId), pool, "totalRefunded never exceeds refundPool");
        }

        assertEq(paid, pool, "aggregate payouts exhaust the pool exactly, in every order");
        assertEq(_totalRefunded(campaignId), pool);
        assertEq(_totalContributedOf(campaignId), GOAL, "historical denominator untouched");
    }

    /// @notice The explicit manual reconciliation from the Day 2 brief:
    ///         A=41, B=37, C=22, total 100, 31 released, pool 69.
    ///         Base entitlements floor to 28 / 25 / 15 (sum 68), leaving residue 1 for the
    ///         final claimant. Demonstrated here under two different claim orders.
    function test_manualReconciliation_41_37_22_orderABC() public {
        uint256[] memory amts = new uint256[](2);
        amts[0] = 31; // released before failure
        amts[1] = 69;
        (uint256 campaignId,,) = _createCampaignWith(100, amts);

        vm.prank(supporterA);
        campaign.contribute(campaignId, 41);
        vm.prank(supporterB);
        campaign.contribute(campaignId, 37);
        vm.prank(supporterC);
        campaign.contribute(campaignId, 22);

        _failAfterFirstMilestoneRelease(campaignId);
        assertEq(_pool(campaignId), 69);
        assertEq(_denominator(campaignId), 100);

        uint256 gotA = _claim(campaignId, supporterA);
        uint256 gotB = _claim(campaignId, supporterB);
        uint256 gotC = _claim(campaignId, supporterC);

        assertEq(gotA, 28, "41*69/100 = 28.29 -> 28");
        assertEq(gotB, 25, "37*69/100 = 25.53 -> 25");
        assertEq(gotC, 16, "final claimant takes 69-53 = 16 (base 15 + residue 1)");
        assertEq(gotA + gotB + gotC, 69);
    }

    function test_manualReconciliation_41_37_22_orderCBA() public {
        uint256[] memory amts = new uint256[](2);
        amts[0] = 31;
        amts[1] = 69;
        (uint256 campaignId,,) = _createCampaignWith(100, amts);

        vm.prank(supporterA);
        campaign.contribute(campaignId, 41);
        vm.prank(supporterB);
        campaign.contribute(campaignId, 37);
        vm.prank(supporterC);
        campaign.contribute(campaignId, 22);

        _failAfterFirstMilestoneRelease(campaignId);

        uint256 gotC = _claim(campaignId, supporterC);
        uint256 gotB = _claim(campaignId, supporterB);
        uint256 gotA = _claim(campaignId, supporterA);

        assertEq(gotC, 15, "22*69/100 = 15.18 -> 15");
        assertEq(gotB, 25, "unchanged: same frozen denominator and pool");
        assertEq(gotA, 29, "final claimant takes 69-40 = 29 (base 28 + residue 1)");
        assertEq(gotA + gotB + gotC, 69, "pool exhausted regardless of order");
    }

    // ==================== ROUNDING RESIDUE ====================

    function test_finalClaimant_receivesRoundingResidue() public {
        uint256[] memory amts = new uint256[](2);
        amts[0] = 31;
        amts[1] = 69;
        (uint256 campaignId,,) = _createCampaignWith(100, amts);
        vm.prank(supporterA);
        campaign.contribute(campaignId, 41);
        vm.prank(supporterB);
        campaign.contribute(campaignId, 37);
        vm.prank(supporterC);
        campaign.contribute(campaignId, 22);
        _failAfterFirstMilestoneRelease(campaignId);

        _claim(campaignId, supporterA); // 28
        _claim(campaignId, supporterB); // 25
        uint256 previewC = campaign.previewRefund(campaignId, supporterC);
        uint256 gotC = _claim(campaignId, supporterC);

        assertEq(previewC, gotC, "previewRefund matches the final claimant's actual payout");
        assertEq(gotC, 16);
        assertGt(gotC, 15, "final claimant strictly exceeds their floored base by the residue");
    }

    /// @notice The residue handed to the final claimant is bounded by (contributorCount - 1)
    ///         base units, since each of the other claimants loses at most 1 unit to flooring.
    function testFuzz_roundingResidue_isBounded(uint256 c1, uint256 c2, uint256 c3, uint256 releaseBps) public {
        c1 = bound(c1, 1, 1_000_000);
        c2 = bound(c2, 1, 1_000_000);
        c3 = bound(c3, 1, 1_000_000);
        releaseBps = bound(releaseBps, 1, 9_000); // release 0.01%..90% of goal in milestone 1

        uint256 goal = c1 + c2 + c3;
        uint256 m1 = (goal * releaseBps) / 10_000;
        vm.assume(m1 > 0 && m1 < goal);

        uint256[] memory amts = new uint256[](2);
        amts[0] = m1;
        amts[1] = goal - m1;
        (uint256 campaignId,,) = _createCampaignWith(goal, amts);

        vm.prank(supporterA);
        campaign.contribute(campaignId, c1);
        vm.prank(supporterB);
        campaign.contribute(campaignId, c2);
        vm.prank(supporterC);
        campaign.contribute(campaignId, c3);
        _failAfterFirstMilestoneRelease(campaignId);

        uint256 pool = _pool(campaignId);
        uint256 gotA = _claim(campaignId, supporterA);
        uint256 gotB = _claim(campaignId, supporterB);
        uint256 gotC = _claim(campaignId, supporterC);

        uint256 baseC = Math.mulDiv(c3, pool, goal);
        uint256 residue = gotC - baseC;
        assertLe(residue, 2, "residue bounded by contributorCount - 1 == 2");
        assertEq(gotA + gotB + gotC, pool, "pool exhausted exactly");
    }

    function test_zeroBaseEntitlementSupporter_canStillClaim() public {
        // A whale plus a dust contributor: dust * pool / denom floors to 0.
        uint256 dust = 1;
        uint256 whale = 1_000_000;
        uint256 goal = dust + whale;

        uint256[] memory amts = new uint256[](2);
        amts[0] = goal - 1; // release almost everything, leaving pool == 1
        amts[1] = 1;
        (uint256 campaignId,,) = _createCampaignWith(goal, amts);

        vm.prank(supporterA);
        campaign.contribute(campaignId, dust);
        vm.prank(supporterB);
        campaign.contribute(campaignId, whale);
        _failAfterFirstMilestoneRelease(campaignId);

        assertEq(_pool(campaignId), 1);
        // A's base is 1 * 1 / 1000001 == 0. The claim must still succeed and be recorded,
        // otherwise B could never become the final claimant and the pool would strand.
        uint256 gotA = _claim(campaignId, supporterA);
        assertEq(gotA, 0);
        assertTrue(campaign.refundClaimed(campaignId, supporterA), "zero-value claim is still recorded");
        assertEq(_claimCount(campaignId), 1);

        uint256 gotB = _claim(campaignId, supporterB);
        assertEq(gotB, 1, "final claimant sweeps the whole remaining pool");
        assertEq(_totalRefunded(campaignId), _pool(campaignId), "nothing stranded");
    }

    function test_zeroBaseEntitlementSupporter_cannotClaimTwice() public {
        uint256 goal = 1_000_001;
        uint256[] memory amts = new uint256[](2);
        amts[0] = goal - 1;
        amts[1] = 1;
        (uint256 campaignId,,) = _createCampaignWith(goal, amts);
        vm.prank(supporterA);
        campaign.contribute(campaignId, 1);
        vm.prank(supporterB);
        campaign.contribute(campaignId, 1_000_000);
        _failAfterFirstMilestoneRelease(campaignId);

        _claim(campaignId, supporterA); // zero-value but recorded
        vm.prank(supporterA);
        vm.expectRevert("refund already claimed");
        campaign.claimRefund(campaignId);
    }

    // ==================== ACCESS / STATE GUARDS ====================

    function test_noDoubleRefund() public {
        (uint256 campaignId, uint256 fundingDeadline,) = _createDefaultCampaign();
        vm.prank(supporterA);
        campaign.contribute(campaignId, 30 ether);
        vm.warp(fundingDeadline);
        campaign.triggerFundingExpiry(campaignId);

        _claim(campaignId, supporterA);
        vm.prank(supporterA);
        vm.expectRevert("refund already claimed");
        campaign.claimRefund(campaignId);
    }

    function test_nonContributorCannotClaim() public {
        (uint256 campaignId, uint256 fundingDeadline,) = _createDefaultCampaign();
        vm.prank(supporterA);
        campaign.contribute(campaignId, 30 ether);
        vm.warp(fundingDeadline);
        campaign.triggerFundingExpiry(campaignId);

        vm.prank(stranger);
        vm.expectRevert("no contribution to refund");
        campaign.claimRefund(campaignId);
    }

    function test_cannotClaimBeforeFailure_duringFunding() public {
        (uint256 campaignId,,) = _createDefaultCampaign();
        vm.prank(supporterA);
        campaign.contribute(campaignId, 30 ether);

        vm.prank(supporterA);
        vm.expectRevert("campaign not failed");
        campaign.claimRefund(campaignId);
    }

    function test_cannotClaimBeforeFailure_whenActive() public {
        (uint256 campaignId,,) = _createDefaultCampaign();
        address[] memory s = new address[](1);
        s[0] = supporterA;
        uint256[] memory a = new uint256[](1);
        a[0] = GOAL;
        _fund(campaignId, s, a);

        vm.prank(supporterA);
        vm.expectRevert("campaign not failed");
        campaign.claimRefund(campaignId);
    }

    function test_cannotClaimAfterSuccess() public {
        (uint256 campaignId,,) = _createDefaultCampaign();
        address[] memory s = new address[](1);
        s[0] = supporterA;
        uint256[] memory a = new uint256[](1);
        a[0] = GOAL;
        _fund(campaignId, s, a);

        vm.prank(creator);
        campaign.submitMilestone(campaignId, 0, "ipfs://m1");
        campaign.approveMilestone(campaignId, 0);
        vm.prank(creator);
        campaign.submitMilestone(campaignId, 1, "ipfs://m2");
        campaign.approveMilestone(campaignId, 1);

        vm.prank(supporterA);
        vm.expectRevert("campaign not failed");
        campaign.claimRefund(campaignId);
    }

    function test_claimRefund_revertsOnNonexistentCampaign() public {
        vm.prank(supporterA);
        vm.expectRevert("campaign does not exist");
        campaign.claimRefund(999);
    }

    function test_refundWorksWhilePaused() public {
        (uint256 campaignId, uint256 fundingDeadline,) = _createDefaultCampaign();
        vm.prank(supporterA);
        campaign.contribute(campaignId, 30 ether);
        vm.warp(fundingDeadline);
        campaign.triggerFundingExpiry(campaignId);

        campaign.pause();
        assertEq(_claim(campaignId, supporterA), 30 ether, "refund is a risk-reducing exit; pause must not block it");
    }

    // ==================== HISTORICAL RECORD IMMUTABILITY ====================

    function test_totalContributedUnchangedAfterEveryRefund() public {
        (uint256 campaignId,,) = _createDefaultCampaign();
        address[] memory s = new address[](3);
        s[0] = supporterA;
        s[1] = supporterB;
        s[2] = supporterC;
        uint256[] memory a = new uint256[](3);
        a[0] = 41 ether;
        a[1] = 37 ether;
        a[2] = 22 ether;
        _fund(campaignId, s, a);
        _failAfterFirstMilestoneRelease(campaignId);

        assertEq(_totalContributedOf(campaignId), GOAL);
        _claim(campaignId, supporterA);
        assertEq(_totalContributedOf(campaignId), GOAL, "unchanged after claim 1");
        _claim(campaignId, supporterB);
        assertEq(_totalContributedOf(campaignId), GOAL, "unchanged after claim 2");
        _claim(campaignId, supporterC);
        assertEq(_totalContributedOf(campaignId), GOAL, "unchanged after claim 3");
        assertEq(_denominator(campaignId), GOAL, "frozen denominator equally unchanged");
    }

    function test_historicalContributionRecordUnchangedAfterRefund() public {
        (uint256 campaignId,,) = _createDefaultCampaign();
        address[] memory s = new address[](2);
        s[0] = supporterA;
        s[1] = supporterB;
        uint256[] memory a = new uint256[](2);
        a[0] = 70 ether;
        a[1] = 30 ether;
        _fund(campaignId, s, a);
        _failAfterFirstMilestoneRelease(campaignId);

        _claim(campaignId, supporterA);
        _claim(campaignId, supporterB);

        assertEq(
            campaign.contributions(campaignId, supporterA), 70 ether, "contribution record is history, not a balance"
        );
        assertEq(campaign.contributions(campaignId, supporterB), 30 ether);
    }

    /// @notice Direct regression against V0's shrinking-denominator bug. In V0 the second
    ///         claimant's payout depended on the first claimant having decremented
    ///         totalContributed. Here the denominator is provably identical before and
    ///         after each claim, and both orderings pay the same amounts.
    function test_shrinkingDenominatorBug_cannotReproduce() public {
        (uint256 campaignId,,) = _createDefaultCampaign();
        address[] memory s = new address[](2);
        s[0] = supporterA;
        s[1] = supporterB;
        uint256[] memory a = new uint256[](2);
        a[0] = 70 ether;
        a[1] = 30 ether;
        _fund(campaignId, s, a);
        _failAfterFirstMilestoneRelease(campaignId);

        uint256 denomBefore = _denominator(campaignId);
        uint256 gotA_first = _claim(campaignId, supporterA);
        uint256 denomMid = _denominator(campaignId);
        uint256 gotB_second = _claim(campaignId, supporterB);
        uint256 denomAfter = _denominator(campaignId);

        assertEq(denomBefore, denomMid, "denominator must not shrink mid-sequence");
        assertEq(denomMid, denomAfter);

        // Same scenario, opposite order, on a fresh campaign.
        (uint256 otherId,,) = _createDefaultCampaign();
        _fund(otherId, s, a);
        _failAfterFirstMilestoneRelease(otherId);
        uint256 gotB_first = _claim(otherId, supporterB);
        uint256 gotA_second = _claim(otherId, supporterA);

        assertEq(gotA_first, gotA_second, "A's entitlement is order-invariant");
        assertEq(gotB_first, gotB_second, "B's entitlement is order-invariant");
    }

    // ==================== BOND SEGREGATION ====================

    function test_underfundedFailure_returnsBond_refundsIndependent() public {
        (uint256 campaignId, uint256 fundingDeadline,) = _createDefaultCampaign();
        vm.prank(supporterA);
        campaign.contribute(campaignId, 40 ether);
        uint256 creatorBefore = token.balanceOf(creator);

        vm.warp(fundingDeadline);
        campaign.triggerFundingExpiry(campaignId);

        assertEq(token.balanceOf(creator), creatorBefore + BOND, "bond returned to creator");
        assertEq(_pool(campaignId), 40 ether, "pool is contributions only; bond excluded");
        assertEq(_claim(campaignId, supporterA), 40 ether, "supporter gets contributions, not bond upside");
    }

    function test_creatorCausedFailure_slashesBond_refundsIndependent() public {
        (uint256 campaignId,,) = _createDefaultCampaign();
        address[] memory s = new address[](2);
        s[0] = supporterA;
        s[1] = supporterB;
        uint256[] memory a = new uint256[](2);
        a[0] = 50 ether;
        a[1] = 50 ether;
        _fund(campaignId, s, a);

        uint256 sinkBefore = token.balanceOf(penaltySink);
        _failAfterFirstMilestoneRelease(campaignId);

        assertEq(token.balanceOf(penaltySink), sinkBefore + BOND, "slashed bond goes only to the sink");
        assertEq(_pool(campaignId), 60 ether, "pool excludes the slashed bond entirely");

        uint256 gotA = _claim(campaignId, supporterA);
        uint256 gotB = _claim(campaignId, supporterB);
        assertEq(gotA + gotB, 60 ether, "supporters split contributions only -- no bond upside");
    }

    function test_verifierCausedExpiry_returnsBond_refundsIndependent() public {
        (uint256 campaignId,, uint256 executionDeadline) = _createDefaultCampaign();
        address[] memory s = new address[](2);
        s[0] = supporterA;
        s[1] = supporterB;
        uint256[] memory a = new uint256[](2);
        a[0] = 50 ether;
        a[1] = 50 ether;
        _fund(campaignId, s, a);

        vm.prank(creator);
        campaign.submitMilestone(campaignId, 0, "ipfs://m1");
        uint256 creatorBefore = token.balanceOf(creator);
        vm.warp(executionDeadline);
        campaign.triggerExecutionExpiry(campaignId);

        assertEq(token.balanceOf(creator), creatorBefore + BOND, "bond returned, verifier at fault");
        assertEq(_pool(campaignId), GOAL, "no release happened, so the full pool refunds");
        assertEq(_claim(campaignId, supporterA) + _claim(campaignId, supporterB), GOAL);
    }

    function test_bondNeverEntersRefundPool_acrossAllFailurePaths() public {
        // Slash path.
        (uint256 slashId,,) = _createDefaultCampaign();
        address[] memory s = new address[](1);
        s[0] = supporterA;
        uint256[] memory a = new uint256[](1);
        a[0] = GOAL;
        _fund(slashId, s, a);
        _failAfterFirstMilestoneRelease(slashId);
        assertEq(_pool(slashId), GOAL - MILESTONE_1);
        assertEq(_claim(slashId, supporterA), GOAL - MILESTONE_1, "never receives bond value");

        // Return path.
        (uint256 returnId, uint256 fundingDeadline,) = _createDefaultCampaign();
        vm.prank(supporterB);
        campaign.contribute(returnId, 25 ether);
        vm.warp(fundingDeadline);
        campaign.triggerFundingExpiry(returnId);
        assertEq(_pool(returnId), 25 ether);
        assertEq(_claim(returnId, supporterB), 25 ether, "never receives bond value");
    }

    // ==================== CROSS-CAMPAIGN ISOLATION ====================

    function test_refundInCampaignA_doesNotAffectCampaignB() public {
        (uint256 idA,,) = _createDefaultCampaign();
        (uint256 idB,,) = _createDefaultCampaign();

        address[] memory s = new address[](2);
        s[0] = supporterA;
        s[1] = supporterB;
        uint256[] memory a = new uint256[](2);
        a[0] = 60 ether;
        a[1] = 40 ether;
        _fund(idA, s, a);
        _fund(idB, s, a);

        _failAfterFirstMilestoneRelease(idA);
        _failAfterFirstMilestoneRelease(idB);

        uint256 poolB_before = _pool(idB);
        uint256 denomB_before = _denominator(idB);
        uint256 previewA_inB = campaign.previewRefund(idB, supporterA);

        _claim(idA, supporterA);
        _claim(idA, supporterB);

        assertEq(_pool(idB), poolB_before, "B's pool untouched by A's claims");
        assertEq(_denominator(idB), denomB_before);
        assertEq(_totalRefunded(idB), 0, "B has had no claims");
        assertEq(_claimCount(idB), 0);
        assertEq(campaign.previewRefund(idB, supporterA), previewA_inB, "B entitlements unchanged");
        assertFalse(campaign.refundClaimed(idB, supporterA), "claiming in A does not mark A's claim in B");
        assertEq(uint8(_statusOf(idB)), uint8(AdvantageAsymmetryCampaign.CampaignStatus.Failed));

        // And B still pays out fully afterwards.
        uint256 paidB = _claim(idB, supporterA) + _claim(idB, supporterB);
        assertEq(paidB, poolB_before);
    }

    function test_claimingInOneCampaign_doesNotUnlockAnother() public {
        (uint256 idA, uint256 fundingDeadlineA,) = _createDefaultCampaign();
        (uint256 idB,,) = _createDefaultCampaign();

        vm.prank(supporterA);
        campaign.contribute(idA, 30 ether);
        vm.warp(fundingDeadlineA);
        campaign.triggerFundingExpiry(idA);
        _claim(idA, supporterA);

        // B is still in Funding and must remain unclaimable.
        vm.prank(supporterA);
        vm.expectRevert("campaign not failed");
        campaign.claimRefund(idB);
    }

    // ==================== CONSERVATION PROPERTIES (FUZZ) ====================

    /// @notice Conservation: totalReleased + refundPool == historical totalContributed for
    ///         any fully-funded campaign that subsequently fails.
    function testFuzz_conservation_releasedPlusPoolEqualsContributed(uint256 c1, uint256 c2, uint256 splitBps) public {
        c1 = bound(c1, 1, 1_000_000 ether);
        c2 = bound(c2, 1, 1_000_000 ether);
        splitBps = bound(splitBps, 1, 9_999);

        uint256 goal = c1 + c2;
        uint256 m1 = (goal * splitBps) / 10_000;
        vm.assume(m1 > 0 && m1 < goal);

        uint256[] memory amts = new uint256[](2);
        amts[0] = m1;
        amts[1] = goal - m1;
        (uint256 campaignId,,) = _createCampaignWith(goal, amts);

        token.mint(supporterA, c1);
        token.mint(supporterB, c2);
        vm.prank(supporterA);
        campaign.contribute(campaignId, c1);
        vm.prank(supporterB);
        campaign.contribute(campaignId, c2);

        _failAfterFirstMilestoneRelease(campaignId);

        assertEq(
            _totalReleasedOf(campaignId) + _pool(campaignId),
            _totalContributedOf(campaignId),
            "released + refundable == historical contributions"
        );
        assertEq(_denominator(campaignId), goal);
    }

    /// @notice Conservation: once every legitimate claimant has claimed,
    ///         totalRefunded == refundPool exactly, with nothing stranded, for randomised
    ///         contribution proportions and a randomised claim order.
    function testFuzz_conservation_allClaimsExhaustPoolExactly(
        uint256 c1,
        uint256 c2,
        uint256 c3,
        uint256 splitBps,
        uint8 orderSeed
    ) public {
        c1 = bound(c1, 1, 1_000_000 ether);
        c2 = bound(c2, 1, 1_000_000 ether);
        c3 = bound(c3, 1, 1_000_000 ether);
        splitBps = bound(splitBps, 1, 9_999);

        uint256 goal = c1 + c2 + c3;
        uint256 m1 = (goal * splitBps) / 10_000;
        vm.assume(m1 > 0 && m1 < goal);

        uint256[] memory amts = new uint256[](2);
        amts[0] = m1;
        amts[1] = goal - m1;
        (uint256 campaignId,,) = _createCampaignWith(goal, amts);

        token.mint(supporterA, c1);
        token.mint(supporterB, c2);
        token.mint(supporterC, c3);
        vm.prank(supporterA);
        campaign.contribute(campaignId, c1);
        vm.prank(supporterB);
        campaign.contribute(campaignId, c2);
        vm.prank(supporterC);
        campaign.contribute(campaignId, c3);

        _failAfterFirstMilestoneRelease(campaignId);
        uint256 pool = _pool(campaignId);

        address[3] memory order;
        uint8 perm = uint8(bound(orderSeed, 0, 5));
        if (perm == 0) order = [supporterA, supporterB, supporterC];
        else if (perm == 1) order = [supporterA, supporterC, supporterB];
        else if (perm == 2) order = [supporterB, supporterA, supporterC];
        else if (perm == 3) order = [supporterB, supporterC, supporterA];
        else if (perm == 4) order = [supporterC, supporterA, supporterB];
        else order = [supporterC, supporterB, supporterA];

        uint256 paid;
        for (uint256 i = 0; i < 3; i++) {
            paid += _claim(campaignId, order[i]);
            assertLe(_totalRefunded(campaignId), pool, "totalRefunded <= refundPool at every step");
        }

        assertEq(paid, pool, "aggregate payouts == refundPool exactly");
        assertEq(_totalRefunded(campaignId), pool);
        assertEq(_totalContributedOf(campaignId), goal, "denominator never mutated");
    }

    /// @notice Arbitrary claim order can never underflow or over-pay, including when some
    ///         claimants are dust-sized and floor to zero.
    function testFuzz_arbitraryOrder_noUnderflowNoOverpay(
        uint256 c1,
        uint256 c2,
        uint256 c3,
        uint256 c4,
        uint8 orderSeed
    ) public {
        c1 = bound(c1, 1, 1e24);
        c2 = bound(c2, 1, 1e24);
        c3 = bound(c3, 1, 1e24);
        c4 = bound(c4, 1, 1e24);

        uint256 goal = c1 + c2 + c3 + c4;
        uint256 m1 = goal / 2;
        vm.assume(m1 > 0 && m1 < goal);

        uint256[] memory amts = new uint256[](2);
        amts[0] = m1;
        amts[1] = goal - m1;
        (uint256 campaignId,,) = _createCampaignWith(goal, amts);

        address[4] memory who = [supporterA, supporterB, supporterC, supporterD];
        uint256[4] memory amt = [c1, c2, c3, c4];
        for (uint256 i = 0; i < 4; i++) {
            token.mint(who[i], amt[i]);
            vm.prank(who[i]);
            campaign.contribute(campaignId, amt[i]);
        }

        _failAfterFirstMilestoneRelease(campaignId);
        uint256 pool = _pool(campaignId);
        uint256 contractBefore = token.balanceOf(address(campaign));

        // Rotate the claim order by a fuzzed offset.
        uint256 offset = bound(orderSeed, 0, 3);
        uint256 paid;
        for (uint256 i = 0; i < 4; i++) {
            address claimant = who[(i + offset) % 4];
            paid += _claim(campaignId, claimant);
            assertLe(_totalRefunded(campaignId), pool, "never over-pays the pool");
        }

        assertEq(paid, pool);
        assertEq(token.balanceOf(address(campaign)), contractBefore - pool, "contract released exactly the pool");
    }

    /// @notice No contributor can ever claim twice, whatever order the fuzzer picks.
    function testFuzz_noDoubleRefund_underAnyOrder(uint8 orderSeed) public {
        (uint256 campaignId,,) = _createDefaultCampaign();
        address[] memory s = new address[](2);
        s[0] = supporterA;
        s[1] = supporterB;
        uint256[] memory a = new uint256[](2);
        a[0] = 55 ether;
        a[1] = 45 ether;
        _fund(campaignId, s, a);
        _failAfterFirstMilestoneRelease(campaignId);

        address first = uint8(bound(orderSeed, 0, 1)) == 0 ? supporterA : supporterB;
        address second = first == supporterA ? supporterB : supporterA;

        _claim(campaignId, first);
        _claim(campaignId, second);

        vm.prank(first);
        vm.expectRevert("refund already claimed");
        campaign.claimRefund(campaignId);

        vm.prank(second);
        vm.expectRevert("refund already claimed");
        campaign.claimRefund(campaignId);

        assertEq(_totalRefunded(campaignId), _pool(campaignId));
    }

    // ==================== CREATOR / SUPPORTER ROLE SEPARATION ====================
    //
    // Prototype-design decision: a creator may not fund their own campaign, so
    // totalContributed and contributorCount represent external support only and cannot be
    // inflated into misleading social proof.

    function test_creatorCannotContributeToOwnCampaign() public {
        (uint256 campaignId,,) = _createDefaultCampaign();

        vm.prank(creator);
        vm.expectRevert("creator cannot contribute");
        campaign.contribute(campaignId, 10 ether);
    }

    function test_failedCreatorContribution_doesNotMutateAccounting() public {
        (uint256 campaignId,,) = _createDefaultCampaign();

        // Establish a baseline with one genuine external supporter.
        vm.prank(supporterA);
        campaign.contribute(campaignId, 30 ether);

        uint256 contributedBefore = _totalContributedOf(campaignId);
        uint256 countBefore = campaign.getContributorCount(campaignId);
        uint256 creatorBalBefore = token.balanceOf(creator);
        uint256 contractBalBefore = token.balanceOf(address(campaign));

        vm.prank(creator);
        vm.expectRevert("creator cannot contribute");
        campaign.contribute(campaignId, 25 ether);

        assertEq(_totalContributedOf(campaignId), contributedBefore, "totalContributed unchanged");
        assertEq(campaign.getContributorCount(campaignId), countBefore, "contributorCount unchanged");
        assertEq(campaign.contributions(campaignId, creator), 0, "no contribution record written for creator");
        assertEq(token.balanceOf(creator), creatorBalBefore, "no tokens pulled from creator");
        assertEq(token.balanceOf(address(campaign)), contractBalBefore, "no tokens entered escrow");
    }

    function test_creatorRejection_doesNotAffectExternalSupporters() public {
        (uint256 campaignId, uint256 fundingDeadline,) = _createDefaultCampaign();

        vm.prank(supporterA);
        campaign.contribute(campaignId, 30 ether);

        vm.prank(creator);
        vm.expectRevert("creator cannot contribute");
        campaign.contribute(campaignId, 20 ether);

        // Normal supporters continue to work exactly as before, before and after the attempt.
        vm.prank(supporterB);
        campaign.contribute(campaignId, 20 ether);
        vm.prank(supporterC);
        campaign.contribute(campaignId, 10 ether);

        assertEq(_totalContributedOf(campaignId), 60 ether);
        assertEq(campaign.getContributorCount(campaignId), 3, "three external supporters, creator excluded");

        // And refunds still settle correctly across exactly those three.
        vm.warp(fundingDeadline);
        campaign.triggerFundingExpiry(campaignId);
        assertEq(_snapshotContributorCount(campaignId), 3);

        uint256 paid = _claim(campaignId, supporterA) + _claim(campaignId, supporterB) + _claim(campaignId, supporterC);
        assertEq(paid, _pool(campaignId), "pool exhausted by external supporters alone");
        assertEq(paid, 60 ether);
    }

    function test_creatorCannotClaimRefund_havingNeverContributed() public {
        (uint256 campaignId, uint256 fundingDeadline,) = _createDefaultCampaign();
        vm.prank(supporterA);
        campaign.contribute(campaignId, 30 ether);
        vm.warp(fundingDeadline);
        campaign.triggerFundingExpiry(campaignId);

        // The creator's bond came back via the bond path, not the refund path; they hold no
        // supporter contribution and so cannot enter refund accounting at all.
        vm.prank(creator);
        vm.expectRevert("no contribution to refund");
        campaign.claimRefund(campaignId);
    }

    function test_creatorOfOneCampaign_canStillSupportAnother() public {
        // The restriction is per-campaign role separation, not a global ban on the address.
        (uint256 ownCampaign,,) = _createDefaultCampaign();

        address otherCreator = address(0x0DDC0DE);
        token.mint(otherCreator, 10_000 ether);
        vm.prank(otherCreator);
        token.approve(address(campaign), type(uint256).max);
        vm.prank(otherCreator);
        uint256 otherCampaign = campaign.createCampaign(
            GOAL,
            BOND,
            _twoMilestoneDescriptions(),
            _twoMilestoneAmounts(),
            block.timestamp + 7 days,
            block.timestamp + 37 days
        );

        vm.prank(creator);
        vm.expectRevert("creator cannot contribute");
        campaign.contribute(ownCampaign, 10 ether);

        vm.prank(creator);
        campaign.contribute(otherCampaign, 10 ether); // must succeed

        assertEq(campaign.contributions(otherCampaign, creator), 10 ether);
        assertEq(campaign.getContributorCount(otherCampaign), 1);
    }

    // ==================== ZERO-VALUE PREVIEW SEMANTICS ====================

    /// @notice previewRefund() == 0 is ambiguous by design: it covers both ineligibility and
    ///         a legitimately claimable dust entitlement. This pins that behaviour so a
    ///         frontend contract change cannot silently alter it.
    function test_previewRefundZero_doesNotImplyIneligible() public {
        uint256 goal = 1_000_001;
        uint256[] memory amts = new uint256[](2);
        amts[0] = goal - 1;
        amts[1] = 1;
        (uint256 campaignId,,) = _createCampaignWith(goal, amts);

        vm.prank(supporterA);
        campaign.contribute(campaignId, 1); // dust
        vm.prank(supporterB);
        campaign.contribute(campaignId, 1_000_000);
        _failAfterFirstMilestoneRelease(campaignId); // pool == 1

        // Eligible-but-zero: preview reads 0, yet the claim succeeds and is recorded.
        assertEq(campaign.previewRefund(campaignId, supporterA), 0, "floored dust entitlement");
        assertGt(campaign.contributions(campaignId, supporterA), 0, "but a real contribution exists");
        assertFalse(campaign.refundClaimed(campaignId, supporterA), "and it is unclaimed");

        vm.prank(supporterA);
        campaign.claimRefund(campaignId); // must not revert
        assertTrue(campaign.refundClaimed(campaignId, supporterA));

        // Genuinely ineligible wallets also read 0, which is why callers must disambiguate
        // using contributions() and refundClaimed() rather than this value alone.
        assertEq(campaign.previewRefund(campaignId, stranger), 0);
        assertEq(campaign.contributions(campaignId, stranger), 0, "no contribution -> truly ineligible");
        assertEq(campaign.previewRefund(campaignId, supporterA), 0, "already claimed -> truly ineligible");
    }

    /// @notice The accounting leaves no residue once everyone claims, but an unclaimed
    ///         entitlement legitimately stays escrowed -- these are different things, and
    ///         neither is a contract accounting defect.
    function test_unclaimedEntitlement_remainsEscrowed_notLostToAccounting() public {
        (uint256 campaignId,,) = _createDefaultCampaign();
        address[] memory s = new address[](2);
        s[0] = supporterA;
        s[1] = supporterB;
        uint256[] memory a = new uint256[](2);
        a[0] = 60 ether;
        a[1] = 40 ether;
        _fund(campaignId, s, a);
        _failAfterFirstMilestoneRelease(campaignId); // pool 60

        uint256 gotA = _claim(campaignId, supporterA); // B deliberately never claims
        assertEq(gotA, 36 ether); // 60 * 60 / 100

        // B's entitlement is still fully preserved and still claimable at any later time.
        assertEq(campaign.previewRefund(campaignId, supporterB), 24 ether, "entitlement intact, just unexercised");
        assertEq(_totalRefunded(campaignId), 36 ether);
        assertLt(_totalRefunded(campaignId), _pool(campaignId), "shortfall is unclaimed, not miscounted");

        // Claiming later settles it exactly, with no residue left by the arithmetic.
        vm.warp(block.timestamp + 365 days);
        assertEq(_claim(campaignId, supporterB), 24 ether);
        assertEq(_totalRefunded(campaignId), _pool(campaignId), "totalRefunded == refundPool once all claim");
    }
}
