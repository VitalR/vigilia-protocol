# 16 Screening Payment Modes Note

## Purpose

This note records a possible future improvement for `VigiliaGrantRound`: explicit screening payment modes.

The feature is **not urgent** and should **not trigger a redeployment for the current demo**. The current GrantRound design already supports the important practical path because `requestApplicationScreening` can be called by an applicant, sponsor, or judge, and the caller supplies the Somnia Agent workflow deposit.

For the current Agentathon/demo version, the recommended product framing remains:

```text
Applicants submit evidence.
Sponsors/judges request agent screening where needed.
Agents screen public evidence.
Judges/sponsors select finalists.
Contracts enforce payout rules.
```

## Current Behavior

The current GrantRound flow allows agent screening to be requested after an application is submitted.

Conceptually:

```text
Application submitted
→ applicant, sponsor, or judge requests screening
→ requester pays the workflow deposit through msg.value
→ verifier starts the configured workflow
→ callback records Complete / NeedsReview / Incomplete / VerificationFailed
→ sponsor/judge selects finalists
→ selected finalists claim prizes after finalization
```

This already supports two useful behaviors without a contract change:

1. **Applicant-paid screening**
   - Useful for open bounty or anti-spam flows.
   - Applicant has economic cost to request attestation.
   - Helps discourage fake submissions.

2. **Sponsor/judge-paid screening**
   - Useful for grants, accelerators, and hackathons.
   - Sponsor or judge pays when they decide an application should be screened.
   - Fits the normal grant-review workflow better than forcing every applicant to pay.

Because both are already possible at the transaction level, adding explicit payment modes is mainly a product/UX and accounting improvement, not a blocker.

## Why We Are Not Redeploying Now

A new deployment is not justified only for this feature because:

- the current contract already supports sponsor/judge-triggered screening;
- applicant-paid screening can still be used for anti-spam scenarios;
- the flagship demo proof is already based on GrantRound v0.4 ThreeAgent;
- changing the contract now would add deployment, proof, frontend, and documentation risk;
- the current final-demo priority is polish, evidence quality, UI clarity, and proof presentation.

The current version is sufficient for the final narrative:

```text
Agents assist review.
Humans select finalists.
Contracts reserve and release payouts safely.
```

## Product Analysis

### Applicant-Paid Screening

Best for:

- open bounty boards;
- public challenges;
- anti-spam application flows;
- self-attestation before sponsor review;
- cases where applicants want to prove readiness early.

Pros:

- discourages low-quality/fake submissions;
- sponsor does not pay to screen spam;
- simple with current contract behavior.

Cons:

- weaker fit for traditional grant/accelerator UX;
- real applicants may dislike paying to be reviewed;
- can reduce participation if agent fees are non-trivial.

### Sponsor/Judge-Paid Screening

Best for:

- grant programs;
- accelerators;
- hackathons;
- curated cohorts;
- programs where review cost belongs to the organizer.

Pros:

- stronger grant-product fit;
- applicants can submit without paying for review infrastructure;
- sponsor/judge can choose which submissions deserve screening;
- avoids wasting agent budget on obvious spam if the UI has a review queue.

Cons:

- sponsor pays per screening request;
- without an explicit budget module, payment is handled one transaction at a time;
- frontend must make it clear which wallet is paying.

## Recommended Current UX

For the current product/demo, the frontend should present screening as a review-board action:

```text
Applicant submits application for free or normal gas only.
Sponsor/judge opens the application board.
Sponsor/judge clicks “Request agent screening”.
Sponsor/judge pays the required workflow deposit.
Screening result appears as review metadata.
Sponsor/judge selects finalists after the deadline.
```

Applicant-paid screening can remain available as an advanced/self-service path:

```text
Applicant may optionally request screening for their own submission.
This is useful for self-attestation or open bounty anti-spam cases.
```

The UI should avoid implying that the applicant must always pay for grant review.

## Future Improvement: Explicit Screening Payment Modes

A future GrantRound version can add an explicit payment-mode enum.

Example:

```solidity
enum ScreeningPaymentMode {
    RequesterPays,
    SponsorBudget
}
```

### Mode 1: RequesterPays

This is closest to the current behavior.

```text
Who can request: applicant, sponsor, or judge
Who pays: msg.sender through msg.value
Best for: open bounties and applicant self-attestation
```

### Mode 2: SponsorBudget

A more grant-native version.

```text
Who can request: sponsor or judge
Who pays: the round's prepaid screening budget
Best for: grants, accelerators, hackathons, curated programs
```

Possible round fields:

```solidity
ScreeningPaymentMode screeningPaymentMode;
uint256 screeningBudgetRemaining;
uint256 screeningBudgetSpent;
```

Possible functions:

```solidity
function fundScreeningBudget(uint256 roundId) external payable;
function refundUnusedScreeningBudget(uint256 roundId) external;
```

Possible events:

```solidity
event ScreeningBudgetFunded(
    uint256 indexed roundId,
    address indexed sponsor,
    uint256 amount
);

event ScreeningBudgetRefunded(
    uint256 indexed roundId,
    address indexed sponsor,
    uint256 amount
);

event ApplicationScreeningRequested(
    uint256 indexed roundId,
    uint256 indexed applicationId,
    address indexed requester,
    address payer,
    ScreeningPaymentMode paymentMode,
    bytes32 requestId,
    uint256 deposit
);
```

## Important Safety Rule

If `SponsorBudget` is added, applicants should **not** be able to freely spend sponsor screening budget by default.

Bad default:

```text
Any applicant submits junk
→ applicant triggers sponsor-paid screening
→ sponsor budget is drained
```

Preferred default:

```text
Applicants submit evidence
→ sponsor/judge reviews queue
→ sponsor/judge chooses which applications to screen
→ screening budget is spent only by sponsor/judge action
```

If applicant-triggered sponsor-paid screening is ever added, it should require additional anti-spam controls:

- application bond;
- allowlist;
- invite code;
- max applications;
- per-applicant screening cap;
- sponsor pre-approval;
- round-level screening quota.

## Possible Implementation Sketch

In `RequesterPays` mode:

```solidity
require(
    msg.sender == app.applicant || msg.sender == round.sponsor || msg.sender == round.judge,
    "unauthorized requester"
);

requestId = verifier.requestVerification{value: msg.value}(...);
```

In `SponsorBudget` mode:

```solidity
require(msg.sender == round.sponsor || msg.sender == round.judge, "unauthorized requester");
require(msg.value == 0, "no direct payment expected");

uint256 deposit = verifier.minimumRequestDepositForWorkflow(workflow);
require(round.screeningBudgetRemaining >= deposit, "insufficient screening budget");

round.screeningBudgetRemaining -= deposit;
round.screeningBudgetSpent += deposit;

requestId = verifier.requestVerification{value: deposit}(...);
```

Refunds should use the same pull-payment style as other sponsor withdrawals:

```text
unused screening budget
→ credited to sponsor pending withdrawal
→ sponsor withdraws explicitly
```

## Suggested Additional Guard

A future version should consider blocking duplicate screening requests while an application is already waiting for a callback.

Recommended requestable statuses:

```text
Submitted
NeedsReview
Incomplete
VerificationFailed
```

Avoid requesting again from:

```text
ScreeningRequested
Complete
Selected
Rejected
Claimed
```

This prevents accidental budget waste and stale request confusion.

## When To Revisit

Revisit this feature after the demo if Vigilia moves toward:

- real grant program operations;
- accelerator cohort review;
- hosted sponsor dashboards;
- paid review budgets;
- larger applicant volume;
- stronger anti-spam economics;
- multiple screening rounds per application.

## Current Decision

Do **not** redeploy for this now.

For the current version:

```text
Use the existing requester-paid mechanism.
In the frontend, make sponsor/judge-paid screening the recommended grant flow.
Keep applicant-paid screening as optional/self-attestation/anti-spam behavior.
Document explicit SponsorBudget mode as a future improvement.
```

