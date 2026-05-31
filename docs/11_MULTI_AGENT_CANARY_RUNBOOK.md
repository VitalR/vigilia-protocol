# Multi-Agent Canary Runbook

This runbook defines the v0.2.0 path after the proven v0.1.0 JSON API Request smoke deployment.

v0.1.0 proof lives in:

- `docs/10_DEPLOYMENT_AND_DEMO_RUNBOOK.md`
- `docs/proofs/2026-05-30-json-api-rpc-proof.md`

The v0.1.0 claim is intentionally narrow:

```text
Somnia JSON API Request -> platform callback -> verifier bounded result -> escrow verdict recording
```

Do not claim GitHub/docs/deployment/LLM/multi-agent verification until each new agent method has its own live
request/callback receipt proof.

## Why A New Verifier

`VigiliaJsonApiVerifier` is intentionally JSON API-specific:

- it encodes `fetchString(url, selector)`;
- it expects a string result: `Complete`, `NeedsReview`, or `Incomplete`;
- it has live receipt proof on Somnia testnet;
- it should remain stable for v0.1.0 demos and regression checks.

v0.2.0 adds `VigiliaMultiAgentVerifier` as a separate canary-first coordinator. It supports multiple `AgentKind` values
without mutating the proven deployment line:

```solidity
enum AgentKind {
    Unknown,
    JsonApi,
    LlmInference,
    LlmParseWebsite
}
```

The coordinator stores per-kind config:

- Somnia agent ID;
- price per validator;
- subcommittee size;
- selector or method metadata;
- canary enabled flag;
- settlement enabled flag.

JSON API settlement is enabled by default in the new coordinator because it follows the proven v0.1.0 method shape. LLM
Inference and LLM Parse Website are canary-only by default. They must not be wired into settlement until live platform
callback receipts prove the exact ABI and validator behavior.

## Current Testnet Risks

- Somnia testnet transactions have needed explicit high gas limits.
- Live platform request transactions often need `--skip-simulation` because local simulation can diverge from live
  platform behavior.
- Legacy transactions have been more reliable for demo calls.
- Shannon explorer search/address tabs may lag or omit transactions; official RPC receipts/logs are canonical.
- Some LLM methods may have active-validator or subcommittee availability issues. A canary callback is required before
  any LLM method becomes settlement-critical.

## ABI Boundary

The ABI references below were checked against the official Somnia markdown docs on 2026-05-31:

- `https://docs.somnia.network/agents/base-agents/json-api-request.md`
- `https://docs.somnia.network/agents/base-agents/llm-inference.md`
- `https://docs.somnia.network/agents/base-agents/llm-parse-website.md`
- `https://docs.somnia.network/agents/invoking-agents/from-solidity.md`
- `https://docs.somnia.network/agents/invoking-agents/gas-fees.md`

The Agent Explorer web app was reachable at `https://agents.testnet.somnia.network/`, but the static HTML did not expose
copyable generated Solidity snippets through a simple HTTP fetch. Treat the docs above plus live canary receipts as the
current source of truth for this repo.

The JSON API Request ABI is proven in v0.1.0 and documented by Somnia:

```solidity
fetchString(string url, string selector) returns (string)
```

Selector: `0xe003c22e`

The LLM Inference canary uses Somnia's documented constrained single-turn method:

```solidity
inferString(
    string prompt,
    string system,
    bool chainOfThought,
    string[] allowedValues
) returns (string response)
```

Selector: `0xfe7ca098`

For Vigilia canaries:

- `allowedValues = ["Complete", "NeedsReview", "Incomplete"]`
- `system` may be empty, but the demo default uses a strict bounded-output system prompt
- `chainOfThought = false` by default

The LLM Parse Website canary uses Somnia's documented direct URL `ExtractString` mode:

```solidity
ExtractString(
    string key,
    string description,
    string[] options,
    string prompt,
    string url,
    bool resolveUrl,
    uint8 numPages,
    uint8 confidenceThreshold
) returns (string output)
```

Selector: `0xc2dd1a7a`

For Vigilia canaries:

- `key = "verdict"`
- `description = "Vigilia milestone verification verdict. Return one bounded value."`
- `options = ["Complete", "NeedsReview", "Incomplete"]`
- `prompt = WEBSITE_CANARY_INSTRUCTION`
- `url = WEBSITE_CANARY_URL`
- `resolveUrl = false`
- `numPages = 1`
- `confidenceThreshold = 70`

Before enabling LLM settlement, prove each method with live request and callback receipts. Do not use `inferToolsChat`
for settlement in this pass.

## Deployment

Dry run:

```bash
make multi-agent-deploy-dry-run
```

Broadcast:

```bash
make multi-agent-deploy-somnia
```

The deployment artifact name is:

```text
deployments/somnia-testnet-50312-multi-agent-canary.json
```

Expected public deployment identity:

```text
deploymentName: vigilia-multi-agent-canary
version: v0.2.0
activeAgentTypes: json-api,llm-inference-canary,llm-parse-website-canary
```

`activeAgentTypes` is generated from configured agent IDs and prices. If an optional LLM ID or price is omitted, that
canary is not listed and the corresponding kind remains unconfigured.

Environment names:

- JSON API: `SOMNIA_JSON_API_AGENT_ID`
- LLM Inference: `SOMNIA_LLM_INFERENCE_AGENT_ID`
- LLM Parse Website: `SOMNIA_LLM_WEB_AGENT_ID`
- Backward-compatible parse alias: `SOMNIA_LLM_PARSE_WEBSITE_AGENT_ID`

If both parse env vars are set, `SOMNIA_LLM_PARSE_WEBSITE_AGENT_ID` takes precedence. The current `.env` name
`SOMNIA_LLM_WEB_AGENT_ID` is supported and should not be renamed just to run this canary.

Pricing env names are optional when using current Somnia defaults:

- `JSON_API_PRICE_PER_VALIDATOR_WEI` falls back to `AGENT_PRICE_PER_VALIDATOR`, then `0.03 ether`
- `LLM_INFERENCE_PRICE_PER_VALIDATOR_WEI` falls back to `0.07 ether`
- `LLM_PARSE_PRICE_PER_VALIDATOR_WEI` falls back to `0.10 ether`
- `AGENT_PLATFORM_RESERVE_WEI` falls back to `0.03 ether` for deployment-summary logging only
- `JSON_CANARY_SELECTOR` falls back to `SOMNIA_VERDICT_SELECTOR`, then `verdict`

The deployed verifier computes live request deposits with `platform.getRequestDeposit()` at request time. The deploy
script does not call the platform during dry-run summary logging because Somnia platform simulation can return
`NotActivated` even when direct RPC calls work.

After deployment:

```bash
export VIGILIA_MULTI_AGENT_VERIFIER=<deployed verifier>
```

Live v0.2.0 canary deployment on 2026-05-31:

```text
verifier: 0x52A44E2fB4741152fD6d5183b37500b5A7820Fa3
deploy tx: 0x1ae6c8904b419b3f936b28fe02dd0c8425f2007ce6af598100c25196d5199126
deploy block: 396487716
gas used: 40,877,973
```

Earlier deployment attempts failed out-of-gas with lower gas multipliers:

```text
0x2fa9e18c2129c18e91301e9b980566656054dee3808bcd07b0f52ab21f88cc16 type-2, gasUsed 5,766,266
0x474ec5663bffa25801d4ddb267e784c30d4bb9b2c8d40e6dd7c03451c5947f89 legacy, gasUsed 14,415,665
0xcce675ceadd1779df7d65bf72ab55bf9a26eab933f40ead0c3551801ddb92065 legacy, gasUsed 28,831,330
```

The successful deployment used a legacy transaction and a very high gas estimate multiplier. Keep `DEMO_GAS_LIMIT` and
legacy broadcast documented as practical Somnia testnet workarounds.

## Deposits

The coordinator uses the same deposit model per kind:

```text
platform.getRequestDeposit() + pricePerValidator * subcommitteeSize
```

Official current per-agent prices:

```text
JSON API Request:  0.03 STT per validator
LLM Inference:     0.07 STT per validator
LLM Parse Website: 0.10 STT per validator
```

With the default subcommittee size of 3 and the current platform floor of 0.03 STT, practical request deposits are:

```text
JSON API Request:  0.12 STT
LLM Inference:     0.24 STT
LLM Parse Website: 0.33 STT
```

Check configured deposits:

```bash
make multi-agent-deposit-json
make multi-agent-deposit-llm-inference
make multi-agent-deposit-llm-parse
```

## JSON API Canary

Use a URL that returns exactly:

```json
{"verdict":"Complete"}
```

Example:

```bash
export JSON_CANARY_URL=https://httpbin.org/base64/eyJ2ZXJkaWN0IjoiQ29tcGxldGUifQ==
export JSON_CANARY_SELECTOR=verdict
make multi-agent-canary-json
```

The live make target sends a direct legacy `cast send` transaction instead of a Forge broadcast script. This avoids the
Somnia platform simulation path that can return `NotActivated` for canary deposit calls while the same request works
through the official RPC.

Required proof before treating the canary as successful:

- request tx succeeds;
- request tx logs include `CanaryRequested`;
- callback tx goes to `SOMNIA_AGENT_PLATFORM`;
- callback receipt includes `CanarySucceeded`;
- raw result bytes decode to `Complete`;
- verifier request context is fulfilled.

## LLM Inference Canary

The prompt should force one bounded output:

```bash
export LLM_CANARY_PROMPT='The milestone is complete. Return exactly one allowed value.'
export LLM_CANARY_SYSTEM='You are a strict Vigilia verifier. Return only one allowed value.'
export LLM_CANARY_CHAIN_OF_THOUGHT=false
make multi-agent-canary-llm-inference
```

The live make target sends a direct legacy `cast send` transaction and forwards `LLM_CANARY_SYSTEM` plus
`LLM_CANARY_CHAIN_OF_THOUGHT` to the documented ABI.

Required proof before enabling LLM Inference settlement:

- confirm `inferString(string,string,bool,string[])` request payload in the request receipt;
- request tx succeeds;
- callback tx goes to `SOMNIA_AGENT_PLATFORM`;
- callback receipt includes `CanarySucceeded`;
- raw bytes decode to exactly `Complete`, `NeedsReview`, or `Incomplete`;
- failed/timed-out/malformed/unknown callbacks emit `CanaryFailed`, not an escrow verdict.

## LLM Parse Website Canary

The website parse canary uses the documented `ExtractString` ABI in direct URL mode. It remains canary-only until live
request/callback receipts prove validator execution.

```bash
export WEBSITE_CANARY_URL=https://example.com/
export WEBSITE_CANARY_INSTRUCTION='Return exactly one of these words after reading the page: Complete, NeedsReview, Incomplete.'
make multi-agent-canary-llm-parse
```

The live make target sends a direct legacy `cast send` transaction. A terminal `CanaryFailed` is still useful evidence:
it proves the callback path and confirms the canary remains isolated from escrow settlement.

Required proof before enabling LLM Parse Website settlement:

- confirm `ExtractString(string,string,string[],string,bool,uint8,uint8)` request payload in the request receipt;
- request tx succeeds;
- callback tx goes to `SOMNIA_AGENT_PLATFORM`;
- callback receipt includes `CanarySucceeded`;
- raw bytes decode to exactly `Complete`, `NeedsReview`, or `Incomplete`;
- failed/timed-out/malformed/unknown callbacks emit `CanaryFailed`.

## Inspecting Canary State

After creating a request:

```bash
export CANARY_REQUEST_ID=<platform request id>
make multi-agent-canary-inspect
```

The request context should show:

```text
taskId = 0
submissionId = 0
isCanary = true
exists = true
fulfilled = true after callback
```

Canary requests never call escrow settlement methods.

## Live Canary Proof - 2026-05-31

All evidence below is from the official Somnia testnet RPC:

```text
https://api.infra.testnet.somnia.network/
```

Deployed verifier:

```text
0x52A44E2fB4741152fD6d5183b37500b5A7820Fa3
```

JSON API canary:

| Field | Value |
| --- | --- |
| request tx | `0xa7433b085a7fb05c5fb644d41979c6cb456e8d2bb444cd2693f6f23ae947b0f9` |
| request block | `396489077` |
| request id | `3378327` / `0x338c97` |
| callback tx | `0x8a8c9aab48b42d4ccf68217c37fc863c1474cc091e5ea5960a11f3b58df57f1d` |
| callback block | `396489105` |
| callback `to` | `0x037Bb9C718F3f7fe5eCBDB0b600D607b52706776` |
| event | `CanarySucceeded` |
| verdict | `Complete` |
| raw result bytes | `0x436f6d706c657465` |
| request context | `taskId=0`, `submissionId=0`, `isCanary=true`, `fulfilled=true` |

LLM Inference canary:

| Field | Value |
| --- | --- |
| request tx | `0xa82c1af1f53aa7636cb816c1e903e1e36d9e539f5b3175659486429198f9d984` |
| request block | `396489486` |
| request id | `3378451` / `0x338d13` |
| callback tx | `0xa708c384c345996681a86a3aeefcc45adcdae5f101e821698b19b6b5580f7120` |
| callback block | `396489493` |
| callback `to` | `0x037Bb9C718F3f7fe5eCBDB0b600D607b52706776` |
| event | `CanarySucceeded` |
| verdict | `Complete` |
| raw result bytes | `0x436f6d706c657465` |
| request context | `taskId=0`, `submissionId=0`, `isCanary=true`, `fulfilled=true` |

LLM Parse Website canary:

| Field | Value |
| --- | --- |
| request tx | `0x39a522a428e949b49a94fedcfc91ca2a4a3b2ff956f3130315865a31da60d924` |
| request block | `396489803` |
| request id | `3378548` / `0x338d74` |
| callback tx | `0x121e51b3d204fe4b3446c68243f95112d0036312b4a6a7483ce910beaefc443a` |
| callback block | `396492401` |
| callback `to` | `0x037Bb9C718F3f7fe5eCBDB0b600D607b52706776` |
| event | `CanaryFailed` |
| platform status | `Failed` (`3`) |
| failure note | `somnia-agent-request:3378548` |
| request context | `taskId=0`, `submissionId=0`, `isCanary=true`, `fulfilled=true` |

The Parse Website canary request payload used the documented `ExtractString` selector `0xc2dd1a7a`, but the platform
returned terminal `Failed`. Do not enable website-parse settlement until a later canary produces `CanarySucceeded` with a
bounded result.

## RPC Evidence Commands

Use the official RPC:

```bash
export SOMNIA_RPC_URL=https://api.infra.testnet.somnia.network/

cast receipt <REQUEST_TX> --rpc-url "$SOMNIA_RPC_URL"
cast receipt <CALLBACK_TX> --rpc-url "$SOMNIA_RPC_URL"
cast tx <CALLBACK_TX> --rpc-url "$SOMNIA_RPC_URL"
cast block <CALLBACK_BLOCK> --rpc-url "$SOMNIA_RPC_URL"

curl -sS "$SOMNIA_RPC_URL" \
  -H 'content-type: application/json' \
  --data '{"jsonrpc":"2.0","id":1,"method":"eth_getTransactionReceipt","params":["<CALLBACK_TX>"]}'

cast logs \
  --address "$VIGILIA_MULTI_AGENT_VERIFIER" \
  --from-block <REQUEST_BLOCK_MINUS_10> \
  --to-block <CALLBACK_BLOCK_PLUS_10> \
  --rpc-url "$SOMNIA_RPC_URL"
```

If explorer address tabs/search disagree with RPC, document the mismatch and keep RPC as the source of truth.

## Settlement Policy

For this pass, use Option A:

- the coordinator supports multiple `AgentKind` canaries;
- escrow settlement still uses one selected kind per request;
- only JSON API settlement is enabled by default;
- future staged or aggregate verification is documented but not implemented.

Escrow safety remains unchanged:

- AI/agent output never moves funds directly;
- coordinator only forwards bounded verdicts or `VerificationFailed`;
- `VerificationFailed` does not allow contractor claim or unilateral client refund;
- stale request IDs cannot overwrite active submissions;
- failed/timed-out/malformed responses fail closed.

## No-Overclaim Rule

Correct:

```text
v0.1.0 proves live Somnia JSON API Request -> platform callback -> verifier bounded result -> escrow verdict recording.
v0.2.0 canaries probe LLM and website parsing methods before settlement use.
```

Incorrect:

```text
Vigilia fully verifies GitHub, docs, deployments, and websites with multi-agent AI.
```

Only claim what has live callback proof.
