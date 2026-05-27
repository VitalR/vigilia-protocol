# MVP, Roadmap, and Risks

## Hackathon MVP

The MVP should prove one clean loop:

```text
funded task
→ public evidence submission
→ Somnia Agent verification
→ escrow state transition
→ payout/review/resubmission
→ Data Stream proof record
```

## Recommended MVP Scope

### Must Have

1. Fixed-task escrow.
2. Simple milestone/project registry.
3. Work submission with public evidence fields.
4. Agent verification request and callback handling.
5. Bounded verdict enum.
6. Client approval path.
7. Review-window / claim path for complete submissions.
8. Resubmission path for incomplete submissions.
9. Simple dispute/challenge freeze.
10. Events for every important lifecycle step.
11. Data Stream proof records.
12. Basic dashboard.
13. Foundry tests.
14. Deterministic demo scripts.

### Should Have

1. Reactivity listener for dashboard and/or verification trigger.
2. Manual fallback for `requestVerification`.
3. Minimal reputation record.
4. Simple fee manager.
5. Mock ERC20 reward token for testnet.
6. One polished demo scenario.

### Nice To Have

1. Multi-milestone project support.
2. Cron-based review-window finalization.
3. Price-feed based USD display.
4. Multiple evidence types.
5. Agent receipts surfaced in UI.
6. Builder profile page.
7. Operator/admin review queue.

### Do Not Build in MVP

1. Full marketplace discovery.
2. Bidding/offers/messaging.
3. Full hourly contracts.
4. Retainers.
5. KYC.
6. Fiat payouts.
7. Complex arbitration.
8. Team payroll.
9. Private evidence verification.
10. Full DAO governance.

## MVP Milestones

### Milestone 1: Core Escrow and Registry

- `ProjectRegistry`
- `TaskRegistry`
- `Escrow`
- create/fund/submit/approve/claim flow
- Foundry tests

### Milestone 2: Agent Verifier

- request verification
- track request IDs
- callback authentication
- decode verdict
- state transition to complete / needs review / incomplete
- tests for unauthorized callback and duplicate callback

### Milestone 3: Data Records and Dashboard

- event indexing or simple frontend reads
- Data Stream schema draft and publisher script
- task timeline UI
- proof record UI

### Milestone 4: Somnia-Native Polish

- Reactivity listener
- live dashboard updates
- review-window finalization flow
- explorer links
- demo scripts
- README and video script

## Future Roadmap

### V1: Grant and Hackathon Product

- program dashboards,
- milestone templates,
- reward pools,
- bulk submissions,
- builder profiles,
- verified project pages.

### V2: Freelance Technical Escrow

- fixed-price contracts,
- milestone contracts,
- client/contractor review windows,
- dispute resolver,
- public work history,
- reusable client templates.

### V3: AI-Agent Work Settlement

- agent wallets / smart accounts,
- budgeted tasks,
- recurring reports,
- tool-use receipts,
- agent reputation,
- automated payout rules.

### V4: Marketplace Layer

- work discovery,
- offers,
- skill tags,
- reputation search,
- agencies / teams,
- split payouts.

### V5: Enterprise / Program Operations

- private deployments,
- compliance settings,
- SSO / role-based review,
- larger program analytics,
- custom evidence verifiers.

## Main Risks

### 1. Somnia Integration Risk

The hardest part is likely not escrow. It is making Somnia Agents, Reactivity, and Data Streams work together reliably on testnet.

Mitigation:

- build escrow core first;
- add manual verification fallback;
- integrate one agent at a time;
- use mocked agent callbacks in tests;
- make Data Streams additive, not critical to fund safety;
- maintain deterministic demo scripts.

### 2. Agent Verification Quality

Deterministic LLM inference does not mean the result is objectively true. It only means the execution should be reproducible under the agent system.

Mitigation:

- use objective public evidence where possible;
- constrain outputs;
- require confidence thresholds;
- route ambiguous cases to review;
- allow challenge/dispute;
- never let AI directly execute arbitrary payments.

### 3. Public Evidence Limitation

MVP works best for public evidence. Private work is harder.

Mitigation:

- explicitly scope MVP to public technical milestones;
- later explore encrypted evidence, permissioned reviewers, or attestations.

### 4. Over-Scoping

The project can easily become a full marketplace.

Mitigation:

- MVP must focus on one funded task and one verified payout;
- marketplace, profiles, hourly, fiat, and KYC are future work.

### 5. Disputes and Subjectivity

Some work cannot be verified automatically.

Mitigation:

- support `NEEDS_REVIEW` as a first-class state;
- preserve human/operator review;
- use agent output as evidence, not final arbitration.

### 6. Regulatory / Platform Complexity

Freelance payments, employment, taxes, KYC, and fiat payouts can become complex.

Mitigation:

- hackathon MVP should use testnet/mock tokens;
- frame as protocol/product prototype;
- focus on technical and grant milestones first.

## Demo Script

### Scene 1: Create Task

A program creates a funded technical milestone:

```text
Task: Build a Somnia Agent callback integration
Reward: 100 mock USDC
Required evidence:
- GitHub repo
- README
- deployed contract address
- demo URL
```

### Scene 2: Submit Work

Builder submits public evidence.

UI shows task state: `Submitted`.

### Scene 3: Verify Work

Somnia Agent verification starts.

UI shows:

- request ID,
- evidence being checked,
- pending state.

### Scene 4: Agent Verdict

Agent returns:

```text
verdict: COMPLETE
confidence: 89
summary: Repo contains callback contract, deployment address, README, and demo instructions.
```

UI shows state: `Complete`.

### Scene 5: Settlement

Client approves or review window is finalized.

Contractor claims reward.

UI shows state: `Paid`.

### Scene 6: Proof Record

Data Stream record appears with:

- task ID,
- submission ID,
- verdict,
- settlement amount,
- proof/evidence hash,
- worker address.

Closing message:

> Vigilia turns public work into verified, payable, portable proof.

## Success Criteria

A strong MVP should demonstrate:

1. Contract deployment on Somnia testnet.
2. Funded escrow task.
3. Public evidence submission.
4. Working or simulated Somnia Agent callback path.
5. Safe bounded verdict handling.
6. Payout/review/resubmission logic.
7. Data Stream proof record or event-backed equivalent.
8. UI timeline showing the lifecycle.
9. Tests with real assertions.
10. Clear “why Somnia” explanation.

## Honest Evaluation

This is a strong project direction because it combines:

- real payment/settlement pain,
- your escrow experience,
- Somnia-native primitives,
- hackathon relevance,
- future startup expansion,
- public proof/reputation moat.

The main pitfall is integration complexity. The safest path is to build a very narrow but polished MVP and keep broader marketplace and AI-agent labor claims as roadmap.
