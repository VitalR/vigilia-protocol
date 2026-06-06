# Two-Agent Settlement Runbook

This runbook covers the Vigilia two-agent settlement path on Somnia testnet. The current hardened deployment is v0.2.3
(`deployments/somnia-testnet-50312-two-agent-settlement-hardened.json`). The proven v0.2.2 deployment remains available as
a historical artifact and must not be overwritten.

```text
JSON API facts -> LLM Inference bounded verdict -> escrow policy
```

This is not a canary-only flow. It is a fresh escrow + verifier deployment where settlement is driven by two Somnia
base-agent requests. The JSON API stage fetches objective facts from a public structured endpoint. The LLM Inference
stage compares those facts against the task requirements and returns one bounded verdict. The escrow contract enforces
claim policy and funds never move from an agent callback.

## Prior Proofs

| Track | Version | Artifact | Boundary |
|---|---|---|---|
| JSON API smoke | v0.1.0 | `deployments/somnia-testnet-50312.json` | JSON API Request -> callback -> bounded verifier result -> escrow verdict |
| Multi-agent canary | v0.2.0 | `deployments/somnia-testnet-50312-multi-agent-canary.json` | JSON API, LLM Inference, and Website Parse canaries; no escrow settlement |
| JSON-only settlement | v0.2.1 | `deployments/somnia-testnet-50312-multi-agent-settlement.json` | Fresh escrow settlement, but the settlement verdict still came from JSON API |
| Two-agent settlement | v0.2.2 | `deployments/somnia-testnet-50312-two-agent-settlement.json` | JSON API facts plus LLM Inference final verdict |
| Two-agent settlement hardened | v0.2.3 | `deployments/somnia-testnet-50312-two-agent-settlement-hardened.json` | v0.2.2 flow plus escrow timeout/claimTo, NeedsReview resubmission, pull cancel refunds, unused LLM budget refunds |

Do not overwrite historical artifacts. v0.2.3 deploys fresh instances.

## No-Overclaim Rule

Correct:

```text
v0.2.2 proves a real two-agent settlement flow: JSON API facts + LLM Inference bounded verdict + escrow policy.
```

Incorrect:

```text
Vigilia fully verifies GitHub, docs, and websites with all three agents.
```

LLM Parse Website remains disabled for settlement. Its canary reached a real platform callback but returned terminal
`Failed`, so it is not settlement-critical in this version.

## Evidence Schema

The public evidence URL must return JSON with a `facts` field.

Complete:

```json
{
  "facts": "repo_exists=true; readme_setup=true; deployment_address_present=true; demo_url_present=true; tests_passed=true"
}
```

Incomplete:

```json
{
  "facts": "repo_exists=true; readme_setup=true; deployment_address_present=false; demo_url_present=false; tests_passed=false"
}
```

NeedsReview:

```json
{
  "facts": "repo_exists=true; readme_setup=true; deployment_address_present=unclear; demo_url_present=true; tests_passed=unknown"
}
```

Malformed:

```json
{
  "status": "unknown"
}
```

The JSON API stage uses:

```text
fetchString(evidenceURI, "facts") returns (string)
```

The LLM stage uses:

```text
inferString(string prompt, string system, bool chainOfThought, string[] allowedValues) returns (string)
```

with `chainOfThought=false` and allowed values:

```text
Complete, NeedsReview, Incomplete
```

The final escrow verdict in `JsonFactsToLlmVerdict` mode comes only from the LLM Inference stage. JSON facts alone never
unlock claim.

## Claim Policy

Tasks support three pull-payment policies:

| Policy | Index | Complete behavior |
|---|---:|---|
| `ClientApprovalOnly` | `0` | Contractor cannot claim until the client approves |
| `ReviewWindowAutoClaim` | `1` | Client can approve early; contractor can claim after review window |
| `ImmediateAutoClaim` | `2` | Contractor can claim immediately after `VerifiedComplete` |

`NeedsReview`, `Incomplete`, and `VerificationFailed` never auto-enable claim.

## Deposit Math

Each Somnia request requires:

```text
platform.getRequestDeposit() + pricePerValidator * subcommitteeSize
```

Current defaults:

| Stage | Price per validator | Subcommittee | Expected minimum |
|---|---:|---:|---:|
| JSON API facts | `0.03 STT` | `3` | `0.12 STT` |
| LLM Inference verdict | `0.07 STT` | `3` | `0.24 STT` |
| Workflow total | | | `0.36 STT` |

The submit and retry scripts call `minimumRequestDepositForWorkflow(JsonFactsToLlmVerdict)` and only fall back to a
computed JSON+LLM value if local platform simulation cannot evaluate the getter.

## Deploy

Validate before broadcast:

```bash
forge fmt
forge build
forge test
git diff --check
make check
```

Dry run:

```bash
make multi-settlement-deploy-dry-run
```

Broadcast:

```bash
make multi-settlement-deploy-somnia
make multi-settlement-show-deployment
make multi-settlement-verifier-deposit
```

After deployment:

```bash
export VIGILIA_MULTI_AGENT_ESCROW=<new escrow>
export VIGILIA_MULTI_AGENT_SETTLEMENT_VERIFIER=<new verifier>
```

Verify wiring:

```bash
cast call "$VIGILIA_MULTI_AGENT_ESCROW" "verifier()(address)" --rpc-url "$SOMNIA_RPC_URL"
cast call "$VIGILIA_MULTI_AGENT_SETTLEMENT_VERIFIER" "escrow()(address)" --rpc-url "$SOMNIA_RPC_URL"
cast call "$VIGILIA_MULTI_AGENT_SETTLEMENT_VERIFIER" "minimumRequestDepositForWorkflow(uint8)(uint256)" 3 --rpc-url "$SOMNIA_RPC_URL"
```

## Demo Commands

### Real Data E2E Sanity Evidence

Use `demo/evidence/escrow-real/` when proving that the two-agent Escrow flow can
consume realistic public Vigilia evidence rather than hand-authored fixture
facts. Generate it with:

```bash
make build-real-evidence
```

The generated JSON separates raw applicant-style claims from validation-derived
facts. The Foundry builder validates:

- GitHub repo URL format;
- docs/proof URL format;
- live Escrow address format;
- `address.code.length != 0` for the deployed Escrow contract over the selected
  Somnia RPC.

It intentionally records HTTP reachability as `unknown` because the
Foundry-native script does not use FFI or an HTTP client. Publish the generated
JSON and optional HTML page to a public raw URL before using them in a live
Somnia agent request. Transaction success means the agent request was accepted;
the final `Complete` verdict depends on the quality and availability of the
public evidence.

Create an immediate-claim task for a compact live demo:

```bash
make multi-agent-demo-create-task-immediate-claim
export DEMO_TASK_ID=<task id>
make multi-agent-demo-fund-task
make multi-agent-demo-submit-facts-complete
```

Wait for the JSON API callback and then the LLM Inference callback. If the JSON callback emits
`LlmVerdictContinuationRequired`, continue with:

```bash
export DEMO_PARENT_REQUEST_ID=<json platform request id>
make multi-agent-demo-continue-llm-verification
```

Inspect and claim:

```bash
make multi-agent-demo-inspect-task
make multi-agent-demo-claim-task
make multi-agent-demo-inspect-task
```

Alternative policy flows:

```bash
make multi-agent-demo-create-task-client-approval
make multi-agent-demo-create-task
```

Non-happy path probes:

```bash
make multi-agent-demo-submit-facts-incomplete
make multi-agent-demo-submit-facts-needs-review
make multi-agent-demo-submit-facts-malformed
```

## Receipt Proof Checklist

Collect:

- create tx
- fund tx
- submit tx
- JSON callback tx
- LLM callback tx
- approve tx if policy requires approval
- claim tx
- task ID and submission ID
- JSON platform request ID
- LLM platform request ID
- JSON facts raw bytes and decoded facts
- LLM verdict raw bytes and decoded verdict
- escrow `VerdictRecorded`
- final task state

Useful RPC commands:

```bash
cast receipt <SUBMIT_TX> --rpc-url "$SOMNIA_RPC_URL"
cast receipt <JSON_CALLBACK_TX> --rpc-url "$SOMNIA_RPC_URL"
cast receipt <LLM_CALLBACK_TX> --rpc-url "$SOMNIA_RPC_URL"
cast tx <LLM_CALLBACK_TX> --rpc-url "$SOMNIA_RPC_URL"
cast logs --address "$VIGILIA_MULTI_AGENT_SETTLEMENT_VERIFIER" --from-block <FROM> --to-block <TO> --rpc-url "$SOMNIA_RPC_URL"
cast logs --address "$VIGILIA_MULTI_AGENT_ESCROW" --from-block <FROM> --to-block <TO> --rpc-url "$SOMNIA_RPC_URL"
```

Expected:

- submit tx targets the current settlement escrow (`VIGILIA_MULTI_AGENT_ESCROW`)
- callback txs target the Somnia Agent Platform
- verifier emits `JsonFactsReceived`
- verifier emits `LlmVerdictRequested`
- verifier emits `MultiAgentVerificationSucceeded` from the LLM request
- escrow emits `VerdictRecorded`
- task reaches `VerifiedComplete`, `NeedsReview`, `Incomplete`, or `VerificationFailed` according to the bounded result

If Shannon explorer address/search tabs disagree with RPC, use official RPC receipts and logs as canonical proof.

## Live Result (v0.2.3 hardened)

Live on Somnia testnet through official RPC on 2026-06-01. Full Makefile E2E tables:
[`docs/proofs/2026-06-01-two-agent-settlement-hardened-rpc-proof.md`](./proofs/2026-06-01-two-agent-settlement-hardened-rpc-proof.md).

| Field | Value |
|---|---|
| Escrow | `0x1FA22E3a97dabB9a8C6de3a5B59eF6cCD5B2F4b9` |
| Verifier | `0xdE0aC9700E591b54A418665575f2e1d329D78f3D` |
| Deployment artifact | `deployments/somnia-testnet-50312-two-agent-settlement-hardened.json` |
| Workflow deposit env | `TWO_AGENT_WORKFLOW_DEPOSIT_WEI=360000000000000000` |
| Blockscout verification | `Response: OK` for both contracts after indexer catch-up |

Makefile scenarios exercised:

| Case | Task | Targets | Final state |
|---|---:|---|---|
| Complete + ImmediateAutoClaim | `4` | `multi-agent-demo-create-task-immediate-claim`, fund, submit-complete, claim | `Claimed` |
| Malformed + recovery | `6` | immediate-claim create, fund, submit-malformed, submit-complete, claim | `Claimed` |
| NeedsReview + approval | `7` | create, fund, submit-needs-review, approve, claim | `Claimed` |

Operational notes:

- Set `TWO_AGENT_WORKFLOW_DEPOSIT_WEI`, not `AGENT_REQUEST_DEPOSIT_WEI`, for settlement submit/retry demos.
- `make multi-settlement-demo-submit-*` may log local simulation failure but still broadcast with `--skip-simulation`.
- Scripted `bindEscrow`, `approveTask`, and `claim` may need explicit `--gas-limit $(DEMO_GAS_LIMIT)` on Somnia; approve/claim
  Makefile targets now use `cast send` with the configured gas cap.

## Live Result (v0.2.2 historical)

| Field | Value |
|---|---|
| Escrow | `0x16F9B1e1e732DFeE1e2231E52b399e9d2344F568` |
| Verifier | `0x79d94c986c64C69fDea935a2Ee6c303Dae852AE2` |
| Deployment artifact | `deployments/somnia-testnet-50312-two-agent-settlement.json` |
| Enabled settlement agents | `json-api,llm-inference` |
| Disabled settlement agent | `llm-parse-website` |
| Workflow deposit | `360000000000000000 wei` |
| Claim policy used for happy path | `ImmediateAutoClaim` (`2`) |
| Blockscout verification | Submitted, but Blockscout returned `Address is not a smart-contract` for both new addresses while official RPC code/receipts showed live contracts |

Deployment transactions:

| Step | Tx | Block | Status |
|---|---|---:|---|
| Deploy verifier | `0xbfcd49ec825ab130e8059cd468b0614850bbdd028d6505bbc52be5d0b95b372e` | `397241733` | success |
| Deploy escrow | `0x84babe092f40ee217a2e1ba167471f3b3e1b8065b7fbb2d65d4b836371e78490` | `397241733` | success |
| Initial bind | `0x5bcc0e11aa5a2ae05553efe5049efc0fa631f5ec28c815d353a59b7673f3aa6b` | `397241733` | failed: low gas cap |
| Replacement bind | `0xfcd78e88fada0f964e858a4a808e5c15599a182acb20bcc3c3a23586d0405716` | `397242373` | success |

Happy path task 1:

| Step | Tx | Block | To |
|---|---|---:|---|
| Create task | `0x2ec214e2403ee9ab3a5f78495235555b4059435506eecafde0c8653f9d336f86` | `397242936` | escrow |
| Fund task | `0x8732826ec8bf3c3c532806263f0385db0aa1895837ff17cc828cd453cfbeef6e` | `397243290` | escrow |
| Submit facts evidence | `0x96008cdb73f9373024a173597864baaa2059d1e09be41ebca6c6acde7fca3449` | `397243710` | escrow |
| JSON callback / LLM request | `0x9885604845585700ebbdfbb1b419b48e050a0c731977de384e5ce034101d1c4a` | `397243725` | Somnia Agent Platform |
| LLM verdict callback | `0x730da5ef5571b8429ee902e96e5993477c63eb71f7404ed053222817f0599e69` | `397243732` | Somnia Agent Platform |
| Claim | `0x43677eb5be49e481294e0a1e64cf265b0b60222bd2b00899321df561b94fa13a` | `397244093` | escrow |

Happy path decoded facts:

```text
taskId: 1
submissionId: 1
JSON platformRequestId: 3608591 / 0x37100f
LLM platformRequestId: 3608598 / 0x371016
JSON facts: repo_exists=true; readme_setup=true; deployment_address_present=true; demo_url_present=true; tests_passed=true
LLM raw result bytes: 0x436f6d706c657465
LLM decoded result: Complete
Escrow notesURI: somnia-agent-request:3608598
State before claim: VerifiedComplete
Final state: Claimed
```

Non-happy path task 2:

| Step | Tx | Block | Result |
|---|---|---:|---|
| Create task | `0x1bed475e65f54a1ead0d8560307134d3be873cacb796a60317aa51acf5050002` | `397244354` | success |
| Fund task | `0xac7b11b701f323c63b4e5ecf3a12aed095e6c181a1bd256afb25e417753ba65f` | `397244464` | success |
| Submit incomplete facts | `0x5a74e62d020df45051b156d1668b92b230f8f868a853e1f6dab65e87caf6a4b9` | `397244650` | JSON request `3608878` |
| JSON callback / LLM request | `0xc35aaaa7f13fd79b5ef32a45494541beab4733f7d89a241901b6709e90781371` | `397244664` | LLM request `3608882` |
| LLM verdict callback | `0x24775942de67f82884b304703e2aaf39e4050e7cf05791d162aa7e8d1b3431f4` | `397244671` | `Incomplete` |

Non-happy path decoded result:

```text
taskId: 2
submissionId: 2
JSON platformRequestId: 3608878 / 0x37112e
LLM platformRequestId: 3608882 / 0x371132
LLM raw result bytes: 0x496e636f6d706c657465
LLM decoded result: Incomplete
Final task state: Incomplete
Claim check: eth_call claim(2) reverted with InvalidState(2, 6)
```

Additional edge-case proof, also from official RPC on 2026-06-01:

| Case | Task | Policy | Key txs | Final result |
|---|---:|---|---|---|
| NeedsReview/manual approval | `3` | `ReviewWindowAutoClaim` | submit `0xcaca53dabfe66dad9fb7607124faa0b0c20c560c7bc5b76e1b855e0c730ac2e6`; JSON callback `0xb6569a659b507e0cd38372c7878d6675a94b963f3c64717e6fbb4a939fcf983e`; LLM callback `0x31ea65802f23c6ade073c243e618b06395c3110ad5b527b474228cdac310854d`; approve `0x18d677ac55b2c8f3762a10206de91bef4b9e07ccb640cb402d800bf419f7a810`; claim `0x09fd63577307aa6ea40e11a3682ed96bc126661fd615ac4da7ab4e03ffc3ba29` | LLM returned `NeedsReview`; claim reverted before approval with `InvalidState(3, 5)`; final state `Claimed` |
| Malformed facts then recovery | `4` | `ImmediateAutoClaim` | malformed submit `0xbf6e8947a06b5a6fa30aab1ff35165c0402480da1d554c14858326c7b3646416`; failure callback `0x875f5822e3792dbe7376d1eaf8cfa6ef91bbfec5fbe4d79344b5693fe8c95b5c`; recovery submit `0xadb2a24b93ebb798470ab47c00b98329121b4bdf4b702494cece2462396174e7`; recovery LLM callback `0xdd358352a38f63c8d35406e3e8e65fbc08471183917c2834df67ad212d74c18f`; claim `0x0bd258b061c989fdf937987aa59463f5a1e69a55f3730de77bb0e03a98488a25` | Missing `facts` produced `VerificationFailed`; claim reverted with `InvalidState(4, 7)`; recovery LLM returned `Complete`; final state `Claimed` |
| ClientApprovalOnly complete | `5` | `ClientApprovalOnly` | submit `0x8a0c5fedb5e967ab08ca4319fa16dae63ec0863ed883970abf29446577178434`; JSON callback `0x3f7e8b9a79726d1c072636feb4958307c4d1b48cd409d03953349d93d237a26f`; LLM callback `0xd4ff494f31c20e9327939b248c8537711052c8667eb7c5ddd340bdfefb1ebbef`; approve `0xd9de4c9065af7d260266df3d40e8c2c814983d3fc667f3fd172598b63407e47c`; claim `0x6f1434f4a73c818e0d0ef2edaf341184e56aeeb123d16b1edd61d92d5c8d59ef` | LLM returned `Complete`; claim reverted before approval with `InvalidState(5, 4)`; final state `Claimed` |
| ReviewWindowAutoClaim complete | `6` | `ReviewWindowAutoClaim`, `60s` | submit `0xb09a20d50e878738c1a986b3e2da0dda5b13ce3c7a64f3876500a16e57afbece`; JSON callback `0x7cfd9a742ff70213b5f45678f87fee1f37330441329dac9702dc117f5785789d`; LLM callback `0x4943b0223d4d1c652be7c576a919b5a69557c815dc0045aa652af844b9120975`; claim `0x28ac936950578e8f97c9e6835de62f66001b96bc8070af24c0c1d82c09c9d01e` | LLM returned `Complete`; claim reverted before review window with `ReviewWindowActive`; final state `Claimed` |

Additional decoded request IDs and raw results are in
[`docs/proofs/2026-06-01-two-agent-settlement-rpc-proof.md`](./proofs/2026-06-01-two-agent-settlement-rpc-proof.md).

Implementation hardening after the live run:

- verifier string normalization now trims leading/trailing ASCII whitespace before matching bounded LLM verdicts;
- successful JSON callbacks with an empty `facts` string now fail closed instead of waiting on an impossible LLM
  continuation;
- the multi-settlement demo script decodes the `tasks()` tuple field-by-field, fixing a local script revert in
  fund/submit actions;
- these source/script changes have not been redeployed to the v0.2.2 live addresses.

## Final pre-redeploy hardening

Target release: **v0.2.3** deployed to Somnia testnet (`deployments/somnia-testnet-50312-two-agent-settlement-hardened.json`).

### Verification timeout liveness

- Each task stores `verificationTimeout` (default `7 days`, bounds `60 seconds` to `30 days`, overridable via
  `createTaskWithPolicyAndTimeout`).
- While a task remains in `Submitted`, either the client or contractor may call `markVerificationTimedOut(taskId)`
  once `block.timestamp > submittedAt + verificationTimeout`.
- Result: task moves to `VerificationFailed` and emits `VerificationTimedOut`.
- This does **not** release funds directly. Recovery paths match infrastructure failure: `retryVerification`,
  resubmit, client `approveTask`, or `raiseDispute`.

### Claim recipient hardening

- `claimTo(taskId, recipient)` lets the contractor choose a payout recipient; `claim(taskId)` delegates to
  `claimTo(taskId, msg.sender)`.
- `recipient == address(0)` reverts. Pull-based settlement is preserved.
- If the recipient cannot receive native tokens, the transaction reverts and escrow accounting stays intact until a
  valid recipient is supplied.

### Client refund hardening

- `cancelTask` now credits the client through `pendingWithdrawals` instead of pushing a direct transfer, matching
  dispute-resolution withdrawals. Clients call `withdrawPending()` or `withdrawPendingTo(recipient)` to pull refunds.

### Verifier refund hardening

- When a two-agent JSON facts stage fails before LLM starts, unused prepaid LLM budget is credited through
  `pendingVerificationRefunds`. The requester calls `withdrawVerificationRefund()` or
  `withdrawVerificationRefundTo(recipient)` to pull the credit.

### NeedsReview resubmission

- Contractors may resubmit from `NeedsReview`. A new submission replaces the active submission and invalidates stale
  verifier callbacks tied to the prior request ID.

### GrantRound / future receiver compatibility

- `VigiliaMultiAgentVerifier` forwards terminal results through `IVigiliaEscrowVerdictReceiver`, not concrete escrow
  logic. A future `GrantRound` contract can implement the same receiver interface and be bound once at deployment.
- Multi-receiver routing is intentionally **not** implemented in v0.2.3 to avoid destabilizing the proven two-agent
  flow.

### Escrow liveness and stuck-fund review

| State / path | Fund disposition | Liveness exits |
|---|---|---|
| `Created` / `Funded` cancel | Client `pendingWithdrawals` credit | `cancelTask` + `withdrawPending` |
| `Submitted` | Escrow held | Verifier callback, `markVerificationTimedOut`, dispute |
| `VerificationFailed` | Escrow held | `retryVerification`, resubmit, `approveTask`, dispute |
| `VerifiedComplete` | Escrow held until claim | Review-window auto-claim, client approval, dispute |
| `NeedsReview` | Escrow held | Resubmit, client approval, dispute |
| `Incomplete` | Escrow held | Resubmit, client cancel, dispute |
| `Approved` | Escrow held until claim | `claim` / `claimTo`, dispute |
| `Disputed` | Escrow held until resolution | Resolver split -> `pendingWithdrawals` + `withdrawPending` |
| `Claimed` / `Cancelled` / `Resolved` | Terminal | None required |

No terminal state traps escrow without at least one party action (`claimTo`, `withdrawPending`, or resolver allocation).

### Remaining production limitations

- Single bound settlement receiver per verifier instance (no dynamic multi-receiver registry yet).
- Native-token only; no ERC20 escrow in this MVP.
- Dispute resolution relies on a per-task resolver chosen at creation time.
- Verifier Blockscout verification for the v0.2.2 multi-agent verifier address may still require manual
  standard-json submission on Somnia testnet.

## Final Dashboard Demo Targets

The final fixed-work proof can be run through high-level Makefile wrappers
instead of direct `cast` commands. They pin the hardened v0.2.3 escrow/verifier,
5 STT task amount, and 0.36 STT TwoAgent workflow deposit by default, while
still accepting overrides such as `DEMO_TASK_ID=<id>`.

Read-only setup:

```bash
make final-demo-escrow-env
make final-demo-escrow-preflight
make final-demo-escrow-inspect-task
```

`final-demo-escrow-inspect-task` uses direct `cast call` reads for
`tasks(taskId)` and, when configured, `submissions(submissionId)`. Override the
submission read with `DEMO_SUBMISSION_ID=<id>` if the inspected task is not the
recorded final proof task.

Create, fund, submit, and claim:

```bash
make final-demo-escrow-create-task
export DEMO_TASK_ID=<task id>

make final-demo-escrow-fund-task DEMO_TASK_ID=$DEMO_TASK_ID
make final-demo-escrow-submit-complete DEMO_TASK_ID=$DEMO_TASK_ID

# Wait for JSON and LLM callbacks, then inspect.
make final-demo-escrow-inspect-task DEMO_TASK_ID=$DEMO_TASK_ID
make final-demo-escrow-claim-task DEMO_TASK_ID=$DEMO_TASK_ID
```

Key selection:

```text
client: CLIENT_PRIVATE_KEY, else SPONSOR_PRIVATE_KEY, else DEPLOYER_PRIVATE_KEY
contractor: CONTRACTOR_PRIVATE_KEY, else APPLICANT_ONE_PRIVATE_KEY
```

For dashboard demos, do not use `APPLICANT_PRIVATE_KEY` as contractor if it
equals the sponsor or deployer key. The final proof used separate client and
contractor accounts.

The already-recorded proof defaults to task `13`, amount `5 STT`, final state
`Claimed`.

## Retry Diagnostics

The failed `retryVerification(11)` proof now has Makefile diagnostics:

```bash
make escrow-retry-decode
make escrow-retry-inspect-task
make escrow-retry-simulate-zero
make escrow-retry-simulate-with-deposit
make escrow-retry-diagnose
```

`escrow-retry-simulate-zero` is expected to revert for the known failed path.
`escrow-retry-simulate-with-deposit` should succeed as an `eth_call` when task
state, caller, and evidence remain valid.

The optional broadcast helper is intentionally guarded:

```bash
make escrow-retry-with-deposit CONFIRM_BROADCAST=1
```

Use it only after confirming the task is still `VerificationFailed`, the caller
is the client or contractor, and the stored evidence URI is still valid.

Proof packages:

- [`docs/proofs/2026-06-01-two-agent-settlement-rpc-proof.md`](./proofs/2026-06-01-two-agent-settlement-rpc-proof.md)
- [`docs/proofs/2026-06-03-final-demo-scenarios.md`](./proofs/2026-06-03-final-demo-scenarios.md)
- [`docs/proofs/2026-06-03-escrow-retry-failure-investigation.md`](./proofs/2026-06-03-escrow-retry-failure-investigation.md)

The final demo proof records task `13`: separate client and contractor
accounts, 5 STT funded amount, TwoAgent `facts-complete.json` verification,
`VerifiedComplete`, and contractor claim. The retry investigation records a
failed `retryVerification(11)` transaction that sent `0` value. Direct
simulation confirmed the retry path requires the fresh `0.36 STT` workflow
deposit; this is a frontend transaction construction issue, not an escrow
accounting failure.
