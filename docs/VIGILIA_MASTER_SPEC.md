# Vigilia Master Spec

This file is a single-file condensed copy of the current product direction for quick ingestion by AI coding agents or future planning passes.

## Product Definition

Vigilia is an agent-verified work settlement protocol on Somnia. Clients, grant programs, and AI-agent operators can fund tasks or milestones in escrow. Builders submit public evidence such as GitHub repositories, deployment addresses, docs, and demos. Somnia Agents verify the evidence through API requests, website parsing, and deterministic LLM classification. The escrow contract then enables payout, review, or resubmission, while Somnia Data Streams publish portable proof-of-work records.

## Category

Agent-verified work settlement.

Alternative positioning:

- Verifiable milestone settlement for builders and autonomous agents.
- Proof-of-work escrow for public technical work.
- Settlement layer for the agent economy.

## Target Users

- Hackathons, grants, accelerators.
- Freelance software clients and contractors.
- AI-agent operators.
- Agencies and technical teams.
- Future creator/recruiting/program workflows.

## Why Somnia

Vigilia uses Somnia primitives as product infrastructure:

- Somnia Agents verify public evidence from APIs, websites, and LLM classification.
- Reactivity detects submission events and updates the dashboard without polling.
- Data Streams publish typed proof-of-work records.
- EVM compatibility enables Solidity escrow and Foundry development.
- Optional price feeds support USD-denominated budgets and fee display.

The product is difficult on traditional chains because it would require centralized verifiers, scrapers, cron jobs, LLM backends, indexers, private databases, and manual payout bots.

## Core Flow

```text
create task
→ fund escrow
→ submit public evidence
→ request agent verification
→ agents inspect evidence
→ bounded verdict returned
→ policy transitions task state
→ payout/review/resubmission
→ Data Stream proof record
→ reputation update
```

## MVP

Build:

- fixed-task escrow,
- simple project/task registry,
- evidence submission,
- agent verifier with callback handling,
- bounded verdicts,
- client approval,
- review-window claim path,
- resubmission path,
- simple dispute freeze,
- Data Stream proof records,
- dashboard timeline,
- Foundry tests,
- deterministic demo scripts.

Do not build first:

- full marketplace,
- bidding/messaging,
- hourly contracts,
- KYC/fiat,
- complex arbitration,
- private evidence verification.

## Contracts

Proposed modules:

- `VigiliaProjectRegistry`
- `VigiliaTaskRegistry`
- `VigiliaEscrow`
- `VigiliaSubmissionRegistry`
- `VigiliaAgentVerifier`
- `VigiliaPolicy`
- `VigiliaDisputeResolver`
- `VigiliaReputation`

## Verdicts

```text
COMPLETE      → requirements appear satisfied; payout can become claimable after approval/window.
NEEDS_REVIEW  → ambiguous or partial evidence; human/operator review required.
INCOMPLETE    → required evidence missing; resubmission required.
```

## State Machine

```text
Created → Funded → Submitted → Verifying
Verifying → Complete / NeedsReview / Incomplete
Complete → Claimable via client approval or review-window expiry
Claimable → Paid
Incomplete → Submitted via resubmission
NeedsReview → Claimable or Incomplete via operator review
Any active state → Disputed when challenged
Disputed → Paid / Refunded / Split by resolver
```

## Data Stream Schemas

- `ProjectCreated`
- `TaskCreated`
- `WorkSubmitted`
- `AgentVerification`
- `TaskSettled`
- `DisputeRecord`
- `ReputationUpdate`

## Demo Scenario

Program creates a task:

```text
Task: Build a Somnia Agent callback integration
Reward: 100 mock USDC
Evidence required: GitHub repo, README, deployment address, demo URL
```

Builder submits evidence. Somnia Agents verify repo/docs/deployment. LLM returns `COMPLETE` with confidence and summary. Client approves or review window expires. Contractor claims reward. Data Stream publishes a proof record.

## Roadmap

V1: hackathon/grant milestone product.
V2: freelance technical milestone escrow.
V3: AI-agent work settlement.
V4: marketplace and team workflows.
V5: enterprise/program operations.

## Key Risks

- Somnia integration complexity.
- Agent verification quality.
- Public-evidence limitation.
- Over-scoping into full marketplace.
- Disputes and subjective work.
- Regulatory/payment complexity for real freelance payouts.

## Safety Principles

- AI classifies evidence; contracts enforce policy.
- AI never directly executes arbitrary payouts.
- Unknown/failed agent results fail closed.
- Ambiguous work goes to human review.
- Public technical evidence is the MVP scope.
