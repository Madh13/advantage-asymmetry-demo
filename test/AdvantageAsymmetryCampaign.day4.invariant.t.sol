// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../contracts/AdvantageAsymmetryCampaign.sol";
import "./mocks/MockERC20.sol";

/// @notice Bounded action handler for Day 4 stateful invariant testing.
///
///         The handler deploys the campaign contract itself, so the handler IS the
///         owner/verifier. Creators, supporters, and the penalty sink are distinct
///         addresses, preserving the role separation the contract enforces.
///
///         Actions are state-guarded rather than blindly random: an action that could not
///         possibly succeed returns early instead of reverting, so invariant runs spend
///         their depth on meaningful state transitions. Invalid/unauthorised actions are
///         tested deliberately and separately in the Day 4 adversarial suite, not here.
///
///         Patronage streams are deliberately non-iterable in production storage, so the
///         handler keeps a ghost list of every (campaignId, supporter) stream it opens.
///         No iterable storage was added to the contract for testing convenience.
contract Day4Handler is Test {
    AdvantageAsymmetryCampaign public campaign;
    MockERC20 public token;

    address public constant PENALTY_SINK = address(0xBEEF);

    address[3] public creators = [address(0xC1), address(0xC2), address(0xC3)];
    address[4] public supporters = [address(0x51), address(0x52), address(0x53), address(0x54)];

    /// @dev Ghost list of every patronage stream ever opened by this handler.
    struct StreamKey {
        uint256 campaignId;
        address supporter;
    }

    StreamKey[] public streamKeys;

    // ---- ghost accounting for patronage settlement correctness ----
    /// @dev Recorded at cancellation time: the accrued value the contract SHOULD have
    ///      settled `claimed` to. Checked against the reported snapshot in an invariant.
    mapping(uint256 => mapping(address => uint256)) public ghostExpectedClaimedAfterCancel;
    mapping(uint256 => mapping(address => bool)) public ghostCancelled;

    /// @dev Incremented whenever a settlement transaction moved a different amount of tokens
    ///      than the accounting said it should. Must remain 0.
    uint256 public ghostConservationViolations;
    uint256 public ghostSettledStreams;

    // ---- call counters, for the final report ----
    uint256 public callsCreateCampaign;
    uint256 public callsContribute;
    uint256 public callsFundingExpiry;
    uint256 public callsSubmitMilestone;
    uint256 public callsApproveMilestone;
    uint256 public callsRejectMilestone;
    uint256 public callsExecutionExpiry;
    uint256 public callsClaimRefund;
    uint256 public callsStartPatronage;
    uint256 public callsClaimPatronage;
    uint256 public callsCancelPatronage;
    uint256 public callsPauseToggle;
    uint256 public callsAdvanceTime;

    constructor() {
        token = new MockERC20();
        campaign = new AdvantageAsymmetryCampaign(address(token), PENALTY_SINK);

        for (uint256 i = 0; i < creators.length; i++) {
            token.mint(creators[i], 1e30);
            vm.prank(creators[i]);
            token.approve(address(campaign), type(uint256).max);
        }
        for (uint256 i = 0; i < supporters.length; i++) {
            token.mint(supporters[i], 1e30);
            vm.prank(supporters[i]);
            token.approve(address(campaign), type(uint256).max);
        }
    }

    function streamCount() external view returns (uint256) {
        return streamKeys.length;
    }

    function getStreamKey(uint256 i) external view returns (uint256, address) {
        return (streamKeys[i].campaignId, streamKeys[i].supporter);
    }

    // ---------- internal read helpers (kept narrow to avoid wide tuple churn) ----------

    function _status(uint256 id) internal view returns (AdvantageAsymmetryCampaign.CampaignStatus s) {
        (,,,,,,,,, s,,,) = campaign.getCampaign(id);
    }

    function _creatorOf(uint256 id) internal view returns (address a) {
        (a,,,,,,,,,,,,) = campaign.getCampaign(id);
    }

    function _goalOf(uint256 id) internal view returns (uint256 v) {
        (, v,,,,,,,,,,,) = campaign.getCampaign(id);
    }

    function _totalContributedOf(uint256 id) internal view returns (uint256 v) {
        (,,, v,,,,,,,,,) = campaign.getCampaign(id);
    }

    function _nextMilestoneOf(uint256 id) internal view returns (uint256 v) {
        (,,,,, v,,,,,,,) = campaign.getCampaign(id);
    }

    function _executionDeadlineOf(uint256 id) internal view returns (uint256 v) {
        (,,,,,,, v,,,,,) = campaign.getCampaign(id);
    }

    function _fundingDeadlineOf(uint256 id) internal view returns (uint256 v) {
        (,,,,,, v,,,,,,) = campaign.getCampaign(id);
    }

    function _milestoneCountOf(uint256 id) internal view returns (uint256 v) {
        (,,,,,,,,,,,, v) = campaign.getCampaign(id);
    }

    /// @dev Selects among campaigns currently in `want`. Purely-random campaign selection
    ///      leaves most actions landing on a campaign in an incompatible state, which makes
    ///      the deeper lifecycle (milestones, success, refunds) effectively unreachable and
    ///      the downstream invariants vacuous. Selecting a state-compatible target is the
    ///      handler-side bounding the Day 4 brief calls for; genuinely invalid/unauthorised
    ///      actions are covered deliberately in the Day 4 adversarial suite instead.
    function _pickCampaignInStatus(uint256 seed, AdvantageAsymmetryCampaign.CampaignStatus want)
        internal
        view
        returns (bool ok, uint256 id)
    {
        uint256 n = campaign.campaignCount();
        if (n == 0) return (false, 0);
        uint256 matches;
        for (uint256 i = 0; i < n; i++) {
            if (_status(i) == want) matches++;
        }
        if (matches == 0) return (false, 0);
        uint256 target = seed % matches;
        uint256 seen;
        for (uint256 i = 0; i < n; i++) {
            if (_status(i) == want) {
                if (seen == target) return (true, i);
                seen++;
            }
        }
        return (false, 0);
    }

    // ---------- actions ----------

    function createCampaign(uint256 creatorSeed, uint256 goalSeed, uint256 bondSeed, uint256 windowSeed) external {
        if (campaign.paused()) return;
        if (campaign.campaignCount() >= 6) return; // keep the state space bounded

        address creator = creators[creatorSeed % creators.length];
        uint256 goal = bound(goalSeed, 2, 1e12);
        uint256 bondAmount = bound(bondSeed, 1, 1e11);
        // Generous windows relative to the max time step, so campaigns can realistically be
        // funded and executed rather than expiring before any action lands on them.
        uint256 fundingDeadline = block.timestamp + bound(windowSeed, 10 days, 60 days);
        uint256 executionDeadline = fundingDeadline + bound(windowSeed, 10 days, 90 days);

        // Two milestones summing exactly to goal; goal >= 2 guarantees both are > 0.
        string[] memory d = new string[](2);
        d[0] = "m1";
        d[1] = "m2";
        uint256[] memory a = new uint256[](2);
        a[0] = goal / 2;
        a[1] = goal - a[0];
        if (a[0] == 0 || a[1] == 0) return;

        vm.prank(creator);
        campaign.createCampaign(goal, bondAmount, d, a, fundingDeadline, executionDeadline);
        callsCreateCampaign++;
    }

    function contribute(uint256 campaignSeed, uint256 supporterSeed, uint256 amountSeed) external {
        if (campaign.paused()) return;
        (bool ok, uint256 id) = _pickCampaignInStatus(campaignSeed, AdvantageAsymmetryCampaign.CampaignStatus.Funding);
        if (!ok) return;
        if (block.timestamp >= _fundingDeadlineOf(id)) return;

        address supporter = supporters[supporterSeed % supporters.length];
        if (supporter == _creatorOf(id)) return;

        uint256 remaining = _goalOf(id) - _totalContributedOf(id);
        if (remaining == 0) return;

        // Reaching Active requires totalContributed == goal EXACTLY. Purely random amounts
        // essentially never land on that, which would leave every campaign stuck in Funding
        // and make the downstream invariants (milestones, patronage, refunds) vacuous. So
        // roughly half the time contribute the exact remainder, which drives campaigns into
        // Active while still exercising partial/multi-supporter funding the rest of the time.
        uint256 amount = (amountSeed % 2 == 0) ? remaining : bound(amountSeed, 1, remaining);

        vm.prank(supporter);
        campaign.contribute(id, amount);
        callsContribute++;
    }

    function triggerFundingExpiry(uint256 campaignSeed) external {
        (bool ok, uint256 id) = _pickCampaignInStatus(campaignSeed, AdvantageAsymmetryCampaign.CampaignStatus.Funding);
        if (!ok) return;
        if (block.timestamp < _fundingDeadlineOf(id)) return;

        campaign.triggerFundingExpiry(id);
        callsFundingExpiry++;
    }

    function submitMilestone(uint256 campaignSeed) external {
        (bool ok, uint256 id) = _pickCampaignInStatus(campaignSeed, AdvantageAsymmetryCampaign.CampaignStatus.Active);
        if (!ok) return;
        if (block.timestamp >= _executionDeadlineOf(id)) return;

        uint256 idx = _nextMilestoneOf(id);
        if (idx >= _milestoneCountOf(id)) return;
        AdvantageAsymmetryCampaign.Milestone memory m = campaign.getMilestone(id, idx);
        if (m.status != AdvantageAsymmetryCampaign.MilestoneStatus.Pending) return;

        vm.prank(_creatorOf(id));
        campaign.submitMilestone(id, idx, "ipfs://evidence");
        callsSubmitMilestone++;
    }

    function approveMilestone(uint256 campaignSeed) external {
        if (campaign.paused()) return;
        (bool ok, uint256 id) = _pickCampaignInStatus(campaignSeed, AdvantageAsymmetryCampaign.CampaignStatus.Active);
        if (!ok) return;
        if (block.timestamp >= _executionDeadlineOf(id)) return;

        uint256 idx = _nextMilestoneOf(id);
        if (idx >= _milestoneCountOf(id)) return;
        AdvantageAsymmetryCampaign.Milestone memory m = campaign.getMilestone(id, idx);
        if (m.status != AdvantageAsymmetryCampaign.MilestoneStatus.Submitted) return;

        campaign.approveMilestone(id, idx); // handler is owner/verifier
        callsApproveMilestone++;
    }

    function rejectMilestone(uint256 campaignSeed) external {
        if (campaign.paused()) return;
        (bool ok, uint256 id) = _pickCampaignInStatus(campaignSeed, AdvantageAsymmetryCampaign.CampaignStatus.Active);
        if (!ok) return;
        if (block.timestamp >= _executionDeadlineOf(id)) return;

        uint256 idx = _nextMilestoneOf(id);
        if (idx >= _milestoneCountOf(id)) return;
        AdvantageAsymmetryCampaign.Milestone memory m = campaign.getMilestone(id, idx);
        if (m.status != AdvantageAsymmetryCampaign.MilestoneStatus.Submitted) return;

        campaign.rejectMilestone(id, idx);
        callsRejectMilestone++;
    }

    function triggerExecutionExpiry(uint256 campaignSeed) external {
        (bool ok, uint256 id) = _pickCampaignInStatus(campaignSeed, AdvantageAsymmetryCampaign.CampaignStatus.Active);
        if (!ok) return;
        if (block.timestamp < _executionDeadlineOf(id)) return;

        campaign.triggerExecutionExpiry(id);
        callsExecutionExpiry++;
    }

    function claimRefund(uint256 campaignSeed, uint256 supporterSeed) external {
        (bool ok, uint256 id) = _pickCampaignInStatus(campaignSeed, AdvantageAsymmetryCampaign.CampaignStatus.Failed);
        if (!ok) return;

        address supporter = supporters[supporterSeed % supporters.length];
        if (campaign.contributions(id, supporter) == 0) return;
        if (campaign.refundClaimed(id, supporter)) return;

        vm.prank(supporter);
        campaign.claimRefund(id);
        callsClaimRefund++;
    }

    function startPatronage(uint256 campaignSeed, uint256 supporterSeed, uint256 depositSeed, uint256 rateSeed)
        external
    {
        if (campaign.paused()) return;
        (bool ok, uint256 id) = _pickCampaignInStatus(campaignSeed, AdvantageAsymmetryCampaign.CampaignStatus.Active);
        if (!ok) return;

        address supporter = supporters[supporterSeed % supporters.length];
        if (supporter == _creatorOf(id)) return;
        if (campaign.hasPatronageStream(id, supporter)) return;

        uint256 deposit = bound(depositSeed, 1, 1e21);
        uint256 rate = bound(rateSeed, 1, deposit); // contract requires rate <= deposit

        vm.prank(supporter);
        campaign.startPatronage(id, deposit, rate);
        streamKeys.push(StreamKey({campaignId: id, supporter: supporter}));
        callsStartPatronage++;
    }

    function claimPatronage(uint256 streamSeed) external {
        if (campaign.paused()) return;
        if (streamKeys.length == 0) return;
        StreamKey memory k = streamKeys[streamSeed % streamKeys.length];

        (,,,, bool cancelled,,,,) = campaign.getPatronageStream(k.campaignId, k.supporter);
        if (cancelled) return;
        uint256 claimable = campaign.claimablePatronage(k.campaignId, k.supporter);
        if (claimable == 0) return;

        address creator = _creatorOf(k.campaignId);
        uint256 creatorBefore = token.balanceOf(creator);

        vm.prank(creator);
        campaign.claimPatronage(k.campaignId, k.supporter);

        // The creator must receive exactly what claimablePatronage() advertised.
        if (token.balanceOf(creator) - creatorBefore != claimable) {
            ghostConservationViolations++;
        }
        callsClaimPatronage++;
    }

    function cancelPatronage(uint256 streamSeed) external {
        if (streamKeys.length == 0) return;
        StreamKey memory k = streamKeys[streamSeed % streamKeys.length];

        (uint256 deposit,,, uint256 claimedBefore, bool cancelled,, uint256 accruedBefore,,) =
            campaign.getPatronageStream(k.campaignId, k.supporter);
        if (cancelled) return;

        address creator = _creatorOf(k.campaignId);
        uint256 creatorBefore = token.balanceOf(creator);
        uint256 supporterBefore = token.balanceOf(k.supporter);

        vm.prank(k.supporter);
        campaign.cancelPatronage(k.campaignId);

        uint256 creatorGot = token.balanceOf(creator) - creatorBefore;
        uint256 supporterGot = token.balanceOf(k.supporter) - supporterBefore;

        // Atomic settlement conservation: what leaves the contract for this stream on
        // cancellation must be exactly the entire unspent deposit, split between the two
        // sides. previousReceipts(claimedBefore) + creatorGot + supporterGot == deposit.
        if (claimedBefore + creatorGot + supporterGot != deposit) {
            ghostConservationViolations++;
        }
        // The creator's cancellation settlement must equal the accrued-but-unclaimed amount.
        if (creatorGot != accruedBefore - claimedBefore) {
            ghostConservationViolations++;
        }

        // Record what `claimed` must now read as, so a later invariant can detect a
        // cancellation that paid correctly but failed to settle its own bookkeeping.
        ghostExpectedClaimedAfterCancel[k.campaignId][k.supporter] = accruedBefore;
        ghostCancelled[k.campaignId][k.supporter] = true;
        ghostSettledStreams++;

        callsCancelPatronage++;
    }

    function pauseToggle(uint256 seed) external {
        if (seed % 2 == 0) {
            if (campaign.paused()) return;
            campaign.pause();
        } else {
            if (!campaign.paused()) return;
            campaign.unpause();
        }
        callsPauseToggle++;
    }

    function advanceTime(uint256 seed) external {
        // Mixed step sizes on purpose. Small steps let a campaign progress through funding
        // and milestones without blowing past its deadlines; occasional large jumps are what
        // actually reach triggerFundingExpiry / triggerExecutionExpiry, which never fire if
        // every step is small enough for the campaign to be resolved first.
        if (seed % 4 == 0) {
            skip(bound(seed, 5 days, 40 days));
        } else {
            skip(bound(seed, 1 hours, 2 days));
        }
        // skip(), not vm.warp(block.timestamp + N): via-IR CSE hazard documented in Day 3.
        callsAdvanceTime++;
    }
}

/// @notice Day 4 stateful invariant suite. Asserts the global token-liability model and the
///         per-bucket accounting invariants after every handler action.
contract AdvantageAsymmetryCampaignDay4InvariantTest is Test {
    Day4Handler handler;
    AdvantageAsymmetryCampaign campaign;
    MockERC20 token;

    function setUp() public {
        handler = new Day4Handler();
        campaign = handler.campaign();
        token = handler.token();

        bytes4[] memory selectors = new bytes4[](13);
        selectors[0] = Day4Handler.createCampaign.selector;
        selectors[1] = Day4Handler.contribute.selector;
        selectors[2] = Day4Handler.triggerFundingExpiry.selector;
        selectors[3] = Day4Handler.submitMilestone.selector;
        selectors[4] = Day4Handler.approveMilestone.selector;
        selectors[5] = Day4Handler.rejectMilestone.selector;
        selectors[6] = Day4Handler.triggerExecutionExpiry.selector;
        selectors[7] = Day4Handler.claimRefund.selector;
        selectors[8] = Day4Handler.startPatronage.selector;
        selectors[9] = Day4Handler.claimPatronage.selector;
        selectors[10] = Day4Handler.cancelPatronage.selector;
        selectors[11] = Day4Handler.pauseToggle.selector;
        selectors[12] = Day4Handler.advanceTime.selector;

        targetSelector(FuzzSelector({addr: address(handler), selectors: selectors}));
        targetContract(address(handler));
    }

    // ---------- liability model ----------

    /// @dev Total tokens the contract owes across all four economically distinct buckets:
    ///
    ///        campaign escrow  : Funding/Active -> totalContributed - totalReleased
    ///        refund liability : Failed         -> refundPool - totalRefunded
    ///                           Succeeded      -> 0
    ///        bond liability   : Unresolved     -> bondAmount, else 0
    ///        patronage        : live stream    -> deposit - claimed, cancelled -> 0
    ///
    ///      Campaign escrow and refund liability are mutually exclusive by construction
    ///      (a campaign is in exactly one status), so the same contributed funds are never
    ///      double-counted across the failure boundary.
    function _totalLiabilities() internal view returns (uint256 liab) {
        uint256 n = campaign.campaignCount();
        for (uint256 i = 0; i < n; i++) {
            (
                ,,
                uint256 bondAmount,
                uint256 totalContributed,
                uint256 totalReleased,,,,,
                AdvantageAsymmetryCampaign.CampaignStatus status,,
                AdvantageAsymmetryCampaign.BondOutcome bondOutcome,
            ) = campaign.getCampaign(i);

            if (
                status == AdvantageAsymmetryCampaign.CampaignStatus.Funding
                    || status == AdvantageAsymmetryCampaign.CampaignStatus.Active
            ) {
                liab += totalContributed - totalReleased;
            } else if (status == AdvantageAsymmetryCampaign.CampaignStatus.Failed) {
                (, uint256 refundPool, uint256 totalRefunded,,,,) = campaign.getRefundAccounting(i);
                liab += refundPool - totalRefunded;
            }
            // Succeeded contributes 0 contribution/refund liability.

            if (bondOutcome == AdvantageAsymmetryCampaign.BondOutcome.Unresolved) {
                liab += bondAmount;
            }
        }

        uint256 s = handler.streamCount();
        for (uint256 i = 0; i < s; i++) {
            (uint256 cid, address supporter) = handler.getStreamKey(i);
            (uint256 deposit,,, uint256 claimed, bool cancelled,,,,) = campaign.getPatronageStream(cid, supporter);
            if (!cancelled) {
                liab += deposit - claimed;
            }
        }
    }

    // ---------- invariants ----------

    /// @notice Closed-world exact solvency. The MockERC20 harness performs no unsolicited
    ///         direct transfers into the contract, so balance must equal tracked liabilities
    ///         exactly -- any drift is either a leak or an over-retention.
    function invariant_globalSolvency_closedWorldExact() public view {
        assertEq(token.balanceOf(address(campaign)), _totalLiabilities(), "closed-world balance != liabilities");
    }

    /// @notice General-case solvency. Holds even if a third party donates tokens directly.
    function invariant_globalSolvency_balanceCoversLiabilities() public view {
        assertGe(token.balanceOf(address(campaign)), _totalLiabilities(), "balance < liabilities");
    }

    function invariant_campaignAccounting() public view {
        uint256 n = campaign.campaignCount();
        for (uint256 i = 0; i < n; i++) {
            (
                ,
                uint256 goal,,
                uint256 totalContributed,
                uint256 totalReleased,
                uint256 nextMilestoneIndex,,,
                uint256 failureTimestamp,
                AdvantageAsymmetryCampaign.CampaignStatus status,,
                AdvantageAsymmetryCampaign.BondOutcome bondOutcome,
                uint256 milestoneCount
            ) = campaign.getCampaign(i);

            assertLe(totalReleased, totalContributed, "totalReleased > totalContributed");
            assertLe(totalContributed, goal, "totalContributed > goal");
            assertLe(nextMilestoneIndex, milestoneCount, "nextMilestoneIndex > milestoneCount");

            (,,,,,, bool refundInitialized) = campaign.getRefundAccounting(i);

            if (status == AdvantageAsymmetryCampaign.CampaignStatus.Funding) {
                assertEq(totalReleased, 0, "Funding with releases");
                assertEq(
                    uint8(bondOutcome),
                    uint8(AdvantageAsymmetryCampaign.BondOutcome.Unresolved),
                    "Funding bond resolved"
                );
                assertFalse(refundInitialized, "Funding refund initialized");
                assertEq(failureTimestamp, 0, "Funding failureTimestamp set");
            } else if (status == AdvantageAsymmetryCampaign.CampaignStatus.Active) {
                assertEq(totalContributed, goal, "Active but not fully funded");
                assertEq(
                    uint8(bondOutcome), uint8(AdvantageAsymmetryCampaign.BondOutcome.Unresolved), "Active bond resolved"
                );
                assertFalse(refundInitialized, "Active refund initialized");
                assertEq(failureTimestamp, 0, "Active failureTimestamp set");
            } else if (status == AdvantageAsymmetryCampaign.CampaignStatus.Succeeded) {
                assertEq(totalContributed, goal, "Succeeded but not fully funded");
                assertEq(totalReleased, goal, "Succeeded but not fully released");
                assertEq(nextMilestoneIndex, milestoneCount, "Succeeded with milestones outstanding");
                assertEq(
                    uint8(bondOutcome),
                    uint8(AdvantageAsymmetryCampaign.BondOutcome.Returned),
                    "Succeeded bond not returned"
                );
                assertFalse(refundInitialized, "Succeeded refund initialized");
            } else {
                // Failed
                assertGt(failureTimestamp, 0, "Failed without failureTimestamp");
                assertTrue(refundInitialized, "Failed without refund accounting");
                (
                    uint256 refundDenominator,
                    uint256 refundPool,
                    uint256 totalRefunded,,
                    uint256 contributorCount,
                    uint256 refundClaimCount,
                ) = campaign.getRefundAccounting(i);
                assertEq(refundDenominator, totalContributed, "denominator != historical contributions");
                assertEq(refundPool, totalContributed - totalReleased, "pool != contributed - released");
                assertLe(totalRefunded, refundPool, "totalRefunded > refundPool");
                assertLe(refundClaimCount, contributorCount, "refundClaimCount > contributorCount");
                assertNotEq(
                    uint8(bondOutcome),
                    uint8(AdvantageAsymmetryCampaign.BondOutcome.Unresolved),
                    "Failed with unresolved bond"
                );
            }
        }
    }

    /// @notice Sequential milestone integrity across arbitrary action sequences.
    function invariant_milestoneSequence() public view {
        uint256 n = campaign.campaignCount();
        for (uint256 i = 0; i < n; i++) {
            (,,,,, uint256 nextMilestoneIndex,,,, AdvantageAsymmetryCampaign.CampaignStatus status,,, uint256 count) =
                campaign.getCampaign(i);

            for (uint256 j = 0; j < count; j++) {
                AdvantageAsymmetryCampaign.Milestone memory m = campaign.getMilestone(i, j);
                if (j < nextMilestoneIndex) {
                    // Everything before the cursor must already be Released -- with one
                    // exception: a rejected milestone fails the campaign without advancing
                    // the cursor, so it is always AT the cursor, never behind it.
                    assertEq(
                        uint8(m.status),
                        uint8(AdvantageAsymmetryCampaign.MilestoneStatus.Released),
                        "milestone before cursor not Released"
                    );
                } else if (j > nextMilestoneIndex) {
                    // Nothing beyond the cursor may have been touched.
                    assertEq(
                        uint8(m.status),
                        uint8(AdvantageAsymmetryCampaign.MilestoneStatus.Pending),
                        "milestone beyond cursor already actioned"
                    );
                } else {
                    // At the cursor: Pending or Submitted while Active; Rejected only in a
                    // Failed campaign; never Released (release advances the cursor).
                    assertNotEq(
                        uint8(m.status),
                        uint8(AdvantageAsymmetryCampaign.MilestoneStatus.Released),
                        "released milestone still at cursor"
                    );
                    if (m.status == AdvantageAsymmetryCampaign.MilestoneStatus.Rejected) {
                        assertEq(
                            uint8(status),
                            uint8(AdvantageAsymmetryCampaign.CampaignStatus.Failed),
                            "rejected milestone without failed campaign"
                        );
                    }
                }
            }
        }
    }

    /// @notice Per-stream patronage bounds, over every stream the handler ever opened.
    function invariant_patronageBounds() public view {
        uint256 s = handler.streamCount();
        for (uint256 i = 0; i < s; i++) {
            (uint256 cid, address supporter) = handler.getStreamKey(i);
            (
                uint256 deposit,
                uint256 ratePerSecond,,
                uint256 claimed,
                bool cancelled,,
                uint256 accrued,
                uint256 creatorClaimable,
                uint256 supporterRecoverable
            ) = campaign.getPatronageStream(cid, supporter);

            assertGt(deposit, 0, "ghost stream with zero deposit");
            assertGt(ratePerSecond, 0, "rate must be > 0");
            assertLe(ratePerSecond, deposit, "rate must be <= deposit");
            assertLe(claimed, deposit, "claimed > deposit");
            assertLe(accrued, deposit, "accrued > deposit");
            assertLe(claimed, accrued, "claimed > accrued");

            if (cancelled) {
                assertEq(creatorClaimable, 0, "cancelled stream still creator-claimable");
                assertEq(supporterRecoverable, 0, "cancelled stream still supporter-recoverable");
                assertEq(campaign.claimablePatronage(cid, supporter), 0, "cancelled claimable != 0");
            } else {
                // The whole unspent deposit is still owed to one side or the other.
                assertEq(creatorClaimable + supporterRecoverable, deposit - claimed, "live stream liability mismatch");
            }
        }
    }

    /// @notice Patronage settlement correctness, using handler-side ghost accounting.
    ///
    ///         Two distinct properties, because they fail independently:
    ///           - token conservation: previouslyClaimed + creatorSettlement + supporterRefund
    ///             == deposit on cancellation, and a creator claim moves exactly the amount
    ///             claimablePatronage() advertised;
    ///           - bookkeeping settlement: after cancellation the stream's own `claimed`
    ///             field must have been advanced to the accrued value it settled at. A
    ///             cancellation can pay both parties correctly and still leave this stale,
    ///             which corrupts the dashboard snapshot without moving any funds -- the
    ///             solvency invariants are blind to it by construction, so it is checked here.
    function invariant_patronageSettlementConservation() public view {
        assertEq(handler.ghostConservationViolations(), 0, "patronage settlement moved unexpected token amounts");

        uint256 s = handler.streamCount();
        for (uint256 i = 0; i < s; i++) {
            (uint256 cid, address supporter) = handler.getStreamKey(i);
            if (!handler.ghostCancelled(cid, supporter)) continue;

            (,,, uint256 claimed, bool cancelled,, uint256 accrued,,) = campaign.getPatronageStream(cid, supporter);
            assertTrue(cancelled, "ghost-cancelled stream not reported cancelled");
            assertEq(
                claimed,
                handler.ghostExpectedClaimedAfterCancel(cid, supporter),
                "cancellation did not settle `claimed` to the accrued value it paid out at"
            );
            assertEq(accrued, claimed, "cancelled stream accrued/claimed snapshot inconsistent");
        }
    }
}
