# Deployments

This directory stores public deployment artifacts for Vigilia Protocol.

Deployment JSON files are safe to commit. They contain deployed contract addresses, public network metadata, and non-secret deployment configuration so reviewers and demo operators can reproduce which contracts were deployed and how they were configured.

`deployments/somnia-testnet-50312.json` currently records `vigilia-json-api-smoke` `v0.1.0`, the first JSON API Request
smoke deployment on Somnia testnet. It proves the real Somnia JSON API request/callback plumbing and the escrow
settlement path.

Each artifact should include a `deploymentName`, `version`, and `activeAgentType`. A later `vigilia-multi-agent-demo`
deployment can carry the final multi-agent verifier story without rewriting history.

The `.env` file contains private or local inputs, including private keys and machine-specific settings, and must not be committed. Deployment JSON may intentionally duplicate non-secret `.env` values because it is the public output snapshot of a deployment.

Foundry broadcast traces remain under `broadcast/`. Those traces are useful for debugging, but they are not the canonical public deployment artifact for this project.

The v0.1.0 JSON API verifier should not be presented as supporting LLM Inference or LLM Parse Website by switching
agent IDs. v0.2.0 should add explicit LLM Parse Website and/or LLM Inference verifier/coordinator logic with the correct
Somnia payloads and bounded-result handling.

Local scratch artifacts can use `*.local.json`; those files are ignored by git.
