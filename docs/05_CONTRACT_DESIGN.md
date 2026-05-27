# Contract Design

## Design Goals

1. Keep escrow settlement deterministic and auditable.
2. Use agents as evidence processors, not unchecked executors.
3. Support fixed tasks and simple milestone projects first.
4. Preserve a path toward freelance, grants, and AI-agent work.
5. Keep contracts modular enough to evolve without overbuilding the MVP.

## Proposed Contracts

### `VigiliaProjectRegistry.sol`

Creates and tracks projects/programs.

Possible function surface:

```solidity
function createProject(
    address client,
    address contractor,
    address rewardToken,
    string calldata metadataURI
) external returns (bytes32 projectId);

function updateProjectMetadata(bytes32 projectId, string calldata metadataURI) external;
function closeProject(bytes32 projectId) external;
```

Project types can be encoded later:

```solidity
enum ProjectType {
    Unknown,
    GrantProgram,
    FreelanceProject,
    AgentTaskGroup,
    AcceleratorTrack
}
```

### `VigiliaTaskRegistry.sol`

Creates and tracks tasks or milestones.

Possible function surface:

```solidity
function createTask(
    bytes32 projectId,
    address assignee,
    address token,
    uint256 amount,
    uint64 deadline,
    uint64 reviewWindow,
    string calldata requirementsURI
) external returns (bytes32 taskId);

function cancelTask(bytes32 taskId) external;
function extendDeadline(bytes32 taskId, uint64 newDeadline) external;
```

### `VigiliaEscrow.sol`

Holds funds and releases/refunds them according to task state.

Possible function surface:

```solidity
function fundTask(bytes32 taskId, uint256 amount) external payable;
function claim(bytes32 taskId) external;
function refund(bytes32 taskId) external;
function releaseToAssignee(bytes32 taskId) external;
```

Important rules:

- funds must be tied to a task ID;
- claimant must be the task assignee/contractor/agent wallet;
- release must be enabled by policy;
- dispute freezes claim/refund;
- fee logic should be simple in MVP.

### `VigiliaSubmissionRegistry.sol`

Stores submitted work evidence.

Possible function surface:

```solidity
function submitWork(
    bytes32 taskId,
    string calldata evidenceURI,
    bytes32 evidenceHash,
    string calldata repoUrl,
    string calldata docsUrl,
    string calldata demoUrl,
    address deploymentAddress
) external returns (bytes32 submissionId);

function resubmitWork(
    bytes32 taskId,
    bytes32 previousSubmissionId,
    string calldata evidenceURI,
    bytes32 evidenceHash
) external returns (bytes32 submissionId);
```

Evidence should be public for MVP.

### `VigiliaAgentVerifier.sol`

Integrates with Somnia Agents.

Possible function surface:

```solidity
function requestVerification(bytes32 submissionId) external payable returns (bytes32 requestId);
function handleAgentCallback(bytes32 requestId, bytes calldata response) external;
function markVerificationFailed(bytes32 requestId, bytes calldata reason) external;
```

Required security:

- validate `msg.sender` is the official/expected agent platform callback address;
- track `requestId => submissionId`;
- reject unknown request IDs;
- reject duplicate callbacks;
- decode only expected response schema;
- fail closed on unknown verdicts;
- support retries or manual review for timeout/failure.

### `VigiliaPolicy.sol`

Maps verification results to allowed state transitions.

Possible function surface:

```solidity
function onVerificationResult(
    bytes32 taskId,
    bytes32 submissionId,
    Verdict verdict,
    uint8 confidence,
    bytes32 evidenceHash
) external;

function approveByClient(bytes32 submissionId) external;
function challenge(bytes32 submissionId, string calldata reasonURI) external;
function finalizeAfterReviewWindow(bytes32 submissionId) external;
```

### `VigiliaDisputeResolver.sol`

MVP can be trusted/operator-based.

Possible function surface:

```solidity
function raiseDispute(bytes32 taskId, string calldata reasonURI) external;
function resolveDispute(
    bytes32 taskId,
    uint256 contractorAmount,
    uint256 clientRefund,
    string calldata resolutionURI
) external;
```

Dispute outcomes:

```solidity
enum DisputeOutcome {
    None,
    ContractorWins,
    ClientWins,
    Split,
    Cancelled
}
```

### `VigiliaReputation.sol`

Records completed work and supports future profile/badge logic.

Possible function surface:

```solidity
function recordCompletedTask(
    address worker,
    bytes32 taskId,
    bytes32 submissionId,
    bytes32 verificationHash
) external;
```

For MVP, reputation can mostly live in events and Data Streams.

## Core Enums

```solidity
enum TaskState {
    Unknown,
    Created,
    Funded,
    Submitted,
    Verifying,
    Complete,
    NeedsReview,
    Incomplete,
    Challenged,
    Disputed,
    Claimable,
    Paid,
    Refunded,
    Cancelled
}

enum Verdict {
    Unknown,
    Complete,
    NeedsReview,
    Incomplete
}

enum EvidenceType {
    Unknown,
    GitHubRepo,
    PullRequest,
    DeploymentAddress,
    DocsUrl,
    DemoUrl,
    TestLog,
    VideoUrl,
    PackageRelease
}
```

## State Machine

```text
Created
  └─ fundTask → Funded
Funded
  └─ submitWork → Submitted
Submitted
  └─ requestVerification → Verifying
Verifying
  ├─ Agent COMPLETE → Complete
  ├─ Agent NEEDS_REVIEW → NeedsReview
  ├─ Agent INCOMPLETE → Incomplete
  └─ Agent failure/timeout → NeedsReview or Submitted
Complete
  ├─ clientApprove → Claimable
  ├─ challenge → Challenged/Disputed
  └─ reviewWindowExpired → Claimable
Claimable
  └─ claim → Paid
Incomplete
  └─ resubmitWork → Submitted
NeedsReview
  ├─ operatorApprove → Claimable
  ├─ operatorReject → Incomplete
  └─ raiseDispute → Disputed
Disputed
  ├─ resolveToContractor → Paid
  ├─ resolveToClient → Refunded
  └─ split → Paid/Refunded
```

## Review Window Policy

A useful rule borrowed from escrow/work platforms:

```text
Agent COMPLETE → client can approve immediately or challenge during review window.
No client action after review window → contractor can claim.
Agent NEEDS_REVIEW → no auto-approval; human/operator review required.
Agent INCOMPLETE → contractor can resubmit.
```

This protects contractors from client stalling while preventing weak submissions from auto-approving.

## Midcontract-Inspired Design Elements

Borrow these ideas:

1. Fixed-price work agreements.
2. Milestone-based work agreements.
3. Review windows.
4. Claim-after-approval logic.
5. Dispute states.
6. Registry-based tracking.
7. Fee manager as a separate module.
8. Event-heavy audit trail.
9. Future extensibility toward hourly/retainer flows.

Do not borrow everything for MVP:

- full hourly billing,
- fiat payout flow,
- KYC,
- full marketplace,
- complex arbitration,
- team payroll.

## Fee Model

MVP fee model should be simple:

```solidity
uint16 protocolFeeBps;
address feeRecipient;
```

Possible future fee tiers:

- free grants/sponsored ecosystems,
- low fee for builder programs,
- SaaS fee for programs,
- protocol fee on payouts,
- enterprise/private deployments.

## Contract Safety Notes

- Use pull payments where possible.
- Use SafeERC20 for ERC20 escrow.
- Separate native STT escrow and ERC20 escrow carefully.
- Do not allow arbitrary agent-triggered calls.
- Avoid storing unbounded strings if possible; use metadata URIs and hashes.
- Prefer events + Data Streams for rich data.
- Use exact custom errors.
- Include request lifecycle tests.
- Include reentrancy protections on claim/refund/release.
- Include authorization checks for client, contractor, operator, resolver.
- Include dispute freezes.
- Include deadline/review-window edge-case tests.

## Initial Test Plan

Minimum tests:

1. Create project.
2. Create task.
3. Fund task.
4. Submit work.
5. Request verification.
6. Reject unauthorized callback.
7. Accept valid callback COMPLETE.
8. Prevent duplicate callback.
9. Mark claimable after client approval.
10. Claim payout.
11. Agent INCOMPLETE leads to resubmission.
12. Agent NEEDS_REVIEW blocks auto-claim.
13. Challenge freezes claim.
14. Resolve dispute to contractor.
15. Resolve dispute to client/refund.
16. Review window expiry enables claim only for COMPLETE verdict.
17. Fee deducted correctly.
18. Reentrancy / double claim prevention.
