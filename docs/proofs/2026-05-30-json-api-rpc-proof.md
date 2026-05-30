# Somnia JSON API RPC Proof - 2026-05-30/31

This document is a concise proof package for the Vigilia v0.1.0 JSON API Request smoke deployment. The official Somnia
testnet RPC is the source of truth:

```text
https://api.infra.testnet.somnia.network/
```

Shannon explorer direct transaction pages may load, but address tabs/search can be incomplete or stale for these
transactions. Use RPC receipts and logs as canonical proof.

## Deployment

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

The verifier minimum deposit was confirmed as:

```text
platform.getRequestDeposit() + pricePerValidator * subcommitteeSize
30000000000000000 + 30000000000000000 * 3 = 120000000000000000
```

## Happy Path

Evidence URL:

```text
https://httpbin.org/base64/eyJ2ZXJkaWN0IjoiQ29tcGxldGUifQ==
```

The endpoint returned exactly:

```json
{"verdict":"Complete"}
```

| Field | Value |
|---|---|
| Task ID | `4` |
| Submission ID | `5` |
| Submit tx | `0x17d5b7b93344729b362009806ea8df3bc4114b92c3c76c9b04fe525431e18868` |
| Submit block | `396389317` |
| Submit tx `to` | `0x8bb7a1DF033FfcAFa376dbC930Df31f215f0403a` |
| Callback tx | `0xef1e7d7abdcba02982d46f78b030a573f72e2ac10614d86ce811104071cb7250` |
| Callback block | `396389330` |
| Callback tx `to` | `0x037Bb9C718F3f7fe5eCBDB0b600D607b52706776` |
| Platform request ID | `3347816` / `0x331568` |
| Raw result bytes | `0x436f6d706c657465` |
| Decoded result | `Complete` |
| Escrow notes URI | `somnia-agent-request:3347816` |
| State before approval | `VerifiedComplete` |
| Final state after approval/claim | `Claimed` |

Decoded event facts:

```text
SomniaVerificationRequested:
  platformRequestId: 3347816
  taskId: 4
  submissionId: 5
  agentId: 13174292974160097713
  deposit: 120000000000000000

SomniaVerificationSucceeded:
  platformRequestId: 3347816
  taskId: 4
  submissionId: 5
  verdict: Complete
  rawResult: Complete
  rawResultBytes: 0x436f6d706c657465

WorkSubmitted:
  taskId: 4
  submissionId: 5
  requestId: 0x0000000000000000000000000000000000000000000000000000000000331568

VerdictRecorded:
  taskId: 4
  submissionId: 5
  verdict: Complete
  notesURI: somnia-agent-request:3347816
```

The callback transaction was sent to the Somnia Agent Platform. Verifier and escrow events appear inside that platform
callback receipt because the platform invoked the verifier callback, and the verifier then recorded the bounded verdict
into escrow.

## Malformed And Recovery Path

Malformed URL:

```text
https://httpbin.org/base64/eyJzdGF0dXMiOiJ1bmtub3duIn0=
```

The endpoint returned exactly:

```json
{"status":"unknown"}
```

| Field | Value |
|---|---|
| Task ID | `5` |
| Create tx | `0xf2c913cfb8b3d85e303af84f87e51518aab008ac3355be962d7477841edc2ad2` |
| Fund tx | `0xb8b691ff298471e2fe10a706f10d2d6cbb343974850823a1e14b4cdbff225d0c` |
| Malformed submit tx | `0x3222fd6ae549de12b77e6a00ee01ef8511bddce85b9ccc2cfec5b7166e69a5fc` |
| Failure callback tx | `0xa27ca4358d57f535ec45478947d2657f28d0105114b5ed615c38060bcf6262a3` |
| Malformed platform request ID | `3348512` / `0x331820` |
| State after malformed callback | `VerificationFailed` |
| Recovery submit tx | `0x15f5920d34f3c5c105dd7e82fa10087ca4e9dc92ed66f2ef4358c2cd4bcaaa34` |
| Recovery callback tx | `0xbdde8b601417197c981353f3d23102e2e9eb1b3eca5726bf63d6ec6acc3d2e8c` |
| Recovery platform request ID | `3348654` / `0x3318ae` |
| Recovery raw result | `Complete` / `0x436f6d706c657465` |
| State after recovery callback | `VerifiedComplete` |
| Approve recovered tx | `0xaf24be4cc38b7e1c0098cb3d36645c62d520be7dce7f4930dd483dd86edc5dd7` |
| Claim recovered tx | `0x2e330358b9a3b2619ff0808fc9690d907ebd678ccaa0b2192ec9246b01333704` |
| Final state | `Claimed` |

Failure event facts:

```text
SomniaVerificationFailed:
  platformRequestId: 3348512
  taskId: 5
  submissionId: 6
  status: Failed
  failureNotesURI: somnia-agent-request:3348512

VerificationFailedRecorded:
  taskId: 5
  submissionId: 6
  requestId: 0x0000000000000000000000000000000000000000000000000000000000331820
  failureNotesURI: somnia-agent-request:3348512
```

Recovery event facts:

```text
SomniaVerificationSucceeded:
  platformRequestId: 3348654
  taskId: 5
  submissionId: 7
  verdict: Complete
  rawResult: Complete
  rawResultBytes: 0x436f6d706c657465

VerdictRecorded:
  taskId: 5
  submissionId: 7
  verdict: Complete
  notesURI: somnia-agent-request:3348654
```

## Receipt Commands

```bash
export SOMNIA_RPC_URL=https://api.infra.testnet.somnia.network/

cast chain-id --rpc-url "$SOMNIA_RPC_URL"
cast receipt 0x17d5b7b93344729b362009806ea8df3bc4114b92c3c76c9b04fe525431e18868 --rpc-url "$SOMNIA_RPC_URL"
cast receipt 0xef1e7d7abdcba02982d46f78b030a573f72e2ac10614d86ce811104071cb7250 --rpc-url "$SOMNIA_RPC_URL"
cast tx 0xef1e7d7abdcba02982d46f78b030a573f72e2ac10614d86ce811104071cb7250 --rpc-url "$SOMNIA_RPC_URL"
cast block 396389330 --rpc-url "$SOMNIA_RPC_URL"

curl -sS "$SOMNIA_RPC_URL" \
  -H 'content-type: application/json' \
  --data '{"jsonrpc":"2.0","id":1,"method":"eth_getTransactionReceipt","params":["0xef1e7d7abdcba02982d46f78b030a573f72e2ac10614d86ce811104071cb7250"]}'
```

## Gas Note

An earlier `make demo-create-task` run produced a type-2/lower-gas failure:

```text
0x40027ce3f109c1644fbb10854414e6ca51889507764b5a1e9d7d8df63fad322c
```

The live transactions in this proof used legacy transactions with explicit high gas limits. Keep
`DEMO_GAS_LIMIT=10000000` documented as the practical workaround for script targets.

## Conclusion

v0.1.0 proves this live path:

```text
Somnia JSON API Request -> platform callback -> verifier bounded result -> escrow verdict recording
```

It does not prove GitHub repository verification, docs parsing, deployment inspection, LLM inference, or multi-agent AI
verification. Those claims require v0.2.0+ verifier/coordinator work and new live receipts.
