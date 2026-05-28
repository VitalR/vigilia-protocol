# 09 Verification Failure Recovery Flow

## Purpose

This document defines the product and protocol behavior for `VerificationFailed` in **Vigilia**, the agent-verified work settlement protocol on Somnia.

The goal is to make agent verification resilient without weakening escrow safety. A failed Somnia Agent request must not unfairly punish the contractor, unlock funds automatically, or leave the task permanently stuck.

This document should guide the next implementation pass before testnet deployment.

---

## Product Decision

`VerificationFailed` means:

> The verification infrastructure failed, not that the contractor failed.

Therefore, `VerificationFailed` must not automatically become `Incomplete`, and it must not directly unlock payout or refund.

The best product and hackathon-friendly recovery flow is:

```text
Agent request failed / timed out / malformed result
→ task enters VerificationFailed
→ contractor or client can retry verification
→ contractor can submit revised evidence
→ client can manually approve if work is clearly complete
→ either party can raise dispute
→ resolver can pay contractor / refund client / split
```

This gives Vigilia a mature safety story:

> Vigilia fails closed, but it does not trap funds. Failed agent verification opens a recovery path: retry, manual approval, or task-scoped dispute resolution.

---

## State Semantics

### `Incomplete`

`Incomplete` means:

```text
The verifier successfully checked the evidence and concluded the work is incomplete.
```

This is a **work-quality verdict**.

Examples:

- repository is missing required files;
- deployment address is absent;
- docs do not satisfy the milestone requirements;
- demo evidence does not match the task.

### `VerificationFailed`

`VerificationFailed` means:

```text
The verifier could not produce a reliable verdict.
```

This is an **infrastructure / verification failure**, not a work verdict.

Examples:

- Somnia Agent request failed;
- Somnia Agent request timed out;
- the evidence endpoint was unavailable;
- response was malformed;
- callback result could not be decoded;
- result string was not one of the supported bounded verdicts.

This distinction is important because:

```text
agent failure != contractor failure
```

---

## Recommended Action Table

| Current state | Who can act | Action | Result |
|---|---|---|---|
| `VerificationFailed` | Contractor | Retry same evidence verification | New Somnia request |
| `VerificationFailed` | Client | Retry same evidence verification | New Somnia request |
| `VerificationFailed` | Contractor | Submit revised evidence | New submission + new request |
| `VerificationFailed` | Client | Manually approve | `Approved` -> contractor can claim |
| `VerificationFailed` | Client or contractor | Raise dispute | `Disputed` |
| `Disputed` | Task resolver | Resolve full contractor payout | Contractor receives / claims funds |
| `Disputed` | Task resolver | Resolve full client refund | Client receives / withdraws funds |
| `Disputed` | Task resolver | Resolve split | Both receive / withdraw shares |

The protocol should **not** allow direct contractor claim from `VerificationFailed`.

The protocol should also **not** allow immediate unilateral client refund from `VerificationFailed`, because the contractor may have completed the work and only the verification infrastructure failed.

---

## Recommended Recovery Paths

### 1. Primary Recovery: Retry Agent Verification

Retrying verification should be the primary recovery path because it is the most Somnia-native and demo-friendly.

Example:

```text
Agent request timed out
→ task state = VerificationFailed
→ contractor clicks "Retry verification"
→ contractor pays a new verification deposit
→ Somnia Agent returns Complete
→ task = VerifiedComplete
→ client approves or review window expires
→ contractor claims
```

This proves that the protocol is resilient and does not break if a single agent request fails.

Recommended function shape:

```solidity
function retryVerification(uint256 _taskId) external payable;
```

Allowed when:

```text
task.state == VerificationFailed
task.activeSubmission exists
msg.sender == task.client || msg.sender == task.contractor
```

For MVP, keep retry authorization limited to the client or contractor. Later, the protocol can support sponsored retries by third parties.

Recommended behavior:

```text
retryVerification()
→ forwards msg.value as verification deposit
→ creates a new Somnia Agent request for the active submission
→ moves task back to Submitted, or keeps it VerificationFailed with pending request metadata
```

Implementation preference:

- If the state machine already uses `Submitted` to mean “waiting for verifier callback,” then retry should set the state back to `Submitted`.
- If the implementation tracks pending request metadata separately, it may keep a `VerificationFailed` state plus a pending request flag, but this is more complex.
- For MVP clarity, `VerificationFailed -> retryVerification() -> Submitted` is the cleaner approach.

---

### 2. Manual Fallback: Client Approval

Manual client approval is essential.

If the agent fails but the client can see that the work is complete, the client should be able to approve manually.

Flow:

```text
VerificationFailed
→ client manually approves
→ Approved
→ contractor claims
```

This is product-realistic because escrow platforms must support human acceptance even when automated verification is unavailable, inconclusive, or wrong.

Recommended `approveTask()` allowed states:

```text
Submitted
VerifiedComplete
NeedsReview
Incomplete
VerificationFailed
```

Reasoning:

- `Submitted`: client may approve before the verifier returns.
- `VerifiedComplete`: normal happy path.
- `NeedsReview`: verifier intentionally requested human review.
- `Incomplete`: client may accept partial work or override an agent mistake.
- `VerificationFailed`: human fallback when infrastructure failed.

The key safety rule:

```text
Only the client can manually approve.
```

The verifier must not manually approve work, and no global protocol owner should approve a task.

---

### 3. Contractor Resubmission

The contractor should be able to submit revised evidence after `VerificationFailed`.

Flow:

```text
VerificationFailed
→ contractor submits new evidence URI/hash
→ new submission ID
→ new Somnia Agent request
→ verifier returns bounded verdict
```

This is useful when the failure was caused by bad evidence formatting, a broken URL, a missing JSON field, or an unavailable demo link.

Recommended behavior:

```text
submitWork() should be allowed from VerificationFailed for the contractor.
```

This is separate from `retryVerification()`:

| Action | Use when |
|---|---|
| `retryVerification()` | Same evidence is likely valid; the agent/platform failed |
| `submitWork()` again | Evidence needs to be corrected or replaced |

---

### 4. Dispute Fallback

If verification fails and the client refuses to approve, the contractor needs a liveness path.

Flow:

```text
VerificationFailed
→ contractor raises dispute
→ resolver checks evidence manually
→ resolver pays contractor / refunds client / splits funds
```

This prevents funds from becoming permanently stuck.

For the MVP, the resolver should be:

```text
task-scoped, not global
```

Example resolver roles:

- grant program operator;
- hackathon administrator;
- mutually agreed reviewer;
- client-side organization representative;
- arbitration address for that task.

The resolver should be set at task creation and should not be a global protocol owner.

---

## Refund Policy

Refund behavior is delicate because `VerificationFailed` does not mean the contractor failed.

### Safe Refund Cases

Client cancellation/refund is generally safe before work is submitted:

```text
Created
Funded
```

Depending on the current implementation, refund may also be allowed after a successful `Incomplete` verdict if the policy intentionally treats `Incomplete` as a failed work verdict.

### Do Not Allow Immediate Refund from `VerificationFailed`

The protocol should not allow this flow:

```text
contractor submits work
→ agent infra times out
→ client immediately refunds themselves
```

That would be unfair to the contractor and weakens the product’s trust model.

Recommended behavior:

```text
VerificationFailed
→ retry / manual approve / dispute
```

If a future liveness escape is needed, add a delayed path:

```text
VerificationFailed + no retry/dispute for N days
→ client may request resolver/refund path
```

This is not needed for the hackathon MVP.

---

## Recommended State Transition Model

```text
Funded
  └─ submitWork()
      → Submitted
          ├─ agent Complete
          │   → VerifiedComplete
          │       ├─ client approve → Approved → claim
          │       └─ review window expires → claim
          │
          ├─ agent NeedsReview
          │   → NeedsReview
          │       ├─ client approve → Approved → claim
          │       ├─ contractor resubmit
          │       └─ dispute
          │
          ├─ agent Incomplete
          │   → Incomplete
          │       ├─ contractor resubmit
          │       ├─ client approve anyway → Approved → claim
          │       └─ dispute / cancellation policy
          │
          └─ agent failed / timeout / malformed
              → VerificationFailed
                  ├─ retry verification
                  ├─ contractor resubmit
                  ├─ client approve manually → Approved → claim
                  └─ dispute → resolver payout/refund/split
```

---

## Product-Friendly Final Behavior

The cleanest product behavior is:

```text
Agent success = bounded work verdict.
Agent failure = retryable verification failure.
Client approval = human fallback.
Task resolver = final liveness fallback.
No direct payout/refund from failed verification.
```

This creates a strong trust and safety story:

> Vigilia combines autonomous verification with safe human recovery. Agents accelerate settlement, but they do not trap funds or unfairly decide outcomes when infrastructure fails.

---

## Hackathon Demo Story

The final demo should show at least two paths.

### Happy Path

```text
Client funds task
→ contractor submits evidence JSON
→ Somnia JSON API Agent reads verdict = Complete
→ escrow records VerifiedComplete
→ client approves or review window expires
→ contractor claims
```

This demonstrates the core agent-verified settlement loop.

### Resilience Path

```text
Contractor submits broken/missing evidence endpoint
→ Somnia request fails or returns malformed result
→ escrow enters VerificationFailed
→ contractor retries with correct evidence endpoint
→ Somnia Agent returns Complete
→ settlement continues
```

This demonstrates that the protocol is resilient and product-safe.

Recommended demo messaging:

> Vigilia does not blindly trust agents. Successful agent results produce bounded verdicts. Failed agent requests fail closed into a retryable state with manual approval and dispute fallback.

---

## Implementation Guidance

### New State

Add:

```solidity
VerificationFailed
```

to `TaskState`.

### New Function: Record Verification Failure

Add a verifier-only function:

```solidity
function recordVerificationFailure(
    uint256 _taskId,
    uint256 _submissionId,
    string calldata _failureNotesURI
) external;
```

Rules:

- only configured verifier can call it;
- task must exist;
- task should normally be in `Submitted`;
- submission must be the active submission;
- set task state to `VerificationFailed`;
- do not mark the submission as `Complete`, `NeedsReview`, or `Incomplete`;
- emit a clear event.

Suggested event:

```solidity
event VerificationFailedRecorded(
    uint256 indexed taskId,
    uint256 indexed submissionId,
    string failureNotesURI
);
```

If the Somnia verifier has the agent request ID, include it either in a separate verifier event or in the escrow event if the escrow stores request IDs.

### New Function: Retry Verification

Add:

```solidity
function retryVerification(uint256 _taskId) external payable;
```

Rules:

- task must be `VerificationFailed`;
- caller must be client or contractor;
- active submission must exist;
- forwards `msg.value` as the verification deposit;
- creates a new verifier request for the active submission;
- should move task back to `Submitted` if the request is created successfully;
- emits an event.

Suggested event:

```solidity
event VerificationRetried(
    uint256 indexed taskId,
    uint256 indexed submissionId,
    bytes32 indexed requestId,
    address payer,
    uint256 verificationDeposit
);
```

### Update `submitWork`

Allow contractor resubmission from:

```text
Funded
Incomplete
NeedsReview
VerificationFailed
```

depending on current state policy.

At minimum, allow resubmission from:

```text
Incomplete
NeedsReview
VerificationFailed
```

### Update `approveTask`

Allow client approval from:

```text
Submitted
VerifiedComplete
NeedsReview
Incomplete
VerificationFailed
```

### Update `raiseDispute`

Allow dispute from:

```text
Submitted
VerifiedComplete
NeedsReview
Incomplete
VerificationFailed
```

or align with the existing disputable-state helper if it already includes the relevant states.

### Update `cancelTask`

Do **not** allow unilateral client cancellation/refund directly from `VerificationFailed`.

If funds need to be returned after `VerificationFailed`, use:

```text
dispute resolution
```

or a future mutual cancellation feature.

---

## Somnia Verifier Behavior

For `VigiliaJsonApiVerifier`:

| Somnia callback result | Escrow action |
|---|---|
| `Success` + `Complete` | `recordVerdict(..., Complete, ...)` |
| `Success` + `NeedsReview` | `recordVerdict(..., NeedsReview, ...)` |
| `Success` + `Incomplete` | `recordVerdict(..., Incomplete, ...)` |
| `Success` + malformed response | `recordVerificationFailure(...)` |
| `Success` + unknown verdict string | `recordVerificationFailure(...)` |
| `Failed` | `recordVerificationFailure(...)` |
| `TimedOut` | `recordVerificationFailure(...)` |

Do not synthesize `Incomplete` for platform failures. `Incomplete` is a work verdict, not an infrastructure verdict.

Prefer not to revert valid terminal callbacks after platform authorization and request checks. A known request with a terminal failed/malformed outcome should be marked fulfilled and should record `VerificationFailed`.

Reverts should remain for:

- unauthorized callback sender;
- unknown request;
- duplicate fulfilled request.

---

## Test Coverage Requirements

### Escrow Tests

Add tests for:

- verifier can record verification failure;
- non-verifier cannot record verification failure;
- verification failure blocks claim;
- contractor can retry verification after `VerificationFailed`;
- client can retry verification after `VerificationFailed`;
- non-client/non-contractor cannot retry verification;
- contractor can submit revised evidence after `VerificationFailed`;
- client can manually approve from `VerificationFailed`;
- contractor can claim after manual approval from `VerificationFailed`;
- client cannot directly cancel/refund from `VerificationFailed`;
- client can raise dispute from `VerificationFailed`;
- contractor can raise dispute from `VerificationFailed`;
- task-scoped resolver can resolve dispute after `VerificationFailed`;
- stale failure for an old submission reverts or is safely ignored according to implementation.

### Somnia Verifier Tests

Add tests for:

- `Failed` status records `VerificationFailed`;
- `TimedOut` status records `VerificationFailed`;
- malformed successful response records `VerificationFailed`;
- unknown verdict string records `VerificationFailed`;
- success with `Complete` still records `Complete`;
- success with `NeedsReview` still records `NeedsReview`;
- success with `Incomplete` still records `Incomplete`;
- callback from non-platform reverts;
- unknown request reverts;
- duplicate terminal callback reverts;
- exact verification deposit is required;
- underpayment reverts;
- overpayment reverts;
- escrow funds remain separate from verification deposit;
- request payer is tracked for rebate accounting if rebate handling is implemented.

---

## Product Copy

Useful copy for README, demo, or submission:

> `VerificationFailed` is a recovery state, not a work verdict. It means the agent request failed, timed out, or returned an unusable response. Vigilia does not punish the contractor for infrastructure failure and does not let the client refund unilaterally. Instead, the task can be retried, manually approved by the client, resubmitted by the contractor, or escalated to task-scoped dispute resolution.

Short version:

> Agent success creates a bounded work verdict. Agent failure creates a retryable recovery state.

---

## Implementation Priority

For the next pass, implement in this order:

1. Add `VerificationFailed` state and escrow transition.
2. Add `recordVerificationFailure`.
3. Add `retryVerification`.
4. Update manual approval states.
5. Update resubmission states.
6. Update dispute states.
7. Ensure direct claim/refund from `VerificationFailed` is blocked.
8. Update `VigiliaJsonApiVerifier` to call `recordVerificationFailure` for failed/timed-out/malformed outcomes.
9. Add tests.
10. Run:
   ```bash
   forge fmt
   forge build
   forge test
   git diff --check
   ```
