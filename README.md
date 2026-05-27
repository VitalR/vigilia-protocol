# Vigilia Protocol

Agent-verified work settlement protocol on Somnia.

Vigilia lets clients, grant programs, and AI-agent operators fund tasks or milestones in escrow. Builders submit public evidence such as GitHub repositories, deployment addresses, docs, demos, and test artifacts. Somnia Agents verify the evidence through API requests, website parsing, and deterministic LLM classification. The escrow contract then enables payout, review, or resubmission, while Somnia Data Streams publish portable proof-of-work records.

## Why Vigilia

Most escrow and work platforms still rely on manual review:
- client checks the work
- operator reviews evidence
- payment is approved manually
- reputation stays trapped in a private database

Vigilia makes this flow programmable and verifiable:
- funded milestone escrow
- public evidence submission
- autonomous agent verification
- bounded settlement rules
- portable proof-of-work records

## Why Somnia

Vigilia is designed around Somnia-native primitives:
- Somnia Agents for API checks, website parsing, and LLM classification
- Somnia Reactivity for event-driven verification flows
- Somnia Data Streams for portable work and verification records
- EVM compatibility and Foundry-based Solidity development

## Current MVP

The first implementation targets a narrow, demoable flow:

1. Client or program creates a task/milestone.
2. Escrow is funded.
3. Builder submits public evidence.
4. Agent verifier classifies the submission.
5. The task enters `Complete`, `NeedsReview`, or `Incomplete`.
6. Contractor can claim after approval or valid review window.
7. Verification records are emitted and later published to Data Streams.

## Repository status

This repository is in early hackathon/product exploration stage. Contracts are experimental and unaudited.

## Documentation

See [`docs/`](./docs/) for the full product and architecture knowledge base.

Recommended starting points:
- [`docs/VIGILIA_MASTER_SPEC.md`](./docs/VIGILIA_MASTER_SPEC.md)
- [`docs/01_PRODUCT_THESIS.md`](./docs/01_PRODUCT_THESIS.md)
- [`docs/04_SYSTEM_ARCHITECTURE.md`](./docs/04_SYSTEM_ARCHITECTURE.md)
- [`docs/05_CONTRACT_DESIGN.md`](./docs/05_CONTRACT_DESIGN.md)
- [`docs/06_AGENT_AND_DATA_FLOWS.md`](./docs/06_AGENT_AND_DATA_FLOWS.md)

## Development

```bash
forge build
forge test
forge fmt
```

## License

MIT