# Deployment And Demo Runbook

This runbook covers the first narrow Somnia testnet deployment for Vigilia Protocol.

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

The current verifier uses Somnia JSON API Request with `fetchString(url, "verdict")`.

## G. One Active Agent

The first deployment uses one active agent: JSON API Request. This keeps the live demo deterministic and auditable for milestone-style verdicts.

LLM Parse Website and LLM Inference agent IDs are kept in `.env.example` as named references for the roadmap. Multi-agent verification is future work. The deployment JSON records `activeAgentType` and `activeAgentId` so reviewers can see exactly which verifier configuration is live.

## H. Verification Commands

Use the Make targets after exporting deployed addresses:

```bash
export VIGILIA_ESCROW=<deployed escrow>
export VIGILIA_SOMNIA_AGENT_VERIFIER=<deployed verifier>

make verify-somnia-verifier
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

forge verify-contract "$VIGILIA_SOMNIA_AGENT_VERIFIER" \
  src/VigiliaSomniaAgentVerifier.sol:VigiliaSomniaAgentVerifier \
  --chain-id "$SOMNIA_CHAIN_ID" \
  --verifier blockscout \
  --verifier-url "$SOMNIA_BLOCKSCOUT_API" \
  --constructor-args "$VERIFIER_ARGS"
```

Raw escrow command:

```bash
ESCROW_ARGS=$(cast abi-encode "constructor(address)" "$VIGILIA_SOMNIA_AGENT_VERIFIER")

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
  --broadcast \
  -vvvv
```
