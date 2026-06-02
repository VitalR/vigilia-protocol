# Vigilia GrantRound Runbook

## Purpose

`VigiliaGrantRound` helps sponsors run transparent grant and bounty rounds.

Builders submit public evidence. Somnia agents screen and summarize submissions. Judges select finalists from an agent-assisted review board. Selected finalists claim prizes on-chain.

This complements, but does not replace, the hardened v0.2.3 `VigiliaEscrow` path:

```text
Fixed work uses VigiliaEscrow.
Grant programs use VigiliaGrantRound.
Agents reduce review load.
Judges choose finalists.
Contracts enforce winner caps, reserved payouts, claims, and refunds.
```

## Architecture

The MVP contract is standalone and native-token-only:

```text
src/VigiliaGrantRound.sol
```

It has:

- no global owner;
- no external admin;
- round-scoped sponsor;
- round-scoped judge;
- equal prize amount per finalist;
- exact full-pool funding;
- pull-based prize claims;
- pull-based sponsor refunds;
- verifier callback compatibility through `IVigiliaEscrowVerdictReceiver`.

For verifier callbacks:

```text
taskId       = roundId
submissionId = applicationId
```

The verifier address is immutable. It can be zero for a deployment that relies on manual fallback while a fresh GrantRound verifier is not yet bound.

## Verifier Requirement

GrantRound should use a separate verifier deployment from the hardened v0.2.3 escrow/verifier pair.

Reason:

```text
VigiliaMultiAgentVerifier binds to one settlement receiver.
The hardened v0.2.3 verifier is part of the fixed-work escrow proof.
GrantRound is a different receiver with round/application IDs.
```

For GrantRound screening, deploy a fresh verifier instance and bind it to the GrantRound contract. Do not reuse:

```text
0xdE0aC9700E591b54A418665575f2e1d329D78f3D
```

That verifier belongs to:

```text
vigilia-two-agent-settlement-hardened
```

Manual fallback is still available if a GrantRound deployment uses `address(0)` as verifier, but that is a recovery mode, not the intended Somnia-powered hackathon path.

## Data Model

### Round

Each round stores sponsor, judge, prize amount, max winners, funded amount, selected/claimed accounting, deadlines, requirements URI, screening mode, and state.

The funding requirement is:

```text
prizeAmount * maxWinners
```

### Application

Each application stores round ID, applicant, evidence URI, evidence hash, active request ID, verdict, status, selected/claimed flags, timestamps, and notes URI.

One address can submit one application per round.

### ScreeningMode

```text
TwoAgent    JSON API facts -> LLM Inference bounded verdict
ThreeAgent  JSON API facts + Website Parse real HTML -> LLM Inference bounded verdict
```

Manual screening is not a round mode. It is a fallback/recovery function for sponsor or judge.

### ThreeAgent Target Mode

ThreeAgent is the preferred GrantRound story if Website Parse works in the deployed verifier setup:

```text
JSON API facts
-> Website Parse extracts README/demo/docs/project-page content from real HTML
-> LLM Inference bounded eligibility verdict and summary
-> judge-selected finalists
-> finalist claims
```

Do not claim ThreeAgent is live unless there is a public hosted HTML page, a successful Website Parse callback, LLM consumption of the extracted content, and a final GrantRound verdict callback visible in receipts or `inspect`.

### TwoAgent Fallback Mode

TwoAgent is the current proven Somnia-powered fallback:

```text
JSON API facts -> LLM Inference bounded verdict -> judge-selected finalists -> claims
```

The deployed GrantRound verifier supports this path through `JsonFactsToLlmVerdict`.

### Manual Recovery

Manual screening is recovery/fallback only. It is useful if agent requests fail or a judge needs to record override metadata, but it is not a round mode and should not be presented as the flagship demo flow.

## Lifecycle

### createRound

Sponsor creates the round:

```solidity
createRound(
    judge,
    prizeAmount,
    maxWinners,
    applicationDeadline,
    reviewDeadline,
    requirementsURI,
    screeningMode
)
```

Rules:

- judge cannot be zero;
- prize amount must be nonzero;
- max winners must be nonzero;
- application deadline must be in the future;
- review deadline must be after application deadline;
- screening mode must be `TwoAgent` or `ThreeAgent`.

Use `ThreeAgent` only after Website Parse has a successful real-HTML proof. Until then, use `TwoAgent` as the safe live fallback.

### fundRound

Sponsor funds exactly:

```text
prizeAmount * maxWinners
```

The round moves from `Created` to `Open`.

Partial funding and repeated funding are intentionally not supported in this MVP.

### submitApplication

Applicants submit:

```solidity
submitApplication(roundId, evidenceURI, evidenceHash)
```

Rules:

- round must be `Open`;
- current time must be at or before the application deadline;
- evidence URI cannot be empty;
- evidence hash cannot be zero;
- duplicate applications by the same applicant are rejected.

### requestApplicationScreening

Applicant, sponsor, or judge may request Somnia-agent screening:

```solidity
requestApplicationScreening(applicationId)
```

The contract reads `round.screeningMode`.

For `TwoAgent`, it requests:

```text
JsonFactsToLlmVerdict
```

For `ThreeAgent`, the current implementation reverts with `UnsupportedScreeningMode` until a fresh verifier exposes a proven Website Parse workflow.

The request stores the active request ID and marks the application `ScreeningRequested`.

### recordVerdict

Only the configured verifier can call:

```solidity
recordVerdict(roundId, applicationId, requestId, verdict, notesURI)
```

Rules:

- unknown verdict reverts;
- round/application mismatch reverts;
- stale request IDs are ignored and emitted;
- no funds move;
- no finalist is selected.

Verdict mapping:

```text
Complete    -> Complete
NeedsReview -> NeedsReview
Incomplete  -> Incomplete
```

### recordVerificationFailure

Only the verifier can call:

```solidity
recordVerificationFailure(roundId, applicationId, requestId, failureNotesURI)
```

It marks the application `VerificationFailed` unless the callback is stale. This is a review/retry status, not permanent rejection.

### recordManualScreening

Sponsor or judge can call:

```solidity
recordManualScreening(applicationId, verdict, notesURI)
```

Use this as fallback, recovery, or judge override. It cannot move funds or select finalists.

### selectFinalists

Sponsor or judge selects finalists after the application deadline and before the review deadline:

```solidity
selectFinalists(roundId, applicationIds)
```

Eligible normal statuses:

```text
Submitted
ScreeningRequested
Complete
NeedsReview
VerificationFailed
```

`Incomplete` is not selectable in the normal path.

The contract enforces:

- only sponsor or judge;
- no selection before application deadline;
- no normal selection after review deadline;
- no missing applications;
- no applications from another round;
- no rejected applications;
- no duplicate selected application;
- no count beyond `maxWinners`;
- no selected allocation beyond funded pool.

### finalizeRound

Sponsor or judge finalizes after the application deadline:

```solidity
finalizeRound(roundId)
```

Claims become available after finalization. No more finalist selection is allowed.

### claimPrize / claimPrizeTo

Selected applicants claim exact equal prizes:

```solidity
claimPrize(applicationId)
claimPrizeTo(applicationId, recipient)
```

Rules:

- round must be finalized;
- caller must be the applicant;
- application must be selected;
- application cannot already be claimed;
- recipient cannot be zero.

The contract updates state before transfer.

### refundUnallocated

Sponsor can credit unallocated funds:

```solidity
refundUnallocated(roundId)
```

Refund amount:

```text
totalFunded - (selectedCount * prizeAmount) - totalRefunded
```

Selected-but-unclaimed prizes remain reserved.

Example:

```text
prizeAmount = 100 STT
maxWinners = 3
funded = 300 STT
selected = 2
unallocated refund = 100 STT
reserved for finalists = 200 STT
```

### withdrawPending / withdrawPendingTo

Sponsor pulls credited refunds:

```solidity
withdrawPending()
withdrawPendingTo(recipient)
```

Balances are cleared before transfer.

### cancelRound

Sponsor can cancel only when safe:

- `Created` and unfunded;
- `Open` with no applications.

Funded cancellation credits the sponsor through `pendingWithdrawals`. It does not push a direct refund.

## Demo Scenario

Round:

```text
Somnia Agentathon Mini-Grant
```

Prize:

```text
100 STT each
```

Max winners:

```text
3
```

Requirements:

```text
public GitHub repo
README/setup docs
deployed contract address
demo transaction or video
```

Recommended live demo mode:

```text
ScreeningMode.TwoAgent
```

Flow:

1. Sponsor creates the round with `TwoAgent`.
2. Sponsor funds `300 STT`.
3. Several builders submit evidence bundles.
4. Agents screen one `Complete`, one `NeedsReview`, and one `Incomplete`.
5. Manual fallback remains available if agent infrastructure fails.
6. Judge selects eligible finalists.
7. Judge finalizes.
8. Finalists claim.
9. Sponsor refunds unallocated funds.

## Composition With v0.2.3

Do not reuse the deployed hardened v0.2.3 verifier for GrantRound.

Canonical v0.2.3 remains:

```text
Deployment name: vigilia-two-agent-settlement-hardened
Chain: Somnia testnet, chain id 50312
Escrow: 0x1FA22E3a97dabB9a8C6de3a5B59eF6cCD5B2F4b9
Verifier: 0xdE0aC9700E591b54A418665575f2e1d329D78f3D
Workflow: JsonFactsToLlmVerdict
```

Future GrantRound deployment should use a fresh verifier instance bound to the GrantRound receiver.

## Validation

Run:

```bash
forge fmt
forge build
forge test
git diff --check
```

`make check` can be run if the Makefile target is present.

## Deploy / Dry Run

GrantRound deployment uses a fresh verifier bound to the GrantRound receiver:

```text
script/deploy/DeployVigiliaGrantRound.s.sol
```

Dry run:

```bash
make grant-round-deploy-dry-run
```

Broadcast:

```bash
make grant-round-deploy-somnia
```

The broadcast target uses `--slow` so Foundry waits between the verifier deploy,
GrantRound deploy, and bind transaction. If a network or nonce issue leaves the
contracts deployed but the verifier unbound, bind the same fresh verifier manually:

```bash
make grant-round-bind-verifier \
  VIGILIA_GRANT_ROUND=<grant round address> \
  VIGILIA_GRANT_ROUND_VERIFIER=<fresh verifier address>
```

Show artifact:

```bash
make grant-round-show-deployment
```

Verify source code and live binding:

```bash
make grant-round-verify-all
```

The verifier and GrantRound contracts should both be verified on Blockscout.
The state check also confirms:

```text
verifier.escrow == VIGILIA_GRANT_ROUND
VigiliaGrantRound.verifier == VIGILIA_GRANT_ROUND_VERIFIER
```

Query the deployed GrantRound verifier's two-agent workflow deposit:

```bash
VIGILIA_GRANT_ROUND_VERIFIER=<fresh verifier address> make grant-round-verifier-deposit
```

Current Somnia testnet GrantRound deployment:

```text
artifact: deployments/somnia-testnet-50312-grant-round.json
grantRound: 0xaA20C6C3F37f5E97cb2fed1c14575b76EE4F3C9a
verifier: 0x44276D0d3149a9915fC2a4d5E6F0f66eD74185C3
bindingTx: 0x1b3d245bca8a043976b65b059879cf6e8caa5470c5d8c18de6e96294c090460e
workflowDeposit: 360000000000000000 wei
GrantRound explorer: https://somnia.w3us.site/address/0xaa20c6c3f37f5e97cb2fed1c14575b76ee4f3c9a
verifier explorer: https://somnia.w3us.site/address/0x44276d0d3149a9915fc2a4d5e6f0f66ed74185c3
current proven fallback: TwoAgent / JsonFactsToLlmVerdict
target mode: ThreeAgent after Website Parse is proven against real hosted HTML
```

## Demo Environment

Add this block to `.env` before running GrantRound demo scripts:

```bash
VIGILIA_GRANT_ROUND=0xaA20C6C3F37f5E97cb2fed1c14575b76EE4F3C9a
VIGILIA_GRANT_ROUND_VERIFIER=0x44276D0d3149a9915fC2a4d5E6F0f66eD74185C3
GRANT_ROUND_WORKFLOW_DEPOSIT_WEI=360000000000000000

# Existing Somnia agent config used by the deployed fresh verifier.
SOMNIA_JSON_API_AGENT_ID=13174292974160097713
SOMNIA_LLM_INFERENCE_AGENT_ID=12847293847561029384
SOMNIA_LLM_PARSE_WEBSITE_AGENT_ID=12875401142070969085
SOMNIA_VERDICT_SELECTOR=verdict
AGENT_SUBCOMMITTEE_SIZE=3
JSON_API_PRICE_PER_VALIDATOR_WEI=30000000000000000
LLM_INFERENCE_PRICE_PER_VALIDATOR_WEI=70000000000000000
LLM_PARSE_PRICE_PER_VALIDATOR_WEI=100000000000000000

# Demo scenario defaults.
GRANT_SCREENING_MODE=0
GRANT_PRIZE_AMOUNT_WEI=1000000000000000000
GRANT_MAX_WINNERS=3
GRANT_APPLICATION_WINDOW_SECONDS=300
GRANT_REVIEW_WINDOW_SECONDS=600
GRANT_FAST_DEADLINES=false
GRANT_FAST_APPLICATION_WINDOW_SECONDS=300
GRANT_FAST_REVIEW_WINDOW_SECONDS=900
GRANT_REQUIREMENTS_URI=https://raw.githubusercontent.com/<org>/<repo>/<branch>/demo/evidence/grants/grant-requirements.md
GRANT_COMPLETE_EVIDENCE_URI=https://raw.githubusercontent.com/<org>/<repo>/<branch>/demo/evidence/grants/facts-complete.json
GRANT_NEEDS_REVIEW_EVIDENCE_URI=https://raw.githubusercontent.com/<org>/<repo>/<branch>/demo/evidence/grants/facts-needs-review.json
GRANT_INCOMPLETE_EVIDENCE_URI=https://raw.githubusercontent.com/<org>/<repo>/<branch>/demo/evidence/grants/facts-incomplete.json
GRANT_MALFORMED_EVIDENCE_URI=https://raw.githubusercontent.com/<org>/<repo>/<branch>/demo/evidence/grants/facts-malformed.json
GRANT_COMPLETE_PROJECT_HTML_URI=https://raw.githubusercontent.com/VitalR/vigilia-protocol/main/demo/evidence/grants/complete-project.html
GRANT_NEEDS_REVIEW_PROJECT_HTML_URI=https://raw.githubusercontent.com/VitalR/vigilia-protocol/main/demo/evidence/grants/needs-review-project.html
GRANT_INCOMPLETE_PROJECT_HTML_URI=https://raw.githubusercontent.com/VitalR/vigilia-protocol/main/demo/evidence/grants/incomplete-project.html
GRANT_ROUND_ID=
GRANT_APPLICATION_ID=
GRANT_APPLICATION_IDS=
GRANT_APPLICANT_INDEX=
GRANT_EVIDENCE_URI=
GRANT_EVIDENCE_HASH=
GRANT_NOTES_URI=
GRANT_REFUND_RECIPIENT=
GRANT_PRIZE_RECIPIENT=
```

`GRANT_SCREENING_MODE=0` means `TwoAgent`; `GRANT_SCREENING_MODE=1` means
`ThreeAgent`. Use `ThreeAgent` only after Website Parse has a successful
real-HTML proof. Until then, `TwoAgent` is the safe live fallback, not the
long-term product ceiling. Manual screening should stay a fallback/recovery
action in the demo script, not the default flow.

`SPONSOR_PRIVATE_KEY` and `JUDGE_PRIVATE_KEY` may share one key for a simple
demo. For a real round, use distinct `APPLICANT_ONE_PRIVATE_KEY` through
`APPLICANT_FOUR_PRIVATE_KEY`; the contract allows one application per address
per round, so repeated submissions from one applicant revert.

## Demo Script

The GrantRound demo runner is:

```text
script/demo/VigiliaGrantRoundDemo.s.sol
```

Each run executes one `DEMO_ACTION`. `make grant-demo-inspect` is read-only.
State-changing targets use `forge script --broadcast --legacy --skip-simulation`.

Available actions:

```text
inspect
create-round
fund-round
submit-application
submit-application-complete
submit-application-needs-review
submit-application-incomplete
submit-application-malformed
request-screening
request-screening-complete
request-screening-needs-review
request-screening-incomplete
request-screening-malformed
manual-screen-complete
manual-screen-needs-review
manual-screen-incomplete
select-finalists
reject-application
finalize-round
claim-prize
refund-unallocated
withdraw-pending
cancel-round
full-two-agent-happy-path-prep
full-two-agent-review-board-prep
```

`full-*` actions do not wait for async callbacks. Use them only for grouped prep
where safe, then run the normal inspect/request/select commands.

### Live Request Screening Fallback

`forge script --broadcast` can be unreliable for the live Somnia agent request
path in some local environments because local execution may query platform
helpers before broadcasting. Use the direct cast fallback when
`make grant-demo-request-screening` fails before sending a transaction:

```bash
make grant-demo-request-screening-cast GRANT_APPLICATION_ID=<app id>
```

The fallback sends:

```bash
cast send "$VIGILIA_GRANT_ROUND" \
  "requestApplicationScreening(uint256)" "$GRANT_APPLICATION_ID" \
  --value "$GRANT_ROUND_WORKFLOW_DEPOSIT_WEI" \
  --rpc-url "$SOMNIA_RPC_URL" \
  --private-key <requester key> \
  --legacy \
  --gas-limit "$DEMO_GAS_LIMIT"
```

Requester key selection is `GRANT_REQUESTER_PRIVATE_KEY`, then
`SPONSOR_PRIVATE_KEY`, then `DEPLOYER_PRIVATE_KEY`. Sponsor, judge, and the
applicant are all valid requesters. Do not print or commit private keys.

## Evidence Hosting

Local fixtures live under:

```text
demo/evidence/grants/
```

For live Somnia agents, host the JSON evidence files at public HTTPS URLs. Local
files are examples only. The current TwoAgent JSON API flow expects a top-level
`facts` field:

```json
{
  "facts": "repo_exists=true; readme_setup=true; deployment_address_present=true; demo_url_present=true; tests_passed=true"
}
```

Website Parse / ThreeAgent testing needs real HTML DOM pages, not plain text.
The HTML fixtures are preparation assets until a real Website Parse callback
proof exists.

For Website Parse, a normal hosted HTML page is preferred over raw GitHub HTML:

```bash
export GRANT_COMPLETE_PROJECT_HTML_URI=https://vigilia-demo.vercel.app/grants/complete-project.html
export GRANT_NEEDS_REVIEW_PROJECT_HTML_URI=https://vigilia-demo.vercel.app/grants/needs-review-project.html
export GRANT_INCOMPLETE_PROJECT_HTML_URI=https://vigilia-demo.vercel.app/grants/incomplete-project.html
```

Vercel, Cloudflare Pages, and Netlify are better Website Parse hosts because
the parser receives a normal HTML page instead of a raw source response.

Recommended public URL templates:

```bash
export GRANT_REQUIREMENTS_URI=https://raw.githubusercontent.com/<org>/<repo>/<branch>/demo/evidence/grants/grant-requirements.md
export GRANT_COMPLETE_EVIDENCE_URI=https://raw.githubusercontent.com/<org>/<repo>/<branch>/demo/evidence/grants/facts-complete.json
export GRANT_NEEDS_REVIEW_EVIDENCE_URI=https://raw.githubusercontent.com/<org>/<repo>/<branch>/demo/evidence/grants/facts-needs-review.json
export GRANT_INCOMPLETE_EVIDENCE_URI=https://raw.githubusercontent.com/<org>/<repo>/<branch>/demo/evidence/grants/facts-incomplete.json
export GRANT_MALFORMED_EVIDENCE_URI=https://raw.githubusercontent.com/<org>/<repo>/<branch>/demo/evidence/grants/facts-malformed.json
```

Vercel static hosting, Cloudflare Pages, Netlify, and GitHub Gist raw URLs are
also acceptable. IPFS or metadata URIs are acceptable for stored metadata, but
public HTTPS is clearer for a live agent-facing demo. If the verifier or LLM
prompt treats the URI as raw text only, IPFS can still work, but it is harder to
demonstrate.

## Four-Applicant Campaign

Strongest current fallback demo:

```text
GRANT_MAX_WINNERS=3
Applicant 1: Complete     -> selected
Applicant 2: NeedsReview  -> selected
Applicant 3: Complete     -> selected
Applicant 4: Incomplete   -> rejected or left unselected
```

This proves many applicants, agent screening, max-three finalist selection,
finalist claims, and non-selection of incomplete work.

### Full Four-Applicant Proof

The live proof for this campaign is recorded in:

```text
docs/proofs/2026-06-03-grant-round-demo-scenarios.md
```

Round `4` proves the current safe fallback path:

```text
agents screened applications;
judge/sponsor selected finalists;
three selected finalists claimed;
the Incomplete application stayed unselected and unclaimed.
```

Do not describe this as agents identifying or choosing finalists. Agents only
produce screening metadata; judges or sponsors choose finalists.

Use fast deadlines only when you are ready to operate quickly:

```bash
export GRANT_FAST_DEADLINES=true
make grant-demo-create-round
export GRANT_ROUND_ID=<round id from logs>

make grant-demo-fund-round

export GRANT_APPLICANT_INDEX=1
export GRANT_EVIDENCE_URI=$GRANT_COMPLETE_EVIDENCE_URI
make grant-demo-submit-complete
export COMPLETE_APP_ID=<id>
export GRANT_APPLICATION_ID=$COMPLETE_APP_ID
make grant-demo-request-screening-complete-cast

export GRANT_APPLICANT_INDEX=2
export GRANT_EVIDENCE_URI=$GRANT_NEEDS_REVIEW_EVIDENCE_URI
make grant-demo-submit-needs-review
export NEEDS_REVIEW_APP_ID=<id>
export GRANT_APPLICATION_ID=$NEEDS_REVIEW_APP_ID
make grant-demo-request-screening-needs-review-cast

export GRANT_APPLICANT_INDEX=3
export GRANT_EVIDENCE_URI=$GRANT_COMPLETE_EVIDENCE_URI
make grant-demo-submit-complete
export COMPLETE_APP_ID_2=<id>
export GRANT_APPLICATION_ID=$COMPLETE_APP_ID_2
make grant-demo-request-screening-complete-cast

export GRANT_APPLICANT_INDEX=4
export GRANT_EVIDENCE_URI=$GRANT_INCOMPLETE_EVIDENCE_URI
make grant-demo-submit-incomplete
export INCOMPLETE_APP_ID=<id>
export GRANT_APPLICATION_ID=$INCOMPLETE_APP_ID
make grant-demo-request-screening-incomplete-cast
```

Wait for async JSON and LLM callbacks, then inspect:

```bash
make grant-demo-inspect
```

After the application deadline:

```bash
export GRANT_APPLICATION_IDS=$COMPLETE_APP_ID,$NEEDS_REVIEW_APP_ID,$COMPLETE_APP_ID_2
make grant-demo-select-finalists

make grant-demo-finalize-round

export GRANT_APPLICATION_ID=$COMPLETE_APP_ID
make grant-demo-claim-prize

make grant-demo-refund-unallocated
make grant-demo-withdraw-pending
```

Claim each selected application with the key that submitted it. The demo script
reads `applications(applicationId).applicant` and uses the matching configured
applicant key.

If fewer than three winners are selected, the sponsor refunds only unallocated
prizes while selected but unclaimed finalist prizes remain reserved.

Avoid 60-second application windows. A live demo includes several transactions,
copying IDs, exporting env vars, and waiting for RPC/callback timing. The fast
defaults are intentionally 300 seconds for applications and 900 seconds for
review:

```bash
export GRANT_FAST_DEADLINES=true
export GRANT_FAST_APPLICATION_WINDOW_SECONDS=300
export GRANT_FAST_REVIEW_WINDOW_SECONDS=900
```

## NeedsReview Selection

`NeedsReview` is eligible for normal finalist selection. The judge can select it
with the Complete application:

```bash
export GRANT_APPLICATION_IDS=<complete_id>,<needs_review_id>
make grant-demo-select-finalists
```

Manual screening can be used only as fallback/recovery:

```bash
export GRANT_APPLICATION_ID=<needs_review_id>
export GRANT_NOTES_URI=ipfs://manual-review/fallback-needs-review
make grant-demo-manual-screen-needs-review
```

## Incomplete Non-Selection

`Incomplete` cannot be selected in the normal path:

```bash
export GRANT_APPLICATION_IDS=<incomplete_id>
make grant-demo-select-finalists
```

That command is expected to revert. Use `make grant-demo-reject-application` for
review-board clarity:

```bash
export GRANT_APPLICATION_ID=<incomplete_id>
export GRANT_NOTES_URI=ipfs://grant-round/incomplete-rejection
make grant-demo-reject-application
```

## Malformed / Recovery

Malformed JSON omits the top-level `facts` field and should drive the verifier
toward `VerificationFailed`:

```bash
export GRANT_EVIDENCE_URI=<public facts-malformed.json URL>
make grant-demo-submit-malformed
export GRANT_APPLICATION_ID=<malformed app id>
make grant-demo-request-screening-malformed
```

Wait for callback failure, then inspect:

```bash
make grant-demo-inspect
```

If a judge independently confirms the work, record manual fallback metadata:

```bash
export GRANT_NOTES_URI=ipfs://manual-review/fallback-complete
make grant-demo-manual-screen-complete
```

This does not select a winner or move funds.

## ThreeAgent Gated Probe

Create a ThreeAgent round only to prove the current deployed verifier gates the
request path until Website Parse workflow support is ready:

```bash
GRANT_SCREENING_MODE=1 make grant-demo-create-round
export GRANT_ROUND_ID=<round id>
make grant-demo-fund-round
export GRANT_EVIDENCE_URI=<public HTML-backed evidence URL>
make grant-demo-submit-application
export GRANT_APPLICATION_ID=<app id>
make grant-demo-request-screening
```

`requestApplicationScreening` is expected to revert with
`UnsupportedScreeningMode(ThreeAgent)` until the verifier supports
`JsonFactsAndWebsiteToLlmVerdict`.

## Proving Website Parse

Before switching the flagship demo to `GRANT_SCREENING_MODE=1`, collect proof
that all of the following are true:

- a real HTML project page is hosted publicly;
- Website Parse succeeds against that page;
- LLM Inference consumes JSON facts plus extracted website content;
- the final bounded verdict reaches `VigiliaGrantRound.recordVerdict`;
- `make grant-demo-inspect` shows the expected final application status;
- receipts or logs include the Website Parse request, LLM request, and GrantRound callback.

A Website Parse canary request submission alone is not sufficient. A positive
ThreeAgent claim requires the full GrantRound path: a `ScreeningMode.ThreeAgent`
round, applicant evidence, Website Parse callback, LLM bounded verdict,
GrantRound `recordVerdict`, finalist selection by judge/sponsor, finalization,
and claim.

If these are not all true, keep the final live demo on `GRANT_SCREENING_MODE=0`
as the safe Somnia-powered fallback.

Current status from the June 3 proof:

```text
TwoAgent GrantRound: proven end to end.
Website Parse canary: succeeded against raw GitHub HTML.
ThreeAgent GrantRound: not proven.
```

The exact blocker is verifier workflow support. `SettlementWorkflow` does not
yet include `JsonFactsAndWebsiteToLlmVerdict`, and
`VigiliaGrantRound._workflowFor(ThreeAgent)` still reverts with
`UnsupportedScreeningMode(ThreeAgent)`.

## Proof Checklist

Collect these artifacts for a complete demo proof:

- create-round transaction;
- fund transaction;
- submit transactions;
- request-screening transactions;
- JSON callback transactions;
- LLM callback transactions;
- selected finalist transaction;
- finalize transaction;
- claim transactions;
- refund and withdraw transactions;
- round ID;
- application IDs;
- request IDs;
- final round/application statuses.

Latest proof note:

```text
docs/proofs/2026-06-03-grant-round-demo-scenarios.md
```

This run proved the live TwoAgent lifecycle against public raw GitHub evidence,
including the full four-applicant campaign: agents screened applications,
judge/sponsor selected three finalists, all selected finalists claimed, and the
Incomplete application remained unselected and unclaimed.

Required environment:

```text
DEPLOYER_PRIVATE_KEY
SOMNIA_RPC_URL
SOMNIA_CHAIN_ID
SOMNIA_AGENT_PLATFORM
SOMNIA_JSON_API_AGENT_ID
SOMNIA_LLM_INFERENCE_AGENT_ID
AGENT_SUBCOMMITTEE_SIZE
```

Optional pricing/env overrides:

```text
JSON_API_PRICE_PER_VALIDATOR_WEI
LLM_INFERENCE_PRICE_PER_VALIDATOR_WEI
LLM_PARSE_PRICE_PER_VALIDATOR_WEI
AGENT_PLATFORM_RESERVE_WEI
SOMNIA_LLM_PARSE_WEBSITE_AGENT_ID
SOMNIA_BLOCK_EXPLORER
SOMNIA_BLOCKSCOUT_API
```

## Current Limitations

- Native token only.
- Equal prizes only.
- Exact full-pool funding only.
- No application update function in this MVP.
- No explicit override path for selecting `Incomplete`.
- `ThreeAgent` is stored as a round mode but request-time gated in the current deployed verifier because `JsonFactsAndWebsiteToLlmVerdict` is not yet exposed.
- Deploy and demo scripts exist for GrantRound plus a fresh two-agent verifier.
