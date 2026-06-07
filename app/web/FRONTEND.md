# Vigilia Frontend

Next.js 14 demo frontend for the Vigilia Protocol hackathon.

---

## Stack

| | |
|---|---|
| Framework | Next.js 14 (App Router) |
| Styling | Tailwind CSS (dark theme, custom design tokens) |
| Wallet | RainbowKit v2 + wagmi v2 + viem |
| Icons | lucide-react |
| Chain | Somnia Testnet (ID 50312, RPC: dream-rpc.somnia.network) |

---

## Setup

```bash
cd frontend
cp .env.example .env.local   # fill in contract addresses
npm install --legacy-peer-deps
npm run dev                   # → http://localhost:3000
```

### `.env.local`

```
NEXT_PUBLIC_VIGILIA_ESCROW_ADDRESS=0x1FA22E3a97dabB9a8C6de3a5B59eF6cCD5B2F4b9
NEXT_PUBLIC_VIGILIA_VERIFIER_ADDRESS=0xdE0aC9700E591b54A418665575f2e1d329D78f3D
NEXT_PUBLIC_WALLETCONNECT_PROJECT_ID=...   # optional, MetaMask works without it
```

Contract addresses are for **v0.2.3** on Somnia Testnet. Re-run `make deploy-somnia` from repo root if contracts are redeployed and update accordingly.

---

## Pages

### `/` — Landing
Hero section with animated 5-step flow diagram (Client funds → Contractor submits → Agent verifies → Verdict → Payment). Value props, use cases, CTA to create or browse milestones. Wallet-connection aware (hydration-safe).

### `/demo` — Interactive Demo ← killer feature for hackathon
Self-contained walkthrough of the full E2E flow — no wallet or deployed contracts needed. Two modes:
- **Auto-play** — full flow animates automatically with realistic timing, for presenting on stage
- **Step-by-step** — manual Next Step button for narrated demos

Each state shows: contract state panel (role, function called, arguments), animated Somnia agent panel (progress bar + per-check status), verdict card with detailed results, and a live on-chain trail building up on the right. Principals footer explains the three core guarantees. Clickable step pills for jumping to any state.

### `/milestones` — List
Fetches `nextTaskId`, batch-reads up to 20 tasks per page (newest first) via `useReadContracts`. Shows ID, color-coded status pill, amount in STT, client/contractor addresses. Pagination controls. Immediately shows `NotDeployedBanner` if contracts not configured — no RPC calls made.

### `/milestones/create` — Create & Fund
Two-step wizard:
1. **Define** — title, description, reference URLs, evidence types (chips), `allowMultiple` toggle, contractor/resolver addresses, amount (STT), review window (hours), **Claim Policy** selector → `createTaskWithPolicy()`
2. **Fund** — deposit exact STT → `fundTask()`. Shows agent fee notice (0.36 STT for `JsonFactsToLlmVerdict` workflow).
3. **Active** — success, auto-redirects to `/milestones/[id]`

Form field order: Title → Description → Reference URLs → Evidence types → Allow multiple submissions toggle → Parties → Terms (review window + claim policy).

**Claim Policy options** (set at creation, stored on-chain):
- `ClientApprovalOnly` — contractor must wait for explicit client approval
- `ReviewWindowAutoClaim` — if client doesn't act within review window, contractor can auto-claim
- `ImmediateAutoClaim` — contractor can claim immediately after `VerifiedComplete`

Task ID extracted via `decodeEventLog` on the `TaskCreated` receipt log.

### `/milestones/[id]` — Milestone Detail ← most important live screen
Role + state aware. Detects whether connected wallet is **client**, **contractor**, or **resolver** and shows the appropriate action panel. Non-participants see a clear "you are not a participant" note.

| State | Client sees | Contractor sees | Resolver sees |
|---|---|---|---|
| Funded | Cancel | Submit Evidence form | — |
| Submitted | — | "Agent verifying…" (or Mark Timed Out if timeout elapsed) | — |
| VerifiedComplete | Approve Early, Raise Dispute | Claim (policy-dependent, countdown timer) | — |
| NeedsReview | Approve, Raise Dispute | Resubmit form (if `allowMultiple`) or "Awaiting decision" | — |
| Incomplete | Override Approve, Cancel | Resubmit Evidence form (if `allowMultiple: true`) or locked message | — |
| VerificationFailed | Override Approve, Retry | Retry Verification | — |
| Approved | — | Claim | — |
| Cancelled | Withdraw pending balance | — | — |
| Disputed | "Awaiting resolver" | "Awaiting resolver" | Split slider + Resolve |
| Resolved/Claimed | Withdraw (if pending balance) | Withdraw (if pending balance) | — |

All write functions wired. Evidence hash auto-computed via `keccak256(toBytes(evidenceURI))`. Agent fee pre-filled from `minimumRequestDepositForWorkflow(3)` (JsonFactsToLlmVerdict, ~0.36 STT). Live countdown timer for review window.

**ClaimPolicy-aware VerifiedComplete UI:**
- `ClientApprovalOnly` → contractor sees "Awaiting client approval" only (no claim button)
- `ReviewWindowAutoClaim` → contractor sees countdown; claim button appears when review window expires
- `ImmediateAutoClaim` → contractor can claim immediately, no countdown

**Raise Dispute** is not shown to the contractor in `Submitted` state — only becomes available from `VerifiedComplete` onward.

**Mark Verification Timed Out** — if `verificationTimeout` has elapsed since submission (and state is still `Submitted`), either party sees a "Mark Verification Timed Out" button that calls `markVerificationTimedOut(taskId)`.

**Evidence schema hint** — submit form shows `{"facts": "..."}` hint above agent fee line, matching the `JsonFactsToLlmVerdict` two-agent workflow expected format.

**Terms section** shows: amount, review window, verification timeout, and claim policy label.

**Execution Trail** section at the bottom shows all on-chain events for this specific milestone, streaming backward from current block to `TaskCreated`. Shows `isScanning` indicator while loading.

### `/trail` — Execution Trail
Shows events for all milestones, newest first. Loads the most recent 50 000 blocks immediately on page load; "Load older events" button pages backward in 50 000-block chunks. Events are reverse-chronological. Shows event name, milestone ID + status pill, details, from address, amount, tx hash → Somnia Explorer.

---

## Somnia Testnet RPC Constraints

**Critical — read before touching any `getLogs` logic:**

- `eth_getLogs` max block range = **1000 blocks** per request (hard limit)
- Queries without `fromBlock`/`toBlock` return `[]` (empty)
- `fromBlock: "earliest"` is rejected
- Block production ~10 blocks/sec → 1000-block window ≈ 100 seconds of history
- Block numbers are ~396 million — `fromBlock: 0n` always exceeds the range limit

**Chunked scan strategy** (`lib/hooks.ts`):

```
PAGE_BLOCKS  = 50_000    // blocks loaded per UI "page"
CHUNK_SIZE   = 1_000     // max blocks per getLogs call (Somnia limit)
BATCH_SIZE   = 50        // parallel getLogs calls per round
```

**`useTrailEvents()`** (used by `/trail`):
1. On mount: `getBlockNumber()` → scan latest `PAGE_BLOCKS` backward
2. Each "page" = 50 chunks × 1000 blocks = 50 000 blocks ≈ 83 minutes of history
3. "Load older events" button triggers next page (50 000 older blocks)
4. Returns `{ events, isScanning, loadMore }`

**`useTaskTrailEvents(taskId)`** (used by `/milestones/[id]`):
1. Streams backward from current block in 50 000-block pages
2. Stops as soon as `TaskCreated` for this taskId is found (no need to scan further back)
3. Client-side filters by `taskId` after decoding
4. Returns `{ events, isScanning }`

Both hooks share `scanRange(publicClient, from, to, filterTaskId?)` helper that fires up to `BATCH_SIZE` parallel `getLogs` calls and returns decoded `TrailEvent[]`.

---

## Contract Version: v0.2.3

### Two-agent settlement workflow
Evidence submission triggers a **two-agent pipeline** on Somnia's agent network:
1. **JSON API agent** — fetches `{"facts": "..."}` from the `evidenceURI`
2. **LLM Inference agent** — receives the facts string, returns a bounded verdict: `Complete | NeedsReview | Incomplete`

This is `SettlementWorkflow.JsonFactsToLlmVerdict = 3`. Agent fee ≈ 0.36 STT (read from `minimumRequestDepositForWorkflow(3)`).

### New / changed contract functions (vs v0.2.2)

| Function | Change |
|---|---|
| `createTaskWithPolicy(contractor, resolver, amount, reviewWindow, uri, claimPolicy)` | New — creates with explicit `ClaimPolicy` |
| `createTaskWithPolicyAndTimeout(…, claimPolicy, verificationTimeout)` | New — also sets timeout |
| `taskClaimPolicies(taskId) → uint8` | New view — returns `ClaimPolicy` for a task |
| `markVerificationTimedOut(taskId)` | New — moves `Submitted → VerificationFailed` after timeout |
| `claimTo(taskId, recipient)` | New — claim to arbitrary address |
| `withdrawPendingTo(recipient)` | New — withdraw to arbitrary address |
| `cancelTask` | Changed — uses `pendingWithdrawals` pull pattern (no direct ETH transfer) |
| `tasks(taskId)` output | Added `verificationTimeout` (uint64) at index 11 |
| `TaskCreated` event | Added `verificationTimeout` and `claimPolicy` fields |
| `TaskClaimed` event | `contractor` field renamed to `recipient` |

### New `TaskState` values (v0.2.3)
`VerificationFailed = 7` — added to handle timed-out verification.

### New events
- `VerificationTimedOut(taskId, submissionId, requestId, timeoutAt)` — all three IDs indexed

---

## Key Files

```
lib/
  abi.ts          — full VigiliaEscrow ABI v0.2.3 (functions + events)
  contracts.ts    — TaskState, ClaimPolicy, VerificationVerdict enums + label maps
  chains.ts       — Somnia Testnet chain definition
  utils.ts        — formatSTT, truncateAddress, formatTimestamp, hashEvidenceURI,
                    RequirementsMeta type (title, description, criteria, refs, allowMultiple)
  hooks.ts        — useTask (+ claimPolicy), useMilestones, useAgentFee,
                    useIsDeployed, extractTaskIdFromReceipt,
                    useTrailEvents (paginated), useTaskTrailEvents (per-milestone),
                    Task/Submission/TrailEvent types, scanRange helper

components/
  providers.tsx     — WagmiProvider + RainbowKitProvider + QueryClientProvider
  nav.tsx           — sticky header with ConnectButton, Demo link
  status-pill.tsx   — color-coded badge for every TaskState
  tx-button.tsx     — TxButton (loading/confirming) + TxStatus (error/success/explorer link)
  not-deployed.tsx  — banner shown when contract addresses not set, CTA → /demo

app/
  layout.tsx
  page.tsx                              — landing
  demo/page.tsx                         — interactive demo (no wallet needed)
  milestones/page.tsx                   — paginated list
  milestones/create/page.tsx            — 2-step create + fund wizard
  milestones/[id]/page.tsx              — thin server wrapper
  milestones/[id]/milestone-detail.tsx  — all client-side detail + action logic
  trail/page.tsx                        — live event feed with pagination
```

---

## Architecture Decisions

**Deployment guard (`useIsDeployed`)**
All `useReadContract` / `useReadContracts` calls have `query: { enabled: isDeployed }`. If `NEXT_PUBLIC_VIGILIA_ESCROW_ADDRESS` is the zero address (env not set), zero RPC requests are made — pages render instantly with the `NotDeployedBanner`.

**Shared data layer (`lib/hooks.ts`)**
- `useTask(taskId)` — task + active submission + `claimPolicy`; single hook for detail page
- `useMilestones(page)` — pagination logic (20/page, newest first) in one place
- `useAgentFee()` — reads `minimumRequestDepositForWorkflow(3)`, falls back to `minimumRequestDeposit()` if not available; pre-fills submit form
- `extractTaskIdFromReceipt()` — uses `decodeEventLog` on `TaskCreated`, not raw `topics[1]`
- `useTrailEvents()` — paginated trail for `/trail`; first page loads instantly, `loadMore` adds older pages
- `useTaskTrailEvents(taskId)` — per-milestone trail for `/milestones/[id]`; streams backward, stops at `TaskCreated`

**`RequirementsMeta` schema** (stored as JSON in `requirementsURI`):
```typescript
{
  title: string;
  description?: string;
  criteria: { label: string; type: string }[];
  refs?: string[];
  allowMultiple?: boolean;   // controls resubmit UI for contractor
}
```

**Hydration safety**
All pages using `useAccount().isConnected` gate behind a `mounted` state to prevent SSR/client mismatch.

**Role Switcher (demo helper)**
`lib/role-context.tsx` provides a global `RoleContext`. The dev-only role switcher in the nav lets you preview client/contractor/resolver views without switching wallets. Disabled in production.

---

## What's Done ✓

- [x] Dark theme design system (Tailwind tokens, custom colors, typography)
- [x] Somnia Testnet chain config with correct RPC + block explorer
- [x] Full contract ABI v0.2.3 and typed enums (TaskState, ClaimPolicy, VerificationVerdict)
- [x] Wallet connection (RainbowKit, hydration-safe `mounted` pattern)
- [x] Landing page with flow diagram and value props
- [x] `/demo` — interactive E2E walkthrough (auto-play + manual, no wallet needed)
- [x] Milestones list — paginated, newest first, instant empty state
- [x] `NotDeployedBanner` — zero RPC calls when contracts not configured
- [x] 2-step create + fund wizard with step progress indicator
- [x] `extractTaskIdFromReceipt` via `decodeEventLog` (robust taskId parsing)
- [x] Agent fee pre-filled from `minimumRequestDepositForWorkflow(3)` with fallback
- [x] `allowMultiple` flag in `RequirementsMeta` — client sets at creation, controls resubmit UI
- [x] ClaimPolicy selector on create form (3 radio cards with icon + label + hint)
- [x] `createTaskWithPolicy` called at creation with chosen policy
- [x] Milestone detail: all task states rendered including `VerificationFailed`, `Cancelled`
- [x] Milestone detail: role detection (client / contractor / resolver / viewer)
- [x] Milestone detail: viewer note for non-participants
- [x] Milestone detail: review window live countdown timer
- [x] Milestone detail: ClaimPolicy-aware `VerifiedComplete` panel (3 distinct UX paths)
- [x] Milestone detail: `NeedsReview` contractor resubmit (if `allowMultiple`)
- [x] Milestone detail: `markVerificationTimedOut` button when timeout elapsed in `Submitted`
- [x] Milestone detail: `cancelTask` pull refund (Cancelled state triggers Withdraw block)
- [x] Milestone detail: evidence submit form shows `{"facts": "..."}` schema hint
- [x] Milestone detail: Terms section shows ClaimPolicy label
- [x] Raise Dispute hidden for contractor in `Submitted` state
- [x] Execution trail: Somnia 1000-block limit solved with chunked parallel scan
- [x] `/trail` — paginated (50k blocks/page), instant first load, "Load older" button
- [x] Per-milestone trail via `useTaskTrailEvents(taskId)` — streams back, stops at `TaskCreated`
- [x] `VerificationTimedOut` event decoded in trail with ⏱ icon
- [x] Explorer links on all tx hashes and addresses
- [x] Shared `lib/hooks.ts` — single source of truth for data fetching + types
- [x] Production build passes with 0 TypeScript errors

---

## What's Needed Next

### 🔴 Blocker for demo

1. **STT testnet tokens**
   Both demo wallets (client + contractor) need STT (~1 STT per task + 0.36 STT agent fee per submission).
   Faucet: https://testnet.somnia.network

### 🟡 Polish before demo

2. **Trail page: block timestamps**
   Currently shows relative time from `Date.now()` at fetch time, not actual block timestamp. Add `getBlock` calls (lazily, per unique block number) for precise on-chain times.

3. **Multi-submission history on detail page**
   When `submissionCount > 1`, only the active submission is shown. Past submissions are not fetched. Add a collapsible history section reading submissions 1..activeSubmissionId-1.

4. **Demo page: NeedsReview and Incomplete scenarios**
   Currently only the happy path (Complete → Approved → Claimed) is scripted. Add scenario switcher for NeedsReview resubmit and Incomplete/dispute flows.

### 🟢 Nice to have (post-demo)

5. **Toast notifications** for tx confirmations instead of inline status divs
6. **Mobile nav** — hamburger menu for small screens
7. **Subgraph / indexer** — replace chunked `getLogs` polling with an indexed query; current parallel scan works for demo but doesn't scale to days of history
8. **og:image meta tags** on `/milestones/[id]` for shareable deep links
9. **`createTaskWithPolicyAndTimeout` on create form** — UI currently uses default timeout (7 days); expose as optional advanced field
