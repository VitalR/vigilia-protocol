# GrantRound ThreeAgent Deployment and Proof Attempt

Date: 2026-06-03

Network: Somnia testnet, chain ID 50312

## Summary

This pass implemented and deployed a fresh GrantRound/verifier pair that supports both GrantRound screening modes:

- `TwoAgent`: JSON API facts -> LLM Inference bounded verdict -> GrantRound callback.
- `ThreeAgent`: JSON API facts -> JSON `websiteURI` -> Website Parse -> LLM Inference bounded verdict -> GrantRound callback.

TwoAgent was already proven end to end in `docs/proofs/2026-06-03-grant-round-demo-scenarios.md`.

ThreeAgent is implemented in source, covered by tests, and deployed on a fresh pair. The first live ThreeAgent request failed closed at the root JSON API stage when using a temporary `httpbin` evidence bundle URL, so full ThreeAgent GrantRound E2E is not yet proven.

Do not present ThreeAgent as live until the full path succeeds: `ScreeningMode.ThreeAgent` round, public bundle evidence, JSON facts callback, JSON `websiteURI` callback, Website Parse callback, LLM bounded verdict, GrantRound `recordVerdict`, judge/sponsor finalist selection, finalization, and claim.

## Deployment

Artifact:

```text
deployments/somnia-testnet-50312-grant-round-three-agent.json
```

Addresses:

```text
GrantRound: 0x5aE1918Dcaa0A00a1d647e1c9946F7FF3fB61679
Verifier:   0xb0a1cdf062B4c295fC2A00F4bf1C84062F40d8e4
Platform:   0x037Bb9C718F3f7fe5eCBDB0b600D607b52706776
```

Deployment transactions:

```text
Verifier create:    0x6da32d43b7acad4eb72bd1064b74d022c44263bfb2196c2271fdd23e4ce7d6aa
GrantRound create:  0xdd5c2e50d9585bf21e03a56e03e49568f97e091c7fd938a98f0843362212016a
Initial bind failed: 0x20afe9177598a499b1faad7b204e27833bf8ae5362e23f87f89c0801b023c033
Manual bind success: 0xe2bff0cc1c9c9ee8509f68af263cbc1fd4548ab41860bdbca39453d507903984
```

The initial deployment-script bind ran out of gas. A later manual `bindEscrow` call succeeded. State verification confirmed:

```text
verifier.escrow() == 0x5aE1918Dcaa0A00a1d647e1c9946F7FF3fB61679
grantRound.verifier() == 0xb0a1cdf062B4c295fC2A00F4bf1C84062F40d8e4
```

Workflow deposits:

```text
JsonFactsToLlmVerdict:              360000000000000000 wei
JsonFactsAndWebsiteToLlmVerdict:    810000000000000000 wei
```

## ThreeAgent Quick Attempt

Round:

```text
Round ID: 1
Screening mode: ThreeAgent
Prize amount: 1 STT
Max winners: 1
```

Application:

```text
Application ID: 1
Applicant: 0x110C2cfaC2Df847FBC98cc0c514A11d0e2046c13
Evidence: temporary https://httpbin.org/base64/... bundle containing facts and websiteURI
Website URI inside bundle: https://raw.githubusercontent.com/VitalR/vigilia-protocol/main/demo/evidence/grants/complete-project.html
```

Transactions:

```text
Create round:      0x61b17d13419b5b52077cf4e0ee8fac53c508c86ddf9cc8542f7123f27c41e432
Fund round:        0x5fe70d72bdeb4957e6bdaa9f45282cfe40db26306a4eea588d3017d53b6c7cbb
Submit app:        0xc8626154d97edb0156aad59b818a67b0d6d4ba57e9a3d42d9b29425a733bfdb6
Request screening: 0x06c3716f2fcad45e75f9bec657e2c68d605f7311fc2ae6bc8faef8bd07365c15
Failure callback:  0x744712a7dea2416ed063ba57609cf0316e7e4c9526447d010df8e034950e4ac2
```

Request IDs:

```text
Root JSON facts request: 4307187
GrantRound requestId: 0x000000000000000000000000000000000000000000000000000000000041b8f3
```

Final observed application state:

```text
verdict: Unknown
status: VerificationFailed
selected: false
claimed: false
notesURI: somnia-agent-request:4307187
```

Verifier event:

```text
MultiAgentVerificationFailed(rootRequestId=4307187, taskId=1, submissionId=1, kind=JsonApi, workflow=JsonFactsAndWebsiteToLlmVerdict, status=Failed)
```

GrantRound event:

```text
ApplicationVerificationFailed(roundId=1, applicationId=1, requestId=4307187, notesURI=somnia-agent-request:4307187)
```

Interpretation:

The fresh contract/verifier pair correctly accepted a ThreeAgent request and failed closed. The request did not reach the JSON `websiteURI`, Website Parse, or LLM stages because the root JSON API request failed. The likely operational cause is the temporary `httpbin` evidence bundle URL. The committed `bundle-*.json` files must be pushed to GitHub or hosted on Vercel, Cloudflare Pages, Netlify, or a raw Gist URL before retrying the live ThreeAgent proof.

## Safety Result

The failed ThreeAgent callback did not select a finalist and did not move funds. Finalist selection remains a judge/sponsor action, and claims remain applicant pull payments after finalization.

## Next Proof Attempt

After pushing or hosting the bundle evidence:

```bash
export VIGILIA_GRANT_ROUND=0x5aE1918Dcaa0A00a1d647e1c9946F7FF3fB61679
export VIGILIA_GRANT_ROUND_VERIFIER=0xb0a1cdf062B4c295fC2A00F4bf1C84062F40d8e4
export GRANT_ROUND_THREE_AGENT_WORKFLOW_DEPOSIT_WEI=810000000000000000
export GRANT_SCREENING_MODE=1
export GRANT_COMPLETE_BUNDLE_EVIDENCE_URI=https://raw.githubusercontent.com/VitalR/vigilia-protocol/main/demo/evidence/grants/bundle-complete.json
make grant-demo-create-round
make grant-demo-fund-round
make grant-demo-submit-three-agent-complete
make grant-demo-request-screening-three-agent-cast DEMO_GAS_LIMIT=30000000
```

Then wait for callbacks and inspect. Only mark ThreeAgent live if the application receives `Complete`, the judge/sponsor selects it, the round finalizes, and the applicant claims.
