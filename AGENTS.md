# AGENTS.md — Vigilia Protocol Engineering Guide

## Project

Vigilia is an agent-verified work settlement protocol on Somnia.

Clients, grant programs, and AI-agent operators can fund tasks or milestones in escrow. Builders submit public evidence such as GitHub repositories, deployment addresses, docs, demos, and test artifacts. Somnia Agents verify the evidence through API requests, website parsing, and deterministic LLM classification. The escrow contract then enables payout, review, or resubmission, while Somnia Data Streams publish portable proof-of-work records.

## Current implementation priority

Build the MVP incrementally.

Do not build a full marketplace, hourly contracts, KYC, fiat payouts, messaging, complex arbitration, or full reputation system yet.

The first useful protocol flow is:

1. Client creates a task.
2. Client funds escrow.
3. Contractor submits public evidence.
4. Agent verifier records a bounded verdict.
5. Task becomes `Complete`, `NeedsReview`, or `Incomplete`.
6. Contractor can claim after client approval or after a valid review window.
7. Events expose enough data for Reactivity and Data Streams integration.

## Important docs to read first

Read these before implementing:

- `docs/VIGILIA_MASTER_SPEC.md`
- `docs/01_PRODUCT_THESIS.md`
- `docs/03_WHY_SOMNIA.md`
- `docs/04_SYSTEM_ARCHITECTURE.md`
- `docs/05_CONTRACT_DESIGN.md`
- `docs/06_AGENT_AND_DATA_FLOWS.md`
- `docs/07_MVP_ROADMAP_AND_RISKS.md`
- `docs/dev/SOLIDITY_STYLE.md`

## Solidity style

Follow `docs/dev/SOLIDITY_STYLE.md`.

Key rules:
- Use `pragma solidity 0.8.34;`
- Prefix function parameters with `_`
- Use custom errors instead of revert strings
- Add rich NatSpec for public and external functions
- Emit events for meaningful state transitions
- Optimize for clarity over compactness
- Use explicit state machines and clear authorization checks
- Do not write fake tests or empty assertions

## Architecture guidance

Prefer a pragmatic MVP over excessive modularity.

For the first implementation, a compact core contract is acceptable if it keeps the state machine clear. Avoid premature splitting into many contracts unless it materially improves safety or testability.

Recommended MVP contracts:

- `VigiliaEscrow.sol`
- `interfaces/IVigiliaVerifier.sol`
- `mocks/MockVerifier.sol`
- `mocks/MockERC20.sol` if needed for ERC20 escrow tests

Later contracts can include:

- `VigiliaProjectRegistry.sol`
- `VigiliaSubmissionRegistry.sol`
- `VigiliaAgentVerifier.sol`
- `VigiliaReputation.sol`
- `VigiliaDataStreamPublisher` off-chain service

## Security model

The AI or agent verifier must not directly control arbitrary fund movement.

Use this pattern:

- agent/verifier returns bounded verdict
- escrow contract applies deterministic policy
- payout is pull-based through `claim`
- disputes and challenge windows pause settlement
- invalid or unknown verdicts fail closed

Preferred verdict enum:

```solidity
enum VerificationVerdict {
    Unknown,
    Complete,
    NeedsReview,
    Incomplete
}
```

Preferred task states:
```solidity
enum TaskState {
    None,
    Created,
    Funded,
    Submitted,
    VerifiedComplete,
    NeedsReview,
    Incomplete,
    Approved,
    Claimed,
    Disputed,
    Resolved,
    Cancelled
}
```

Testing expectations

Use Foundry.

Every implemented feature must include real tests:

positive path
negative path
authorization
state transition correctness
accounting correctness
boundary conditions
event emission

Use exact custom-error selectors where practical.

Test naming:
```solidity
function test_CreateTask_ClientCreatesTask() public {}
function test_FundTask_ClientFundsEscrow() public {}
function test_SubmitWork_ContractorSubmitsEvidence() public {}
function test_SubmitWork_UnauthorizedCallerReverts() public {}
function test_Claim_ContractorClaimsApprovedTask() public {}
```

Development commands

Run before completing work:
```bash
forge build
forge test
forge fmt
```

Decision policy for agents

Be senior and independent.

If the docs propose an approach that is inefficient, unsafe, or over-scoped, use a better approach and explain it in the final handoff.

---

## Efficient implementation strategy

The docs mention multiple contracts, but for speed I would **not start with 6 contracts**.

For hackathon velocity, start with this:

```text
src/
├── VigiliaEscrow.sol
├── interfaces/
│   └── IVigiliaVerifier.sol
└── mocks/
    ├── MockVerifier.sol
    └── MockERC20.sol
```

Why?

A lot of early bugs in escrow systems come from cross-contract ownership, stale IDs, duplicated state, or inconsistent transitions. A single well-tested core escrow state machine is more efficient for MVP.

Phase 1 contract model

Use one core contract:

VigiliaEscrow

It should handle:

task creation
funding
evidence submission
mock verifier callback / verdict record
client approval
contractor claim
basic dispute pause
cancellation/refund where safe
Keep agent integration abstract first

Do not integrate Somnia Agents in the first code step.

Use:
```solidity
interface IVigiliaVerifier {
    function requestVerification(uint256 _taskId, uint256 _submissionId, string calldata _evidenceURI) external returns (bytes32 requestId);
}
```

Then:
```
Phase 1: MockVerifier
Phase 2: SomniaAgentVerifier
Phase 3: Reactivity listener
Phase 4: Data Streams publisher
```
This avoids blocking core escrow implementation on Somnia testnet integration.

Use pull payments

Do not push payment in the verifier callback.

Better:
```
verifier marks task complete
→ claim becomes available
→ contractor calls claim
```

This avoids callback reentrancy/payment coupling and makes debugging easier.
