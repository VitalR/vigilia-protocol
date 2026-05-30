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
