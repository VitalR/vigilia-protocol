# Agent and Data Flows

## Core Verification Flow

```text
1. Client/program creates and funds a task.
2. Builder/contractor/AI agent submits public evidence.
3. SubmissionRegistry emits WorkSubmitted.
4. Reactivity listener detects the event and/or UI updates instantly.
5. AgentVerifier creates one or more Somnia Agent requests.
6. Agents inspect public evidence.
7. Agent callback returns bounded result.
8. Policy contract updates task state.
9. Escrow enables payout, review, dispute, or resubmission.
10. Data Streams publish durable proof records.
```

## Agent Types

### JSON API Request Agent

Purpose:

- fetch public structured data.

Example checks:

- GitHub repository exists,
- repo has commits after task creation,
- PR is merged,
- issue is closed,
- package release exists,
- public status API returns success,
- deployment metadata endpoint returns expected data.

Example outputs:

```text
repo_exists=true
commit_count=27
last_commit_timestamp=...
pr_merged=true
```

### LLM Parse Website Agent

Purpose:

- extract facts from public web pages.

Example checks:

- README contains setup instructions,
- docs contain deployment address,
- demo page contains required project name,
- changelog mentions completed feature,
- public article includes campaign deliverables.

Example outputs:

```text
has_setup_section=true
has_deployment_address=true
has_agent_callback_description=true
summary="README describes Somnia Agent callback flow and includes deployment link."
```

### LLM Inference Agent

Purpose:

- classify evidence against requirements.

Use bounded outputs only:

```text
COMPLETE
NEEDS_REVIEW
INCOMPLETE
```

Recommended result schema:

```json
{
  "verdict": "COMPLETE",
  "confidence": 89,
  "summary": "Repo includes required Somnia Agent callback contract, deployment address, docs, and demo instructions.",
  "missing": []
}
```

Do not let LLM return arbitrary settlement instructions.

## Multi-Agent Verification Pipeline

A strong future version can use staged verification:

```text
Stage 1: JSON API Agent checks objective API facts.
Stage 2: Website Parse Agent extracts facts from docs/demo pages.
Stage 3: LLM Inference Agent compares facts against task requirements.
Stage 4: Policy contract maps verdict to state transition.
```

MVP can simplify this to one or two checks if integration time is limited.

## Agent Request Lifecycle

Conceptual lifecycle:

```text
requestVerification(submissionId)
→ encode agent request
→ pay request/deposit budget
→ store requestId => submissionId
→ platform/agent executes asynchronously
→ callback arrives
→ validate platform/callback sender
→ validate requestId is known and pending
→ decode response
→ store result
→ transition task state
→ emit event
```

## Callback Security

Required checks:

1. `msg.sender` must be trusted Somnia Agent platform/callback sender.
2. Request ID must exist and be pending.
3. Submission ID must exist and be in `Verifying` state.
4. Callback cannot be replayed.
5. Response must decode into expected result type.
6. Unknown verdicts fail closed.
7. Agent errors/timeouts route to retry or manual review.

## Reactivity Use

Reactivity should be used for:

- instantly updating dashboard on `TaskCreated`, `WorkSubmitted`, `VerificationCompleted`, `TaskPaid`, and `DisputeRaised`;
- triggering verification after `WorkSubmitted`, if on-chain or off-chain reactivity path is stable;
- deadline and review-window automation via cron/system events, where available.

Fallback if Reactivity is unavailable:

- user/operator can call `requestVerification` manually;
- dashboard can use normal event indexing/RPC polling;
- core escrow remains safe and usable.

## Data Streams Strategy

Data Streams are not just logs. They are Vigilia's public work memory.

Use them for:

- portable proof-of-work records,
- builder profiles,
- grant dashboards,
- work history,
- AI-agent reputation,
- third-party indexing,
- future recruiter/client views.

## Proposed Data Stream Schemas

### `ProjectCreated`

```text
uint64 timestamp
bytes32 projectId
address client
address operator
address rewardToken
string projectType
string metadataURI
```

### `TaskCreated`

```text
uint64 timestamp
bytes32 taskId
bytes32 projectId
address client
address assignee
address rewardToken
uint256 rewardAmount
uint64 deadline
uint64 reviewWindow
string requirementsURI
```

### `WorkSubmitted`

```text
uint64 timestamp
bytes32 taskId
bytes32 submissionId
address submitter
string evidenceURI
bytes32 evidenceHash
string repoUrl
string docsUrl
string demoUrl
address deploymentAddress
```

### `AgentVerification`

```text
uint64 timestamp
bytes32 taskId
bytes32 submissionId
bytes32 requestId
uint8 verdict
uint8 confidence
bytes32 evidenceHash
string summary
string missingFields
```

### `TaskSettled`

```text
uint64 timestamp
bytes32 taskId
bytes32 submissionId
address assignee
address rewardToken
uint256 grossAmount
uint256 feeAmount
uint256 netAmount
uint8 settlementType
bytes32 verificationRecordId
```

### `DisputeRecord`

```text
uint64 timestamp
bytes32 taskId
bytes32 submissionId
address raisedBy
string reasonURI
uint8 disputeState
```

### `ReputationUpdate`

```text
uint64 timestamp
address worker
bytes32 taskId
bytes32 projectId
uint8 workType
uint8 verdict
bytes32 verificationHash
string skillsURI
```

## Demo Scenario 1: Hackathon Milestone

```text
Program: Somnia Agentathon Mini-Grant
Task: Deploy a working Somnia Agent callback contract
Reward: 100 mock USDC
Evidence: GitHub repo, README, deployment address, demo transaction
Agent verdict: COMPLETE
Outcome: reward claimable; Data Stream proof record published
```

## Demo Scenario 2: Freelance Software Task

```text
Client creates fixed task: Build a Somnia Data Stream publisher script
Contractor submits repo + docs + test log
Agent verifies repo and docs
LLM verdict: NEEDS_REVIEW because deployment address missing
Outcome: no payout yet; contractor resubmits with deployment address
Second verdict: COMPLETE
Client approves or review window expires
Contractor claims payout
```

## Demo Scenario 3: AI-Agent Work

```text
Operator funds recurring task: Publish weekly protocol health summary
AI agent submits public report URL and data hash
Website Parse Agent extracts summary
LLM classifies it against required sections
Outcome: payment to agent wallet and reputation update
```

## Evidence Quality Levels

| Evidence Level | Description | MVP Use |
|---|---|---|
| Level 0 | Self-reported text only | Avoid for auto-settlement |
| Level 1 | Public URL exists | Accept as weak signal |
| Level 2 | Public URL contains required fields | Good signal |
| Level 3 | Public API confirms objective state | Strong signal |
| Level 4 | On-chain deployment/event proof exists | Strongest signal |

Recommended MVP auto-settlement should require at least one strong objective signal plus LLM classification.

## Verdict Policy

```text
COMPLETE:
  Requirements appear satisfied.
  Claim becomes possible after client approval or review-window expiry.

NEEDS_REVIEW:
  Some evidence is ambiguous or partial.
  Human/operator review required.

INCOMPLETE:
  Required evidence is missing or contradicts requirements.
  Resubmission required.
```

## Agent Failure Policy

```text
Agent request failed:
  mark submission as NEEDS_REVIEW or allow retry.

Agent timeout:
  allow manual retry; do not auto-pay.

Malformed result:
  fail closed; route to review.

Conflicting results:
  route to review or require additional verifier.
```
