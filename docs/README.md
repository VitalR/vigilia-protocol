# Vigilia Documentation

This directory contains the product, architecture, runbook, deployment, and proof notes for Vigilia Protocol.

Vigilia is a Somnia-native agent-verified work settlement protocol. The final hackathon MVP has two live surfaces:

- **Milestone Escrow**: fixed technical work settlement through JSON facts + LLM bounded verdicts.
- **GrantRound**: grant/hackathon prize pools with agent screening and judge-selected finalists.

## Start Here

| Doc | Purpose |
|---|---|
| [`../README.md`](../README.md) | Judge-facing overview and quickstart |
| [`SUBMISSION_GUIDE.md`](./SUBMISSION_GUIDE.md) | Short review path for judges/ecosystem teams |
| [`DEPLOYMENTS.md`](./DEPLOYMENTS.md) | Canonical Somnia testnet deployment table |
| [`proofs/2026-06-08-final-demo-data.md`](./proofs/2026-06-08-final-demo-data.md) | Final live demo proof and dashboard-equivalent reads |

## Product

| Doc | Notes |
|---|---|
| [`01_PRODUCT_THESIS.md`](./01_PRODUCT_THESIS.md) | Core positioning: agent-verified work settlement |
| [`02_MARKETS_AND_USE_CASES.md`](./02_MARKETS_AND_USE_CASES.md) | Hackathons/grants wedge, freelance escrow, AI-agent work |
| [`07_MVP_ROADMAP_AND_RISKS.md`](./07_MVP_ROADMAP_AND_RISKS.md) | Shipped MVP, roadmap, and risks |
| [`14_GRANT_ROUND_AND_FINALISTS.md`](./14_GRANT_ROUND_AND_FINALISTS.md) | GrantRound product/design note |

## Architecture

| Doc | Notes |
|---|---|
| [`03_WHY_SOMNIA.md`](./03_WHY_SOMNIA.md) | Why Somnia Agents and EVM settlement matter |
| [`04_SYSTEM_ARCHITECTURE.md`](./04_SYSTEM_ARCHITECTURE.md) | System diagrams, modules, and trust boundaries |
| [`05_CONTRACT_DESIGN.md`](./05_CONTRACT_DESIGN.md) | Contract states, actions, and policy rules |
| [`06_AGENT_AND_DATA_FLOWS.md`](./06_AGENT_AND_DATA_FLOWS.md) | Agent pipeline, callbacks, Data Streams path |
| [`09_VERIFICATION_FAILURE_RECOVERY_FLOW.md`](./09_VERIFICATION_FAILURE_RECOVERY_FLOW.md) | Retry/recovery paths for failed verification |

## Runbooks

| Doc | Status |
|---|---|
| [`13_TWO_AGENT_SETTLEMENT_RUNBOOK.md`](./13_TWO_AGENT_SETTLEMENT_RUNBOOK.md) | Canonical hardened milestone escrow runbook |
| [`15_GRANT_ROUND_RUNBOOK.md`](./15_GRANT_ROUND_RUNBOOK.md) | Canonical GrantRound v0.4 runbook |
| [`10_DEPLOYMENT_AND_DEMO_RUNBOOK.md`](./10_DEPLOYMENT_AND_DEMO_RUNBOOK.md) | Historical v0.1 JSON API smoke runbook |
| [`11_MULTI_AGENT_CANARY_RUNBOOK.md`](./11_MULTI_AGENT_CANARY_RUNBOOK.md) | Historical canary runbook |
| [`12_MULTI_AGENT_SETTLEMENT_RUNBOOK.md`](./12_MULTI_AGENT_SETTLEMENT_RUNBOOK.md) | Historical v0.2.1 multi-agent settlement runbook |

## Proofs

Use proof docs for transaction hashes, request IDs, callback notes, final states, and caveats.

| Proof | Purpose |
|---|---|
| [`proofs/2026-06-08-final-demo-data.md`](./proofs/2026-06-08-final-demo-data.md) | Final dashboard/demo data proof |
| [`proofs/2026-06-03-grant-round-three-agent-proof.md`](./proofs/2026-06-03-grant-round-three-agent-proof.md) | ThreeAgent GrantRound proof |
| [`proofs/2026-06-03-final-demo-scenarios.md`](./proofs/2026-06-03-final-demo-scenarios.md) | Final GrantRound/Escrow scenario proof |
| [`proofs/2026-06-01-two-agent-settlement-hardened-rpc-proof.md`](./proofs/2026-06-01-two-agent-settlement-hardened-rpc-proof.md) | Hardened TwoAgent escrow proof |

## Development

| Doc | Purpose |
|---|---|
| [`dev/SOLIDITY_STYLE.md`](./dev/SOLIDITY_STYLE.md) | Solidity style and testing rules |
| [`VIGILIA_MASTER_SPEC.md`](./VIGILIA_MASTER_SPEC.md) | Broader master spec and historical context |
| [`08_REFERENCE_LINKS.md`](./08_REFERENCE_LINKS.md) | Somnia and related references |

## Current No-Overclaim Rules

- This is a Somnia testnet hackathon MVP, not a production-audited protocol.
- Agents screen public evidence and return bounded verdicts.
- Agents do not choose winners and do not directly move arbitrary funds.
- Judges/sponsors select GrantRound finalists.
- Clients or policy rules determine milestone settlement paths.
- Manual screening exists as recovery, not as the flagship product flow.
