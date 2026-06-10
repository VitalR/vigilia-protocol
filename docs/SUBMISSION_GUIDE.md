# Submission Guide

Short path for judges, reviewers, and ecosystem teams.

## 1. Open The Live App

- Landing page: https://vigilia-protocol.vercel.app/
- Dashboard: https://vigilia-protocol.vercel.app/dashboard

The dashboard reads live Somnia testnet contracts. If an explorer/indexer is behind, use the proof docs and direct RPC reads as the source of truth.

## 2. Understand The Product

Vigilia is agent-verified work settlement on Somnia:

```text
Fund work -> submit public evidence -> Somnia Agents verify
-> bounded verdict -> contract-enforced payout/review/resubmission
```

Product surfaces:

- **Milestone Escrow** for fixed technical work.
- **GrantRound** for grant, hackathon, and accelerator prize pools.

## 3. Inspect The Deployed Stack

Canonical deployment doc:

- [`DEPLOYMENTS.md`](./DEPLOYMENTS.md)

Final live contracts:

| Surface | Address |
|---|---|
| Escrow | `0x1FA22E3a97dabB9a8C6de3a5B59eF6cCD5B2F4b9` |
| Escrow verifier | `0xdE0aC9700E591b54A418665575f2e1d329D78f3D` |
| GrantRound v0.4 | `0x5aE1918Dcaa0A00a1d647e1c9946F7FF3fB61679` |
| Grant verifier | `0xb0a1cdf062B4c295fC2A00F4bf1C84062F40d8e4` |

## 4. Review The Proof Trail

Start with:

- [`proofs/2026-06-08-final-demo-data.md`](./proofs/2026-06-08-final-demo-data.md)

That proof records final live demo rows, transaction hashes, request IDs, verdict callbacks, dashboard-equivalent aggregate reads, and caveats.

## 5. Check The Agent Evidence

Public evidence examples:

- Escrow: `https://raw.githubusercontent.com/VitalR/vigilia-protocol/main/demo/evidence/escrow-real/evidence-real-verified-complete.json`
- Grant: `https://raw.githubusercontent.com/VitalR/vigilia-protocol/main/demo/evidence/grants-real/evidence-real-verified-complete.json`
- Grant website page: `https://raw.githubusercontent.com/VitalR/vigilia-protocol/main/demo/evidence/grants-real/website-real-complete.html`

## 6. Read The Architecture

- [`04_SYSTEM_ARCHITECTURE.md`](./04_SYSTEM_ARCHITECTURE.md)
- [`06_AGENT_AND_DATA_FLOWS.md`](./06_AGENT_AND_DATA_FLOWS.md)
- [`05_CONTRACT_DESIGN.md`](./05_CONTRACT_DESIGN.md)

## 7. Run Local Checks

```bash
forge build
forge test
npm --prefix app/web run test
npm --prefix app/web run build
```

Use `.env.example` for public variable names. Never commit `.env`.

## Boundaries

Correct framing:

- Agents screen evidence.
- Clients, judges, and sponsors remain responsible for review/selection decisions.
- Contracts enforce payout, claim, refund, and winner-cap rules.
- Verdicts are bounded: `Complete`, `NeedsReview`, `Incomplete`, `VerificationFailed`.

Do not frame the project as production-audited, fully autonomous arbitrary payout execution, or AI-selected winners.
