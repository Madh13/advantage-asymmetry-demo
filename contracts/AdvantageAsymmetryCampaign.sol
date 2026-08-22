// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";

/// @title AdvantageAsymmetryCampaign
/// @notice Research prototype instantiating the advantage-asymmetry design principle:
///         smart-contract-controlled escrow with no discretionary platform withdrawal
///         function, subject to a centralised milestone verifier in this proof-of-concept
///         (see design-science paper Section 8 for the precise non-custodial wording).
/// @dev Testnet demo artifact for a design-science research paper. Not audited.
///
///      ============================ BUILD STATUS ============================
///      This is the Day 1 (state-machine) pass of the V1.1 refactor described in
///      the project master brief. It implements:
///        - the Funding -> Active -> {Succeeded, Failed} state machine (Section 7.1)
///        - campaign creation validation (Section 7.2)
///        - the funding-phase contribution cap and auto-activation (Section 7.3)
///        - the permissionless funding-expiry failure trigger (Section 7.4)
///        - sequential milestone submission/approval/rejection (Section 7.5)
///        - the permissionless execution-expiry failure trigger, with creator/verifier
///          fault attribution (Section 7.6, refined per stakeholder clarification)
///        - full creator-bond disposition across all four terminal paths: returned on
///          success, returned on underfunded failure, returned on verifier-review
///          timeout, and slashed to a neutral sink on creator-caused failure
///        - existence validation for campaign/milestone IDs (Section 7.11)
///
///      It deliberately does NOT yet implement:
///        - claimRefund() / the supporter-facing pro-rata refund pool (Section 7.7).
///          This is the complex, order-sensitive multi-supporter accounting fix
///          (baseline defect #1) and remains scoped to Day 2 per the master brief's
///          execution plan (Section 17, Day 2: "Refund + bond correctness"). The
///          `contributions` mapping below is still populated so Day 2 has the data
///          it needs.
///        - Patronage streaming (startPatronage/claimPatronage/cancelPatronage),
///          scoped to Day 3 (Section 17). These functions, along with their struct
///          and mapping, have been removed from this pass rather than carried over
///          in their known-broken V0 form (baseline defects #7, #8), since a missing
///          feature is safer than a live one that can strand funds. A `failureTimestamp`
///          field has been added to the Campaign struct now, since Day 3's patronage
///          accrual-freeze logic depends on knowing when a campaign failed, and it is
///          more consistent to record that fact at the point of failure than retrofit
///          it later.
///
///      An independent review of this Day 1 pass surfaced two material issues, fixed
///      before Day 2 began:
///        - executionDeadline is now a hard boundary. submitMilestone, approveMilestone,
///          and rejectMilestone all revert at/after executionDeadline; triggerExecutionExpiry
///          is the sole resolution path from that instant on. This closes both a creator
///          bypass (late evidence submitted specifically to be reclassified as
///          VerifierReviewExpired instead of CreatorExecutionExpired) and a post-deadline
///          transaction-order race between rejectMilestone (slash) and
///          triggerExecutionExpiry (return) over the same timely-submitted milestone.
///        - The verifier identity is now fixed for the deployment: transferOwnership and
///          renounceOwnership are both overridden to unconditionally revert, so ownership
///          can never move to a campaign creator (breaking creator/verifier separation)
///          or to the penalty sink (letting the party who benefits from a slash also
///          decide it).
///      Also hardened in the same pass: the verifier and the penalty sink are now barred
///      from contributing (contribute()); createCampaign is nonReentrant; submitMilestone
///      requires a non-empty evidence URI.
///      ========================================================================
contract AdvantageAsymmetryCampaign is Ownable, ReentrancyGuard, Pausable {
    using SafeERC20 for IERC20;

    /// @notice The single supported stablecoin for every campaign on this deployment
    ///         (Section 4, "Recommended contract simplification"). Set once at deploy
    ///         time; there is no per-campaign token parameter.
    IERC20 public immutable token;

    /// @notice Neutral, pre-disclosed destination for slashed creator bonds. Deliberately
    ///         not the verifier and not the creator, so slashing cannot financially
    ///         benefit the party deciding the slash (Section 6, Section 7.6).
    address public immutable penaltySink;

    enum MilestoneStatus {
        Pending,
        Submitted,
        Rejected,
        Released
    }

    enum CampaignStatus {
        Funding,
        Active,
        Succeeded,
        Failed
    }

    /// @notice Explicit, disclosed reason a campaign failed (Section 7.4: "record an
    ///         explicit failure reason"). VerifierReviewExpired is distinct from
    ///         CreatorExecutionExpired precisely so a verifier's delay is never
    ///         recorded, or penalised, as creator misconduct.
    enum FailureReason {
        None,
        Underfunded,
        MilestoneRejected,
        CreatorExecutionExpired,
        VerifierReviewExpired
    }

    /// @notice Tracks the single terminal disposition of a campaign's creator bond, so
    ///         the invariant "a bond resolves to exactly one outcome" is enforceable
    ///         on-chain, not just documented.
    enum BondOutcome {
        Unresolved,
        Returned,
        Slashed
    }

    struct Milestone {
        string description;
        uint256 amount; // amount released to creator on approval
        MilestoneStatus status;
        string evidenceURI; // off-chain evidence pointer (IPFS/URL), for the dashboard
    }

    struct Campaign {
        address creator;
        uint256 goal;
        uint256 bondAmount; // creator's posted bond; historical record, not zeroed on disposition
        uint256 totalContributed;
        uint256 totalReleased;
        uint256 nextMilestoneIndex; // index of the next milestone that must be submitted/released
        uint256 fundingDeadline;
        uint256 executionDeadline;
        uint256 failureTimestamp; // 0 until the campaign fails; used later by patronage accrual (Day 3)
        CampaignStatus status;
        FailureReason failureReason;
        BondOutcome bondOutcome;
        Milestone[] milestones;
    }

    uint256 public campaignCount;
    mapping(uint256 => Campaign) private campaigns;
    mapping(uint256 => mapping(address => uint256)) public contributions; // campaignId => contributor => amount

    // Simplification for prototype scope: the contract owner acts as milestone verifier.
    // A production version would replace this with a DAO vote, multisig, or oracle attestation.
    // This is disclosed explicitly, not hidden, per the paper's evaluation criteria (Section 6, 8).

    event CampaignCreated(
        uint256 indexed campaignId,
        address indexed creator,
        uint256 goal,
        uint256 bondAmount,
        uint256 fundingDeadline,
        uint256 executionDeadline
    );
    event Contributed(uint256 indexed campaignId, address indexed contributor, uint256 amount);
    event CampaignActivated(uint256 indexed campaignId);
    event MilestoneSubmitted(uint256 indexed campaignId, uint256 indexed milestoneIndex, string evidenceURI);
    event MilestoneApproved(uint256 indexed campaignId, uint256 indexed milestoneIndex, uint256 amountReleased);
    event MilestoneRejected(uint256 indexed campaignId, uint256 indexed milestoneIndex);
    event CampaignSucceeded(uint256 indexed campaignId);
    event CampaignFailed(uint256 indexed campaignId, FailureReason reason);
    event BondReturned(uint256 indexed campaignId, address indexed creator, uint256 amount);
    event BondSlashed(uint256 indexed campaignId, address indexed sink, uint256 amount);

    modifier campaignExists(uint256 campaignId) {
        require(campaignId < campaignCount, "campaign does not exist");
        _;
    }

    modifier milestoneExists(uint256 campaignId, uint256 milestoneIndex) {
        require(milestoneIndex < campaigns[campaignId].milestones.length, "milestone does not exist");
        _;
    }

    /// @param _token Single immutable supported stablecoin for this deployment.
    /// @param _penaltySink Neutral bond-slash destination. Must not be the deployer
    ///        (who becomes the verifier/owner via Ownable) and must not be the zero address.
    constructor(address _token, address _penaltySink) Ownable(msg.sender) {
        require(_token != address(0), "token cannot be zero address");
        require(_penaltySink != address(0), "penalty sink cannot be zero address");
        require(_penaltySink != msg.sender, "penalty sink cannot be the verifier");
        token = IERC20(_token);
        penaltySink = _penaltySink;
    }

    // ---------- Verifier identity (fixed for the deployment) ----------
    //
    // Ownable's transferOwnership/renounceOwnership are disabled. The verifier/owner
    // identity is a role-separation assumption baked into createCampaign (creator != owner)
    // and contribute (owner cannot contribute); letting ownership move after deployment
    // could hand the verifier role to a campaign creator (breaking that separation) or to
    // the penalty sink (letting the party who benefits from a slash also decide it). For
    // this research prototype the verifier is fixed at deploy time; a production version
    // could replace the whole role with a DAO/multisig/oracle instead of allowing transfer.

    /// @dev Overridden to permanently disable ownership transfer (baseline hardening item).
    function transferOwnership(address) public view override onlyOwner {
        revert("verifier is fixed for this deployment");
    }

    /// @dev Overridden to permanently disable ownership renunciation (baseline hardening item).
    function renounceOwnership() public view override onlyOwner {
        revert("verifier is fixed for this deployment");
    }

    // ---------- Campaign lifecycle ----------

    function createCampaign(
        uint256 goal,
        uint256 bondAmount,
        string[] calldata milestoneDescriptions,
        uint256[] calldata milestoneAmounts,
        uint256 fundingDeadline,
        uint256 executionDeadline
    ) external nonReentrant whenNotPaused returns (uint256 campaignId) {
        require(msg.sender != owner(), "creator cannot be the verifier");
        require(msg.sender != penaltySink, "creator cannot be the penalty sink");
        require(goal > 0, "goal must be > 0");
        require(bondAmount > 0, "bond must be > 0");
        require(milestoneDescriptions.length == milestoneAmounts.length, "milestone arrays mismatch");
        require(milestoneDescriptions.length > 0, "need at least one milestone");
        require(fundingDeadline > block.timestamp, "funding deadline must be in the future");
        require(executionDeadline > fundingDeadline, "execution deadline must follow funding deadline");

        uint256 sum;
        for (uint256 i = 0; i < milestoneAmounts.length; i++) {
            require(milestoneAmounts[i] > 0, "milestone amount must be > 0");
            sum += milestoneAmounts[i];
        }
        require(sum == goal, "milestones must sum to goal");

        campaignId = campaignCount++;
        Campaign storage c = campaigns[campaignId];
        c.creator = msg.sender;
        c.goal = goal;
        c.bondAmount = bondAmount;
        c.status = CampaignStatus.Funding;
        c.fundingDeadline = fundingDeadline;
        c.executionDeadline = executionDeadline;

        for (uint256 i = 0; i < milestoneDescriptions.length; i++) {
            c.milestones
                .push(
                    Milestone({
                        description: milestoneDescriptions[i],
                        amount: milestoneAmounts[i],
                        status: MilestoneStatus.Pending,
                        evidenceURI: ""
                    })
                );
        }

        // Creator posts bond up front: issuer skin-in-the-game. Unconditional for V1.1 --
        // the "for the fidelity demo" bondAmount == 0 escape hatch from the baseline is gone.
        token.safeTransferFrom(msg.sender, address(this), bondAmount);

        emit CampaignCreated(campaignId, msg.sender, goal, bondAmount, fundingDeadline, executionDeadline);
    }

    function contribute(uint256 campaignId, uint256 amount)
        external
        nonReentrant
        whenNotPaused
        campaignExists(campaignId)
    {
        Campaign storage c = campaigns[campaignId];
        require(msg.sender != owner(), "verifier cannot contribute");
        require(msg.sender != penaltySink, "penalty sink cannot contribute");
        require(c.status == CampaignStatus.Funding, "campaign not in funding");
        require(block.timestamp < c.fundingDeadline, "funding deadline has passed");
        require(amount > 0, "amount must be > 0");
        require(amount <= c.goal - c.totalContributed, "amount exceeds remaining goal");

        token.safeTransferFrom(msg.sender, address(this), amount);
        contributions[campaignId][msg.sender] += amount;
        c.totalContributed += amount;

        emit Contributed(campaignId, msg.sender, amount);

        if (c.totalContributed == c.goal) {
            c.status = CampaignStatus.Active;
            emit CampaignActivated(campaignId);
        }
    }

    /// @notice Permissionless. Anyone may call this once the funding deadline has passed
    ///         on a campaign that never reached its goal, converting it to a refundable
    ///         failure state. Failing to attract funding is not creator misconduct
    ///         (Section 7.4), so the bond is returned, never slashed.
    /// @dev Deliberately NOT gated by whenNotPaused: a permissionless failure/exit trigger
    ///      must remain callable while paused (Section 7.10 / stakeholder clarification 6).
    function triggerFundingExpiry(uint256 campaignId) external nonReentrant campaignExists(campaignId) {
        Campaign storage c = campaigns[campaignId];
        require(c.status == CampaignStatus.Funding, "campaign not in funding");
        require(block.timestamp >= c.fundingDeadline, "funding deadline not yet reached");

        c.status = CampaignStatus.Failed;
        c.failureReason = FailureReason.Underfunded;
        c.failureTimestamp = block.timestamp;

        _returnBond(campaignId, c);

        emit CampaignFailed(campaignId, FailureReason.Underfunded);
    }

    // ---------- Milestones ----------

    /// @dev Deliberately NOT gated by whenNotPaused: evidence submission moves no funds
    ///      and is not "new risk-taking" under Section 7.10's pause policy.
    function submitMilestone(uint256 campaignId, uint256 milestoneIndex, string calldata evidenceURI)
        external
        campaignExists(campaignId)
        milestoneExists(campaignId, milestoneIndex)
    {
        Campaign storage c = campaigns[campaignId];
        require(msg.sender == c.creator, "only creator");
        require(c.status == CampaignStatus.Active, "campaign not active");
        require(block.timestamp < c.executionDeadline, "execution deadline has passed");
        require(milestoneIndex == c.nextMilestoneIndex, "not the next milestone");
        require(bytes(evidenceURI).length > 0, "evidence URI required");

        Milestone storage m = c.milestones[milestoneIndex];
        require(m.status == MilestoneStatus.Pending, "milestone not pending");

        m.status = MilestoneStatus.Submitted;
        m.evidenceURI = evidenceURI;

        emit MilestoneSubmitted(campaignId, milestoneIndex, evidenceURI);
    }

    /// @dev Verifier-gated (contract owner for this prototype, see note above). Approval
    ///      and release are atomic in the same transaction -- there is no separately
    ///      observable "Approved" state (baseline defect #11; stakeholder clarification 3).
    ///      Gated by whenNotPaused: this is exactly the "milestone approval/release" case
    ///      Section 7.10 says a pause must stop.
    function approveMilestone(uint256 campaignId, uint256 milestoneIndex)
        external
        onlyOwner
        nonReentrant
        whenNotPaused
        campaignExists(campaignId)
        milestoneExists(campaignId, milestoneIndex)
    {
        Campaign storage c = campaigns[campaignId];
        require(c.status == CampaignStatus.Active, "campaign not active");
        require(block.timestamp < c.executionDeadline, "execution deadline has passed");
        require(milestoneIndex == c.nextMilestoneIndex, "not the next milestone");

        Milestone storage m = c.milestones[milestoneIndex];
        require(m.status == MilestoneStatus.Submitted, "milestone not submitted");

        m.status = MilestoneStatus.Released;
        c.totalReleased += m.amount;
        c.nextMilestoneIndex += 1;

        token.safeTransfer(c.creator, m.amount);
        emit MilestoneApproved(campaignId, milestoneIndex, m.amount);

        if (c.nextMilestoneIndex == c.milestones.length) {
            c.status = CampaignStatus.Succeeded;
            _returnBond(campaignId, c);
            emit CampaignSucceeded(campaignId);
        }
    }

    /// @notice Rejection is creator-caused failure by definition (Section 7.6): the
    ///         creator submitted, and the verifier judged the submission inadequate.
    /// @dev Gated by whenNotPaused, matching approveMilestone -- both are the verifier
    ///      exercising release/reject discretion, which Section 7.10 treats as a single
    ///      "milestone approval/release" category that a pause must stop.
    function rejectMilestone(uint256 campaignId, uint256 milestoneIndex)
        external
        onlyOwner
        nonReentrant
        whenNotPaused
        campaignExists(campaignId)
        milestoneExists(campaignId, milestoneIndex)
    {
        Campaign storage c = campaigns[campaignId];
        require(c.status == CampaignStatus.Active, "campaign not active");
        require(block.timestamp < c.executionDeadline, "execution deadline has passed");
        require(milestoneIndex == c.nextMilestoneIndex, "not the next milestone");

        Milestone storage m = c.milestones[milestoneIndex];
        require(m.status == MilestoneStatus.Submitted, "milestone not submitted");

        m.status = MilestoneStatus.Rejected;
        c.status = CampaignStatus.Failed;
        c.failureReason = FailureReason.MilestoneRejected;
        c.failureTimestamp = block.timestamp;

        _slashBond(campaignId, c);

        emit MilestoneRejected(campaignId, milestoneIndex);
        emit CampaignFailed(campaignId, FailureReason.MilestoneRejected);
    }

    /// @notice Permissionless. executionDeadline is a hard boundary: submitMilestone,
    ///         approveMilestone, and rejectMilestone all revert once
    ///         block.timestamp >= executionDeadline (see those functions), so this is the
    ///         sole resolution path for an Active campaign from that instant on -- there is
    ///         no window in which a late submission or a race against rejectMilestone can
    ///         change the outcome. Fault attribution depends on the status of the next
    ///         unresolved milestone at the moment expiry is triggered, which is necessarily
    ///         its state as of the deadline itself, since nothing can move it after:
    ///           - Pending   -> creator never submitted -> creator-caused -> bond slashed.
    ///           - Submitted -> creator submitted in time, verifier never ruled -> not
    ///             creator-caused -> bond returned (stakeholder clarification 4).
    ///         A milestone can never be Rejected or Released here: Rejected already moves
    ///         the campaign to Failed, and Released either advances nextMilestoneIndex to
    ///         a later Pending/Submitted milestone or completes the campaign (Succeeded),
    ///         so this function is unreachable in the Active state in either case.
    /// @dev Deliberately NOT gated by whenNotPaused, for the same reason as
    ///      triggerFundingExpiry.
    function triggerExecutionExpiry(uint256 campaignId) external nonReentrant campaignExists(campaignId) {
        Campaign storage c = campaigns[campaignId];
        require(c.status == CampaignStatus.Active, "campaign not active");
        require(block.timestamp >= c.executionDeadline, "execution deadline not yet reached");

        c.status = CampaignStatus.Failed;
        c.failureTimestamp = block.timestamp;

        Milestone storage m = c.milestones[c.nextMilestoneIndex];

        if (m.status == MilestoneStatus.Submitted) {
            c.failureReason = FailureReason.VerifierReviewExpired;
            _returnBond(campaignId, c);
        } else {
            c.failureReason = FailureReason.CreatorExecutionExpired;
            _slashBond(campaignId, c);
        }

        emit CampaignFailed(campaignId, c.failureReason);
    }

    // ---------- Bond disposition (internal) ----------

    /// @dev Enforces the "bond resolves to exactly one terminal outcome" invariant on-chain.
    function _returnBond(uint256 campaignId, Campaign storage c) internal {
        require(c.bondOutcome == BondOutcome.Unresolved, "bond already resolved");
        c.bondOutcome = BondOutcome.Returned;
        uint256 bond = c.bondAmount;
        token.safeTransfer(c.creator, bond);
        emit BondReturned(campaignId, c.creator, bond);
    }

    /// @dev Enforces the "bond resolves to exactly one terminal outcome" invariant on-chain.
    ///      Sends directly to the immutable, verifier-excluded, creator-excluded sink --
    ///      never pooled with, or claimable as, supporter refunds (Section 7.6).
    function _slashBond(uint256 campaignId, Campaign storage c) internal {
        require(c.bondOutcome == BondOutcome.Unresolved, "bond already resolved");
        c.bondOutcome = BondOutcome.Slashed;
        uint256 bond = c.bondAmount;
        token.safeTransfer(penaltySink, bond);
        emit BondSlashed(campaignId, penaltySink, bond);
    }

    // ---------- Dashboard read helpers ----------

    function getCampaign(uint256 campaignId)
        external
        view
        campaignExists(campaignId)
        returns (
            address creator,
            uint256 goal,
            uint256 bondAmount,
            uint256 totalContributed,
            uint256 totalReleased,
            uint256 nextMilestoneIndex,
            uint256 fundingDeadline,
            uint256 executionDeadline,
            uint256 failureTimestamp,
            CampaignStatus status,
            FailureReason failureReason,
            BondOutcome bondOutcome,
            uint256 milestoneCount
        )
    {
        Campaign storage c = campaigns[campaignId];
        return (
            c.creator,
            c.goal,
            c.bondAmount,
            c.totalContributed,
            c.totalReleased,
            c.nextMilestoneIndex,
            c.fundingDeadline,
            c.executionDeadline,
            c.failureTimestamp,
            c.status,
            c.failureReason,
            c.bondOutcome,
            c.milestones.length
        );
    }

    function getMilestone(uint256 campaignId, uint256 milestoneIndex)
        external
        view
        campaignExists(campaignId)
        milestoneExists(campaignId, milestoneIndex)
        returns (Milestone memory)
    {
        return campaigns[campaignId].milestones[milestoneIndex];
    }

    // ---------- Emergency controls ----------
    //
    // Pause policy (Section 7.10, stakeholder clarification 6), applied incrementally
    // as each function is touched during the V1.1 refactor:
    //
    //   Blocked while paused (new risk-taking / discretionary release):
    //     - createCampaign      (new campaign)
    //     - contribute          (new contribution)
    //     - approveMilestone    (discretionary release)
    //     - rejectMilestone     (discretionary verifier decision)
    //
    //   Never blocked by pause (objective triggers and risk-reducing exits must always
    //   remain callable, per Section 7.10's "user exit should remain available wherever
    //   safely possible" and clarification 6's "pause must not prevent risk-reducing
    //   exits ... or objective expiry triggers"):
    //     - submitMilestone         (moves no funds; not risk-taking)
    //     - triggerFundingExpiry    (permissionless, objective, resolves locked funds)
    //     - triggerExecutionExpiry  (permissionless, objective, resolves locked funds)
    //
    //   Not yet implemented in this Day 1 pass, but committed to the same policy when
    //   they land: claimRefund and cancelPatronage must never be pause-gated; only
    //   startPatronage (new risk) and the creator's claimPatronage (discretionary release
    //   of accrued value) should be.

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }
}
