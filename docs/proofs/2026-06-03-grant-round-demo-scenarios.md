# GrantRound Demo Scenario Proof - 2026-06-03

## Summary

Network: Somnia testnet, chain id `50312`

GrantRound: `0xaA20C6C3F37f5E97cb2fed1c14575b76EE4F3C9a`

Fresh GrantRound verifier: `0x44276D0d3149a9915fC2a4d5E6F0f66eD74185C3`

Current proven workflow: `TwoAgent / JsonFactsToLlmVerdict`

Current workflow deposit: `360000000000000000` wei

ThreeAgent status: gated/future. The deployed verifier does not expose a proven `JsonFactsAndWebsiteToLlmVerdict` workflow.

This run rechecked the previously missing public evidence URLs after the repository was made public. The raw GitHub evidence URLs now return `200`, and a live TwoAgent screening request completed with a final GrantRound `Complete` verdict.

## Preflight

Commands:

```bash
make grant-demo-inspect
make grant-round-verify-state
```

Observed:

```text
GrantRound: 0xaA20C6C3F37f5E97cb2fed1c14575b76EE4F3C9a
Verifier: 0x44276D0d3149a9915fC2a4d5E6F0f66eD74185C3
verifier.escrow: 0xaA20C6C3F37f5E97cb2fed1c14575b76EE4F3C9a
grantRound.verifier: 0x44276D0d3149a9915fC2a4d5E6F0f66eD74185C3
twoAgentWorkflowDeposit: 360000000000000000
threeAgentRequestPath: gated until verifier exposes Website Parse workflow proof
```

`make grant-demo-inspect` still cannot read `minimumRequestDepositForWorkflow(3)` inside local Forge script execution because the platform helper reverts with `NotActivated` in that local execution path. A direct `cast call` to the deployed verifier returned the expected deposit:

```bash
cast call 0x44276D0d3149a9915fC2a4d5E6F0f66eD74185C3 \
  "minimumRequestDepositForWorkflow(uint8)(uint256)" 3 \
  --rpc-url https://api.infra.testnet.somnia.network/
```

Result:

```text
360000000000000000
```

## Evidence URL Check

Configured raw GitHub URLs were checked with `curl`.

```text
https://raw.githubusercontent.com/VitalR/vigilia-protocol/main/demo/evidence/grants/grant-requirements.md       200
https://raw.githubusercontent.com/VitalR/vigilia-protocol/main/demo/evidence/grants/facts-complete.json          200
https://raw.githubusercontent.com/VitalR/vigilia-protocol/main/demo/evidence/grants/facts-needs-review.json     200
https://raw.githubusercontent.com/VitalR/vigilia-protocol/main/demo/evidence/grants/facts-incomplete.json       200
https://raw.githubusercontent.com/VitalR/vigilia-protocol/main/demo/evidence/grants/facts-malformed.json        200
https://raw.githubusercontent.com/VitalR/vigilia-protocol/main/demo/evidence/grants/complete-project.html       200
```

Facts schema check:

```json
{ "facts": "repo_exists=true; readme_setup=true; deployment_address_present=true; demo_url_present=true; tests_passed=true" }
{ "facts": "repo_exists=true; readme_setup=true; deployment_address_present=unclear; demo_url_present=true; tests_passed=unknown" }
{ "facts": "repo_exists=true; readme_setup=true; deployment_address_present=false; demo_url_present=false; tests_passed=false" }
{ "status": "unknown" }
```

The malformed fixture intentionally omits `facts`.

## Scenario A - TwoAgent Quick Positive Flow

Purpose: prove the live GrantRound TwoAgent path after the raw GitHub evidence URLs became reachable.

Mode: `GRANT_SCREENING_MODE=0`

Prize: `1000000000000000000` wei

Max winners: `1`

Round ID: `3`

Application ID: `2`

Applicant: `0x8998a83a6192dD5500EEbb666cad0bC2Ab0258E7`

Evidence URI:

```text
https://raw.githubusercontent.com/VitalR/vigilia-protocol/main/demo/evidence/grants/facts-complete.json
```

Evidence hash:

```text
0x371495ddc5cd8ba25e14aa81cf8332d0282b88e0d25abefe312570592d34bf61
```

Requirements URI:

```text
https://raw.githubusercontent.com/VitalR/vigilia-protocol/main/demo/evidence/grants/grant-requirements.md
```

Request ID:

```text
0x00000000000000000000000000000000000000000000000000000000003f055e
```

Somnia agent request note:

```text
somnia-agent-request:4130149
```

Commands:

```bash
make grant-demo-create-round \
  GRANT_SCREENING_MODE=0 \
  GRANT_MAX_WINNERS=1 \
  GRANT_PRIZE_AMOUNT_WEI=1000000000000000000 \
  GRANT_FAST_DEADLINES=true \
  GRANT_FAST_APPLICATION_WINDOW_SECONDS=300 \
  GRANT_FAST_REVIEW_WINDOW_SECONDS=900

make grant-demo-fund-round GRANT_ROUND_ID=3

make grant-demo-submit-application \
  GRANT_ROUND_ID=3 \
  GRANT_EVIDENCE_URI=https://raw.githubusercontent.com/VitalR/vigilia-protocol/main/demo/evidence/grants/facts-complete.json \
  GRANT_APPLICANT_INDEX=0
```

The Forge script path for `request-screening` hit the known local `NotActivated` execution issue before broadcasting. The request was sent directly:

```bash
cast send 0xaA20C6C3F37f5E97cb2fed1c14575b76EE4F3C9a \
  "requestApplicationScreening(uint256)" 2 \
  --value 360000000000000000 \
  --private-key "$DEPLOYER_PRIVATE_KEY" \
  --rpc-url https://api.infra.testnet.somnia.network/ \
  --legacy \
  --gas-limit 10000000
```

Then:

```bash
make grant-demo-inspect GRANT_ROUND_ID=3 GRANT_APPLICATION_ID=2
make grant-demo-select-finalists GRANT_ROUND_ID=3 GRANT_APPLICATION_IDS=2
make grant-demo-finalize-round GRANT_ROUND_ID=3
make grant-demo-claim-prize GRANT_APPLICATION_ID=2
make grant-demo-inspect GRANT_ROUND_ID=3 GRANT_APPLICATION_ID=2
```

Transactions:

```text
create round 3:              0x4253f13bd5d2bbb1402d9ea289a770283604aea9d6e406f8263a0e90abf209b2
fund round 3:                0x8dbf94d608cf0e89e43df0ecb07df96b23e0c584cb2cee547b8b0d6922d5b4f6
submit application 2:        0x874ccd8c4fb225c2e6ab654dbc42a2f0cfc84cc57a1baf8f9b78bbd2e449e22a
request screening:           0xe4b9324a6655b7a5768e9c881bed9778718877284c6b74b058a6272aecc08580
GrantRound verdict callback: 0xa85c950ae48ea5c129942000ed526192ef22ea5b2db0a91fbfb15b2278324266
select finalist:             0xf13ea4680392c1f83c348b58af6dc0d028ecd10e23c084279c3a8a8f163c7c19
finalize round 3:            0xad6e6a14908bee66fd05ffab3bf5607df072cba4bbd1f4b9fd37b2477bc283ae
claim application 2:         0x0eab2a77807af493167ff0580aaa8103793c54de4c232e7e8d538c3fc03cc4f7
```

Callback log:

```text
blockNumber: 398946683
event: ApplicationVerdictRecorded
roundId: 3
applicationId: 2
verdict: Complete
notesURI: somnia-agent-request:4130149
transactionHash: 0xa85c950ae48ea5c129942000ed526192ef22ea5b2db0a91fbfb15b2278324266
```

Final inspected round state:

```text
round.state: Finalized
round.stateIndex: 4
round.prizeAmount: 1000000000000000000
round.maxWinners: 1
round.totalFunded: 1000000000000000000
round.selectedCount: 1
round.claimedCount: 1
round.totalClaimed: 1000000000000000000
round.totalRefunded: 0
round.applicationsCount: 1
round.screeningMode: TwoAgent
round.screeningModeIndex: 0
requiredFunding: 1000000000000000000
selectedAllocation: 1000000000000000000
unallocatedAmount: 0
```

Final inspected application state:

```text
application.roundId: 3
application.verdict: Complete
application.verdictIndex: 1
application.status: Claimed
application.statusIndex: 9
application.selected: true
application.claimed: true
application.requestId: 0x00000000000000000000000000000000000000000000000000000000003f055e
application.notesURI: somnia-agent-request:4130149
application.canSelect: false
```

Result: passed. This proves the live TwoAgent GrantRound path:

```text
public JSON facts -> LLM bounded verdict -> judge/sponsor finalist selection -> finalization -> claim
```

## Scenario B - Four-Applicant Positive Flow

Status: skipped in this rerun.

Reason: Scenario A already proved the live TwoAgent agent callback path after public evidence became reachable. Running the full four-applicant flow would spend additional testnet funds and time without changing the primary blocker outcome. The command path remains documented in `docs/15_GRANT_ROUND_RUNBOOK.md`.

Expected path after choosing to spend the additional gas:

```text
Applicant 1 -> Complete
Applicant 2 -> NeedsReview
Applicant 3 -> Complete
Applicant 4 -> Incomplete
Select only applicants 1, 2, and 3 when maxWinners = 3.
```

## Scenario C - Negative Cases

Live negative cases were not rebroadcast in this rerun. They remain covered by Foundry tests:

```text
duplicate applicant: second submit reverts with duplicate application error
Incomplete cannot be selected: selectFinalists reverts
more than maxWinners: selectFinalists reverts
claim before finalize: claimPrize reverts
malformed evidence: expected VerificationFailed after live agent callback
```

Relevant passing tests:

```text
test_SubmitApplication_DuplicateApplicantReverts
test_SelectFinalists_CannotSelectIncompleteApplication
test_SelectFinalists_CannotSelectMoreThanMaxWinners
test_ClaimPrize_BlockedBeforeFinalize
test_HandleResponse_JsonMalformedResultCreditsUnusedLlmBudget
```

## Scenario D - ThreeAgent

Status: gated/future.

No positive ThreeAgent scenario was run.

Reason:

```text
The current deployed verifier supports JsonFactsToLlmVerdict.
The current source stores ScreeningMode.ThreeAgent but request-time support is gated.
No proven JsonFactsAndWebsiteToLlmVerdict workflow exists in the deployed verifier.
Raw GitHub HTML is reachable, but normal hosted HTML on Vercel, Cloudflare Pages, or Netlify is still preferred for Website Parse.
```

A positive ThreeAgent proof still requires:

```text
real hosted HTML is reachable;
Website Parse callback succeeds;
LLM Inference consumes JSON facts + parsed website content;
GrantRound receives final bounded verdict;
receipts/events prove the full path.
```

## Limitations

- `make grant-demo-request-screening` hit Forge script local execution `NotActivated`; direct `cast send` worked and produced the live request.
- The applicant used `APPLICANT_PRIVATE_KEY`, which fell back to the deployer key in this environment.
- Four-applicant and negative live scenarios were skipped to avoid additional testnet spend.
- ThreeAgent remains gated/future.

## Recommended Next Demo

For the concise proven demo:

```bash
make grant-demo-create-round GRANT_SCREENING_MODE=0 GRANT_MAX_WINNERS=1 GRANT_PRIZE_AMOUNT_WEI=1000000000000000000
make grant-demo-fund-round GRANT_ROUND_ID=<round>
make grant-demo-submit-application GRANT_ROUND_ID=<round> GRANT_EVIDENCE_URI=$GRANT_COMPLETE_EVIDENCE_URI
cast send $VIGILIA_GRANT_ROUND "requestApplicationScreening(uint256)" <app> \
  --value $GRANT_ROUND_WORKFLOW_DEPOSIT_WEI \
  --private-key "$DEPLOYER_PRIVATE_KEY" \
  --rpc-url "$SOMNIA_RPC_URL" \
  --legacy \
  --gas-limit 10000000
make grant-demo-inspect GRANT_ROUND_ID=<round> GRANT_APPLICATION_ID=<app>
make grant-demo-select-finalists GRANT_ROUND_ID=<round> GRANT_APPLICATION_IDS=<app>
make grant-demo-finalize-round GRANT_ROUND_ID=<round>
make grant-demo-claim-prize GRANT_APPLICATION_ID=<app>
```
