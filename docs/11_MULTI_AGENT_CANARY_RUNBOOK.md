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

The JSON API Request ABI is proven in v0.1.0:

```solidity
fetchString(string url, string selector) returns (string)
```

The v0.2.0 LLM interfaces are canary-only candidates:

```solidity
inferString(string prompt, string[] allowedValues) returns (string)
parseWebsite(string url, string instruction) returns (string)
```

Before enabling LLM settlement, confirm the exact method selectors and parameter order from Somnia Agent Explorer or
generated snippets, then prove them with live request and callback receipts.

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

After deployment:

```bash
export VIGILIA_MULTI_AGENT_VERIFIER=<deployed verifier>
```

## Deposits

The coordinator uses the same deposit model per kind:

```text
platform.getRequestDeposit() + pricePerValidator * subcommitteeSize
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
export LLM_CANARY_PROMPT='Return exactly one of these words for a completed software milestone: Complete, NeedsReview, Incomplete. Return Complete.'
make multi-agent-canary-llm-inference
```

Required proof before enabling LLM Inference settlement:

- confirm `inferString(string,string[])` selector and argument shape from Somnia-generated snippets;
- request tx succeeds;
- callback tx goes to `SOMNIA_AGENT_PLATFORM`;
- callback receipt includes `CanarySucceeded`;
- raw bytes decode to exactly `Complete`, `NeedsReview`, or `Incomplete`;
- failed/timed-out/malformed/unknown callbacks emit `CanaryFailed`, not an escrow verdict.

## LLM Parse Website Canary

The website parse ABI is provisional in this repo. Use it only as a live probe until Somnia-generated snippets confirm
the exact method shape.

```bash
export WEBSITE_CANARY_URL=https://example.com/
export WEBSITE_CANARY_INSTRUCTION='Return exactly one of these words after reading the page: Complete, NeedsReview, Incomplete.'
make multi-agent-canary-llm-parse
```

Required proof before enabling LLM Parse Website settlement:

- confirm `parseWebsite(string,string)` or the correct replacement ABI from Somnia-generated snippets;
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
