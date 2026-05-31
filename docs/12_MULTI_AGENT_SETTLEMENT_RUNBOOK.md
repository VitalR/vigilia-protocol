# Multi-Agent Settlement Runbook

This runbook covers the v0.2.1 **full settlement** deployment for Vigilia Protocol on Somnia testnet.

It is intentionally separate from:

| Track | Version | Artifact | Purpose |
|---|---|---|---|
| JSON API smoke | v0.1.0 | `deployments/somnia-testnet-50312.json` | Proven single-agent JSON API Request settlement through `VigiliaJsonApiVerifier` |
| Multi-agent canary | v0.2.0 | `deployments/somnia-testnet-50312-multi-agent-canary.json` | Standalone `VigiliaMultiAgentVerifier` canary requests without escrow |
| Multi-agent settlement | v0.2.1 | `deployments/somnia-testnet-50312-multi-agent-settlement.json` | Fresh escrow + fresh multi-agent verifier full settlement |

Do not overwrite the v0.1.0 or v0.2.0 artifacts or redeploy those addresses.

## No-Overclaim Rule

Correct:

```text
v0.2.1 proves a fresh escrow settlement system wired to VigiliaMultiAgentVerifier.
The live settlement path uses JSON API bounded verdicts.
LLM Inference has canary proof and may be promoted later after settlement integration.
LLM Parse Website remains disabled due to platform Failed callbacks.
```

Incorrect:

```text
Vigilia fully verifies GitHub/docs/websites with all three agents.
```

## Network

```text
chainId: 50312
RPC: https://api.infra.testnet.somnia.network/
Explorer: https://shannon-explorer.somnia.network/
Blockscout API: https://somnia.w3us.site/api/
Somnia Agent Platform: 0x037Bb9C718F3f7fe5eCBDB0b600D607b52706776
```

## Settlement Boundary

The v0.2.1 deployment uses **Option B**:

1. Deploy fresh `VigiliaMultiAgentVerifier`.
2. Deploy fresh `VigiliaEscrow` pointing to the new verifier.
3. Bind the verifier to the new escrow once.
4. Run full escrow E2E through the new instances only.

Enabled settlement kinds:

- JSON API Request only

Disabled settlement kinds:

- LLM Inference (canary-capable, settlement disabled)
- LLM Parse Website (canary-capable, settlement disabled due to live platform `Failed` callbacks)

See also: [`docs/11_MULTI_AGENT_CANARY_RUNBOOK.md`](./11_MULTI_AGENT_CANARY_RUNBOOK.md) and the v0.2.1 settlement runbook at [`docs/12_MULTI_AGENT_SETTLEMENT_RUNBOOK.md`](./12_MULTI_AGENT_SETTLEMENT_RUNBOOK.md).

## Environment

```bash
set -a
source .env
set +a
```

Required for deployment:

```text
DEPLOYER_PRIVATE_KEY
SOMNIA_RPC_URL
SOMNIA_CHAIN_ID
SOMNIA_AGENT_PLATFORM
SOMNIA_JSON_API_AGENT_ID
SOMNIA_LLM_INFERENCE_AGENT_ID
SOMNIA_LLM_PARSE_WEBSITE_AGENT_ID
AGENT_SUBCOMMITTEE_SIZE
JSON_API_PRICE_PER_VALIDATOR_WEI
LLM_INFERENCE_PRICE_PER_VALIDATOR_WEI
LLM_PARSE_PRICE_PER_VALIDATOR_WEI
SOMNIA_VERDICT_SELECTOR
SOMNIA_BLOCKSCOUT_API
```

After deployment, export:

```bash
export VIGILIA_MULTI_AGENT_ESCROW=<new escrow>
export VIGILIA_MULTI_AGENT_SETTLEMENT_VERIFIER=<new verifier>
```

Settlement demo scripts accept `VIGILIA_MULTI_AGENT_SETTLEMENT_VERIFIER` and fall back to `VIGILIA_MULTI_AGENT_VERIFIER` for single-wallet smoke runs. Keep `VIGILIA_MULTI_AGENT_VERIFIER=0x52A44E2fB4741152fD6d5183b37500b5A7820Fa3` for v0.2.0 canary commands.

## Preflight

```bash
make multi-settlement-env-check
make account
make balance
make platform-check
```

## Deployment

Dry run:

```bash
make multi-settlement-deploy-dry-run
```

Broadcast:

```bash
make multi-settlement-deploy-somnia
make multi-settlement-show-deployment
make multi-settlement-deployment-addresses
make multi-settlement-verifier-deposit
```

The deploy script writes `deployments/somnia-testnet-50312-multi-agent-settlement.json` and the Makefile enriches it with broadcast transaction hashes when `jq` and the Foundry broadcast trace are available.

## Wiring Checks

```bash
cast call $VIGILIA_MULTI_AGENT_ESCROW "verifier()(address)" --rpc-url "$SOMNIA_RPC_URL"
cast call $VIGILIA_MULTI_AGENT_VERIFIER "escrow()(address)" --rpc-url "$SOMNIA_RPC_URL"
cast call $VIGILIA_MULTI_AGENT_VERIFIER "agentConfigs(uint8)(uint256,uint256,uint256,string,bool,bool)" 1 --rpc-url "$SOMNIA_RPC_URL"
cast call $VIGILIA_MULTI_AGENT_VERIFIER "agentConfigs(uint8)(uint256,uint256,uint256,string,bool,bool)" 3 --rpc-url "$SOMNIA_RPC_URL"
```

Expected:

- `escrow.verifier()` equals the new verifier
- `verifier.escrow()` equals the new escrow
- JSON API config has `settlementEnabled = true`
- LLM Parse Website config has `settlementEnabled = false`

## Verification

```bash
make multi-settlement-verify-verifier
make multi-settlement-verify-escrow
```

Do not claim verified status unless Blockscout confirms both contracts.

## Full E2E Happy Path

Evidence URL returning exactly `{"verdict":"Complete"}`:

```text
https://httpbin.org/base64/eyJ2ZXJkaWN0IjoiQ29tcGxldGUifQ==
```

Commands:

```bash
make multi-settlement-demo-create-task
export DEMO_TASK_ID=<task id from logs>
make multi-settlement-demo-fund-task
export VIGILIA_EVIDENCE_JSON_URL=https://httpbin.org/base64/eyJ2ZXJkaWN0IjoiQ29tcGxldGUifQ==
make multi-settlement-demo-submit-complete

# Wait for async Somnia callback, then:
make multi-settlement-demo-inspect-task
make multi-settlement-demo-approve-task
make multi-settlement-demo-claim-task
make multi-settlement-demo-inspect-task
```

Expected final state:

- before approval: `VerifiedComplete`
- after claim: `Claimed`
- `fundedAmount = 0`

## Failure / Recovery Path

Malformed evidence:

```text
https://httpbin.org/base64/eyJzdGF0dXMiOiJ1bmtub3duIn0=
```

```bash
export VIGILIA_EVIDENCE_JSON_URL=https://httpbin.org/base64/eyJzdGF0dXMiOiJ1bmtub3duIn0=
make multi-settlement-demo-submit-malformed
make multi-settlement-demo-inspect-task
```

Expected:

- task state: `VerificationFailed`
- no claim allowed

Recovery options:

```bash
# Retry same stored evidence URI after fixing mutable endpoint in place
make multi-settlement-demo-retry-verification

# Or submit revised evidence with a new Complete URL
export VIGILIA_EVIDENCE_JSON_URL=https://httpbin.org/base64/eyJ2ZXJkaWN0IjoiQ29tcGxldGUifQ==
make multi-settlement-demo-submit-complete
```

## Proof Checklist

Collect for the happy path:

- create tx
- fund tx
- submit tx
- callback tx to Somnia Agent Platform
- approve tx
- claim tx
- task ID
- submission ID
- platform request ID
- raw result bytes
- decoded result
- final task state

Useful RPC commands:

```bash
cast receipt <SUBMIT_TX> --rpc-url "$SOMNIA_RPC_URL"
cast receipt <CALLBACK_TX> --rpc-url "$SOMNIA_RPC_URL"
cast tx <CALLBACK_TX> --rpc-url "$SOMNIA_RPC_URL"
cast logs --address "$VIGILIA_MULTI_AGENT_VERIFIER" --from-block <FROM> --to-block <TO> --rpc-url "$SOMNIA_RPC_URL"
cast logs --address "$VIGILIA_MULTI_AGENT_ESCROW" --from-block <FROM> --to-block <TO> --rpc-url "$SOMNIA_RPC_URL"
```

Proof requirements:

- submit tx targets the **new** escrow
- callback tx targets the Somnia Agent Platform
- verifier emits `MultiAgentVerificationSucceeded`
- escrow emits `VerdictRecorded`
- raw bytes decode to `Complete`
- task reaches `VerifiedComplete` before approval
- final state is `Claimed`

If Shannon explorer address/search tabs disagree with RPC, treat official RPC receipts/logs as canonical.

## Live Result - 2026-05-31

| Field | Value |
|---|---|
| Escrow | `0xF96C2b1Fe8dC48552D009908a9E440D38a014a41` |
| Verifier | `0xa486D433ee320a714d162a7cf9276b419cEb66e0` |
| E2E task | `1` |
| Final state | `Claimed` |
| RPC proof | [`docs/proofs/2026-05-31-multi-agent-settlement-rpc-proof.md`](./proofs/2026-05-31-multi-agent-settlement-rpc-proof.md) |

Blockscout verification was submitted but lagged immediately after deployment; re-run the verification Make targets before claiming verified status in external materials.

## Gas Notes

Settlement deploy uses `MULTI_SETTLEMENT_GAS_ESTIMATE_MULTIPLIER=2000`. Demo broadcasts use
`MULTI_SETTLEMENT_DEMO_GAS_ESTIMATE_MULTIPLIER=2000`. Some Somnia transactions still need direct
`cast send --legacy --gas-limit ...` when scripted `bindEscrow`, `fundTask`, or `approveTask` estimates are too low.

If scripted `bindEscrow` fails out-of-gas after verifier/escrow deploy, run:

```bash
cast send $VIGILIA_MULTI_AGENT_SETTLEMENT_VERIFIER "bindEscrow(address)" $VIGILIA_MULTI_AGENT_ESCROW \
  --legacy --gas-limit 10000000 --rpc-url "$SOMNIA_RPC_URL" --private-key "$DEPLOYER_PRIVATE_KEY"
```

## Recommended Next Step

After v0.2.1 JSON API settlement proof:

1. promote LLM Inference from canary-only to settlement after adding a safe JSON-facts -> LLM Inference path;
2. keep LLM Parse Website disabled until live platform callbacks stop returning `Failed`;
3. add a dedicated RPC proof doc under `docs/proofs/` for the v0.2.1 settlement run.
