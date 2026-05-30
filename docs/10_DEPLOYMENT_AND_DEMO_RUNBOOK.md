# Deployment And Demo Runbook

This runbook covers the first narrow Somnia testnet deployment for Vigilia Protocol.

This is the JSON API smoke deployment:

```json
{
  "deploymentName": "vigilia-json-api-smoke",
  "version": "v0.1.0",
  "activeAgentType": "json-api-request"
}
```

It proves the live Somnia `createRequest` and callback path. It is not the final multi-agent verifier deployment.

## A. Environment Loading

```bash
set -a
source .env
set +a
```

Never commit `.env`. Use `.env.example` as the public template.

## B. Deployer Address

```bash
export DEPLOYER_ADDRESS=$(cast wallet address --private-key "$DEPLOYER_PRIVATE_KEY")
```

## C. Manual Network Checks

```bash
cast balance "$DEPLOYER_ADDRESS" --rpc-url "$SOMNIA_RPC_URL" --ether
cast code "$SOMNIA_AGENT_PLATFORM" --rpc-url "$SOMNIA_RPC_URL"
cast call "$SOMNIA_AGENT_PLATFORM" "getRequestDeposit()(uint256)" --rpc-url "$SOMNIA_RPC_URL"
```

`SOMNIA_AGENT_PLATFORM` must be the platform contract address, not the Agent Explorer URL.

## D. Makefile Helpers

```bash
make env-check
make account
make balance
make platform-check
make deploy-somnia-dry-run
make deploy-somnia
make show-deployment
```

The dry-run target suppresses deployment artifact writes. The broadcast target writes `deployments/somnia-testnet-50312.json`.
Both deployment targets use `GAS_ESTIMATE_MULTIPLIER`, defaulting to `2000`, because Somnia testnet
contract-creation gas can be materially higher than local Foundry estimates.
Foundry compiles with `evm_version = "paris"` for Somnia deployment compatibility. This keeps Solidity `0.8.34` while avoiding `PUSH0` bytecode on networks that have not enabled the Shanghai opcode set.

## E. First Live Demo Flow

1. Create a task.
2. Fund the task with STT.
3. Submit evidence JSON with the exact verification deposit.
4. Wait for the Somnia callback.
5. Confirm `VerifiedComplete` or `VerificationFailed`.
6. Client approves, or the contractor waits through the review window if the task is `VerifiedComplete`.
7. Contractor claims.

## F. Evidence Endpoint Format

For the first demo, the public JSON endpoint should return exact bounded strings:

```json
{"verdict":"Complete"}
```

Also supported:

```json
{"verdict":"NeedsReview"}
{"verdict":"Incomplete"}
```

The current `VigiliaJsonApiVerifier` uses Somnia JSON API Request with `fetchString(url, "verdict")`.

## G. One Active Agent

The first deployment uses one active agent: JSON API Request. This keeps the live demo deterministic and auditable for milestone-style verdicts.

LLM Parse Website and LLM Inference agent IDs are kept in `.env.example` as named references for the roadmap. The current smart contract does not support those base-agent payloads by switching IDs alone. Multi-agent verification is future work. The deployment JSON records `deploymentName`, `version`, `activeAgentType`, and `activeAgentId` so reviewers can see exactly which verifier configuration is live.

The intended deployment story is:

- `v0.1.0` / `vigilia-json-api-smoke`: proves live Somnia callback plumbing and escrow settlement.
- `v0.2.0` / `vigilia-multi-agent-demo`: adds a real multi-agent verifier/coordinator for final demo verification.

## H. Verification Commands

Use the Make targets after exporting deployed addresses:

```bash
export VIGILIA_ESCROW=<deployed escrow>
export VIGILIA_JSON_API_VERIFIER=<deployed JSON API verifier>

make verify-somnia-json-verifier
make verify-somnia-escrow
```

Raw verifier command:

```bash
DEPLOYER_ADDRESS=$(cast wallet address --private-key "$DEPLOYER_PRIVATE_KEY")
VERIFIER_ARGS=$(cast abi-encode \
  "constructor(address,address,uint256,uint256,uint256,string)" \
  "$SOMNIA_AGENT_PLATFORM" \
  "$DEPLOYER_ADDRESS" \
  "$SOMNIA_AGENT_ID" \
  "$AGENT_SUBCOMMITTEE_SIZE" \
  "$AGENT_PRICE_PER_VALIDATOR" \
  "$SOMNIA_VERDICT_SELECTOR")

forge verify-contract "$VIGILIA_JSON_API_VERIFIER" \
  src/VigiliaJsonApiVerifier.sol:VigiliaJsonApiVerifier \
  --chain-id "$SOMNIA_CHAIN_ID" \
  --verifier blockscout \
  --verifier-url "$SOMNIA_BLOCKSCOUT_API" \
  --constructor-args "$VERIFIER_ARGS"
```

Raw escrow command:

```bash
ESCROW_ARGS=$(cast abi-encode "constructor(address)" "$VIGILIA_JSON_API_VERIFIER")

forge verify-contract "$VIGILIA_ESCROW" \
  src/VigiliaEscrow.sol:VigiliaEscrow \
  --chain-id "$SOMNIA_CHAIN_ID" \
  --verifier blockscout \
  --verifier-url "$SOMNIA_BLOCKSCOUT_API" \
  --constructor-args "$ESCROW_ARGS"
```

## Deployment Command

```bash
make deploy-somnia
```

Equivalent raw command:

```bash
forge script script/DeployVigiliaSystem.s.sol:DeployVigiliaSystem \
  --rpc-url "$SOMNIA_RPC_URL" \
  --gas-estimate-multiplier 2000 \
  --broadcast \
  -vvvv
```

## v0.1.0 JSON API Smoke Lifecycle

The live v0.1.0 deployment is a JSON API smoke deployment, not final multi-agent verification.

```text
Deployment name: vigilia-json-api-smoke
Version: v0.1.0
Escrow: 0x8bb7a1DF033FfcAFa376dbC930Df31f215f0403a
JSON API verifier: 0x880154CCa9C3fddA472250B16a1DF8118E3c0960
Active agent type: json-api-request
```

The current verifier uses the Somnia JSON API Request base agent and extracts `SOMNIA_VERDICT_SELECTOR=verdict` from a
public JSON endpoint. It does not support LLM Inference or LLM Parse Website by switching `SOMNIA_AGENT_ID`; those
require a v0.2.0 verifier/coordinator with the correct payloads and result handling.

### Evidence Hosting

Local examples live under `demo/evidence/`:

```text
demo/evidence/complete.json
demo/evidence/needs-review.json
demo/evidence/incomplete.json
demo/evidence/malformed.json
```

For live Somnia tests, host the selected JSON from a public URL, such as a GitHub raw URL, Vercel static file, or another
public static host. The first smoke test should use:

```json
{"verdict":"Complete"}
```

Then set:

```bash
export VIGILIA_EVIDENCE_JSON_URL=<public complete.json URL>
```

### Demo Script

All live smoke actions use one configurable script:

```bash
DEMO_ACTION=inspect forge script script/demo/VigiliaJsonApiSmokeDemo.s.sol:VigiliaJsonApiSmokeDemo \
  --rpc-url "$SOMNIA_RPC_URL" \
  --broadcast \
  -vvvv
```

`submit` and `retry` Make targets add `--skip-simulation` and use `AGENT_REQUEST_DEPOSIT_WEI`. This avoids a local
Foundry simulation mismatch against Somnia platform bytecode while still broadcasting the real transaction to Somnia.

Supported `DEMO_ACTION` values:

```text
create
fund
submit
inspect
approve
claim
retry
deposit
```

Role-specific keys are optional. If `CLIENT_PRIVATE_KEY`, `CONTRACTOR_PRIVATE_KEY`, or `RESOLVER_PRIVATE_KEY` are not
set, the script falls back to `DEPLOYER_PRIVATE_KEY` for single-wallet smoke testing. Real usage should use separate
accounts.

### Makefile Flow

Preflight:

```bash
make env-check
make account
make balance
make platform-check
make deployment-addresses
make verifier-deposit
```

`make verifier-deposit` uses a direct RPC `cast call` and should return `120000000000000000` for the current v0.1.0
deployment. Keep `AGENT_REQUEST_DEPOSIT_WEI` aligned with that value before submit or retry.

Create and fund:

```bash
make demo-create-task

# Set DEMO_TASK_ID from the script output.
export DEMO_TASK_ID=<task id>

make demo-fund-task
```

Submit evidence and wait for the async Somnia callback:

```bash
export VIGILIA_EVIDENCE_JSON_URL=<public complete.json URL>
make demo-submit-complete

# The Somnia callback is asynchronous. Wait for finalization, then inspect.
make demo-inspect-task
```

Settle:

```bash
make demo-approve-task
make demo-claim-task
```

If the task reaches `VerifiedComplete`, the contractor can also claim after the configured review window without manual
approval. `DEMO_REVIEW_WINDOW=300` is a practical live-demo value.

### VerificationFailed Flow

To intentionally trigger `VerificationFailed`, submit an endpoint that does not expose `verdict`, for example:

```json
{"status":"unknown"}
```

Flow:

```bash
export VIGILIA_EVIDENCE_JSON_URL=<public malformed.json URL>
make demo-submit-malformed

# Wait for Somnia callback, then inspect. Expected state: VerificationFailed.
make demo-inspect-task
```

Recovery has two paths:

```bash
# If the same public URL can be updated in place to return {"verdict":"Complete"},
# retry the active submission.
make demo-retry-verification

# If the malformed URL is immutable, set a new complete endpoint and submit revised evidence instead.
export VIGILIA_EVIDENCE_JSON_URL=<public complete.json URL>
make demo-submit-complete
```

`retryVerification` uses the active submission's stored evidence URI. It does not read a new
`VIGILIA_EVIDENCE_JSON_URL`, because the deployed v0.1.0 contract intentionally keeps retry scoped to the same
submission. This is useful for transient agent/API failures and mutable static URLs; revised immutable evidence should
use `submitWork`.

## Live RPC Receipt Proof - 2026-05-30/31

This is the strongest v0.1.0 evidence collected before moving to v0.2.0 multi-agent work. The source of truth is the
official Somnia testnet RPC:

```text
https://api.infra.testnet.somnia.network/
```

Shannon explorer direct transaction pages may return HTML for these hashes, but explorer search and address tabs can be
incomplete or stale. Treat explorer visibility as an indexer/search issue. RPC receipts and logs are canonical for this
proof package.

### Deployment Under Test

| Field | Value |
|---|---|
| Chain ID | `50312` |
| Escrow | `0x8bb7a1DF033FfcAFa376dbC930Df31f215f0403a` |
| JSON API verifier | `0x880154CCa9C3fddA472250B16a1DF8118E3c0960` |
| Somnia Agent Platform | `0x037Bb9C718F3f7fe5eCBDB0b600D607b52706776` |
| JSON API Agent ID | `13174292974160097713` |
| minimumRequestDeposit | `120000000000000000` wei / `0.12 STT` |
| Active agent type | `json-api-request` |
| Selector | `verdict` |

The deposit model was confirmed from live RPC reads:

```text
platform.getRequestDeposit() = 30000000000000000
pricePerValidator = 30000000000000000
subcommitteeSize = 3
minimumRequestDeposit() = 30000000000000000 + (30000000000000000 * 3)
minimumRequestDeposit() = 120000000000000000
```

### Happy Path Task 4

The evidence endpoint returned exactly:

```json
{"verdict":"Complete"}
```

Evidence URL:

```text
https://httpbin.org/base64/eyJ2ZXJkaWN0IjoiQ29tcGxldGUifQ==
```

| Step | Tx / Value | Block | `to` |
|---|---:|---:|---|
| Submit task `4`, submission `5` | `0x17d5b7b93344729b362009806ea8df3bc4114b92c3c76c9b04fe525431e18868` | `396389317` | `0x8bb7a1DF033FfcAFa376dbC930Df31f215f0403a` |
| Platform callback | `0xef1e7d7abdcba02982d46f78b030a573f72e2ac10614d86ce811104071cb7250` | `396389330` | `0x037Bb9C718F3f7fe5eCBDB0b600D607b52706776` |
| Platform request ID | `3347816` / `0x331568` | | |
| Raw result bytes | `0x436f6d706c657465` | | |
| Decoded result | `Complete` | | |
| Escrow notes URI | `somnia-agent-request:3347816` | | |
| State before approval | `VerifiedComplete` | | |
| Final state after approval/claim | `Claimed` | | |

Decoded event facts from the submit/callback block range:

```text
SomniaVerificationRequested
  platformRequestId: 3347816
  vigiliaRequestId: 0x0000000000000000000000000000000000000000000000000000000000331568
  taskId: 4
  submissionId: 5
  agentId: 13174292974160097713
  deposit: 120000000000000000
  evidenceURI: https://httpbin.org/base64/eyJ2ZXJkaWN0IjoiQ29tcGxldGUifQ==

WorkSubmitted
  taskId: 4
  submissionId: 5
  submitter: 0x8998a83a6192dD5500EEbb666cad0bC2Ab0258E7
  requestId: 0x0000000000000000000000000000000000000000000000000000000000331568

SomniaVerificationSucceeded
  platformRequestId: 3347816
  taskId: 4
  submissionId: 5
  verdict: Complete
  rawResult: Complete
  rawResultBytes: 0x436f6d706c657465

VerdictRecorded
  taskId: 4
  submissionId: 5
  verdict: Complete
  requestId: 0x0000000000000000000000000000000000000000000000000000000000331568
  notesURI: somnia-agent-request:3347816
```

The callback receipt proves the async callback transaction was sent to the Somnia Agent Platform, not directly to the
verifier or escrow:

```text
callback tx to: 0x037Bb9C718F3f7fe5eCBDB0b600D607b52706776
logs include: verifier 0x880154CCa9C3fddA472250B16a1DF8118E3c0960
logs include: escrow   0x8bb7a1DF033FfcAFa376dbC930Df31f215f0403a
```

This is expected: the platform callback transaction invokes the verifier callback, and the verifier then calls escrow.
Verifier and escrow events appear inside the platform callback receipt because they are emitted during that transaction.

### Malformed And Recovery Path Task 5

The malformed evidence endpoint returned exactly:

```json
{"status":"unknown"}
```

Malformed URL:

```text
https://httpbin.org/base64/eyJzdGF0dXMiOiJ1bmtub3duIn0=
```

| Step | Tx / Value | State / Notes |
|---|---|---|
| Create task `5` | `0xf2c913cfb8b3d85e303af84f87e51518aab008ac3355be962d7477841edc2ad2` | Created |
| Fund task `5` | `0xb8b691ff298471e2fe10a706f10d2d6cbb343974850823a1e14b4cdbff225d0c` | Funded |
| Malformed submit | `0x3222fd6ae549de12b77e6a00ee01ef8511bddce85b9ccc2cfec5b7166e69a5fc` | submission `6` |
| Failure callback | `0xa27ca4358d57f535ec45478947d2657f28d0105114b5ed615c38060bcf6262a3` | callback `to` platform |
| Malformed platform request ID | `3348512` / `0x331820` | `VerificationFailed` |
| Recovery submit | `0x15f5920d34f3c5c105dd7e82fa10087ca4e9dc92ed66f2ef4358c2cd4bcaaa34` | submission `7` |
| Recovery callback | `0xbdde8b601417197c981353f3d23102e2e9eb1b3eca5726bf63d6ec6acc3d2e8c` | callback `to` platform |
| Recovery platform request ID | `3348654` / `0x3318ae` | `VerifiedComplete` |
| Recovery raw result | `Complete` / `0x436f6d706c657465` | decoded bounded result |
| Approve recovered | `0xaf24be4cc38b7e1c0098cb3d36645c62d520be7dce7f4930dd483dd86edc5dd7` | Approved |
| Claim recovered | `0x2e330358b9a3b2619ff0808fc9690d907ebd678ccaa0b2192ec9246b01333704` | Claimed |

Decoded failure facts:

```text
SomniaVerificationFailed
  platformRequestId: 3348512
  taskId: 5
  submissionId: 6
  status: Failed
  failureNotesURI: somnia-agent-request:3348512

VerificationFailedRecorded
  taskId: 5
  submissionId: 6
  requestId: 0x0000000000000000000000000000000000000000000000000000000000331820
  failureNotesURI: somnia-agent-request:3348512

Task state after malformed callback: VerificationFailed
```

Decoded recovery facts:

```text
SomniaVerificationSucceeded
  platformRequestId: 3348654
  taskId: 5
  submissionId: 7
  verdict: Complete
  rawResult: Complete
  rawResultBytes: 0x436f6d706c657465

VerdictRecorded
  taskId: 5
  submissionId: 7
  verdict: Complete
  requestId: 0x00000000000000000000000000000000000000000000000000000000003318ae
  notesURI: somnia-agent-request:3348654

Task state after recovery callback: VerifiedComplete
Final task state after approval/claim: Claimed
```

### Reproduction Commands

Use the official RPC for proof collection:

```bash
export SOMNIA_RPC_URL=https://api.infra.testnet.somnia.network/

cast chain-id --rpc-url "$SOMNIA_RPC_URL"

cast receipt 0x17d5b7b93344729b362009806ea8df3bc4114b92c3c76c9b04fe525431e18868 \
  --rpc-url "$SOMNIA_RPC_URL"

cast receipt 0xef1e7d7abdcba02982d46f78b030a573f72e2ac10614d86ce811104071cb7250 \
  --rpc-url "$SOMNIA_RPC_URL"

cast tx 0xef1e7d7abdcba02982d46f78b030a573f72e2ac10614d86ce811104071cb7250 \
  --rpc-url "$SOMNIA_RPC_URL"

cast block 396389330 --rpc-url "$SOMNIA_RPC_URL"

curl -sS "$SOMNIA_RPC_URL" \
  -H 'content-type: application/json' \
  --data '{"jsonrpc":"2.0","id":1,"method":"eth_getTransactionReceipt","params":["0xef1e7d7abdcba02982d46f78b030a573f72e2ac10614d86ce811104071cb7250"]}'

cast logs \
  --address 0x880154CCa9C3fddA472250B16a1DF8118E3c0960 \
  --from-block 396389307 \
  --to-block 396389340 \
  --rpc-url "$SOMNIA_RPC_URL"

cast logs \
  --address 0x8bb7a1DF033FfcAFa376dbC930Df31f215f0403a \
  --from-block 396389307 \
  --to-block 396389340 \
  --rpc-url "$SOMNIA_RPC_URL"
```

Equivalent malformed/recovery proof commands:

```bash
cast receipt 0x3222fd6ae549de12b77e6a00ee01ef8511bddce85b9ccc2cfec5b7166e69a5fc \
  --rpc-url "$SOMNIA_RPC_URL"

cast receipt 0xa27ca4358d57f535ec45478947d2657f28d0105114b5ed615c38060bcf6262a3 \
  --rpc-url "$SOMNIA_RPC_URL"

cast receipt 0xbdde8b601417197c981353f3d23102e2e9eb1b3eca5726bf63d6ec6acc3d2e8c \
  --rpc-url "$SOMNIA_RPC_URL"

cast logs \
  --address 0x880154CCa9C3fddA472250B16a1DF8118E3c0960 \
  --from-block 396391519 \
  --to-block 396392022 \
  --rpc-url "$SOMNIA_RPC_URL"

cast logs \
  --address 0x8bb7a1DF033FfcAFa376dbC930Df31f215f0403a \
  --from-block 396391519 \
  --to-block 396392022 \
  --rpc-url "$SOMNIA_RPC_URL"
```

### Gas And Tooling Notes

`make demo-create-task` had an earlier type-2/lower-gas failure:

```text
0x40027ce3f109c1644fbb10854414e6ca51889507764b5a1e9d7d8df63fad322c
```

The live task 4/5 transactions used legacy transactions with explicit high gas limits. Keep `DEMO_GAS_LIMIT=10000000`
documented as the practical workaround for the demo script targets, and use `--gas-limit 15000000 --legacy` for direct
`submitWork` smoke transactions when needed.

### Proof Boundary

This proof establishes:

```text
live Somnia JSON API Request -> platform callback -> verifier bounded result -> escrow verdict recording
```

It does not claim GitHub repository verification, docs parsing, deployment inspection, LLM inference, or multi-agent
verification. Those belong to v0.2.0+ and require separate verifier/coordinator logic and separate live receipts.

## Live Smoke Result - 2026-05-30

### Environment

- Chain: Somnia testnet `50312`
- Deployment: `vigilia-json-api-smoke` `v0.1.0`
- Escrow: `0x8bb7a1DF033FfcAFa376dbC930Df31f215f0403a`
- JSON API verifier: `0x880154CCa9C3fddA472250B16a1DF8118E3c0960`
- Agent ID: `13174292974160097713`
- Active agent type: `json-api-request`
- minimumRequestDeposit: `120000000000000000` wei
- Complete evidence URL: `https://httpbin.org/base64/eyJ2ZXJkaWN0IjoiQ29tcGxldGUifQ==`
- Malformed evidence URL: `https://httpbin.org/base64/eyJzdGF0dXMiOiJ1bmtub3duIn0=`

### Commands Run

```bash
git status --short
git log --oneline -5
find . -maxdepth 3 -type f
forge fmt --check
forge build
forge test
git diff --check
make check
make env-check
make account
make balance
make platform-check
make deployment-addresses
make verifier-deposit
make evidence-url
curl -sS -i https://raw.githubusercontent.com/VitalR/vigilia-protocol/main/demo/evidence/complete.json
curl -sS -i https://httpbin.org/base64/eyJ2ZXJkaWN0IjoiQ29tcGxldGUifQ==
curl -sS -i https://httpbin.org/base64/eyJzdGF0dXMiOiJ1bmtub3duIn0=
cast call 0x880154CCa9C3fddA472250B16a1DF8118E3c0960 "escrow()(address)" --rpc-url https://api.infra.testnet.somnia.network/
cast call 0x8bb7a1DF033FfcAFa376dbC930Df31f215f0403a "verifier()(address)" --rpc-url https://api.infra.testnet.somnia.network/
cast call 0x880154CCa9C3fddA472250B16a1DF8118E3c0960 "agentId()(uint256)" --rpc-url https://api.infra.testnet.somnia.network/
cast send 0x8bb7a1DF033FfcAFa376dbC930Df31f215f0403a "createTask(address,address,uint256,uint64,string)" ... --gas-limit 10000000 --legacy
cast send 0x8bb7a1DF033FfcAFa376dbC930Df31f215f0403a "fundTask(uint256)" ... --gas-limit 10000000 --legacy
cast send 0x8bb7a1DF033FfcAFa376dbC930Df31f215f0403a "submitWork(uint256,string,bytes32)" ... --gas-limit 15000000 --legacy
cast send 0x8bb7a1DF033FfcAFa376dbC930Df31f215f0403a "approveTask(uint256)" ... --gas-limit 10000000 --legacy
cast send 0x8bb7a1DF033FfcAFa376dbC930Df31f215f0403a "claim(uint256)" ... --gas-limit 10000000 --legacy
make verify-somnia-json-verifier
make verify-somnia-escrow
```

### Happy Path Result

- Task ID: `1`
- Submission ID: `1`
- Create tx: `0xffcdccebd99a4c12f4e1e3e7b243ba4d4cbc6c619424796e7611681d56c99769`
- Fund tx: `0xe5f9ed78c5d4dbf55ecef8871e0c4f2a6905f7dc6b3a503a0fa491c7a376b132`
- Submit tx: `0xfc84d95fa8d5f775c269ce2206062c01ec7eadee504ee6ee1cc6c7d836b62592`
- Vigilia request ID: `0x0000000000000000000000000000000000000000000000000000000000329c9e`
- Platform request ID: `3316894`
- Callback tx / observed callback event: `0xf98034b7c2022a8aa36d6465498d5ee6ba7b7ada41c5cd3524ec0dc24961d87f`
- State after callback: `VerifiedComplete`
- Approve tx: `0x618d27b7c5ba4dedb246860e60868a7da8328c1f8b6b2134fcc32cca5cb75184`
- Claim tx: `0xef82fcce6064c3e4681834568f7401e01cfdd4c35b9446b9c3b6907959570d52`
- Final state: `Claimed`

The deployed contract wiring is healthy:

- `verifier.escrow()` returned `0x8bb7a1DF033FfcAFa376dbC930Df31f215f0403a`
- `escrow.verifier()` returned `0x880154CCa9C3fddA472250B16a1DF8118E3c0960`
- `verifier.agentId()` returned `13174292974160097713`
- `make verifier-deposit` returned `120000000000000000`
- deployer balance was `99.467661118` STT
- Final task accounting for task `1`: `fundedAmount` cleared to `0`, active submission `1`, submission verdict
  `Complete`.

### VerificationFailed / Recovery Result

- Malformed evidence URL: `https://httpbin.org/base64/eyJzdGF0dXMiOiJ1bmtub3duIn0=`
- Task ID: `2`
- Malformed submission ID: `2`
- Create tx: `0xb20920dfc606d2a2ec74a39489e698d1234909bfb76305cdc2635fdf42c67dee`
- Fund tx: `0x61314addbfc8f03ed62fa2542456c12cbaa1368bc416114b3312ab70ea704e59`
- Malformed submit tx: `0x10730779a24de16265d40eba9e5a91929ee09caab0e22655b263593780ea2bd5`
- Malformed platform request ID: `3319684`
- Failure callback tx: `0xa82e0356683d83c3a3a3a0784fcc1557bc2bea272cd0392ddd623258e03a4997`
- State after malformed callback: `VerificationFailed`
- Recovery path used: revised evidence submission, because the malformed `httpbin` URL is immutable.
- Recovery evidence URL: `https://httpbin.org/base64/eyJ2ZXJkaWN0IjoiQ29tcGxldGUifQ==`
- Recovery submission ID: `3`
- Recovery submit tx: `0xc12371b52b8a283746d312b0b27afb55680501d5229571d0c5a41a756941454f`
- Recovery platform request ID: `3319974`
- Recovery callback tx: `0xb7e7137786d6b34eadfdfd621272d519a224d069bcd559f6b53b73314f414a9c`
- State after recovery callback: `VerifiedComplete`
- Approve tx: `0xf4890f7b309fcab9150bb5407c2e429050afc74137884eb3bccb067c4c84400a`
- Claim tx: `0x1327ff4f5b8381e631490e805c6059f4c78dce65be24eaa2a63ea2cad3b59b3c`
- Final state: `Claimed`

### Issues / Notes

- `make evidence-url` failed because `VIGILIA_EVIDENCE_JSON_URL` is not set.
- The candidate GitHub raw URL
  `https://raw.githubusercontent.com/VitalR/vigilia-protocol/main/demo/evidence/complete.json` returned `404: Not Found`,
  because the demo evidence fixture is not public on `main` yet.
- `https://httpbin.org/base64/eyJ2ZXJkaWN0IjoiQ29tcGxldGUifQ==` returned exactly `{"verdict":"Complete"}` and was used
  as the public happy-path evidence endpoint.
- `https://httpbin.org/base64/eyJzdGF0dXMiOiJ1bmtub3duIn0=` returned exactly `{"status":"unknown"}` and was used as the
  public failure-path evidence endpoint.
- `make demo-create-task` and lower-gas `cast send` attempts failed on Somnia by consuming the full transaction gas
  limit. Successful live transactions used explicit legacy transactions with high gas caps. The Makefile now exposes
  `DEMO_GAS_LIMIT=10000000` and passes `--gas-limit` to demo script targets.
- Earlier failed create attempts:
  - `0x27d3064d2cce2941614b0e15f9c803409af853c411cee864491655303f064270`
  - `0xf2dcfa42ab99059afd38262edb995838ce9835de9f6151dbbb5448127a202726`
  - `0x1f84e5a999af635ef9bc811ea524b8f5eb11f2135f793d846ea6a43bd27f5735`
  - `0x7d69e2429182dc796dd81e2c327aa83152807604c05ac7e6030a92da55ec95de`
  - `0x2c1b1bac7d94f6b174821911c95ba939171d857d0c6f12333fd03739526814a9`
- Contract verification now resolves cleanly:
  - `make verify-somnia-json-verifier`: already verified
  - `make verify-somnia-escrow`: already verified
- To repeat the smoke flow with a project-hosted evidence URL, host a public endpoint that returns exactly
  `{"verdict":"Complete"}` and run:

```bash
export VIGILIA_EVIDENCE_JSON_URL=<public URL returning {"verdict":"Complete"}>
make demo-create-task
export DEMO_TASK_ID=<task id from logs>
make demo-fund-task
make demo-submit-complete
```
