# ADVANTAGE ASYMMETRY TECHNICAL DEMO — MASTER BUILD BRIEF

**Project:** Technical demonstration for *Building Trust in Stablecoins: Advantage Asymmetry in Ethical FinTech Design*  
**Status:** Architecture frozen for build unless a genuine technical blocker appears  
**Working date:** 22 August 2026  
**Time constraint:** Approximately one week  
**Primary objective:** Deliver a polished, defensible, public-testnet design-science artifact that instantiates the paper's Advantage Asymmetry design principles without overbuilding a production platform.

---

## 0. READ THIS FIRST — INSTRUCTION FOR A NEW CHAT / CODING AGENT

Treat this document as the source of truth for the project. The architecture debate is finished. Do **not** reopen Stellar vs Ethereum, Giveth vs custom, or Superfluid vs custom unless an actual implementation blocker makes the current plan impossible.

The immediate priority is **contract correctness before frontend polish**. The current baseline Solidity contract is included in Appendix A, but it is **not deploy-ready**. It contains several known state/accounting problems identified below. Repair and test those first. The requirements in this master brief override conflicting behaviour in the baseline code.

The project is a **research prototype**, not a production financial product. Do not claim it is audited, production-ready, empirically proven to increase trust, or fully decentralised. The strongest outcome is a small system whose behaviour is transparent, testable, reproducible, and tightly mapped to the paper's design propositions.

### Operating rule

**Reuse infrastructure; own the mechanism.**

Use established open-source infrastructure for standard security and Web3 plumbing. The original contribution is the application-specific combination of downside containment, milestone-conditioned release, visible accounting, low-stakes patronage, and creator/issuer accountability.

---

## 1. EXECUTIVE SUMMARY

### What we are building

A small public-testnet fundraising and creator-patronage dApp that demonstrates **Advantage Asymmetry** at the application layer. The system should let a supporter contribute a stablecoin into smart-contract-controlled escrow, let a creator access funds only through pre-defined milestones, provide a transparent failure/refund path, require the creator to post a bond that creates genuine downside exposure, and support a simple recurring low-stakes patronage stream.

### Final technology choice

- **Blockchain:** Ethereum Sepolia public testnet
- **Smart contracts:** Solidity
- **Stablecoin:** Prefer official AUDD on Ethereum Sepolia for the final public demo
- **Standard contract components:** OpenZeppelin Contracts
- **dApp scaffold/frontend:** Scaffold-ETH 2
- **Contract testing/deployment:** Foundry
- **Wallet/UI plumbing:** Scaffold-ETH 2 stack (Next.js, Wagmi, Viem, RainbowKit)
- **Application logic:** Custom `AdvantageAsymmetryCampaign` contract owned by this project

### Explicitly NOT in the critical path

- No Giveth fork
- No Gitcoin Allo integration
- No Superfluid integration
- No bespoke token standard
- No DAO governance system
- No oracle network
- No backend database unless later proven necessary
- No tokenised supporter acknowledgement unless all Must-Have items are complete

### Why this is the final architecture

The professor has confirmed that the technical demo is not restricted to Stellar and may use Ethereum, Solidity, or another suitable stack. The professor also supports the pragmatic reuse of open-source infrastructure because the time window is extremely short. Ethereum + Solidity + OpenZeppelin + Scaffold-ETH provides the fastest route to a polished and well-supported public-testnet prototype while preserving the paper's AUDD/stablecoin context.

---

## 2. PAPER CONTEXT — WHAT THE DEMO IS SUPPOSED TO PROVE

### Paper title

*Building Trust in Stablecoins: Advantage Asymmetry in Ethical FinTech Design*

### Core problem

The paper distinguishes **instrument-level trust** from **application-level trust**. Regulation, reserve backing, and issuer oversight can strengthen trust in the stablecoin itself, but they do not automatically make a user trust an application built on top of that stablecoin.

### Core construct: Advantage Asymmetry

The paper proposes Advantage Asymmetry as an application-layer design principle in which:

1. **User downside is structurally capped** rather than merely described as low risk.
2. **Containment is visible and credible** through transparent, observable application behaviour.
3. **The issuer/designer retains skin in the game**, so protecting users does not make failure costless for the party designing the system.

The behavioural pathway proposed in the paper is roughly:

**Loss aversion + betrayal aversion + weak social proof → high trust barrier → visible downside containment → low-stakes first interaction → repeated positive interactions → social proof → broader trust/adoption.**

### Use case chosen in the paper

Talent-driven fundraising / creator monetisation is the focal demonstration because it naturally supports low-stakes, non-leveraged value transfer with low or no expectation of financial return to supporters.

### What Section 4.5 currently expects from the technical artifact

The draft describes a proof-of-concept on a public testnet with these features:

- wallet-based onboarding;
- smart-contract-controlled campaigns;
- milestone-based releases;
- a real-time on-chain dashboard of fund flows and campaign progress;
- streaming / recurring low-stakes patronage;
- optional tokenised acknowledgements;
- no leverage or counterparty credit exposure.

The paper evaluates the artifact using three design-science criteria:

1. **Fidelity** — does the implementation realise the proposed design principles?
2. **Completeness of instantiation** — are the claimed architectural features actually present?
3. **Technical feasibility** — can the design be implemented using existing public-blockchain infrastructure?

### What the artifact must NOT claim

The demonstration does **not** prove:

- that real users trust the system more;
- that adoption increases;
- that the interface is easier than Kickstarter, Patreon, Giveth, or another platform;
- that the system is production-ready;
- that the smart contracts are professionally audited;
- that a central milestone verifier has been eliminated;
- that the theoretical trust mechanism is empirically validated.

Those questions require real users, comparison groups, trust/friction measures, experiments, or field studies and remain future research.

---

## 3. FINAL ARCHITECTURE DECISIONS — LOCK THESE

### 3.1 OpenZeppelin: dependency, not product base

Use **OpenZeppelin Contracts** for standard security-sensitive building blocks such as:

- `IERC20` / token interfaces;
- `SafeERC20`;
- `Ownable` or a similarly simple access-control primitive;
- `ReentrancyGuard`;
- `Pausable`;
- `Math`/utility functions where helpful.

Do **not** fork the OpenZeppelin repository and reshape it into the product. Create a new project repository and import OpenZeppelin as a dependency.

OpenZeppelin is infrastructure. The project still owns the application logic: campaigns, funding states, milestones, refund rules, bond logic, patronage, and dashboard semantics.

### 3.2 Giveth, Allo, and Superfluid

These are useful **references/precedents**, not dependencies.

- **Giveth:** evidence that blockchain fundraising and recurring donations are practical; too large to fork for a one-week research prototype.
- **Gitcoin Allo:** evidence that milestone/capital-allocation mechanisms exist; integration is unnecessary for our simple milestone state machine.
- **Superfluid:** evidence that continuous payment streaming exists; external integration is unnecessary because a simple time-accrual mechanism is enough to instantiate the paper's recurring low-stakes patronage concept.

### 3.3 Why not build everything proprietary?

Reimplementing token standards, access control, pause logic, reentrancy protection, wallet connection, and basic Web3 plumbing would consume time without increasing the paper's contribution. Originality should be concentrated where it matters: the **Advantage Asymmetry mechanism**.

---

## 4. VERIFIED NETWORK AND TOKEN INFORMATION

### Preferred final asset: AUDD on Ethereum Sepolia

AUDD's official Developer Hub lists an Ethereum Sepolia testnet contract:

**AUDD Ethereum Sepolia:** `0x3619d7f95b0eacae63dfa1909ab797eb0afc01e1`

Always verify this address again through the official AUDD Developer Hub immediately before final deployment.

### Important practical distinction

The existence of the official Sepolia contract does not necessarily mean there is a frictionless public faucet. Obtaining test AUDD may require sandbox/account access, wallet registration, or help from the AUDD/project team.

### Development fallback hierarchy

1. **Local Foundry tests:** use a small mock ERC-20.
2. **Public-testnet development while waiting for AUDD:** an official recognised Sepolia test token such as Circle testnet USDC is acceptable.
3. **Final public demo:** use AUDD if a test balance can be obtained in time.

If the final deployment does not actually use AUDD, the paper must state the token used accurately. Never write “using AUDD” merely because the contract is compatible with AUDD.

### Recommended contract simplification

For the final research artifact, prefer a **single immutable supported token** set when the contract is deployed rather than allowing arbitrary ERC-20 addresses per campaign. This reduces attack surface and makes the paper/demo easier to explain. If the final asset changes from development USDC to AUDD, redeploy the contract with the correct token address.

---

## 5. TARGET SYSTEM ARCHITECTURE

```text
                    SUPPORTER
                       |
                 Wallet / UI
                       |
                  AUDD (ERC-20)
                       |
                       v
        +--------------------------------+
        | AdvantageAsymmetryCampaign.sol |
        |                                |
        |  Funding state                 |
        |  Contribution escrow           |
        |  Milestone state machine       |
        |  Evidence URI                  |
        |  Conditional releases          |
        |  Failure / refund rules        |
        |  Creator bond                  |
        |  Patronage accrual             |
        +--------------------------------+
              |                 |
              v                 v
          CREATOR           DASHBOARD
                           - escrowed
                           - released
                           - milestones
                           - evidence
                           - bond
                           - refund status
                           - patronage
                           - tx history

             VERIFIER / CONTRACT OWNER
                       |
              approve / reject milestone
```

The application should require no off-chain backend for its core financial state. The frontend should read contract state and events directly from Sepolia. Milestone evidence may be an off-chain URL/IPFS pointer stored on-chain.

---

## 6. ACTORS AND RESPONSIBILITIES

### Supporter

- connects wallet;
- contributes stablecoin during the funding phase;
- can see where funds are held and what has been released;
- can claim a refund when the contract enters a refundable failure state;
- can start/cancel a low-stakes patronage stream;
- should never be exposed to leverage or an obligation beyond committed funds.

### Creator

- creates a campaign;
- defines milestone descriptions and release amounts;
- posts the creator bond up front;
- submits milestone evidence;
- receives only milestone amounts that pass verification;
- receives accrued patronage;
- recovers the bond on successful performance;
- loses the bond on creator-caused failure under the predefined rules.

### Verifier

- separate from the creator in the demonstration;
- approves or rejects submitted milestones;
- has **no discretionary platform withdrawal function**;
- must not financially benefit from slashing the creator bond.

For prototype scope, the contract owner can act as verifier. A production design could replace this with multisig, DAO, oracle/attestation, or another dispute-resolution mechanism.

---

## 7. REQUIRED CONTRACT BEHAVIOUR — RECOMMENDED V1.1 DESIGN

The current baseline contract should be refactored toward the following behaviour before frontend work begins.

### 7.1 Campaign states

Use an explicit state machine:

```text
Funding -> Active -> Succeeded
   |          |
   |          +------> Failed
   +-----------------> Failed
```

Recommended enum:

- `Funding` — contributions accepted; milestones cannot release funds yet.
- `Active` — goal reached; contribution pool frozen; milestone execution begins.
- `Succeeded` — all milestones released successfully.
- `Failed` — refundable failure state.

This solves a major accounting problem: all campaign contributions are finalised **before** milestone releases begin, so later contributors cannot unfairly subsidise earlier releases.

### 7.2 Campaign creation

Require:

- valid creator;
- creator is not the verifier/owner in the demo;
- `goal > 0`;
- `bondAmount > 0` for the fidelity demo;
- at least one milestone;
- every milestone amount > 0;
- milestone amounts sum exactly to the goal;
- valid funding and execution deadlines;
- execution deadline occurs after funding deadline.

The contract should hold the creator bond from creation.

### 7.3 Funding phase

- accept contributions only while status is `Funding` and before `fundingDeadline`;
- reject contributions that exceed the remaining goal (simpler and more transparent than silently truncating them);
- once `totalContributed == goal`, move automatically to `Active`;
- no new campaign contributions after `Active` begins.

### 7.4 Underfunded campaign

If the funding deadline passes before the goal is reached:

- anyone should be able to trigger the funding-expiry failure;
- supporters can recover their full contributions;
- the creator bond should be **returned**, not slashed, because failure to attract sufficient funding is not necessarily creator misconduct;
- record an explicit failure reason.

### 7.5 Milestone execution

- milestones should be sequential;
- only the next unresolved milestone can be submitted;
- creator submits an evidence URI;
- verifier can approve or reject only a submitted milestone;
- on approval, exactly that milestone's pre-specified amount is transferred to the creator;
- the same milestone can never be released twice;
- after the last milestone is released, campaign becomes `Succeeded` and creator bond is returned.

### 7.6 Creator-caused failure

Creator-caused failure can include:

- verifier rejects a submitted milestone; and/or
- a defined execution deadline expires without the required creator performance.

On creator-caused failure:

- campaign becomes `Failed`;
- future milestone releases stop;
- supporters become eligible to recover the **remaining unreleased contribution pool**;
- creator bond is slashed;
- slashed bond should **not** be distributed to supporters as upside, because the paper deliberately frames the supporter relationship as patronage/donation rather than an investment return.

Recommended demo treatment: send the slashed bond to a pre-disclosed neutral penalty/sink address that does not belong to the verifier. A production version could instead route it to a public-good, insurance, or resolution mechanism.

### 7.7 Refund accounting

Do not mutate `totalContributed` when individual supporters claim refunds.

At failure, preserve a stable refund denominator and pool. Because the campaign funding pool is frozen before releases begin, a pro-rata refund of remaining campaign escrow is conceptually coherent.

Recommended accounting variables:

- `refundPoolRemaining`;
- `refundWeightRemaining`;
- `refundClaimed[campaignId][supporter]`.

A claimant's share should be calculated from their recorded contribution and the remaining refund pool/weight. Ensure:

- no double claim;
- no order-dependent economic distortion beyond unavoidable integer rounding;
- no underflow;
- no creator bond accidentally mixed into supporter return unless the paper explicitly changes its economic framing.

### 7.8 Campaign expiry / indefinite-lock protection

The contract must have a permissionless timeout/failure trigger. Otherwise a creator who disappears can leave supporter money locked indefinitely, which directly contradicts the paper's “capped downside” design claim.

At minimum use:

- `fundingDeadline` for underfunded campaigns;
- `executionDeadline` for milestone performance.

The exact deadline calibration is not an empirical claim; it is a configurable prototype parameter.

### 7.9 Patronage streaming / recurring support

Do **not** integrate Superfluid unless the core build is already complete.

Use simple on-chain linear accrual:

```text
accrued = elapsed_time x rate
claimable = min(accrued, deposit) - already_claimed
```

Required behaviour:

- patron deposits a fixed maximum amount;
- rate is explicitly bounded by the deposit;
- creator can claim only accrued value;
- supporter can cancel future accrual;
- cancellation settles any legitimately accrued amount and refunds the unaccrued balance;
- accrued funds must never become stranded after cancellation;
- `claimed` can never exceed `deposit`;
- on campaign failure, future patronage accrual should stop at the failure timestamp;
- after success, existing patronage may continue until the supporter cancels, which better matches the paper's sustained patronage framing;
- patronage funds are separate from the campaign funding goal and milestone escrow.

For a public testnet demo, time can be compressed to seconds/minutes. The paper should describe this accurately as **time-based linear accrual settled through on-chain claims**, not as a transaction being emitted every second.

### 7.10 Pausing philosophy

Emergency pause should stop **new risk-taking and discretionary releases**, but user exit should remain available wherever safely possible.

Suggested approach:

Paused:
- no new campaigns;
- no new contributions;
- no new patronage streams;
- no milestone approval/release;
- no creator patronage claim.

Still available:
- supporter refund claims;
- supporter stream cancellation / recovery;
- expiry/failure trigger where appropriate.

This is consistent with the paper's user-downside containment logic.

### 7.11 Existence and parameter validation

Add explicit checks for:

- nonexistent campaign IDs;
- nonexistent milestone IDs;
- zero address token / deployment parameters;
- zero-value goal, milestone, contribution, bond, deposit, or rate where inappropriate;
- invalid deadlines;
- invalid status transitions.

Do not rely on enum default values to imply a campaign exists.

---

## 8. TERMINOLOGY — SAY THIS CAREFULLY

Avoid casually describing the whole prototype as simply “non-custodial.” The contract may not let the platform arbitrarily withdraw user money, but the prototype retains a **central milestone verifier** who has discretion over release/failure decisions.

Preferred wording:

> **Smart-contract-controlled escrow with no discretionary platform withdrawal function, subject to a centralised milestone verifier in the proof-of-concept.**

This is more precise and harder for a reviewer to attack.

---

## 9. CURRENT BASELINE CONTRACT — WHAT IS GOOD

The current `AdvantageAsymmetryCampaign.sol` is a useful V0 and should be repaired rather than discarded. It already contains:

- OpenZeppelin ERC-20 handling;
- SafeERC20;
- Ownable verifier simplification;
- Reentrancy guard;
- pause capability;
- campaign creation;
- milestone descriptions/amounts;
- evidence URI;
- contribution accounting;
- milestone submit/approve/reject;
- creator bond posting;
- attempted bond slashing;
- attempted refund logic;
- simple patronage accrual;
- dashboard read helpers;
- relevant events.

The overall architecture is small and understandable enough for a one-week research artifact.

---

## 10. CURRENT BASELINE CONTRACT — KNOWN PROBLEMS TO FIX BEFORE DEPLOYMENT

These are **not optional polish items**. They affect correctness and paper fidelity.

### Critical

1. **Refund calculation is incorrect.** The baseline changes `totalContributed` after each refund and calculates later refunds from a changing denominator. This makes outcomes depend on claim order and can lead to underflow or stranded funds.
2. **The slashed bond is described as part of the refund pool but is not actually included correctly.** More importantly, distributing it to supporters may contradict the paper's no-return patronage framing.
3. **Creator bond is never returned on successful completion.**
4. **Campaign never transitions to `Succeeded`.**
5. **Contributions can exceed the campaign goal.** Excess funds then have no milestone allocation.
6. **No timeout/expiry path exists.** Funds can be locked indefinitely if the creator never submits.
7. **Patronage cancellation can strand already-accrued value** because a cancelled stream becomes non-claimable before accrued funds are settled.
8. **Patronage can continue after campaign failure** unless separately cancelled.

### Important

9. Nonexistent campaign IDs rely on default enum values rather than explicit existence checks.
10. Milestones can be approved out of order.
11. `Approved` is only a transient state before immediately becoming `Released`; either justify or simplify.
12. Creator could theoretically be the same address as verifier unless prevented operationally or in code.
13. `PatronageClaimed` should identify the relevant contributor/stream in the event for dashboard traceability.
14. Pause semantics are inconsistent across state-changing functions and should be designed intentionally.
15. The baseline supports arbitrary token addresses per campaign, which increases attack surface unnecessarily for this single-token research demo.

### Accounting/design issue that requires the Funding -> Active split

If contributors are allowed to enter **after** milestone funds have already been released, a simple pro-rata failure refund is not economically fair. A late contributor's entire deposit may still be in escrow while an early contributor's funds partially financed an already-released milestone. Freezing the contribution pool before milestone execution avoids this complexity and is strongly recommended.

---

## 11. CONTRACT TESTING PLAN — DO THIS BEFORE UI POLISH

### 11.1 Core unit tests

#### Creation
- valid campaign creation;
- bond transferred into contract;
- milestone sum must equal goal;
- zero/invalid parameters revert;
- creator cannot be verifier if that rule is adopted;
- deadlines validated.

#### Funding
- contribution succeeds in Funding;
- contribution after funding deadline reverts;
- over-goal contribution reverts;
- exact goal transitions campaign to Active;
- contribution in Active/Succeeded/Failed reverts;
- funding expiry creates refundable failure;
- underfunded expiry returns creator bond.

#### Milestones
- only creator can submit;
- only next milestone can be submitted;
- only verifier can approve/reject;
- cannot approve unsubmitted milestone;
- approved milestone releases exactly its allocation;
- cannot release milestone twice;
- milestone releases never exceed goal;
- final milestone transitions to Succeeded;
- successful completion returns creator bond once and only once.

#### Failure/refunds
- rejection transitions to Failed;
- remaining contribution pool becomes refundable;
- creator-caused failure slashes bond to neutral sink;
- verifier does not receive slashed bond;
- supporters recover correct proportional unreleased amount;
- claim order does not materially alter economic entitlement;
- no double refund;
- total refunded never exceeds refund pool;
- already released funds are not refunded;
- no underflow after multiple claims.

#### Patronage
- only permitted campaign states can start patronage;
- deposit/rate validation;
- time accrual correct;
- creator cannot claim more than accrued;
- total claimed never exceeds deposit;
- cancellation pays/records accrued amount correctly and refunds only unaccrued balance;
- cancellation cannot occur twice;
- failure timestamp stops future accrual;
- existing stream can continue after successful campaign if that policy is adopted;
- unrelated campaign patronage cannot be claimed.

#### Access control / emergency
- non-owner cannot approve/reject/pause;
- pause stops new risk exposure;
- user refunds/cancellations remain available where designed;
- no privileged arbitrary withdrawal function exists.

#### Cross-campaign isolation
- campaign A cannot spend campaign B's accounted escrow;
- patronage for A cannot be claimed through B;
- refund in A does not alter B accounting.

### 11.2 Fuzz / invariant tests

High-value invariants:

- `totalReleased <= goal` for every campaign;
- no milestone can be released twice;
- no contributor can refund twice;
- campaign contribution releases + remaining refundable contribution pool never exceed historical campaign contributions;
- creator bond can end in only one terminal outcome: returned or slashed;
- patronage claimed + refundable remainder never exceeds stream deposit;
- failed campaign cannot release new milestones;
- succeeded campaign cannot return to Active/Funding;
- contract has no path for verifier to withdraw arbitrary campaign funds.

### 11.3 Quality gates

Before Sepolia deployment:

- `forge fmt`
- `forge build`
- `forge test -vvv`
- `forge coverage`
- aim for very high coverage of custom state-transition logic, not merely raw line coverage;
- run a static analyser such as Slither if installation/time permits;
- perform a second-model adversarial code review after tests pass.

Passing tests do not equal an external security audit. Paper and README must say **not audited**.

---

## 12. FRONTEND / DASHBOARD SPECIFICATION

The UI is part of the research artifact because **visible containment** is one of the theoretical design requirements. It should not merely be decorative.

### 12.1 Primary campaign page

Show clearly:

- campaign creator;
- stablecoin and network;
- goal;
- total contributed;
- funding state / milestone state;
- current escrowed contribution amount;
- total released to creator;
- creator bond amount and current bond status;
- funding deadline;
- execution deadline;
- current/next milestone;
- milestone evidence URI;
- verifier decision/status;
- refund availability;
- link to relevant block-explorer transactions.

### 12.2 Supporter actions

- connect wallet;
- approve AUDD/token allowance;
- contribute;
- start patronage;
- cancel patronage;
- claim refund when eligible.

Before transaction confirmation, show plain-language consequences such as:

- “Maximum campaign contribution at risk: X AUDD.”
- “Funds remain in contract escrow until milestone release.”
- “Unreleased contribution funds become refundable if the campaign enters a refundable failure state.”
- “Recurring patronage can be cancelled; only accrued value is payable to the creator.”

This is the **visible containment** layer. Do not hide it in documentation.

### 12.3 Creator actions

- create campaign;
- approve token/bond transfer;
- submit milestone evidence;
- view released/remaining funds;
- view bond status;
- claim accrued patronage.

### 12.4 Verifier actions

A simple verifier panel can allow the owner/verifier wallet to:

- inspect submitted evidence;
- approve milestone;
- reject milestone.

The UI should visibly label this as **Prototype verifier** so the centralised simplification is transparent.

### 12.5 Dashboard visual priority

The strongest dashboard is not the prettiest dashboard. It is the one that lets a reviewer immediately see:

**What can the user lose? Where is the money? What has been released? What must happen next? What happens if the creator fails? What does the creator stand to lose?**

---

## 13. PUBLIC-TESTNET DEPLOYMENT PLAN

### 13.1 Scaffold

```bash
npx create-eth@latest
```

Choose Foundry.

### 13.2 OpenZeppelin

Install and pin the chosen OpenZeppelin Contracts version/commit. Do not leave dependencies floating during the sprint.

### 13.3 Local development

- deploy mock ERC-20;
- run full Foundry suite;
- use local chain time-warping for deadlines and patronage tests;
- integrate frontend only after contract tests are green.

### 13.4 Sepolia preparation

Need:

- dedicated deployer/verifier wallet;
- separate creator wallet;
- at least one supporter wallet, ideally two for refund demonstration;
- Sepolia ETH for gas;
- test stablecoin balance;
- final verified AUDD address;
- stable RPC provider.

### 13.5 Final deployment

- deploy contract with final supported token and any immutable penalty/sink configuration;
- record deployed contract address;
- verify contract source on Etherscan if practical;
- save compiler version and dependency commit;
- create demo campaigns;
- execute success and failure scenarios;
- preserve every transaction hash needed for the paper/evidence pack.

### 13.6 Frontend hosting

Preferred: deploy the Next.js frontend to a simple public host such as Vercel after the contract is stable. Network should be clearly labelled **Ethereum Sepolia — testnet**.

---

## 14. DEMO SCENARIOS TO RECORD

Do not rely on a single happy-path campaign.

### Scenario A — Success

Example only; amounts can change:

- Goal: 100 AUDD
- Creator bond: 10 AUDD
- Milestone 1: 40 AUDD
- Milestone 2: 60 AUDD
- Two supporters fund the campaign to 100 AUDD
- Campaign transitions Funding -> Active
- Creator submits milestone 1 evidence
- Verifier approves
- Exactly 40 AUDD releases
- Creator submits milestone 2 evidence
- Verifier approves
- Exactly 60 AUDD releases
- Campaign becomes Succeeded
- Creator bond is returned

Evidence to capture:

- campaign state before/after;
- contract balance/accounting;
- milestone evidence/status;
- release tx hashes;
- bond return tx;
- dashboard screenshots.

### Scenario B — Creator failure / refund

- Campaign fully funded
- First milestone may be approved or leave all funds unreleased
- Next milestone is submitted and rejected (or creator misses execution requirement)
- Campaign becomes Failed
- Remaining contribution escrow becomes refundable
- Creator bond is slashed to neutral sink
- Supporter 1 claims
- Supporter 2 claims
- Combined refunds equal the defined remaining contribution pool subject only to integer rounding

This is the most important failure demonstration because it makes **downside containment** visible.

### Scenario C — Patronage

- Supporter deposits a small amount for recurring patronage
- Use a short testnet time scale so accrual is visible within minutes
- Creator claims only the accrued amount
- Supporter cancels
- Unaccrued balance returns to supporter
- Show that creator can never claim more than deposit

### Scenario D — Adverse action prevention

Show at least one reverted transaction in tests, not necessarily public UI:

- creator attempts unauthorised release;
- supporter attempts over-goal contribution;
- creator attempts milestone out of order;
- second refund claim;
- creator claims patronage above accrued amount.

---

## 15. DESIGN-SCIENCE EVIDENCE PACKAGE

Create a reproducibility/evidence folder in the repo:

```text
evidence/
  architecture.png
  contract-addresses.md
  transactions.md
  test-results.txt
  coverage-summary.txt
  screenshots/
    campaign-funded.png
    milestone-approved.png
    failure-refund.png
    creator-bond.png
    patronage.png
  design-mapping.md
```

### Evaluation matrix

| Evaluation criterion | Question | Evidence |
|---|---|---|
| Fidelity | Does the artifact instantiate capped downside, visible containment, and issuer accountability? | Contract logic + design-mapping table + UI screenshots + tests |
| Completeness | Are escrow, milestone release, transparent dashboard, and recurring patronage actually present? | Live demo + code + transaction hashes + screenshots |
| Technical feasibility | Can the required properties run on existing public blockchain infrastructure? | Sepolia deployment + verified token + successful transactions + contract address |

### Design-principle mapping

| Paper principle | Technical instantiation |
|---|---|
| Capped downside | Fixed supporter commitments, no leverage, deadlines, refund path, cancellable patronage |
| Visible containment | On-chain campaign state, milestones, escrow/released/refundable values, transaction links |
| Conditional release | Sequential milestone state machine and verifier-gated release |
| Issuer skin in the game | Nonzero creator bond returned on success, slashed on creator-caused failure |
| Low-stakes repeat interaction | Bounded recurring patronage deposit with time-based accrual and cancellation |
| No investment-style upside | No promised financial return; bond penalty is not distributed as supporter profit |

---

## 16. PAPER UPDATE CHECKLIST AFTER THE BUILD

Do not rewrite Section 4.5 as “finished” before the artifact is actually deployed and tested.

After the build, update the paper with only verifiable facts:

### Replace placeholders

- exact network;
- exact stablecoin used;
- contract address;
- deployment date/block if useful;
- implementation details that actually exist.

### Update architecture description

Recommended wording direction:

- public Ethereum Sepolia testnet;
- smart-contract-controlled stablecoin escrow;
- sequential milestone-conditioned releases;
- on-chain/readable dashboard state;
- bounded time-accrual patronage;
- creator bond as issuer accountability;
- central verifier as explicit prototype simplification.

### Correct the “non-custodial” language

Prefer the precise wording from Section 8 of this brief.

### Evaluation claims

Only write “the artifact satisfies” fidelity/completeness/feasibility after evidence exists. If a feature is omitted, change the claim rather than pretending it was built.

### Tokenised acknowledgements

The current draft calls them optional. If not implemented, either:

- remove them from the final feature list; or
- clearly label them future/optional rather than part of the evaluated artifact.

### Limitations to preserve

Keep explicit that the prototype does not empirically establish:

- trust formation;
- adoption;
- comparative usability;
- superiority to traditional crowdfunding;
- security/audit assurance.

### Author positionality

Retain the paper's acknowledgement that authors have an interest in the focal application. The artifact is evidence of **technical instantiation**, not evidence that the authors' product concept produces superior real-world outcomes.

---

## 17. ONE-WEEK EXECUTION PLAN

This is a target sequence, not a promise. If a critical issue consumes a day, cut Stretch items rather than compromising contract correctness.

### Day 0 — Architecture freeze / environment

- create repo;
- Scaffold-ETH 2 with Foundry;
- install/pin OpenZeppelin;
- establish three/four test wallets;
- confirm token plan;
- obtain/ask for Sepolia AUDD;
- place current contract into repo as V0;
- create issue/checklist from this master brief.

### Day 1 — Contract refactor

- implement Funding -> Active -> terminal state machine;
- immutable supported token;
- existence validation;
- deadlines;
- contribution cap;
- milestone ordering;
- success/bond return;
- failure reasons.

### Day 2 — Refund + bond correctness

- repair failure accounting;
- separate bond from supporter refunds;
- implement neutral bond penalty;
- write unit tests for success/failure/refunds;
- adversarially test multi-supporter scenarios.

### Day 3 — Patronage + invariants

- repair patronage cancellation;
- cap accrual on failure;
- write time-warp tests;
- fuzz/invariant tests;
- coverage/static analysis;
- second-model review.

### Day 4 — Frontend core

- campaign list/detail;
- wallet connection;
- contribution flow;
- milestone/evidence display;
- verifier controls;
- dashboard values.

### Day 5 — Transparency + patronage UI

- refund UX;
- bond status;
- patronage start/claim/cancel;
- block explorer links;
- visible downside explanation;
- responsive/polished UI.

### Day 6 — Sepolia deployment / demo runs

- deploy final contract;
- use AUDD if available;
- run success campaign;
- run failure/refund campaign;
- run patronage scenario;
- save transaction evidence;
- fix deployment/UI edge cases.

### Day 7 — Research packaging

- screenshots;
- architecture diagram;
- test/coverage evidence;
- transaction table;
- design-principle mapping;
- README;
- paper Section 4.5 rewrite;
- final adversarial review of claims vs actual implementation.

---

## 18. PRIORITIES — DO NOT LET SCOPE CREEP KILL THE BUILD

### MUST HAVE

- Ethereum Sepolia deployment;
- stablecoin contribution;
- contract-controlled escrow;
- funding state and contribution cap;
- deadlines / no indefinite lock;
- sequential milestones;
- evidence submission;
- verifier approve/reject;
- conditional release;
- failure/refund path;
- creator bond with success return and creator-failure penalty;
- correct multi-supporter accounting;
- recurring low-stakes patronage;
- supporter cancellation/refund of unaccrued patronage;
- dashboard showing containment/transparency;
- Foundry tests;
- success + failure public-testnet evidence.

### SHOULD HAVE

- Etherscan source verification;
- public hosted frontend;
- two-supporter failure demo;
- high test coverage;
- static analysis;
- clear architecture diagram;
- public or submission-ready reproducibility repo.

### STRETCH

- tokenised supporter acknowledgement/NFT;
- IPFS upload integration rather than a simple evidence URI;
- more advanced verifier governance;
- DAO/multisig/oracle;
- sophisticated animations;
- extensive analytics;
- Superfluid integration;
- Giveth/Allo integration.

If time is short, delete Stretch items without hesitation.

---

## 19. RISK REGISTER

| Risk | Why it matters | Mitigation |
|---|---|---|
| AUDD test balance unavailable | Could delay final on-chain demo | Develop with mock/official test token; pursue AUDD access in parallel; only claim final asset truthfully |
| Contract accounting bug | Could invalidate “capped downside” claim | Tests before UI, multi-user failure tests, invariants, second-model review |
| Central verifier criticism | Reviewer may say trust merely moved to owner | Explicitly disclose prototype verifier; owner has no arbitrary withdrawal; production alternatives stated |
| Bond creates supporter investment-like upside | Could contradict patronage framing | Do not distribute slashed bond as supporter profit; use neutral penalty sink |
| Indefinite fund lock | Directly undermines downside containment | Funding/execution deadlines + permissionless expiry/refund path |
| Overbuilding | One-week deadline | Architecture frozen; no external protocols; Must/Should/Stretch discipline |
| UI looks polished but mechanism is wrong | Weak research artifact | Contract correctness and evidence precede polish |
| “Non-custodial” overclaim | Conceptual vulnerability | Use precise smart-contract-controlled escrow terminology |
| AI-generated code assumed safe | Smart contract risk | Adversarial tests, static analysis, independent model review, explicit “not audited” limitation |
| Paper and code drift apart | Reviewer can find contradictions | Final claim-by-claim implementation audit before submission |

---

## 20. DEFINITION OF DONE

The project is finished when all of the following are true:

1. Contract builds cleanly.
2. Core Foundry tests and invariants pass.
3. No known critical accounting/state bug remains.
4. A public Sepolia contract exists.
5. The final stablecoin used is documented accurately.
6. At least one success campaign is executed on testnet.
7. At least one failure/refund campaign is executed on testnet.
8. Creator bond is visibly returned on success and penalised on creator-caused failure.
9. Patronage accrues, can be claimed only within limits, and can be cancelled without stranding funds.
10. Dashboard exposes escrow, releases, milestones, evidence, bond, refunds, and patronage state.
11. Transaction hashes and screenshots are preserved.
12. Architecture/design mapping exists.
13. README explains setup and limitations.
14. Paper Section 4.5 matches the implementation exactly.
15. Paper still states that trust/adoption effects are not empirically validated.
16. No claim of professional audit or production readiness appears.

---

## 21. FIRST TASKS FOR THE NEW CHAT

When this document is uploaded to a new chat, begin in this order:

1. **Read this master brief fully and confirm the architecture is frozen.**
2. **Inspect Appendix A baseline contract against Sections 7 and 10.**
3. **Produce a concise V1.1 refactor plan before changing code.**
4. **Implement contract fixes and Foundry tests before building the frontend.**
5. **Use a builder/reviewer loop:** one agent/model writes; a second pass tries to break state transitions, accounting, access control, and paper claims.

Do not spend the opening session researching alternative chains or protocols.

---

## 22. VERIFIED EXTERNAL REFERENCES

Use official sources where possible and re-check live details before deployment.

- AUDD Developer Hub — Supported Blockchains: https://devhub.audd.digital/docs/supported-blockchains
- AUDD Developer Hub — External Wallet Management / Minting: https://devhub.audd.digital/docs/managing-external-wallets
- AUDD Developer Hub — Mint AUDD: https://devhub.audd.digital/docs/mint-audd
- Scaffold-ETH 2 documentation: https://docs.scaffoldeth.io/
- OpenZeppelin Contracts documentation: https://docs.openzeppelin.com/contracts/

Current verified AUDD Ethereum Sepolia address (re-verify before deployment):

`0x3619d7f95b0eacae63dfa1909ab797eb0afc01e1`

---

# APPENDIX A — CURRENT V0 CONTRACT (NOT DEPLOY-READY)

The following is the exact baseline supplied before the final master brief. Preserve it for traceability, but **requirements in the main document override conflicting behaviour here**.

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";

/// @title AdvantageAsymmetryCampaign
/// @notice Research prototype instantiating the advantage-asymmetry design principle:
///         non-custodial escrow, milestone-conditional release, creator bond
///         (issuer skin-in-the-game), and recurring low-stakes patronage.
/// @dev Testnet demo artifact for a design-science research paper. Not audited.
///      Simplifications are flagged inline where made for scope, not by accident.
contract AdvantageAsymmetryCampaign is Ownable, ReentrancyGuard, Pausable {
    using SafeERC20 for IERC20;

    enum MilestoneStatus { Pending, Submitted, Approved, Rejected, Released }
    enum CampaignStatus { Active, Succeeded, Failed }

    struct Milestone {
        string description;
        uint256 amount;         // amount released to creator on approval
        MilestoneStatus status;
        string evidenceURI;     // off-chain evidence pointer (IPFS/URL), for the dashboard
    }

    struct Campaign {
        address creator;
        IERC20 token;            // stablecoin used for this campaign (AUDD or USDC address)
        uint256 goal;
        uint256 bondAmount;      // creator's posted bond, held in escrow alongside contributions
        bool bondPosted;
        uint256 totalContributed;
        uint256 totalReleased;
        CampaignStatus status;
        Milestone[] milestones;
    }

    struct PatronageStream {
        uint256 deposit;
        uint256 ratePerSecond;
        uint256 startTime;
        uint256 claimed;
        bool cancelled;
    }

    uint256 public campaignCount;
    mapping(uint256 => Campaign) private campaigns;
    mapping(uint256 => mapping(address => uint256)) public contributions;       // campaignId => contributor => amount
    mapping(uint256 => mapping(address => PatronageStream)) public patronage;   // campaignId => contributor => stream

    // Simplification for prototype scope: the contract owner acts as milestone verifier.
    // A production version would replace this with a DAO vote, multisig, or oracle attestation.
    // This is disclosed explicitly, not hidden, per the paper's evaluation criteria.

    event CampaignCreated(uint256 indexed campaignId, address indexed creator, address token, uint256 goal, uint256 bondAmount);
    event Contributed(uint256 indexed campaignId, address indexed contributor, uint256 amount);
    event MilestoneSubmitted(uint256 indexed campaignId, uint256 indexed milestoneIndex, string evidenceURI);
    event MilestoneApproved(uint256 indexed campaignId, uint256 indexed milestoneIndex, uint256 amountReleased);
    event MilestoneRejected(uint256 indexed campaignId, uint256 indexed milestoneIndex);
    event Refunded(uint256 indexed campaignId, address indexed contributor, uint256 amount);
    event BondSlashed(uint256 indexed campaignId, uint256 amount);
    event PatronageStarted(uint256 indexed campaignId, address indexed contributor, uint256 deposit, uint256 ratePerSecond);
    event PatronageClaimed(uint256 indexed campaignId, uint256 amount);
    event PatronageCancelled(uint256 indexed campaignId, address indexed contributor, uint256 refunded);

    constructor() Ownable(msg.sender) {}

    // ---------- Campaign lifecycle ----------

    function createCampaign(
        address token,
        uint256 goal,
        uint256 bondAmount,
        string[] calldata milestoneDescriptions,
        uint256[] calldata milestoneAmounts
    ) external whenNotPaused returns (uint256 campaignId) {
        require(milestoneDescriptions.length == milestoneAmounts.length, "milestone arrays mismatch");
        require(milestoneDescriptions.length > 0, "need at least one milestone");

        uint256 sum;
        for (uint256 i = 0; i < milestoneAmounts.length; i++) {
            sum += milestoneAmounts[i];
        }
        require(sum == goal, "milestones must sum to goal");

        campaignId = campaignCount++;
        Campaign storage c = campaigns[campaignId];
        c.creator = msg.sender;
        c.token = IERC20(token);
        c.goal = goal;
        c.bondAmount = bondAmount;
        c.status = CampaignStatus.Active;

        for (uint256 i = 0; i < milestoneDescriptions.length; i++) {
            c.milestones.push(Milestone({
                description: milestoneDescriptions[i],
                amount: milestoneAmounts[i],
                status: MilestoneStatus.Pending,
                evidenceURI: ""
            }));
        }

        // Creator posts bond up front: issuer skin-in-the-game, the piece that
        // isn't just borrowed from existing crowdfunding patterns.
        if (bondAmount > 0) {
            c.token.safeTransferFrom(msg.sender, address(this), bondAmount);
            c.bondPosted = true;
        }

        emit CampaignCreated(campaignId, msg.sender, token, goal, bondAmount);
    }

    function contribute(uint256 campaignId, uint256 amount) external nonReentrant whenNotPaused {
        Campaign storage c = campaigns[campaignId];
        require(c.status == CampaignStatus.Active, "campaign not active");
        require(amount > 0, "amount must be > 0");

        c.token.safeTransferFrom(msg.sender, address(this), amount);
        contributions[campaignId][msg.sender] += amount;
        c.totalContributed += amount;

        emit Contributed(campaignId, msg.sender, amount);
    }

    // ---------- Milestones ----------

    function submitMilestone(uint256 campaignId, uint256 milestoneIndex, string calldata evidenceURI) external {
        Campaign storage c = campaigns[campaignId];
        require(msg.sender == c.creator, "only creator");
        Milestone storage m = c.milestones[milestoneIndex];
        require(m.status == MilestoneStatus.Pending, "milestone not pending");

        m.status = MilestoneStatus.Submitted;
        m.evidenceURI = evidenceURI;

        emit MilestoneSubmitted(campaignId, milestoneIndex, evidenceURI);
    }

    /// @dev Verifier-gated (contract owner for this prototype, see note above).
    function approveMilestone(uint256 campaignId, uint256 milestoneIndex) external onlyOwner nonReentrant {
        Campaign storage c = campaigns[campaignId];
        Milestone storage m = c.milestones[milestoneIndex];
        require(m.status == MilestoneStatus.Submitted, "milestone not submitted");
        require(c.totalContributed >= c.totalReleased + m.amount, "insufficient escrow for release");

        m.status = MilestoneStatus.Approved;
        c.totalReleased += m.amount;
        m.status = MilestoneStatus.Released;

        c.token.safeTransfer(c.creator, m.amount);

        emit MilestoneApproved(campaignId, milestoneIndex, m.amount);
    }

    /// @dev Rejection triggers the failure path: contributors become eligible to
    ///      claim refunds on their unreleased share, and the creator bond is slashed.
    function rejectMilestone(uint256 campaignId, uint256 milestoneIndex) external onlyOwner {
        Campaign storage c = campaigns[campaignId];
        Milestone storage m = c.milestones[milestoneIndex];
        require(m.status == MilestoneStatus.Submitted, "milestone not submitted");

        m.status = MilestoneStatus.Rejected;
        c.status = CampaignStatus.Failed;

        if (c.bondPosted && c.bondAmount > 0) {
            uint256 slashed = c.bondAmount;
            c.bondAmount = 0;
            c.bondPosted = false;
            emit BondSlashed(campaignId, slashed);
            // Slashed bond stays in contract escrow, distributed pro-rata via claimRefund
            // alongside unreleased contributions. Kept simple and inspectable for the demo.
        }

        emit MilestoneRejected(campaignId, milestoneIndex);
    }

    /// @notice Contributors pull their pro-rata share of unreleased escrow (plus any
    ///         slashed bond) after a campaign is marked Failed. Pull-payment pattern,
    ///         not push, to avoid a single failing transfer blocking everyone else.
    function claimRefund(uint256 campaignId) external nonReentrant {
        Campaign storage c = campaigns[campaignId];
        require(c.status == CampaignStatus.Failed, "campaign not failed");

        uint256 contributed = contributions[campaignId][msg.sender];
        require(contributed > 0, "nothing to refund");

        uint256 unreleased = c.totalContributed - c.totalReleased;
        uint256 pool = unreleased; // bond, if slashed, already sits in this same escrow balance
        uint256 share = (contributed * pool) / c.totalContributed;

        contributions[campaignId][msg.sender] = 0;
        c.totalContributed -= contributed; // prevents double counting on repeated calls across contributors

        c.token.safeTransfer(msg.sender, share);

        emit Refunded(campaignId, msg.sender, share);
    }

    // ---------- Patronage streaming (linear accrual, no external protocol) ----------

    function startPatronage(uint256 campaignId, uint256 deposit, uint256 ratePerSecond) external nonReentrant whenNotPaused {
        Campaign storage c = campaigns[campaignId];
        require(c.status == CampaignStatus.Active, "campaign not active");
        require(deposit > 0 && ratePerSecond > 0, "invalid stream params");

        PatronageStream storage s = patronage[campaignId][msg.sender];
        require(s.deposit == 0 || s.cancelled, "existing stream active");

        c.token.safeTransferFrom(msg.sender, address(this), deposit);

        patronage[campaignId][msg.sender] = PatronageStream({
            deposit: deposit,
            ratePerSecond: ratePerSecond,
            startTime: block.timestamp,
            claimed: 0,
            cancelled: false
        });

        emit PatronageStarted(campaignId, msg.sender, deposit, ratePerSecond);
    }

    function claimablePatronage(uint256 campaignId, address contributor) public view returns (uint256) {
        PatronageStream storage s = patronage[campaignId][contributor];
        if (s.deposit == 0 || s.cancelled) return 0;

        uint256 elapsed = block.timestamp - s.startTime;
        uint256 accrued = elapsed * s.ratePerSecond;
        uint256 capped = accrued > s.deposit ? s.deposit : accrued;

        return capped - s.claimed;
    }

    function claimPatronage(uint256 campaignId, address contributor) external nonReentrant {
        Campaign storage c = campaigns[campaignId];
        require(msg.sender == c.creator, "only creator claims");

        uint256 claimable = claimablePatronage(campaignId, contributor);
        require(claimable > 0, "nothing to claim");

        PatronageStream storage s = patronage[campaignId][contributor];
        s.claimed += claimable;

        c.token.safeTransfer(c.creator, claimable);

        emit PatronageClaimed(campaignId, claimable);
    }

    /// @notice Supporter stops future accrual and withdraws whatever hasn't been claimed yet.
    function cancelPatronage(uint256 campaignId) external nonReentrant {
        PatronageStream storage s = patronage[campaignId][msg.sender];
        require(s.deposit > 0 && !s.cancelled, "no active stream");

        uint256 alreadyAccrued = claimablePatronage(campaignId, msg.sender) + s.claimed;
        uint256 refundable = s.deposit - alreadyAccrued;

        s.cancelled = true;

        if (refundable > 0) {
            campaigns[campaignId].token.safeTransfer(msg.sender, refundable);
        }

        emit PatronageCancelled(campaignId, msg.sender, refundable);
    }

    // ---------- Dashboard read helpers ----------

    function getCampaign(uint256 campaignId) external view returns (
        address creator,
        address token,
        uint256 goal,
        uint256 bondAmount,
        bool bondPosted,
        uint256 totalContributed,
        uint256 totalReleased,
        CampaignStatus status,
        uint256 milestoneCount
    ) {
        Campaign storage c = campaigns[campaignId];
        return (c.creator, address(c.token), c.goal, c.bondAmount, c.bondPosted,
                c.totalContributed, c.totalReleased, c.status, c.milestones.length);
    }

    function getMilestone(uint256 campaignId, uint256 milestoneIndex) external view returns (Milestone memory) {
        return campaigns[campaignId].milestones[milestoneIndex];
    }

    // ---------- Emergency controls ----------

    function pause() external onlyOwner { _pause(); }
    function unpause() external onlyOwner { _unpause(); }
}

```

---

# APPENDIX B — CURRENT BASELINE SETUP NOTES

These setup notes are preserved as the starting environment guide. Some implementation details (especially token choice and contract logic) may be superseded by this master brief.

```markdown
# Setup — run these in order

## 1. Scaffold the project
```bash
npx create-eth@latest
```
Choose Foundry when prompted (faster local testing than Hardhat for this size of contract).

## 2. Install OpenZeppelin
```bash
cd packages/foundry
forge install OpenZeppelin/openzeppelin-contracts
```

## 3. Drop in the contract
Copy `AdvantageAsymmetryCampaign.sol` into `packages/foundry/contracts/`

## 4. Point it at Sepolia + a test token
- Network: Ethereum Sepolia
- Stablecoin address: pass Sepolia testnet USDC's address as the `token` param when you call `createCampaign` (get it from Circle's testnet faucet, no application needed). Swap to AUDD's Sepolia testnet address later if sandbox access comes through, it's a parameter, not a rebuild.

## 5. First build + test
```bash
forge build
forge test
```

## 6. Deploy to Sepolia
Scaffold-ETH 2's deploy scripts are in `packages/foundry/script/`. Get Sepolia ETH for gas from a public faucet (search "Sepolia ETH faucet"), then:
```bash
yarn deploy --network sepolia
```

## 7. Frontend
`yarn start` runs the Scaffold-ETH 2 frontend, already wired for wallet connect. Your dashboard work goes into `packages/nextjs/app/`, reading `getCampaign` and `getMilestone` for the live state your paper's Section 4.5 needs to show.

---

**What's already handled in the contract:** contribution, escrow, milestone submit/approve/reject, refund claiming, creator bond posting and slashing, patronage streaming (start/claim/cancel). What you still write: the frontend dashboard, your Foundry tests (adversarially, try to break every rule listed in the contract's comments), and the milestone evidence/verification UI.

**What's intentionally simplified, and should be stated as such in the paper:** the contract owner acts as milestone verifier instead of a DAO or oracle. That's flagged inline in the contract, not hidden.

```

---

# APPENDIX C — FINAL PRINCIPLE

The goal is not to build the biggest possible Web3 application in one week.

The goal is to build the **smallest complete, testable and transparent system that convincingly instantiates the paper's design theory**.

**Reuse infrastructure. Own the mechanism. Prove only what the artifact actually proves.**
