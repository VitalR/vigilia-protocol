# Vigilia GrantRound Runbook

## Purpose

`VigiliaGrantRound` helps sponsors run transparent grant and bounty rounds.

Builders submit public evidence. Somnia agents screen and summarize submissions. Judges select finalists from an agent-assisted review board. Selected finalists claim prizes on-chain.

This complements, but does not replace, the hardened v0.2.3 `VigiliaEscrow` path:

```text
Fixed work uses VigiliaEscrow.
Grant programs use VigiliaGrantRound.
Agents reduce review load.
Judges choose finalists.
Contracts enforce winner caps, reserved payouts, claims, and refunds.
```

## Architecture

The MVP contract is standalone and native-token-only:

```text
src/VigiliaGrantRound.sol
```

It has:

- no global owner;
- no external admin;
- round-scoped sponsor;
- round-scoped judge;
- equal prize amount per finalist;
- exact full-pool funding;
- pull-based prize claims;
- pull-based sponsor refunds;
- verifier callback compatibility through `IVigiliaEscrowVerdictReceiver`.

For verifier callbacks:

```text
taskId       = roundId
submissionId = applicationId
```

The verifier address is immutable. It can be zero for a deployment that relies on manual fallback while a fresh GrantRound verifier is not yet bound.

## Verifier Requirement

GrantRound should use a separate verifier deployment from the hardened v0.2.3 escrow/verifier pair.

Reason:

```text
VigiliaMultiAgentVerifier binds to one settlement receiver.
The hardened v0.2.3 verifier is part of the fixed-work escrow proof.
GrantRound is a different receiver with round/application IDs.
```

For GrantRound screening, deploy a fresh verifier instance and bind it to the GrantRound contract. Do not reuse:

```text
0xdE0aC9700E591b54A418665575f2e1d329D78f3D
```

That verifier belongs to:

```text
vigilia-two-agent-settlement-hardened
```

Manual fallback is still available if a GrantRound deployment uses `address(0)` as verifier, but that is a recovery mode, not the intended Somnia-powered hackathon path.

## Data Model

### Round

Each round stores sponsor, judge, prize amount, max winners, funded amount, selected/claimed accounting, deadlines, requirements URI, screening mode, and state.

The funding requirement is:

```text
prizeAmount * maxWinners
```

### Application

Each application stores round ID, applicant, evidence URI, evidence hash, active request ID, verdict, status, selected/claimed flags, timestamps, and notes URI.

One address can submit one application per round.

### ScreeningMode

```text
TwoAgent    JSON API facts -> LLM Inference bounded verdict
ThreeAgent  future JSON API + Website Parse + LLM Inference flow
```

Manual screening is not a round mode. It is a fallback/recovery function for sponsor or judge.

## Lifecycle

### createRound

Sponsor creates the round:

```solidity
createRound(
    judge,
    prizeAmount,
    maxWinners,
    applicationDeadline,
    reviewDeadline,
    requirementsURI,
    screeningMode
)
```

Rules:

- judge cannot be zero;
- prize amount must be nonzero;
- max winners must be nonzero;
- application deadline must be in the future;
- review deadline must be after application deadline;
- screening mode must be `TwoAgent` or `ThreeAgent`.

Use `TwoAgent` for live demo rounds unless Website Parse has a successful real-HTML proof.

### fundRound

Sponsor funds exactly:

```text
prizeAmount * maxWinners
```

The round moves from `Created` to `Open`.

Partial funding and repeated funding are intentionally not supported in this MVP.

### submitApplication

Applicants submit:

```solidity
submitApplication(roundId, evidenceURI, evidenceHash)
```

Rules:

- round must be `Open`;
- current time must be at or before the application deadline;
- evidence URI cannot be empty;
- evidence hash cannot be zero;
- duplicate applications by the same applicant are rejected.

### requestApplicationScreening

Applicant, sponsor, or judge may request Somnia-agent screening:

```solidity
requestApplicationScreening(applicationId)
```

The contract reads `round.screeningMode`.

For `TwoAgent`, it requests:

```text
JsonFactsToLlmVerdict
```

For `ThreeAgent`, the current implementation reverts with `UnsupportedScreeningMode` until a future verifier exposes a proven Website Parse workflow.

The request stores the active request ID and marks the application `ScreeningRequested`.

### recordVerdict

Only the configured verifier can call:

```solidity
recordVerdict(roundId, applicationId, requestId, verdict, notesURI)
```

Rules:

- unknown verdict reverts;
- round/application mismatch reverts;
- stale request IDs are ignored and emitted;
- no funds move;
- no finalist is selected.

Verdict mapping:

```text
Complete    -> Complete
NeedsReview -> NeedsReview
Incomplete  -> Incomplete
```

### recordVerificationFailure

Only the verifier can call:

```solidity
recordVerificationFailure(roundId, applicationId, requestId, failureNotesURI)
```

It marks the application `VerificationFailed` unless the callback is stale. This is a review/retry status, not permanent rejection.

### recordManualScreening

Sponsor or judge can call:

```solidity
recordManualScreening(applicationId, verdict, notesURI)
```

Use this as fallback, recovery, or judge override. It cannot move funds or select finalists.

### selectFinalists

Sponsor or judge selects finalists after the application deadline and before the review deadline:

```solidity
selectFinalists(roundId, applicationIds)
```

Eligible normal statuses:

```text
Submitted
ScreeningRequested
Complete
NeedsReview
VerificationFailed
```

`Incomplete` is not selectable in the normal path.

The contract enforces:

- only sponsor or judge;
- no selection before application deadline;
- no normal selection after review deadline;
- no missing applications;
- no applications from another round;
- no rejected applications;
- no duplicate selected application;
- no count beyond `maxWinners`;
- no selected allocation beyond funded pool.

### finalizeRound

Sponsor or judge finalizes after the application deadline:

```solidity
finalizeRound(roundId)
```

Claims become available after finalization. No more finalist selection is allowed.

### claimPrize / claimPrizeTo

Selected applicants claim exact equal prizes:

```solidity
claimPrize(applicationId)
claimPrizeTo(applicationId, recipient)
```

Rules:

- round must be finalized;
- caller must be the applicant;
- application must be selected;
- application cannot already be claimed;
- recipient cannot be zero.

The contract updates state before transfer.

### refundUnallocated

Sponsor can credit unallocated funds:

```solidity
refundUnallocated(roundId)
```

Refund amount:

```text
totalFunded - (selectedCount * prizeAmount) - totalRefunded
```

Selected-but-unclaimed prizes remain reserved.

Example:

```text
prizeAmount = 100 STT
maxWinners = 3
funded = 300 STT
selected = 2
unallocated refund = 100 STT
reserved for finalists = 200 STT
```

### withdrawPending / withdrawPendingTo

Sponsor pulls credited refunds:

```solidity
withdrawPending()
withdrawPendingTo(recipient)
```

Balances are cleared before transfer.

### cancelRound

Sponsor can cancel only when safe:

- `Created` and unfunded;
- `Open` with no applications.

Funded cancellation credits the sponsor through `pendingWithdrawals`. It does not push a direct refund.

## Demo Scenario

Round:

```text
Somnia Agentathon Mini-Grant
```

Prize:

```text
100 STT each
```

Max winners:

```text
3
```

Requirements:

```text
public GitHub repo
README/setup docs
deployed contract address
demo transaction or video
```

Recommended live demo mode:

```text
ScreeningMode.TwoAgent
```

Flow:

1. Sponsor creates the round with `TwoAgent`.
2. Sponsor funds `300 STT`.
3. Several builders submit evidence bundles.
4. Agents screen one `Complete`, one `NeedsReview`, and one `Incomplete`.
5. Manual fallback remains available if agent infrastructure fails.
6. Judge selects eligible finalists.
7. Judge finalizes.
8. Finalists claim.
9. Sponsor refunds unallocated funds.

## Composition With v0.2.3

Do not reuse the deployed hardened v0.2.3 verifier for GrantRound.

Canonical v0.2.3 remains:

```text
Deployment name: vigilia-two-agent-settlement-hardened
Chain: Somnia testnet, chain id 50312
Escrow: 0x1FA22E3a97dabB9a8C6de3a5B59eF6cCD5B2F4b9
Verifier: 0xdE0aC9700E591b54A418665575f2e1d329D78f3D
Workflow: JsonFactsToLlmVerdict
```

Future GrantRound deployment should use a fresh verifier instance bound to the GrantRound receiver.

## Validation

Run:

```bash
forge fmt
forge build
forge test
git diff --check
```

`make check` can be run if the Makefile target is present.

## Deploy / Dry Run

GrantRound deployment uses a fresh verifier bound to the GrantRound receiver:

```text
script/deploy/DeployVigiliaGrantRound.s.sol
```

Dry run:

```bash
make grant-round-deploy-dry-run
```

Broadcast:

```bash
make grant-round-deploy-somnia
```

Show artifact:

```bash
make grant-round-show-deployment
```

Query the deployed GrantRound verifier's two-agent workflow deposit:

```bash
VIGILIA_GRANT_ROUND_VERIFIER=<fresh verifier address> make grant-round-verifier-deposit
```

Required environment:

```text
DEPLOYER_PRIVATE_KEY
SOMNIA_RPC_URL
SOMNIA_CHAIN_ID
SOMNIA_AGENT_PLATFORM
SOMNIA_JSON_API_AGENT_ID
SOMNIA_LLM_INFERENCE_AGENT_ID
AGENT_SUBCOMMITTEE_SIZE
```

Optional pricing/env overrides:

```text
JSON_API_PRICE_PER_VALIDATOR_WEI
LLM_INFERENCE_PRICE_PER_VALIDATOR_WEI
LLM_PARSE_PRICE_PER_VALIDATOR_WEI
AGENT_PLATFORM_RESERVE_WEI
SOMNIA_LLM_PARSE_WEBSITE_AGENT_ID
SOMNIA_BLOCK_EXPLORER
SOMNIA_BLOCKSCOUT_API
```

## Current Limitations

- Native token only.
- Equal prizes only.
- Exact full-pool funding only.
- No application update function in this MVP.
- No explicit override path for selecting `Incomplete`.
- `ThreeAgent` is stored as a round mode but request-time gated until Website Parse workflow support exists.
- Deploy script exists for GrantRound plus a fresh two-agent verifier. No full demo action script is included yet.
