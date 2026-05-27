# Markets and Use Cases

## Primary Customer Segments

Vigilia can serve multiple markets, but they should be phased carefully. The first version should focus on the most objective and demoable workflows.

| Rank | Segment | Buildability | Startup Potential | Somnia Fit | Recommendation |
|---:|---|---:|---:|---:|---|
| 1 | Hackathons / grants / accelerators | High | High | Excellent | Best MVP wedge |
| 2 | Freelance software milestone escrow | Medium-high | Very high | Excellent | Best commercial extension |
| 3 | AI-agent work marketplace | Medium | Very high | Excellent | Strong future narrative |
| 4 | Agencies / teams | Medium | High | Good | V2 |
| 5 | Creator campaigns | Medium | Medium-high | Good | Later |
| 6 | Recruiting trials | Medium-low | High | Medium | Later, more sensitive |

## Segment 1: Hackathons, Grants, and Accelerators

### Problem

Programs need to review many submissions and milestones manually:

- GitHub repository checks.
- README checks.
- deployment checks.
- demo link checks.
- video link checks.
- milestone completeness checks.
- payout eligibility decisions.

This creates reviewer bottlenecks and weak public audit trails.

### Vigilia Workflow

```text
program creates milestone
→ funds escrow or reward pool
→ builder submits evidence
→ agents verify public artifacts
→ milestone is marked COMPLETE / NEEDS_REVIEW / INCOMPLETE
→ reward is claimable or review is requested
→ Data Stream proof record updates builder profile
```

### Why This Is the Best MVP Wedge

- Easy to understand.
- Strongly aligned with Somnia Agentathon.
- Relevant to ecosystems that run grants and builder programs.
- Public technical artifacts are realistic to verify.
- Does not require full marketplace network effects.

### Example Milestone

```text
Milestone: Deploy a working Somnia Agent integration
Reward: 100 mock USDC or STT-denominated test reward
Requirements:
- public GitHub repo
- README with setup instructions
- deployed contract address on Somnia testnet
- agent callback handler
- demo transaction / proof link
```

## Segment 2: Freelance Software Milestone Escrow

### Problem

Clients want confidence that paid technical work is delivered. Contractors want faster payment and less subjective delay.

### Vigilia Workflow

```text
client creates project
→ client funds milestone escrow
→ contractor submits GitHub / deployment / docs evidence
→ agents verify objective signals
→ client can approve, challenge, or wait for review window
→ contractor claims if policy permits
```

### Why It Is Strong

This builds on proven escrow patterns while adding autonomous verification. The product is not only non-custodial escrow; it is evidence-aware escrow.

### Suitable Work Types

Best early work types:

- smart-contract delivery,
- frontend feature delivery,
- documentation delivery,
- repo setup,
- integration demos,
- bug-fix PRs,
- deployment tasks,
- weekly technical reports.

Avoid first:

- private client work,
- subjective design work,
- private Slack/Figma evidence,
- purely hourly billing,
- non-public deliverables.

## Segment 3: AI-Agent Work Marketplace

### Problem

As autonomous agents complete tasks, buyers need to know:

- Did the agent actually complete the task?
- Is there public evidence?
- Should the agent be paid?
- Can the agent build reputation?
- Can the buyer constrain agent budgets?

### Vigilia Workflow

```text
human/protocol creates task
→ AI agent accepts or is assigned
→ agent performs public work
→ evidence is submitted
→ Somnia Agents verify output
→ smart account / agent wallet receives bounded payment
→ Data Stream record updates agent reputation
```

### Why It Matters

This could become a settlement layer for autonomous labor. AI agents need payment, budgets, permissions, reputation, and public receipts. Vigilia can provide that without starting as a broad marketplace.

## Segment 4: Agencies and Teams

### Future Use Cases

- multi-contributor milestone splits,
- team payout distribution,
- agency-managed clients,
- subcontractor proof records,
- bulk milestone settlement,
- internal proof-of-work history.

### Recommendation

Do not build for this in MVP. Keep the architecture compatible with future split payouts and multiple contractors.

## Segment 5: Creator and Campaign Work

### Possible Use Cases

- verify campaign post exists,
- verify public URL,
- verify hashtag or brand mention,
- verify view/like/comment thresholds through public APIs,
- release campaign payment.

### Caution

Social APIs are inconsistent and platform-dependent. Some verification can become fragile or subjective. This is a later vertical, not the MVP.

## Segment 6: Recruiting and Trial Tasks

### Possible Use Cases

- paid code challenges,
- trial project escrow,
- probation milestone payouts,
- contributor reputation records.

### Caution

This can involve HR/privacy sensitivity. The MVP should avoid private identity-heavy workflows.

## Product Ranking Against Other Ideas

| Rank | Product Idea | Assessment |
|---:|---|---|
| 1 | Vigilia: agent-verified milestone escrow | Best balance of real value, Somnia-native primitives, and buildability |
| 2 | Agent work escrow / AI-agent task settlement | Strong future expansion; larger market but harder marketplace dynamics |
| 3 | Agent treasury accounts | Interesting infrastructure but needs a workflow wrapper |
| 4 | Real-time game economy governor | Very Somnia-native but more dependent on game/UI execution |
| 5 | DePIN SLA monitor | Strong data-stream fit but harder to demo with real devices |
| 6 | AI stablecoin | Technically interesting but regulatory-heavy and too close to reserve-oracle/vault guard patterns |
| 7 | Prediction/outcome markets | Not recommended for this project; likely crowded, riskier, and not the cleanest fit for this user/work-settlement thesis |

## For Whom?

### Builders / Contractors

- get paid faster,
- reduce approval friction,
- submit public proof once,
- build portable reputation.

### Clients / Companies

- fund work safely,
- reduce manual verification,
- keep transparent proof trails,
- use review windows and disputes when needed.

### Grant Programs / Accelerators

- verify many milestones at scale,
- publish transparent records,
- reduce reviewer load,
- reward builders with less manual overhead.

### AI-Agent Operators

- fund tasks for autonomous agents,
- verify agent outputs,
- pay agents based on evidence,
- build agent reputation.

### Somnia Ecosystem

- showcase Agents, Reactivity, and Data Streams in one real product,
- create a useful platform for builder programs,
- generate reusable on-chain ecosystem contribution records.
