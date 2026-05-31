# Grant Round and Finalist Selection Extension

## Purpose

This note captures a future Vigilia extension for grant programs, hackathons, bounty rounds, and accelerator cohorts where many builders submit work to one funded opportunity and judges manually select a limited number of winners or finalists.

This is **additional scope** beyond the current v0.1/v0.2 escrow and agent-verification work. It should not block the current path of proving JSON API + LLM Inference verification and settlement.

## Current Escrow Limitation

The current `VigiliaEscrow` model is task-scoped and contractor-scoped:

```text
one task
→ one client
→ one contractor
→ one active submission
→ one escrow amount
→ one verification result
→ approve / claim / resubmit / dispute
```

This works well for fixed milestones and freelance-style tasks, but it does **not** natively model:

```text
one grant round
→ many applicants
→ many submissions
→ agent-assisted screening
→ judges select top N finalists
→ finalists claim prizes
```

The current workaround is to create one escrow task per applicant, but that is not ideal for grant programs because it can overfund non-finalists and does not provide a clean round-level finalist-selection model.

## Proposed Product Extension

Add a separate grant/bounty module rather than bloating the existing escrow contract.

Possible names:

```text
VigiliaGrantRound
VigiliaBountyBoard
VigiliaGrantProgram
```

The module should represent a funded round with many submissions and a limited number of winners.

## Target Flow

```text
Sponsor creates grant round
→ sponsor funds prize pool
→ many builders submit evidence
→ agents verify each submission
→ submissions receive Complete / NeedsReview / Incomplete / VerificationFailed
→ judges review eligible submissions manually
→ judges select up to N finalists
→ finalists claim prizes
→ unallocated funds can be refunded or rolled over
```

This model is useful for:

- hackathon prize tracks;
- ecosystem grants;
- accelerator milestones;
- public bounty boards;
- AI-agent work competitions;
- reviewer-assisted builder programs.

## Agent Role

Agents should **screen and structure evidence**, not choose winners autonomously in the first version.

Recommended policy:

```text
Complete       → eligible for judge finalist review
NeedsReview    → visible to judges, flagged for manual review
Incomplete     → not eligible unless judge explicitly overrides
VerificationFailed → retry / resubmit / manual review path
```

Agents help reduce reviewer load, but judges/program operators make final winner decisions.

## Suggested Data Model

### Round

```solidity
struct Round {
    address sponsor;
    address judge;
    uint256 totalPool;
    uint256 prizeAmount;
    uint256 maxWinners;
    uint64 submissionDeadline;
    uint64 reviewDeadline;
    string requirementsURI;
    RoundState state;
}
```

### Application

```solidity
struct Application {
    uint256 roundId;
    address applicant;
    string evidenceURI;
    bytes32 evidenceHash;
    Verdict agentVerdict;
    uint256 requestId;
    bool finalist;
    bool claimed;
}
```

### RoundState

```solidity
enum RoundState {
    Unknown,
    Created,
    Funded,
    Open,
    Reviewing,
    FinalistsSelected,
    Settled,
    Cancelled
}
```

## Minimal Function Surface

```solidity
function createRound(
    address judge,
    uint256 prizeAmount,
    uint256 maxWinners,
    uint64 submissionDeadline,
    uint64 reviewDeadline,
    string calldata requirementsURI
) external returns (uint256 roundId);

function fundRound(uint256 roundId) external payable;

function submitApplication(
    uint256 roundId,
    string calldata evidenceURI,
    bytes32 evidenceHash
) external payable returns (uint256 applicationId);

function retryApplicationVerification(uint256 applicationId) external payable;

function selectFinalists(uint256 roundId, uint256[] calldata applicationIds) external;

function claimPrize(uint256 applicationId) external;

function refundUnallocated(uint256 roundId) external;
```

## Safety Rules

- Only the applicant can claim their own prize.
- Only the configured judge/sponsor can select finalists.
- `maxWinners` must be enforced.
- Total selected payout must never exceed the funded prize pool.
- Agent output must never directly transfer funds.
- Agent output should only determine eligibility/review status.
- `VerificationFailed` must not become an automatic rejection.
- Judges should be able to manually include or exclude submissions, depending on round policy.
- Unallocated funds should be recoverable after the round closes.

## Integration With Existing Vigilia Components

The grant module should reuse the same verification concepts:

```text
Application evidenceURI
→ Vigilia verifier/coordinator
→ bounded verdict
→ application verification state
→ judge finalist selection
→ prize claim
```

It can integrate with the v0.2 multi-agent direction:

```text
JSON API Agent → public structured facts
LLM Inference Agent → bounded eligibility verdict
LLM Parse Website Agent → optional future README/docs/demo extraction
```

## Recommended Build Order

Do **not** build this before the current v0.2 settlement path is stable.

Suggested roadmap:

```text
1. Finish v0.2.1 JSON API + LLM Inference settlement flow.
2. Document a stable evidence schema.
3. Add grant-round spec/tests.
4. Implement minimal GrantRound/BountyBoard contract.
5. Add frontend/demo flow for one round with several applicants.
6. Later add Data Streams records for round/applicant/finalist history.
```

## MVP Demo Example

```text
Round: Somnia Agentathon Mini-Grant
Prize: 100 STT each
Max winners: 3
Requirements:
- public GitHub repo
- README/setup docs
- deployed contract address
- demo transaction or video

Builders submit evidence.
Agents verify each submission.
Judges review Complete and NeedsReview submissions.
Judges select 3 finalists.
Finalists claim prizes.
```

## Product Positioning

This extension would make Vigilia stronger for real hackathon/grant operations:

```text
Vigilia is not only fixed-task escrow.
It can become an agent-assisted grant operations layer where programs fund rounds, agents screen public evidence, and judges select winners with a transparent on-chain audit trail.
```

## Status

This is a **future extension / product design note**. It is not implemented in the current deployed contracts.

Current deployed contracts remain:

```text
v0.1.0: JSON API Request escrow smoke flow
v0.2.0: multi-agent canary verifier foundation
```

