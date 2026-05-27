# Why Somnia

## Core Claim

Vigilia should not be a generic automation project deployed to Somnia. It should be a Somnia-native application that combines Agents, Reactivity, Data Streams, and EVM escrow in a workflow that is difficult to build cleanly on a traditional passive blockchain.

## Somnia Features Vigilia Uses

| Somnia Feature | Vigilia Usage |
|---|---|
| EVM-compatible chain | Solidity escrow, registries, policy, payout logic, Foundry deployment |
| Network tooling | Testnet/mainnet RPCs, explorers, Multicall, CreateX, EntryPoint where needed |
| Somnia Agents | Public evidence verification from APIs, websites, and LLM classification |
| JSON API Request Agent | GitHub metadata, package metadata, status APIs, public endpoint checks |
| LLM Parse Website Agent | README/docs/demo page extraction |
| LLM Inference Agent | Bounded milestone verdicts such as COMPLETE / NEEDS_REVIEW / INCOMPLETE |
| Agent receipts | Evidence that agent requests executed and produced callbacks/results |
| Reactivity | Verification can start when a submission event happens; dashboard updates without polling |
| Cron subscriptions | Review-window expiry, deadline checks, auto-approval/refund windows |
| Data Streams | Typed work records, evidence records, verification records, settlement records, reputation feed |
| Protofire / DIA price feeds | Optional USD-denominated budgeting, fee display, reward normalization |

## Why This Is Difficult on Traditional Chains

On a normal EVM chain, the same workflow requires a lot of centralized infrastructure:

```text
submission event
→ centralized backend detects event
→ backend calls GitHub API
→ backend scrapes website
→ backend calls LLM
→ backend writes private DB state
→ backend triggers payout tx
→ custom indexer updates UI
→ proof/reputation is non-portable
```

With Somnia, the product can be designed around native primitives:

```text
submission event
→ Reactivity triggers verification flow
→ Somnia Agents verify public evidence
→ escrow contract receives agent callbacks
→ policy contract gates settlement
→ Data Streams publish public typed records
→ UI subscribes to live work/reputation data
```

The product is stronger because the verification and settlement loop is not only a private backend process. It becomes a public, composable, verifiable workflow.

## Somnia-Native Product Loop

The strongest product loop is:

```text
1. Funded task or milestone is created.
2. Builder submits public evidence.
3. Submission event is emitted.
4. Reactivity detects the event and/or updates the dashboard.
5. AgentVerifier requests Somnia Agent checks.
6. Agents fetch API data, parse websites, and classify the result.
7. Contract receives bounded callback result.
8. Policy engine transitions task state.
9. Escrow enables claim, review, or resubmission.
10. Data Streams publish typed proof-of-work records.
11. Builder/agent reputation updates.
```

## Agent Use-Case Mapping

Somnia lists broad agent use-case categories such as Oracles, AI Services, Outbound Communication, and Data Processing. Vigilia maps each to a concrete product function:

| Agent Use-Case Category | Vigilia Product Function |
|---|---|
| Oracles | Fetch GitHub/API/deployment/status evidence |
| AI Services | Evaluate milestone completeness using constrained verdicts |
| Outbound Communication | Optional notifications to client, contractor, reviewer, or program operator |
| Data Processing | Convert scattered public evidence into structured proof-of-work records |

## Why This Is More Than Escrow

Traditional escrow answers:

> Are funds locked and can the client release them?

Vigilia answers:

> Was the work publicly evidenced, was it verified by agents, did policy permit settlement, and can anyone reuse the proof record later?

## Why This Helps Somnia

Vigilia can become useful to Somnia itself and its ecosystem:

- run agentathon/grant milestones,
- verify builder contributions,
- publish public project completion records,
- onboard AI-agent developers,
- showcase multiple Somnia primitives in a single practical app,
- provide reusable infrastructure for future autonomous work markets.

## Testnet Caveat

Some Somnia primitives, especially Reactivity, may be testnet-only or evolving. The MVP should degrade gracefully:

- core escrow and submission contracts must work without Reactivity;
- Reactivity can provide automation/live updates where available;
- manual `requestVerification` fallback should exist;
- Data Streams should be used for public records but not block core escrow safety if temporarily unavailable.

## Optional Price Feeds

Protofire and DIA feeds can be used later for:

- USD display of reward value,
- fee calculation in USD terms,
- stablecoin or native token accounting,
- grant budget normalization.

They are not required for the first MVP unless the demo specifically needs USD-denominated budget views.
