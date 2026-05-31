# Somnia Multi-Agent Settlement RPC Proof - 2026-05-31

Canonical RPC endpoint:

```text
https://api.infra.testnet.somnia.network/
```

Deployment line: `vigilia-multi-agent-settlement` `v0.2.1`

## Deployed System

| Field | Value |
|---|---|
| Chain ID | `50312` |
| Escrow | `0xF96C2b1Fe8dC48552D009908a9E440D38a014a41` |
| Multi-agent verifier | `0xa486D433ee320a714d162a7cf9276b419cEb66e0` |
| Somnia Agent Platform | `0x037Bb9C718F3f7fe5eCBDB0b600D607b52706776` |
| JSON API Agent ID | `13174292974160097713` |
| JSON API minimum deposit | `120000000000000000` wei |
| Enabled settlement | JSON API only |
| Disabled settlement | LLM Inference, LLM Parse Website |

Deploy transactions:

| Step | Tx hash |
|---|---|
| Verifier deploy | `0x649197c0ee1610539504fe2c4d2ceb0ff08d3af2ae799ed9544462c4d444cd02` |
| Escrow deploy | `0x08864079efa90ee642aaccafa7e0aa5f9ae566e33c9d7ed1833665c2ebe62b25` |
| bindEscrow (manual recovery) | `0x766ae363126fe18266ccc2ae6f18fade6ba3da6a3642894b5463df5c007d683b` |

Note: the scripted `bindEscrow` broadcast ran out of gas on Somnia; binding was completed manually with `--gas-limit 10000000`.

## Happy Path E2E

Evidence URL:

```text
https://httpbin.org/base64/eyJ2ZXJkaWN0IjoiQ29tcGxldGUifQ==
```

Decoded JSON:

```json
{"verdict":"Complete"}
```

| Field | Value |
|---|---|
| Task ID | `1` |
| Submission ID | `1` |
| Create tx | `0x3fbcd7c79eeb97cc68d1bd1d6e1ecee7ec9f4f1dcd549510356e02adf6c5b53b` |
| Fund tx | `0x7ebed45d1fa91b1d62c032b27c23a16710a38462c0406d0a27db4ef95fdf92ac` |
| Submit tx | `0x7d14bc2518d013d26d4552f0f782eaa840c64d9b608023c8d47de2140b943ba3` |
| Submit block | `397162586` |
| Callback tx | `0xdb994c6ef8dbe30141cd9800826e3d1b516ba4486967fd4e847915a83b54d970` |
| Callback block | `397162595` |
| Callback tx `to` | `0x037Bb9C718F3f7fe5eCBDB0b600D607b52706776` |
| Platform request ID | `3583766` / `0x36af16` |
| Decoded result | `Complete` |
| Escrow notes URI | `somnia-agent-request:3583766` |
| State before approval | `VerifiedComplete` |
| Approve tx | `0x52871ab93cd97501cc5a90fbcae6d590e298b1aab917d9154f7fa6fd8a2ed828` |
| Claim tx | `0xe979556e0efac4a8dbb8ef426797cac80bcb44e95adda1232e060a77d41f5f78` |
| Final state | `Claimed` |
| Final `fundedAmount` | `0` |

Decoded event facts:

```text
MultiAgentVerificationRequested:
  platformRequestId: 3583766
  taskId: 1
  submissionId: 1
  agentId: 13174292974160097713
  deposit: 120000000000000000

MultiAgentVerificationSucceeded:
  platformRequestId: 3583766
  taskId: 1
  submissionId: 1
  kind: JsonApi
  verdict: Complete
  rawResult: Complete

VerdictRecorded:
  taskId: 1
  submissionId: 1
  requestId: 0x36af16
  verdict: Complete
  verifierNotesURI: somnia-agent-request:3583766
```

## Verification Status

Blockscout verification was attempted immediately after deployment but returned `Address is not a smart-contract` due to indexer lag. Re-run:

```bash
make multi-settlement-verify-verifier
make multi-settlement-verify-escrow
```

## Gas Notes

Somnia live gas materially exceeds local Foundry estimates for:

- contract creation (~41M verifier, ~30M escrow)
- scripted `bindEscrow`, `approveTask`, and some demo script broadcasts when `gas-estimate-multiplier=200`

Settlement deploy uses `MULTI_SETTLEMENT_GAS_ESTIMATE_MULTIPLIER=2000`. Some demo steps succeeded only with `MULTI_SETTLEMENT_DEMO_GAS_ESTIMATE_MULTIPLIER=2000` or direct `cast send --gas-limit`.

## Failure / Recovery Path

Not run in this pass. Use `make multi-settlement-demo-submit-malformed` and `make multi-settlement-demo-retry-verification` against a fresh task when needed.
