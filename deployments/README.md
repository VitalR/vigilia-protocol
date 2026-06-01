# Deployments

This directory stores public deployment artifacts for Vigilia Protocol.

Deployment JSON files are safe to commit. They contain deployed contract addresses, public network metadata, and non-secret deployment configuration so reviewers and demo operators can reproduce which contracts were deployed and how they were configured.

`deployments/somnia-testnet-50312.json` currently records `vigilia-json-api-smoke` `v0.1.0`, the first JSON API Request
smoke deployment on Somnia testnet. It proves the real Somnia JSON API request/callback plumbing and the escrow
settlement path.

`deployments/somnia-testnet-50312-multi-agent-canary.json` records the v0.2.0 canary-first multi-agent verifier. It proves
real Somnia agent request/callback plumbing for JSON API, LLM Inference, and LLM Parse Website canaries without touching
escrow.

`deployments/somnia-testnet-50312-multi-agent-settlement.json` records the v0.2.1 full settlement system: a fresh
`VigiliaMultiAgentVerifier` bound to a fresh `VigiliaEscrow`. JSON API settlement is enabled; LLM Inference and LLM Parse
Website remain canary-capable but settlement-disabled in this pass.

`deployments/somnia-testnet-50312-two-agent-settlement.json` records the v0.2.2 two-agent settlement system: JSON API
fetches structured facts, LLM Inference returns the bounded final verdict, and `VigiliaEscrow` applies deterministic
claim policy. LLM Parse Website remains disabled for settlement.
The live proof is recorded in `docs/13_TWO_AGENT_SETTLEMENT_RUNBOOK.md` and
`docs/proofs/2026-06-01-two-agent-settlement-rpc-proof.md`. Additional 2026-06-01 RPC runs covered `NeedsReview`,
malformed-facts `VerificationFailed` plus recovery, `ClientApprovalOnly`, and `ReviewWindowAutoClaim`.

`deployments/somnia-testnet-50312-two-agent-settlement-hardened.json` records the v0.2.3 hardened redeployment: fresh
escrow and verifier with timeout liveness, `claimTo`, NeedsReview resubmission, pull-based cancel refunds, and unused LLM
budget refunds on JSON-stage failure. Live Makefile E2E proof:
`docs/proofs/2026-06-01-two-agent-settlement-hardened-rpc-proof.md`. Blockscout verification returned `Response: OK` for
both contracts after indexer catch-up.

Each artifact should include a `deploymentName`, `version`, and public agent configuration. Do not overwrite older
artifacts when adding a new deployment line.

The `.env` file contains private or local inputs, including private keys and machine-specific settings, and must not be committed. Deployment JSON may intentionally duplicate non-secret `.env` values because it is the public output snapshot of a deployment.

Foundry broadcast traces remain under `broadcast/`. Those traces are useful for debugging, but they are not the canonical public deployment artifact for this project.

The v0.1.0 JSON API verifier should not be presented as supporting LLM Inference or LLM Parse Website by switching
agent IDs. v0.2.0 should add explicit LLM Parse Website and/or LLM Inference verifier/coordinator logic with the correct
Somnia payloads and bounded-result handling.

Live smoke status on 2026-05-30/31: the v0.1.0 JSON API Request flow has been proven by official Somnia RPC
receipts/logs: JSON API Request -> platform callback -> verifier bounded result -> escrow verdict recording. Shannon
explorer search and address tabs may be incomplete or stale for these transactions, so direct RPC receipts are the
canonical proof. The v0.1.0 deployment is JSON API only, not multi-agent and not LLM Parse Website / LLM Inference.
See `docs/10_DEPLOYMENT_AND_DEMO_RUNBOOK.md` and `docs/proofs/2026-05-30-json-api-rpc-proof.md` for transaction hashes,
request IDs, decoded events, the explorer caveat, and the gas-limit note. Blockscout verification now reports both
deployed contracts as already verified.

Local scratch artifacts can use `*.local.json`; those files are ignored by git.
