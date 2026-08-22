// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../contracts/AdvantageAsymmetryCampaign.sol";
import "./mocks/MockERC20.sol";

/// @notice Day 1 scope only: state machine, creation validation, funding cap/activation,
///         funding-expiry, sequential milestones, atomic approve/reject, execution-expiry
///         fault attribution, bond disposition, existence checks, and pause semantics.
///         claimRefund and patronage are intentionally out of scope (Day 2 / Day 3) and
///         are not tested here.
contract AdvantageAsymmetryCampaignDay1Test is Test {
    AdvantageAsymmetryCampaign campaign;
    MockERC20 token;

    address verifier = address(this); // deployer == owner == verifier for this prototype
    address penaltySink = address(0xBEEF);
    address creator = address(0xC12EA702);
    address supporter1 = address(0x51);
    address supporter2 = address(0x52);

    uint256 constant GOAL = 100 ether;
    uint256 constant BOND = 10 ether;
    uint256 constant MILESTONE_1 = 40 ether;
    uint256 constant MILESTONE_2 = 60 ether;

    function setUp() public {
        token = new MockERC20();
        campaign = new AdvantageAsymmetryCampaign(address(token), penaltySink);

        token.mint(creator, 1_000 ether);
        token.mint(supporter1, 1_000 ether);
        token.mint(supporter2, 1_000 ether);

        vm.prank(creator);
        token.approve(address(campaign), type(uint256).max);
        vm.prank(supporter1);
        token.approve(address(campaign), type(uint256).max);
        vm.prank(supporter2);
        token.approve(address(campaign), type(uint256).max);
    }

    // ---------- helpers ----------

    function _descriptions() internal pure returns (string[] memory d) {
        d = new string[](2);
        d[0] = "Milestone 1: prototype";
        d[1] = "Milestone 2: launch";
    }

    function _amounts() internal pure returns (uint256[] memory a) {
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
        campaignId =
            campaign.createCampaign(GOAL, BOND, _descriptions(), _amounts(), fundingDeadline, executionDeadline);
    }

    function _fundToGoal(uint256 campaignId) internal {
        vm.prank(supporter1);
        campaign.contribute(campaignId, 60 ether);
        vm.prank(supporter2);
        campaign.contribute(campaignId, 40 ether);
    }

    function _statusOf(uint256 campaignId) internal view returns (AdvantageAsymmetryCampaign.CampaignStatus status) {
        (,,,,,,,,, status,,,) = campaign.getCampaign(campaignId);
    }

    function _bondOutcomeOf(uint256 campaignId) internal view returns (AdvantageAsymmetryCampaign.BondOutcome outcome) {
        (,,,,,,,,,,, outcome,) = campaign.getCampaign(campaignId);
    }

    function _failureReasonOf(uint256 campaignId)
        internal
        view
        returns (AdvantageAsymmetryCampaign.FailureReason reason)
    {
        (,,,,,,,,,, reason,,) = campaign.getCampaign(campaignId);
    }

    // ==================== CREATION ====================

    function test_createCampaign_succeeds_andTransfersBond() public {
        uint256 creatorBalBefore = token.balanceOf(creator);
        (uint256 campaignId,,) = _createDefaultCampaign();

        assertEq(campaignId, 0);
        assertEq(token.balanceOf(address(campaign)), BOND);
        assertEq(token.balanceOf(creator), creatorBalBefore - BOND);

        (
            address c,
            uint256 goal,
            uint256 bondAmount,,,,,,,
            AdvantageAsymmetryCampaign.CampaignStatus status,,,
            uint256 milestoneCount
        ) = campaign.getCampaign(campaignId);
        assertEq(c, creator);
        assertEq(goal, GOAL);
        assertEq(bondAmount, BOND);
        assertEq(uint8(status), uint8(AdvantageAsymmetryCampaign.CampaignStatus.Funding));
        assertEq(milestoneCount, 2);
    }

    function test_createCampaign_revertsIf_milestonesDoNotSumToGoal() public {
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 40 ether;
        amounts[1] = 61 ether; // sums to 101, not 100
        vm.prank(creator);
        vm.expectRevert("milestones must sum to goal");
        campaign.createCampaign(
            GOAL, BOND, _descriptions(), amounts, block.timestamp + 1 days, block.timestamp + 10 days
        );
    }

    function test_createCampaign_revertsIf_goalZero() public {
        vm.prank(creator);
        vm.expectRevert("goal must be > 0");
        campaign.createCampaign(
            0, BOND, _descriptions(), _amounts(), block.timestamp + 1 days, block.timestamp + 10 days
        );
    }

    function test_createCampaign_revertsIf_bondZero() public {
        vm.prank(creator);
        vm.expectRevert("bond must be > 0");
        campaign.createCampaign(
            GOAL, 0, _descriptions(), _amounts(), block.timestamp + 1 days, block.timestamp + 10 days
        );
    }

    function test_createCampaign_revertsIf_noMilestones() public {
        string[] memory d = new string[](0);
        uint256[] memory a = new uint256[](0);
        vm.prank(creator);
        vm.expectRevert("need at least one milestone");
        campaign.createCampaign(GOAL, BOND, d, a, block.timestamp + 1 days, block.timestamp + 10 days);
    }

    function test_createCampaign_revertsIf_arrayLengthMismatch() public {
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = GOAL;
        vm.prank(creator);
        vm.expectRevert("milestone arrays mismatch");
        campaign.createCampaign(
            GOAL, BOND, _descriptions(), amounts, block.timestamp + 1 days, block.timestamp + 10 days
        );
    }

    function test_createCampaign_revertsIf_zeroMilestoneAmount() public {
        string[] memory d = new string[](2);
        d[0] = "a";
        d[1] = "b";
        uint256[] memory a = new uint256[](2);
        a[0] = 0;
        a[1] = GOAL;
        vm.prank(creator);
        vm.expectRevert("milestone amount must be > 0");
        campaign.createCampaign(GOAL, BOND, d, a, block.timestamp + 1 days, block.timestamp + 10 days);
    }

    function test_createCampaign_revertsIf_fundingDeadlineNotFuture() public {
        vm.prank(creator);
        vm.expectRevert("funding deadline must be in the future");
        campaign.createCampaign(GOAL, BOND, _descriptions(), _amounts(), block.timestamp, block.timestamp + 10 days);
    }

    function test_createCampaign_revertsIf_executionDeadlineBeforeFundingDeadline() public {
        uint256 fundingDeadline = block.timestamp + 10 days;
        vm.prank(creator);
        vm.expectRevert("execution deadline must follow funding deadline");
        campaign.createCampaign(GOAL, BOND, _descriptions(), _amounts(), fundingDeadline, fundingDeadline - 1);
    }

    function test_createCampaign_revertsIf_creatorIsVerifier() public {
        vm.prank(verifier);
        vm.expectRevert("creator cannot be the verifier");
        campaign.createCampaign(
            GOAL, BOND, _descriptions(), _amounts(), block.timestamp + 1 days, block.timestamp + 10 days
        );
    }

    function test_createCampaign_revertsIf_creatorIsPenaltySink() public {
        token.mint(penaltySink, 1_000 ether);
        vm.prank(penaltySink);
        token.approve(address(campaign), type(uint256).max);
        vm.prank(penaltySink);
        vm.expectRevert("creator cannot be the penalty sink");
        campaign.createCampaign(
            GOAL, BOND, _descriptions(), _amounts(), block.timestamp + 1 days, block.timestamp + 10 days
        );
    }

    function test_createCampaign_revertsWhenPaused() public {
        campaign.pause();
        vm.prank(creator);
        vm.expectRevert();
        campaign.createCampaign(
            GOAL, BOND, _descriptions(), _amounts(), block.timestamp + 1 days, block.timestamp + 10 days
        );
    }

    // ---------- constructor validation ----------

    function test_constructor_revertsIf_tokenZeroAddress() public {
        vm.expectRevert("token cannot be zero address");
        new AdvantageAsymmetryCampaign(address(0), penaltySink);
    }

    function test_constructor_revertsIf_sinkZeroAddress() public {
        vm.expectRevert("penalty sink cannot be zero address");
        new AdvantageAsymmetryCampaign(address(token), address(0));
    }

    function test_constructor_revertsIf_sinkIsDeployer() public {
        vm.expectRevert("penalty sink cannot be the verifier");
        new AdvantageAsymmetryCampaign(address(token), address(this));
    }

    // ==================== FUNDING ====================

    function test_contribute_succeeds_inFunding() public {
        (uint256 campaignId,,) = _createDefaultCampaign();

        vm.prank(supporter1);
        campaign.contribute(campaignId, 30 ether);

        assertEq(campaign.contributions(campaignId, supporter1), 30 ether);
        (,,, uint256 totalContributed,,,,,,,,,) = campaign.getCampaign(campaignId);
        assertEq(totalContributed, 30 ether);
    }

    function test_contribute_revertsAfterFundingDeadline() public {
        (uint256 campaignId, uint256 fundingDeadline,) = _createDefaultCampaign();
        vm.warp(fundingDeadline);

        vm.prank(supporter1);
        vm.expectRevert("funding deadline has passed");
        campaign.contribute(campaignId, 10 ether);
    }

    function test_contribute_revertsIfExceedsRemainingGoal() public {
        (uint256 campaignId,,) = _createDefaultCampaign();

        vm.prank(supporter1);
        vm.expectRevert("amount exceeds remaining goal");
        campaign.contribute(campaignId, GOAL + 1);
    }

    function test_contribute_revertsIfExceedsRemainingGoal_afterPartialFunding() public {
        (uint256 campaignId,,) = _createDefaultCampaign();
        vm.prank(supporter1);
        campaign.contribute(campaignId, 90 ether);

        vm.prank(supporter2);
        vm.expectRevert("amount exceeds remaining goal");
        campaign.contribute(campaignId, 11 ether); // only 10 ether remains
    }

    function test_contribute_exactGoal_activatesCampaign() public {
        (uint256 campaignId,,) = _createDefaultCampaign();

        vm.prank(supporter1);
        campaign.contribute(campaignId, 60 ether); // partial -- must not activate yet
        assertEq(uint8(_statusOf(campaignId)), uint8(AdvantageAsymmetryCampaign.CampaignStatus.Funding));

        vm.expectEmit(true, false, false, false);
        emit AdvantageAsymmetryCampaign.CampaignActivated(campaignId);

        vm.prank(supporter2);
        campaign.contribute(campaignId, 40 ether); // completes the goal exactly

        assertEq(uint8(_statusOf(campaignId)), uint8(AdvantageAsymmetryCampaign.CampaignStatus.Active));
    }

    function test_contribute_revertsWhenActive() public {
        (uint256 campaignId,,) = _createDefaultCampaign();
        _fundToGoal(campaignId);

        vm.prank(supporter1);
        vm.expectRevert("campaign not in funding");
        campaign.contribute(campaignId, 1 ether);
    }

    function test_contribute_revertsWhenFailed() public {
        (uint256 campaignId, uint256 fundingDeadline,) = _createDefaultCampaign();
        vm.warp(fundingDeadline);
        campaign.triggerFundingExpiry(campaignId);

        vm.prank(supporter1);
        vm.expectRevert("campaign not in funding");
        campaign.contribute(campaignId, 1 ether);
    }

    function test_contribute_revertsWhenPaused() public {
        (uint256 campaignId,,) = _createDefaultCampaign();
        campaign.pause();

        vm.prank(supporter1);
        vm.expectRevert();
        campaign.contribute(campaignId, 1 ether);
    }

    function test_contribute_revertsOnNonexistentCampaign() public {
        vm.prank(supporter1);
        vm.expectRevert("campaign does not exist");
        campaign.contribute(999, 1 ether);
    }

    // ---------- funding expiry ----------

    function test_triggerFundingExpiry_returnsBondAndMarksUnderfunded() public {
        (uint256 campaignId, uint256 fundingDeadline,) = _createDefaultCampaign();
        vm.prank(supporter1);
        campaign.contribute(campaignId, 20 ether); // underfunded

        uint256 creatorBalBefore = token.balanceOf(creator);
        vm.warp(fundingDeadline);

        vm.expectEmit(true, false, false, true);
        emit AdvantageAsymmetryCampaign.BondReturned(campaignId, creator, BOND);
        campaign.triggerFundingExpiry(campaignId);

        assertEq(uint8(_statusOf(campaignId)), uint8(AdvantageAsymmetryCampaign.CampaignStatus.Failed));
        assertEq(uint8(_failureReasonOf(campaignId)), uint8(AdvantageAsymmetryCampaign.FailureReason.Underfunded));
        assertEq(uint8(_bondOutcomeOf(campaignId)), uint8(AdvantageAsymmetryCampaign.BondOutcome.Returned));
        assertEq(token.balanceOf(creator), creatorBalBefore + BOND);
    }

    function test_triggerFundingExpiry_isPermissionless() public {
        (uint256 campaignId, uint256 fundingDeadline,) = _createDefaultCampaign();
        vm.warp(fundingDeadline);

        vm.prank(supporter2); // arbitrary caller, not owner/creator
        campaign.triggerFundingExpiry(campaignId);

        assertEq(uint8(_statusOf(campaignId)), uint8(AdvantageAsymmetryCampaign.CampaignStatus.Failed));
    }

    function test_triggerFundingExpiry_revertsBeforeDeadline() public {
        (uint256 campaignId,,) = _createDefaultCampaign();
        vm.expectRevert("funding deadline not yet reached");
        campaign.triggerFundingExpiry(campaignId);
    }

    function test_triggerFundingExpiry_revertsIfAlreadyActive() public {
        (uint256 campaignId, uint256 fundingDeadline,) = _createDefaultCampaign();
        _fundToGoal(campaignId);
        vm.warp(fundingDeadline);

        vm.expectRevert("campaign not in funding");
        campaign.triggerFundingExpiry(campaignId);
    }

    function test_triggerFundingExpiry_worksWhilePaused() public {
        (uint256 campaignId, uint256 fundingDeadline,) = _createDefaultCampaign();
        vm.warp(fundingDeadline);
        campaign.pause();

        campaign.triggerFundingExpiry(campaignId); // must NOT revert -- exits stay open while paused
        assertEq(uint8(_statusOf(campaignId)), uint8(AdvantageAsymmetryCampaign.CampaignStatus.Failed));
    }

    // ==================== MILESTONES ====================

    function test_submitMilestone_onlyCreator() public {
        (uint256 campaignId,,) = _createDefaultCampaign();
        _fundToGoal(campaignId);

        vm.prank(supporter1);
        vm.expectRevert("only creator");
        campaign.submitMilestone(campaignId, 0, "ipfs://evidence-1");
    }

    function test_submitMilestone_revertsIfNotActive() public {
        (uint256 campaignId,,) = _createDefaultCampaign();
        // still in Funding
        vm.prank(creator);
        vm.expectRevert("campaign not active");
        campaign.submitMilestone(campaignId, 0, "ipfs://evidence-1");
    }

    function test_submitMilestone_revertsOutOfOrder() public {
        (uint256 campaignId,,) = _createDefaultCampaign();
        _fundToGoal(campaignId);

        vm.prank(creator);
        vm.expectRevert("not the next milestone");
        campaign.submitMilestone(campaignId, 1, "ipfs://evidence-2"); // skipping milestone 0
    }

    function test_submitMilestone_worksWhilePaused() public {
        (uint256 campaignId,,) = _createDefaultCampaign();
        _fundToGoal(campaignId);
        campaign.pause();

        vm.prank(creator);
        campaign.submitMilestone(campaignId, 0, "ipfs://evidence-1"); // must NOT revert

        AdvantageAsymmetryCampaign.Milestone memory m = campaign.getMilestone(campaignId, 0);
        assertEq(uint8(m.status), uint8(AdvantageAsymmetryCampaign.MilestoneStatus.Submitted));
    }

    // ---------- approve ----------

    function test_approveMilestone_releasesExactAmount_andAdvancesIndex() public {
        (uint256 campaignId,,) = _createDefaultCampaign();
        _fundToGoal(campaignId);
        vm.prank(creator);
        campaign.submitMilestone(campaignId, 0, "ipfs://evidence-1");

        uint256 creatorBalBefore = token.balanceOf(creator);
        campaign.approveMilestone(campaignId, 0);

        assertEq(token.balanceOf(creator), creatorBalBefore + MILESTONE_1);
        (,,,, uint256 totalReleased, uint256 nextMilestoneIndex,,,,,,,) = campaign.getCampaign(campaignId);
        assertEq(totalReleased, MILESTONE_1);
        assertEq(nextMilestoneIndex, 1);
        assertEq(uint8(_statusOf(campaignId)), uint8(AdvantageAsymmetryCampaign.CampaignStatus.Active));
    }

    function test_approveMilestone_onlyOwner() public {
        (uint256 campaignId,,) = _createDefaultCampaign();
        _fundToGoal(campaignId);
        vm.prank(creator);
        campaign.submitMilestone(campaignId, 0, "ipfs://evidence-1");

        vm.prank(creator);
        vm.expectRevert(); // Ownable custom error
        campaign.approveMilestone(campaignId, 0);
    }

    function test_approveMilestone_revertsIfNotSubmitted() public {
        (uint256 campaignId,,) = _createDefaultCampaign();
        _fundToGoal(campaignId);

        vm.expectRevert("milestone not submitted");
        campaign.approveMilestone(campaignId, 0);
    }

    function test_approveMilestone_revertsWhenPaused() public {
        (uint256 campaignId,,) = _createDefaultCampaign();
        _fundToGoal(campaignId);
        vm.prank(creator);
        campaign.submitMilestone(campaignId, 0, "ipfs://evidence-1");
        campaign.pause();

        vm.expectRevert();
        campaign.approveMilestone(campaignId, 0);
    }

    function test_finalMilestoneApproval_succeedsCampaign_andReturnsBond() public {
        (uint256 campaignId,,) = _createDefaultCampaign();
        _fundToGoal(campaignId);

        vm.prank(creator);
        campaign.submitMilestone(campaignId, 0, "ipfs://evidence-1");
        campaign.approveMilestone(campaignId, 0);

        vm.prank(creator);
        campaign.submitMilestone(campaignId, 1, "ipfs://evidence-2");

        uint256 creatorBalBefore = token.balanceOf(creator);

        vm.expectEmit(true, false, false, false);
        emit AdvantageAsymmetryCampaign.CampaignSucceeded(campaignId);
        campaign.approveMilestone(campaignId, 1);

        assertEq(uint8(_statusOf(campaignId)), uint8(AdvantageAsymmetryCampaign.CampaignStatus.Succeeded));
        assertEq(uint8(_bondOutcomeOf(campaignId)), uint8(AdvantageAsymmetryCampaign.BondOutcome.Returned));
        // creator receives milestone 2 amount AND the bond in the same tx
        assertEq(token.balanceOf(creator), creatorBalBefore + MILESTONE_2 + BOND);

        (,,,, uint256 totalReleased,,,,,,,,) = campaign.getCampaign(campaignId);
        assertEq(totalReleased, GOAL);
    }

    function test_cannotReleaseSameMilestoneTwice() public {
        (uint256 campaignId,,) = _createDefaultCampaign();
        _fundToGoal(campaignId);
        vm.prank(creator);
        campaign.submitMilestone(campaignId, 0, "ipfs://evidence-1");
        campaign.approveMilestone(campaignId, 0);

        vm.expectRevert("not the next milestone");
        campaign.approveMilestone(campaignId, 0);
    }

    // ---------- reject ----------

    function test_rejectMilestone_failsCampaign_andSlashesBondToSink() public {
        (uint256 campaignId,,) = _createDefaultCampaign();
        _fundToGoal(campaignId);
        vm.prank(creator);
        campaign.submitMilestone(campaignId, 0, "ipfs://evidence-1");

        uint256 sinkBalBefore = token.balanceOf(penaltySink);

        vm.expectEmit(true, false, false, true);
        emit AdvantageAsymmetryCampaign.BondSlashed(campaignId, penaltySink, BOND);
        campaign.rejectMilestone(campaignId, 0);

        assertEq(uint8(_statusOf(campaignId)), uint8(AdvantageAsymmetryCampaign.CampaignStatus.Failed));
        assertEq(uint8(_failureReasonOf(campaignId)), uint8(AdvantageAsymmetryCampaign.FailureReason.MilestoneRejected));
        assertEq(uint8(_bondOutcomeOf(campaignId)), uint8(AdvantageAsymmetryCampaign.BondOutcome.Slashed));
        assertEq(token.balanceOf(penaltySink), sinkBalBefore + BOND);
    }

    function test_rejectMilestone_onlyOwner() public {
        (uint256 campaignId,,) = _createDefaultCampaign();
        _fundToGoal(campaignId);
        vm.prank(creator);
        campaign.submitMilestone(campaignId, 0, "ipfs://evidence-1");

        vm.prank(creator);
        vm.expectRevert();
        campaign.rejectMilestone(campaignId, 0);
    }

    function test_rejectMilestone_revertsWhenPaused() public {
        (uint256 campaignId,,) = _createDefaultCampaign();
        _fundToGoal(campaignId);
        vm.prank(creator);
        campaign.submitMilestone(campaignId, 0, "ipfs://evidence-1");
        campaign.pause();

        vm.expectRevert();
        campaign.rejectMilestone(campaignId, 0);
    }

    function test_stoppedAfterFailure_noFurtherMilestoneRelease() public {
        (uint256 campaignId,,) = _createDefaultCampaign();
        _fundToGoal(campaignId);
        vm.prank(creator);
        campaign.submitMilestone(campaignId, 0, "ipfs://evidence-1");
        campaign.rejectMilestone(campaignId, 0);

        vm.expectRevert("campaign not active");
        campaign.approveMilestone(campaignId, 0);
    }

    // ---------- execution expiry: fault attribution ----------

    function test_executionExpiry_creatorNeverSubmitted_slashesBond() public {
        (uint256 campaignId,, uint256 executionDeadline) = _createDefaultCampaign();
        _fundToGoal(campaignId);
        // creator never calls submitMilestone
        vm.warp(executionDeadline);

        uint256 sinkBalBefore = token.balanceOf(penaltySink);
        campaign.triggerExecutionExpiry(campaignId);

        assertEq(uint8(_statusOf(campaignId)), uint8(AdvantageAsymmetryCampaign.CampaignStatus.Failed));
        assertEq(
            uint8(_failureReasonOf(campaignId)), uint8(AdvantageAsymmetryCampaign.FailureReason.CreatorExecutionExpired)
        );
        assertEq(uint8(_bondOutcomeOf(campaignId)), uint8(AdvantageAsymmetryCampaign.BondOutcome.Slashed));
        assertEq(token.balanceOf(penaltySink), sinkBalBefore + BOND);
    }

    function test_executionExpiry_verifierNeverRuled_returnsBond_doesNotSlash() public {
        (uint256 campaignId,, uint256 executionDeadline) = _createDefaultCampaign();
        _fundToGoal(campaignId);
        vm.prank(creator);
        campaign.submitMilestone(campaignId, 0, "ipfs://evidence-1"); // submitted in time
        // verifier never calls approve/reject
        vm.warp(executionDeadline);

        uint256 creatorBalBefore = token.balanceOf(creator);
        campaign.triggerExecutionExpiry(campaignId);

        assertEq(uint8(_statusOf(campaignId)), uint8(AdvantageAsymmetryCampaign.CampaignStatus.Failed));
        assertEq(
            uint8(_failureReasonOf(campaignId)), uint8(AdvantageAsymmetryCampaign.FailureReason.VerifierReviewExpired)
        );
        assertEq(uint8(_bondOutcomeOf(campaignId)), uint8(AdvantageAsymmetryCampaign.BondOutcome.Returned));
        assertEq(token.balanceOf(creator), creatorBalBefore + BOND);
    }

    function test_executionExpiry_isPermissionless() public {
        (uint256 campaignId,, uint256 executionDeadline) = _createDefaultCampaign();
        _fundToGoal(campaignId);
        vm.warp(executionDeadline);

        vm.prank(supporter1);
        campaign.triggerExecutionExpiry(campaignId);

        assertEq(uint8(_statusOf(campaignId)), uint8(AdvantageAsymmetryCampaign.CampaignStatus.Failed));
    }

    function test_executionExpiry_revertsBeforeDeadline() public {
        (uint256 campaignId,,) = _createDefaultCampaign();
        _fundToGoal(campaignId);

        vm.expectRevert("execution deadline not yet reached");
        campaign.triggerExecutionExpiry(campaignId);
    }

    function test_executionExpiry_revertsIfNotActive() public {
        (uint256 campaignId, uint256 fundingDeadline, uint256 executionDeadline) = _createDefaultCampaign();
        // never funded -- still in Funding
        vm.warp(executionDeadline);

        vm.expectRevert("campaign not active");
        campaign.triggerExecutionExpiry(campaignId);
        // fundingDeadline referenced only to silence unused-var warning in some tooling
        fundingDeadline;
    }

    function test_executionExpiry_worksWhilePaused() public {
        (uint256 campaignId,, uint256 executionDeadline) = _createDefaultCampaign();
        _fundToGoal(campaignId);
        vm.warp(executionDeadline);
        campaign.pause();

        campaign.triggerExecutionExpiry(campaignId); // must NOT revert
        assertEq(uint8(_statusOf(campaignId)), uint8(AdvantageAsymmetryCampaign.CampaignStatus.Failed));
    }

    // ---------- bond resolves exactly once (guarded via state, spot-checked here) ----------

    function test_bondCannotBeDisposedTwice_viaDoubleFundingExpiry() public {
        (uint256 campaignId, uint256 fundingDeadline,) = _createDefaultCampaign();
        vm.warp(fundingDeadline);
        campaign.triggerFundingExpiry(campaignId);

        vm.expectRevert("campaign not in funding");
        campaign.triggerFundingExpiry(campaignId);
    }

    function test_bondCannotBeDisposedTwice_viaDoubleExecutionExpiry() public {
        (uint256 campaignId,, uint256 executionDeadline) = _createDefaultCampaign();
        _fundToGoal(campaignId);
        vm.warp(executionDeadline);
        campaign.triggerExecutionExpiry(campaignId);

        vm.expectRevert("campaign not active");
        campaign.triggerExecutionExpiry(campaignId);
    }

    // ==================== EXISTENCE CHECKS ====================

    function test_getCampaign_revertsOnNonexistentId() public {
        vm.expectRevert("campaign does not exist");
        campaign.getCampaign(0);
    }

    function test_getMilestone_revertsOnNonexistentCampaign() public {
        vm.expectRevert("campaign does not exist");
        campaign.getMilestone(0, 0);
    }

    function test_getMilestone_revertsOnNonexistentMilestone() public {
        (uint256 campaignId,,) = _createDefaultCampaign();
        vm.expectRevert("milestone does not exist");
        campaign.getMilestone(campaignId, 5);
    }

    function test_submitMilestone_revertsOnNonexistentCampaign() public {
        vm.expectRevert("campaign does not exist");
        campaign.submitMilestone(0, 0, "x");
    }

    function test_approveMilestone_revertsOnNonexistentMilestone() public {
        (uint256 campaignId,,) = _createDefaultCampaign();
        _fundToGoal(campaignId);
        vm.expectRevert("milestone does not exist");
        campaign.approveMilestone(campaignId, 5);
    }

    // ==================== PAUSE ACCESS CONTROL ====================

    function test_pause_onlyOwner() public {
        vm.prank(creator);
        vm.expectRevert();
        campaign.pause();
    }

    function test_unpause_onlyOwner() public {
        campaign.pause();
        vm.prank(creator);
        vm.expectRevert();
        campaign.unpause();
    }

    // ==================== EXECUTION-DEADLINE HARD BOUNDARY ====================
    //
    // Independent review finding #1: submitMilestone/approveMilestone/rejectMilestone
    // must be impossible at/after executionDeadline, so triggerExecutionExpiry is the
    // sole resolution path from that instant on -- closing both the late-submission
    // reclassification bypass and the rejectMilestone-vs-triggerExecutionExpiry race.

    function test_submitMilestone_revertsAtExecutionDeadline() public {
        (uint256 campaignId,, uint256 executionDeadline) = _createDefaultCampaign();
        _fundToGoal(campaignId);
        vm.warp(executionDeadline);

        vm.prank(creator);
        vm.expectRevert("execution deadline has passed");
        campaign.submitMilestone(campaignId, 0, "ipfs://late");
    }

    function test_submitMilestone_revertsAfterExecutionDeadline() public {
        (uint256 campaignId,, uint256 executionDeadline) = _createDefaultCampaign();
        _fundToGoal(campaignId);
        vm.warp(executionDeadline + 1 hours);

        vm.prank(creator);
        vm.expectRevert("execution deadline has passed");
        campaign.submitMilestone(campaignId, 0, "ipfs://late");
    }

    function test_submitMilestone_allowedRightBeforeExecutionDeadline() public {
        (uint256 campaignId,, uint256 executionDeadline) = _createDefaultCampaign();
        _fundToGoal(campaignId);
        vm.warp(executionDeadline - 1);

        vm.prank(creator);
        campaign.submitMilestone(campaignId, 0, "ipfs://just-in-time"); // must NOT revert

        AdvantageAsymmetryCampaign.Milestone memory m = campaign.getMilestone(campaignId, 0);
        assertEq(uint8(m.status), uint8(AdvantageAsymmetryCampaign.MilestoneStatus.Submitted));
    }

    function test_approveMilestone_revertsAtExecutionDeadline_evenIfSubmittedInTime() public {
        (uint256 campaignId,, uint256 executionDeadline) = _createDefaultCampaign();
        _fundToGoal(campaignId);
        vm.prank(creator);
        campaign.submitMilestone(campaignId, 0, "ipfs://on-time");
        vm.warp(executionDeadline);

        vm.expectRevert("execution deadline has passed");
        campaign.approveMilestone(campaignId, 0);
    }

    function test_rejectMilestone_revertsAtExecutionDeadline_evenIfSubmittedInTime() public {
        (uint256 campaignId,, uint256 executionDeadline) = _createDefaultCampaign();
        _fundToGoal(campaignId);
        vm.prank(creator);
        campaign.submitMilestone(campaignId, 0, "ipfs://on-time");
        vm.warp(executionDeadline);

        vm.expectRevert("execution deadline has passed");
        campaign.rejectMilestone(campaignId, 0);
    }

    function test_timelySubmission_thenVerifierNeverRules_resolvesViaExpiry_bondReturned() public {
        (uint256 campaignId,, uint256 executionDeadline) = _createDefaultCampaign();
        _fundToGoal(campaignId);
        vm.prank(creator);
        campaign.submitMilestone(campaignId, 0, "ipfs://on-time"); // timely
        vm.warp(executionDeadline);

        uint256 creatorBalBefore = token.balanceOf(creator);
        campaign.triggerExecutionExpiry(campaignId);

        assertEq(
            uint8(_failureReasonOf(campaignId)), uint8(AdvantageAsymmetryCampaign.FailureReason.VerifierReviewExpired)
        );
        assertEq(uint8(_bondOutcomeOf(campaignId)), uint8(AdvantageAsymmetryCampaign.BondOutcome.Returned));
        assertEq(token.balanceOf(creator), creatorBalBefore + BOND);
    }

    /// @notice Directly demonstrates elimination of the post-deadline slash/return race:
    ///         once the deadline hits, the verifier's rejectMilestone (slash) path is no
    ///         longer callable at all, so there is no transaction-order dependency left --
    ///         triggerExecutionExpiry is the only path, and it always returns the bond for
    ///         a milestone that was genuinely submitted on time.
    function test_race_rejectVsExpiry_eliminated_forTimelySubmission() public {
        (uint256 campaignId,, uint256 executionDeadline) = _createDefaultCampaign();
        _fundToGoal(campaignId);
        vm.prank(creator);
        campaign.submitMilestone(campaignId, 0, "ipfs://on-time");
        vm.warp(executionDeadline);

        // The verifier can no longer slash this timely submission, regardless of tx order.
        vm.expectRevert("execution deadline has passed");
        campaign.rejectMilestone(campaignId, 0);

        // The sole remaining path resolves in the creator's favour.
        campaign.triggerExecutionExpiry(campaignId);
        assertEq(
            uint8(_failureReasonOf(campaignId)), uint8(AdvantageAsymmetryCampaign.FailureReason.VerifierReviewExpired)
        );
        assertEq(uint8(_bondOutcomeOf(campaignId)), uint8(AdvantageAsymmetryCampaign.BondOutcome.Returned));
    }

    /// @notice Directly demonstrates elimination of the late-submission reclassification
    ///         bypass: submitting after the deadline now reverts outright, so a creator can
    ///         no longer manufacture a "Submitted" state after the fact to be reclassified
    ///         as VerifierReviewExpired instead of CreatorExecutionExpired.
    function test_creatorCannotBypassSlashing_viaLateSubmission() public {
        (uint256 campaignId,, uint256 executionDeadline) = _createDefaultCampaign();
        _fundToGoal(campaignId);
        vm.warp(executionDeadline);

        vm.prank(creator);
        vm.expectRevert("execution deadline has passed");
        campaign.submitMilestone(campaignId, 0, "ipfs://too-late");

        // Milestone is still Pending at the deadline -> expiry correctly attributes fault
        // to the creator and slashes the bond.
        campaign.triggerExecutionExpiry(campaignId);
        assertEq(
            uint8(_failureReasonOf(campaignId)), uint8(AdvantageAsymmetryCampaign.FailureReason.CreatorExecutionExpired)
        );
        assertEq(uint8(_bondOutcomeOf(campaignId)), uint8(AdvantageAsymmetryCampaign.BondOutcome.Slashed));
    }

    // ==================== VERIFIER IDENTITY FIXED FOR DEPLOYMENT ====================
    //
    // Independent review finding #2: transferOwnership/renounceOwnership must be disabled
    // so the verifier role can never move to a creator or to the penalty sink.

    function test_transferOwnership_disabled_whenCalledByOwner() public {
        vm.expectRevert("verifier is fixed for this deployment");
        campaign.transferOwnership(supporter1);
    }

    function test_transferOwnership_disabled_whenCalledByNonOwner() public {
        vm.prank(creator);
        vm.expectRevert(); // Ownable's own auth error fires before our override's body
        campaign.transferOwnership(creator);
    }

    function test_renounceOwnership_disabled_whenCalledByOwner() public {
        vm.expectRevert("verifier is fixed for this deployment");
        campaign.renounceOwnership();
    }

    function test_renounceOwnership_disabled_whenCalledByNonOwner() public {
        vm.prank(creator);
        vm.expectRevert(); // Ownable's own auth error fires before our override's body
        campaign.renounceOwnership();
    }

    function test_ownerUnchanged_afterFailedTransferAttempt() public {
        vm.expectRevert("verifier is fixed for this deployment");
        campaign.transferOwnership(creator);
        assertEq(campaign.owner(), verifier);
    }

    function test_ownerUnchanged_afterFailedRenounceAttempt() public {
        vm.expectRevert("verifier is fixed for this deployment");
        campaign.renounceOwnership();
        assertEq(campaign.owner(), verifier);
    }

    // ==================== VERIFIER / PENALTY SINK CANNOT CONTRIBUTE ====================

    function test_contribute_revertsForVerifier() public {
        (uint256 campaignId,,) = _createDefaultCampaign();
        token.mint(verifier, 10 ether);
        token.approve(address(campaign), type(uint256).max);

        vm.expectRevert("verifier cannot contribute");
        campaign.contribute(campaignId, 1 ether);
    }

    function test_contribute_revertsForPenaltySink() public {
        (uint256 campaignId,,) = _createDefaultCampaign();
        token.mint(penaltySink, 10 ether);
        vm.prank(penaltySink);
        token.approve(address(campaign), type(uint256).max);

        vm.prank(penaltySink);
        vm.expectRevert("penalty sink cannot contribute");
        campaign.contribute(campaignId, 1 ether);
    }

    // ==================== EVIDENCE URI REQUIRED ====================

    function test_submitMilestone_revertsOnEmptyEvidenceURI() public {
        (uint256 campaignId,,) = _createDefaultCampaign();
        _fundToGoal(campaignId);

        vm.prank(creator);
        vm.expectRevert("evidence URI required");
        campaign.submitMilestone(campaignId, 0, "");
    }

    // ==================== FUZZ / ADVERSARIAL ====================

    /// @notice Contribution bounds: no matter how the fuzzer splits two contributions,
    ///         totalContributed never exceeds goal, and any amount that would push it over
    ///         reverts rather than silently truncating.
    function testFuzz_contribute_neverExceedsGoal(uint256 amount1, uint256 amount2) public {
        amount1 = bound(amount1, 1, 500 ether);
        amount2 = bound(amount2, 1, 500 ether);
        (uint256 campaignId,,) = _createDefaultCampaign();

        vm.prank(supporter1);
        if (amount1 > GOAL) {
            vm.expectRevert("amount exceeds remaining goal");
            campaign.contribute(campaignId, amount1);
        } else {
            campaign.contribute(campaignId, amount1);
        }

        (,,, uint256 contributedAfterFirst,,,,,, AdvantageAsymmetryCampaign.CampaignStatus statusAfterFirst,,,) =
            campaign.getCampaign(campaignId);
        assertLe(contributedAfterFirst, GOAL);

        vm.prank(supporter2);
        if (statusAfterFirst != AdvantageAsymmetryCampaign.CampaignStatus.Funding) {
            vm.expectRevert("campaign not in funding");
            campaign.contribute(campaignId, amount2);
        } else if (amount2 > GOAL - contributedAfterFirst) {
            vm.expectRevert("amount exceeds remaining goal");
            campaign.contribute(campaignId, amount2);
        } else {
            campaign.contribute(campaignId, amount2);
        }

        (,,, uint256 contributedFinal,,,,,,,,,) = campaign.getCampaign(campaignId);
        assertLe(contributedFinal, GOAL);
    }

    /// @notice Terminal-state irreversibility: once a campaign has failed, no
    ///         state-changing function can move it anywhere, regardless of which one the
    ///         fuzzer picks.
    function testFuzz_failedCampaign_rejectsAllStateChangingActions(uint8 actionSeed) public {
        (uint256 campaignId, uint256 fundingDeadline,) = _createDefaultCampaign();
        vm.warp(fundingDeadline);
        campaign.triggerFundingExpiry(campaignId); // Failed (Underfunded)

        uint8 action = uint8(bound(actionSeed, 0, 4));
        if (action == 0) {
            vm.prank(supporter1);
            vm.expectRevert("campaign not in funding");
            campaign.contribute(campaignId, 1 ether);
        } else if (action == 1) {
            vm.prank(creator);
            vm.expectRevert("campaign not active");
            campaign.submitMilestone(campaignId, 0, "ipfs://x");
        } else if (action == 2) {
            vm.expectRevert("campaign not active");
            campaign.approveMilestone(campaignId, 0);
        } else if (action == 3) {
            vm.expectRevert("campaign not active");
            campaign.rejectMilestone(campaignId, 0);
        } else {
            vm.expectRevert("campaign not in funding");
            campaign.triggerFundingExpiry(campaignId);
        }

        assertEq(uint8(_statusOf(campaignId)), uint8(AdvantageAsymmetryCampaign.CampaignStatus.Failed));
    }

    /// @notice Terminal-state irreversibility: once a campaign has succeeded, no
    ///         state-changing function can move it anywhere, regardless of which one the
    ///         fuzzer picks.
    function testFuzz_succeededCampaign_rejectsAllStateChangingActions(uint8 actionSeed) public {
        (uint256 campaignId,,) = _createDefaultCampaign();
        _fundToGoal(campaignId);
        vm.prank(creator);
        campaign.submitMilestone(campaignId, 0, "ipfs://1");
        campaign.approveMilestone(campaignId, 0);
        vm.prank(creator);
        campaign.submitMilestone(campaignId, 1, "ipfs://2");
        campaign.approveMilestone(campaignId, 1); // Succeeded

        uint8 action = uint8(bound(actionSeed, 0, 5));
        if (action == 0) {
            vm.prank(supporter1);
            vm.expectRevert("campaign not in funding");
            campaign.contribute(campaignId, 1 ether);
        } else if (action == 1) {
            vm.prank(creator);
            vm.expectRevert("campaign not active");
            campaign.submitMilestone(campaignId, 1, "ipfs://x");
        } else if (action == 2) {
            vm.expectRevert("campaign not active");
            campaign.approveMilestone(campaignId, 1);
        } else if (action == 3) {
            vm.expectRevert("campaign not active");
            campaign.rejectMilestone(campaignId, 1);
        } else if (action == 4) {
            vm.expectRevert("campaign not in funding");
            campaign.triggerFundingExpiry(campaignId);
        } else {
            vm.expectRevert("campaign not active");
            campaign.triggerExecutionExpiry(campaignId);
        }

        assertEq(uint8(_statusOf(campaignId)), uint8(AdvantageAsymmetryCampaign.CampaignStatus.Succeeded));
    }

    /// @notice Release bounds: for any fuzzed two-milestone split, totalReleased never
    ///         exceeds goal at any intermediate step and equals goal exactly at the end.
    function testFuzz_totalReleasedNeverExceedsGoal(uint256 m1, uint256 m2) public {
        m1 = bound(m1, 1, 400 ether);
        m2 = bound(m2, 1, 400 ether);
        uint256 fuzzGoal = m1 + m2;

        string[] memory d = new string[](2);
        d[0] = "m1";
        d[1] = "m2";
        uint256[] memory amts = new uint256[](2);
        amts[0] = m1;
        amts[1] = m2;

        uint256 fundingDeadline = block.timestamp + 7 days;
        uint256 executionDeadline = fundingDeadline + 30 days;

        vm.prank(creator);
        uint256 campaignId = campaign.createCampaign(fuzzGoal, BOND, d, amts, fundingDeadline, executionDeadline);

        token.mint(supporter1, fuzzGoal);
        vm.prank(supporter1);
        campaign.contribute(campaignId, fuzzGoal);

        vm.prank(creator);
        campaign.submitMilestone(campaignId, 0, "ipfs://1");
        campaign.approveMilestone(campaignId, 0);
        (,,,, uint256 releasedAfter1,,,,,,,,) = campaign.getCampaign(campaignId);
        assertLe(releasedAfter1, fuzzGoal);
        assertEq(releasedAfter1, m1);

        vm.prank(creator);
        campaign.submitMilestone(campaignId, 1, "ipfs://2");
        campaign.approveMilestone(campaignId, 1);
        (,,,, uint256 releasedFinal,,,,,,,,) = campaign.getCampaign(campaignId);
        assertEq(releasedFinal, fuzzGoal);
        assertLe(releasedFinal, fuzzGoal);
    }

    /// @notice Single bond disposition: across four distinct terminal paths chosen by the
    ///         fuzzer, the bond is transferred exactly once; any second attempt to resolve
    ///         the same campaign reverts and moves no further tokens.
    function testFuzz_bondDisposedExactlyOnce_acrossTerminalPaths(uint8 pathSeed) public {
        uint8 path = uint8(bound(pathSeed, 0, 3));
        (uint256 campaignId, uint256 fundingDeadline, uint256 executionDeadline) = _createDefaultCampaign();

        if (path == 0) {
            // Underfunded failure -> bond returned.
            vm.warp(fundingDeadline);
            campaign.triggerFundingExpiry(campaignId);
            uint256 creatorBalAfter = token.balanceOf(creator);

            vm.expectRevert("campaign not in funding");
            campaign.triggerFundingExpiry(campaignId);

            assertEq(token.balanceOf(creator), creatorBalAfter);
        } else if (path == 1) {
            // Success -> bond returned.
            _fundToGoal(campaignId);
            vm.prank(creator);
            campaign.submitMilestone(campaignId, 0, "ipfs://1");
            campaign.approveMilestone(campaignId, 0);
            vm.prank(creator);
            campaign.submitMilestone(campaignId, 1, "ipfs://2");
            campaign.approveMilestone(campaignId, 1);
            uint256 creatorBalAfter = token.balanceOf(creator);

            vm.expectRevert("campaign not active");
            campaign.approveMilestone(campaignId, 1);

            assertEq(token.balanceOf(creator), creatorBalAfter);
        } else if (path == 2) {
            // Milestone rejection -> bond slashed.
            _fundToGoal(campaignId);
            vm.prank(creator);
            campaign.submitMilestone(campaignId, 0, "ipfs://1");
            campaign.rejectMilestone(campaignId, 0);
            uint256 sinkBalAfter = token.balanceOf(penaltySink);

            vm.expectRevert("campaign not active");
            campaign.rejectMilestone(campaignId, 0);
            vm.expectRevert("campaign not active");
            campaign.triggerExecutionExpiry(campaignId);

            assertEq(token.balanceOf(penaltySink), sinkBalAfter);
        } else {
            // Creator never submitted, execution expiry -> bond slashed.
            _fundToGoal(campaignId);
            vm.warp(executionDeadline);
            campaign.triggerExecutionExpiry(campaignId);
            uint256 sinkBalAfter = token.balanceOf(penaltySink);

            vm.expectRevert("campaign not active");
            campaign.triggerExecutionExpiry(campaignId);

            assertEq(token.balanceOf(penaltySink), sinkBalAfter);
        }
    }
}
