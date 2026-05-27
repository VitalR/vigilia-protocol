# Vigilia Docs Pack

This folder is an early product and architecture knowledge base for **Vigilia**, a Somnia-native agent-verified work settlement protocol.

The goal is to preserve the current product direction, market reasoning, Somnia-specific architecture, escrow design, MVP scope, and future roadmap so the repository can be explored and implemented incrementally.

## Working Product Definition

**Vigilia is an agent-verified work settlement protocol on Somnia. Clients, grant programs, and AI-agent operators can fund tasks or milestones in escrow. Builders submit public evidence such as GitHub repositories, deployment addresses, docs, and demos. Somnia Agents verify the evidence through API requests, website parsing, and deterministic LLM classification. The escrow contract then enables payout, review, or resubmission, while Somnia Data Streams publish portable proof-of-work records.**

## Suggested Reading Order

1. [`01_PRODUCT_THESIS.md`](./01_PRODUCT_THESIS.md) — product idea, positioning, why this is not generic automation infra.
2. [`02_MARKETS_AND_USE_CASES.md`](./02_MARKETS_AND_USE_CASES.md) — target users, segments, product ranking, startup wedge.
3. [`03_WHY_SOMNIA.md`](./03_WHY_SOMNIA.md) — Somnia primitives and why this product is difficult on traditional chains.
4. [`04_SYSTEM_ARCHITECTURE.md`](./04_SYSTEM_ARCHITECTURE.md) — high-level architecture, modules, agent loop, data flow.
5. [`05_CONTRACT_DESIGN.md`](./05_CONTRACT_DESIGN.md) — proposed smart-contract system, states, actions, policy rules, escrow flows.
6. [`06_AGENT_AND_DATA_FLOWS.md`](./06_AGENT_AND_DATA_FLOWS.md) — verification flows, agent roles, Data Stream schemas, Reactivity paths.
7. [`07_MVP_ROADMAP_AND_RISKS.md`](./07_MVP_ROADMAP_AND_RISKS.md) — build priorities, hackathon MVP, future roadmap, pitfalls.
8. [`08_REFERENCE_LINKS.md`](./08_REFERENCE_LINKS.md) — Somnia, Agentathon, Midcontract, and related reference links.

## Recommended Repository Location

Suggested destination inside the future project repo:

```text
/docs/product/
  README.md
  01_PRODUCT_THESIS.md
  02_MARKETS_AND_USE_CASES.md
  03_WHY_SOMNIA.md
  04_SYSTEM_ARCHITECTURE.md
  05_CONTRACT_DESIGN.md
  06_AGENT_AND_DATA_FLOWS.md
  07_MVP_ROADMAP_AND_RISKS.md
  08_REFERENCE_LINKS.md
```

## Current Strategic Decision

Do **not** build a generic “agent automation infra” project as the primary product. Somnia already exposes agent, reactivity, and data-stream primitives as part of its stack. Vigilia should instead be a real application/protocol that uses those primitives to solve a concrete, valuable problem:

> **verifiable settlement of real work.**

The first wedge should be public technical milestones for hackathons, grants, accelerators, freelance software work, and later AI-agent work.
