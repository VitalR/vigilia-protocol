# Vigilia Product Thesis

## One-Liner

**Vigilia is a Somnia-native agent-verified work settlement protocol where clients, grant programs, and AI-agent operators fund tasks or milestones in escrow; builders submit public evidence; Somnia Agents verify the evidence; and escrow settlement, review, or resubmission is handled by programmable policy.**

## Short Description

Vigilia lets programs and clients fund work with autonomous milestone escrow. Builders submit public evidence such as GitHub repositories, deployment addresses, docs, test logs, demos, and videos. Somnia Agents verify the evidence through API requests, website parsing, and deterministic LLM classification. The escrow contract then marks the task as complete, needs review, or incomplete.

Current MVP proof records are exposed through on-chain events, deployment artifacts, dashboard reads, and proof docs. Somnia Data Streams are the intended next step for portable proof-of-work records that can power reputation, grant dashboards, builder profiles, and AI-agent work histories.

## Updated Thesis

The earlier idea of a general AgentOps or protocol incident-response layer is technically strong, but it risks being too horizontal because Somnia already provides important agentic infrastructure by default:

- Agents for API, website, and LLM-based compute.
- Reactivity for event-driven app flows.
- Data Streams for typed public records.
- EVM-compatible deployment and Solidity tooling.

The better product direction is an application that **requires** those primitives to be useful:

```text
funded work agreement
→ public evidence submission
→ reactive verification trigger
→ API / website / LLM agent checks
→ escrow state transition
→ payout / review / resubmission
→ public proof-of-work record
```

This is more startup-like than a generic automation framework because it has a clear user, payment flow, workflow pain, and long-term reputation moat.

## Product Category

Vigilia should define its category as:

> **Agent-verified work settlement.**

Alternative category language:

- Verifiable milestone settlement.
- Proof-of-work escrow for builders and agents.
- Autonomous work verification and payout infrastructure.
- Settlement layer for public technical work.
- Work-reputation protocol for the agent economy.

## Why This Is Valuable

Many programs, companies, protocols, and clients fund work but verify it manually:

```text
submit work
→ check repo manually
→ check docs manually
→ check deployment manually
→ inspect demo manually
→ approve payment manually
→ write status in spreadsheet manually
→ reputation disappears into private context
```

This creates payment delays, weak accountability, subjective review, fragmented proof, and repeated verification work.

Vigilia turns that into:

```text
submit public evidence
→ agents verify objective signals
→ LLM classifies against milestone requirements
→ policy contract gates settlement
→ payout / review / resubmission happens transparently
→ proof is streamed as public structured data
```

## Core Differentiation

Vigilia is **not** only escrow. Traditional on-chain escrow can already hold funds, approve work, release payments, and handle disputes.

Vigilia adds:

1. **Agent-verified evidence** — public artifacts are checked by Somnia Agents.
2. **Reactive work settlement** — submission events can trigger verification automatically.
3. **Bounded AI verdicts** — LLM output is constrained to safe states such as `COMPLETE`, `NEEDS_REVIEW`, and `INCOMPLETE`.
4. **Portable proof records** — Data Streams store typed work, evidence, verdict, and settlement records.
5. **Reputation substrate** — builders and AI agents accumulate verified public work history.

## Core User Promise

For builders and contractors:

> Submit public evidence once, get verified faster, receive payment with less manual friction, and keep portable proof of your work.

For clients, grant programs, and accelerators:

> Fund work safely, reduce manual review load, and build a transparent audit trail of what was delivered and why it was paid.

For AI-agent operators:

> Give agents a way to complete tasks, prove outputs, receive budgeted payments, and build a verifiable work history.

## Why This Is Startup-Shaped

Vigilia has several credible startup paths:

1. **Hackathon / grant operations SaaS** — programs fund milestones and verify submissions.
2. **Freelance technical escrow** — clients fund work and agents verify public deliverables.
3. **AI-agent work marketplace** — agents complete and prove recurring tasks.
4. **Builder reputation network** — verified work records become portable credentials.
5. **Protocol ecosystem tooling** — chains and ecosystems use Vigilia to manage grants and contributor programs.

## Initial Strategic Wedge

Start with public technical milestones because they are objectively verifiable:

- GitHub repository exists.
- Required README sections exist.
- Deployment address exists.
- Contract/source/demo is public.
- Tests or logs are attached.
- Docs URL exists.
- Demo video URL exists.
- Issue or PR is closed/merged.

This is easier and safer than verifying private design work, private client deliverables, or subjective hourly time.

## Strongest Initial Positioning

**Vigilia: Agent-Verified Milestone Escrow for Builders and Autonomous Agents.**

Suggested submission/pitch description:

> Vigilia is an agent-verified work settlement protocol on Somnia. Clients, grant programs, and AI-agent operators can fund tasks or milestones in escrow. Builders submit public evidence such as GitHub repositories, deployment addresses, docs, and demos. Somnia Agents verify the evidence through API requests, website parsing, and deterministic LLM classification. The escrow contract then enables payout, review, or resubmission, while Somnia Data Streams publish portable proof-of-work records.

## What Not To Build First

Avoid positioning the MVP as a full Upwork competitor. That creates unnecessary expectations:

- marketplace discovery,
- messaging,
- bidding,
- KYC,
- fiat off-ramps,
- ratings,
- complex arbitration,
- full hourly contracts,
- agency payroll.

The MVP should prove the core loop:

```text
funded milestone → public evidence → agent verification → escrow state → payout/review → proof record
```
