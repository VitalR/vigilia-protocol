# Grant Round and Finalist Selection

## Purpose

`VigiliaGrantRound` extends Vigilia from fixed-work escrow into transparent grant, bounty, hackathon, and accelerator rounds.

The existing hardened v0.2.3 product claim remains unchanged:

```text
Vigilia proves a real two-agent settlement flow:
JSON API facts + LLM Inference bounded verdict + escrow policy.
```

GrantRound uses the same safety philosophy, but it solves a different product shape:

```text
many applicants
-> agent-assisted screening
-> sponsor/judge finalist selection
-> finalist prize claims
-> sponsor refund of unallocated funds
```

## Why GrantRound Is Separate From Escrow

`VigiliaEscrow` is intentionally task-scoped:

```text
one client
one contractor
one funded task
one active submission
one verifier verdict
one payout path
```

That model is right for fixed milestones and contractor settlement. It is not the right primitive for a grant round where many builders apply to one pool and only a subset become winners.

`VigiliaGrantRound` is round-scoped:

```text
one sponsor
one judge
one funded prize pool
many applicants
many applications
agent screening metadata per application
manual finalist selection
pull-based prize claims
pull-based sponsor refunds
```

Keeping the modules separate avoids overloading the hardened escrow state machine and preserves the final product claim around the proven v0.2.3 settlement path.

## Product Flow

1. Sponsor creates a round with prize amount, maximum winners, deadlines, requirements, and a per-round `screeningMode`.
2. Sponsor funds the exact full pool: `prizeAmount * maxWinners`.
3. Builders submit public evidence before the application deadline.
4. Somnia agents screen each application and store bounded metadata:
   - `Complete`
   - `NeedsReview`
   - `Incomplete`
   - `VerificationFailed`
5. Sponsor or judge reviews the agent-assisted board.
6. Sponsor or judge selects finalists after the application deadline.
7. Sponsor or judge finalizes the round.
8. Selected finalists claim exact equal prizes.
9. Sponsor refunds unallocated funds without touching selected-but-unclaimed prize reservations.

Agents reduce review load. Judges choose winners. The contract enforces winner caps, reservations, claims, and refunds.

## Screening Modes

GrantRound is not manual-only. Each round is configured for an agent-based screening mode.

```solidity
enum ScreeningMode {
    TwoAgent,
    ThreeAgent
}
```

### TwoAgent

Default live mode until Website Parse is proven reliable against real HTML.

```text
JSON API facts
-> LLM Inference bounded eligibility verdict
-> judge-selected finalists
-> finalist claims
```

This reuses the proven v0.2.3 architecture without reusing the deployed v0.2.3 verifier instance. A future GrantRound deployment should use a fresh verifier bound to the GrantRound receiver.

The hardened v0.2.3 verifier is already part of the fixed-work escrow proof and should not be reused for GrantRound. `VigiliaMultiAgentVerifier` binds to one receiver; GrantRound has a different receiver contract and interprets `taskId` as `roundId` and `submissionId` as `applicationId`.

### ThreeAgent

Preferred future mode after Website Parse succeeds reliably against real HTML.

```text
JSON API facts
-> Website Parse README/docs/demo extraction
-> LLM Inference bounded eligibility verdict and summary
-> judge-selected finalists
-> finalist claims
```

The current contract stores `ThreeAgent` at the round level, but request-time support should remain gated until the verifier exposes a proven `JsonFactsAndWebsiteToLlmVerdict` workflow. Do not claim this mode is live until there is a real Website Parse proof.

### Manual Fallback / Recovery

Manual screening is deliberately not a round mode.

Sponsor or judge can call `recordManualScreening` only as fallback, recovery, or judge override. It cannot transfer funds, select finalists, bypass `maxWinners`, or bypass finalization.

## State Machine

### RoundState

```text
None
Created     sponsor created the round, not funded
Open        sponsor funded the exact full pool, applications accepted
Review      finalist selection has started
Finalized   claims and unallocated refunds are available
Cancelled   safely cancelled before applications/finalists make cancellation unsafe
```

### ApplicationStatus

```text
None
Submitted
ScreeningRequested
Complete
NeedsReview
Incomplete
VerificationFailed
Selected
Rejected
Claimed
```

`VerificationFailed` is infrastructure failure, not applicant rejection. It remains reviewable.

## Selection Policy

Normal finalist selection can include:

```text
Submitted
ScreeningRequested
Complete
NeedsReview
VerificationFailed
```

Normal finalist selection cannot include:

```text
Incomplete
Rejected
Selected
Claimed
Missing application
Application from another round
```

There is no automatic winner selection from an agent verdict. A `Complete` result is only screening metadata.

## Safety Invariants

- No global owner or admin can move funds.
- Sponsor and judge authority is scoped to a round.
- Agent callbacks never transfer funds.
- Agent callbacks never select winners.
- Unknown verdicts fail closed.
- Stale callbacks are ignored and emitted.
- Exact full-pool funding is required for MVP.
- Selected allocation is always `selectedCount * prizeAmount`.
- Sponsor refunds only unallocated funds.
- Selected-but-unclaimed prizes remain reserved.
- Applicants claim with pull payments.
- Sponsor refunds use pull withdrawals.
- Double selection and double claim are blocked.

## MVP Scope

Implemented now:

- native-token-only prize pool;
- exact full-pool funding;
- one application per address per round;
- two-agent workflow request path;
- `ThreeAgent` round configuration with request-time gate until verifier support exists;
- verifier receiver compatibility;
- manual screening fallback;
- judge/sponsor finalist selection;
- finalist claims;
- unallocated sponsor refunds;
- safe cancellation before applications make cancellation unsafe.

Future work:

- fresh GrantRound-bound multi-agent verifier deployment;
- proven Website Parse workflow before making `ThreeAgent` the live default;
- frontend review board;
- Data Streams publisher for round/application/finalist history;
- optional tiered prizes;
- optional application evidence updates;
- optional explicit override path for selecting `Incomplete` applications.
