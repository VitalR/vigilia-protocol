# GrantRound Demo Scenario Proof - 2026-06-02

## Summary

Network: Somnia testnet, chain id `50312`

GrantRound: `0xaA20C6C3F37f5E97cb2fed1c14575b76EE4F3C9a`

Fresh GrantRound verifier: `0x44276D0d3149a9915fC2a4d5E6F0f66eD74185C3`

Current proven workflow: `TwoAgent / JsonFactsToLlmVerdict`

Current workflow deposit: `360000000000000000` wei

ThreeAgent status: gated/future. The deployed verifier does not expose a proven `JsonFactsAndWebsiteToLlmVerdict` workflow, and no Website Parse callback proof was produced in this run.

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

`make grant-demo-inspect` could not read `minimumRequestDepositForWorkflow(3)` inside the local Forge script because the platform helper reverted with `NotActivated`, so the script printed the configured fallback deposit `360000000000000000`.

## Evidence URL Check

Configured raw GitHub URLs were checked with `curl`.

```text
https://raw.githubusercontent.com/VitalR/vigilia-protocol/main/demo/evidence/grants/grant-requirements.md       404
https://raw.githubusercontent.com/VitalR/vigilia-protocol/main/demo/evidence/grants/facts-complete.json          404
https://raw.githubusercontent.com/VitalR/vigilia-protocol/main/demo/evidence/grants/facts-needs-review.json     404
https://raw.githubusercontent.com/VitalR/vigilia-protocol/main/demo/evidence/grants/facts-incomplete.json       404
https://raw.githubusercontent.com/VitalR/vigilia-protocol/main/demo/evidence/grants/facts-malformed.json        404
https://raw.githubusercontent.com/VitalR/vigilia-protocol/main/demo/evidence/grants/complete-project.html       404
https://raw.githubusercontent.com/VitalR/vigilia-protocol/main/demo/evidence/grants/needs-review-project.html   404
https://raw.githubusercontent.com/VitalR/vigilia-protocol/main/demo/evidence/grants/incomplete-project.html     404
```

Result: live Somnia agent callbacks were skipped. The local fixture files exist, but the branch content was not reachable from raw GitHub at the time of this proof.

Required next step for agent proof: push the fixture files to GitHub or host them on Vercel, Cloudflare Pages, Netlify, or GitHub Gist raw URLs.

## Scenario A - TwoAgent Quick Positive, Contract-Only Recovery

Purpose: prove the GrantRound contract lifecycle with the current deployment while evidence URLs were not publicly reachable.

Mode: `GRANT_SCREENING_MODE=0`

Prize: `1000000000000000000` wei

Max winners: `1`

Round ID: `2`

Application ID: `1`

Applicant: `0x110C2cfaC2Df847FBC98cc0c514A11d0e2046c13`

Evidence URI stored on-chain:

```text
https://raw.githubusercontent.com/VitalR/vigilia-protocol/main/demo/evidence/grants/facts-complete.json
```

Evidence hash:

```text
0x371495ddc5cd8ba25e14aa81cf8332d0282b88e0d25abefe312570592d34bf61
```

Notes URI:

```text
ipfs://manual-review/evidence-url-404-contract-only-complete
```

Commands:

```bash
make grant-demo-create-round \
  GRANT_SCREENING_MODE=0 \
  GRANT_MAX_WINNERS=1 \
  GRANT_PRIZE_AMOUNT_WEI=1000000000000000000 \
  GRANT_FAST_DEADLINES=true \
  GRANT_FAST_APPLICATION_WINDOW_SECONDS=180 \
  GRANT_FAST_REVIEW_WINDOW_SECONDS=600

make grant-demo-fund-round GRANT_ROUND_ID=2

make grant-demo-submit-complete GRANT_ROUND_ID=2 GRANT_APPLICANT_INDEX=0

make grant-demo-manual-screen-complete \
  GRANT_APPLICATION_ID=1 \
  GRANT_NOTES_URI=ipfs://manual-review/evidence-url-404-contract-only-complete

make grant-demo-select-finalists GRANT_ROUND_ID=2 GRANT_APPLICATION_IDS=1

make grant-demo-finalize-round GRANT_ROUND_ID=2

make grant-demo-claim-prize GRANT_APPLICATION_ID=1

make grant-demo-inspect GRANT_ROUND_ID=2 GRANT_APPLICATION_ID=1
```

Note: `grant-demo-submit-complete` is a scenario target and defaulted to `APPLICANT_ONE_PRIVATE_KEY`; for a strict generic `APPLICANT_PRIVATE_KEY` submission, use `make grant-demo-submit-application` with `GRANT_EVIDENCE_URI` set.

Transactions:

```text
create round 2:       0x8d35358758523c1904d5abf2e4d7606acf5f20ce8849c8dd1f1338d7e4878bb5 status=1
fund round 2:         0xd113696bd460ab8982937d3deeeb1dbc709c22beb838fef662897834cde0b39c status=1
submit app 1:         0x6631a1bb42dfd18496b467db77f87633bd6287b32170f24e0642479a0af84d28 status=1
manual screen app 1:  0x80f3dbfbdfd974598bf455a199d573d311b46e4f95a62a99a3adc99b03a8cad5 status=1
select finalist:      0xe68323246899232be8ec79df41c907dd32e9fdf0f90dcb4936251686c1b3115f status=1
finalize round 2:     0x153d3d826d7906c27c32d7ee8f0e3e707d9f40a1f9d11393d7d71e3013ddb2d5 status=1
claim app 1:          0x11840c8ff75d4be19fe778906febb843f178e2519b1e0edf99852f698f755faa status=1
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
application.roundId: 2
application.verdict: Complete
application.verdictIndex: 1
application.status: Claimed
application.statusIndex: 9
application.selected: true
application.claimed: true
application.requestId: 0x0000000000000000000000000000000000000000000000000000000000000000
application.canSelect: false
```

No request ID or callback transaction exists for this scenario because live agent screening was skipped after the evidence URL check returned 404.

## Cleanup

An initial create-round command was run with shell environment overrides. The repository Makefile imports `.env`, so `.env` values took precedence over those shell exports. This created round `1` with the existing `.env` demo values.

Round `1` was unfunded and was cancelled safely.

```text
create round 1:  0x9627526aa6ca2582decb2963603189af8acdb39d13d72880433dbd36a881a897 status=1
cancel round 1:  0x6bcdc39f913a015c5a82e1c0dbbbbbe0f33b8aa85d23700a84cf4324e238fcdc status=1
```

Operator note: pass demo overrides as Make command variables, for example:

```bash
make grant-demo-create-round GRANT_MAX_WINNERS=1 GRANT_PRIZE_AMOUNT_WEI=1000000000000000000
```

## Scenario B - Four-Applicant Positive Flow

Status: skipped.

Reason: the required public JSON evidence URLs returned 404, so live Somnia TwoAgent callbacks could not be proven. Running a four-applicant contract-only flow would spend additional testnet funds without proving the agent path.

Expected command path after hosted evidence is available:

```bash
make grant-demo-create-round GRANT_SCREENING_MODE=0 GRANT_MAX_WINNERS=3
make grant-demo-fund-round GRANT_ROUND_ID=<round>

make grant-demo-submit-complete GRANT_ROUND_ID=<round> GRANT_APPLICANT_INDEX=1
make grant-demo-request-screening-complete GRANT_APPLICATION_ID=<app1>

make grant-demo-submit-needs-review GRANT_ROUND_ID=<round> GRANT_APPLICANT_INDEX=2
make grant-demo-request-screening-needs-review GRANT_APPLICATION_ID=<app2>

make grant-demo-submit-complete GRANT_ROUND_ID=<round> GRANT_APPLICANT_INDEX=3
make grant-demo-request-screening-complete GRANT_APPLICATION_ID=<app3>

make grant-demo-submit-incomplete GRANT_ROUND_ID=<round> GRANT_APPLICANT_INDEX=4
make grant-demo-request-screening-incomplete GRANT_APPLICATION_ID=<app4>
```

Expected statuses after callbacks:

```text
app1 -> Complete
app2 -> NeedsReview
app3 -> Complete
app4 -> Incomplete
```

## Scenario C - Negative Cases

Live negative cases were skipped to avoid spending testnet gas on expected-revert broadcasts while public evidence was not hosted.

Expected behavior is covered by Foundry tests:

```text
duplicate applicant: second submit reverts with duplicate application error
Incomplete cannot be selected: selectFinalists reverts
more than maxWinners: selectFinalists reverts
claim before finalize: claimPrize reverts
malformed evidence: expected VerificationFailed after live agent callback once hosted JSON is reachable
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
The raw GitHub HTML fixture URLs returned 404.
```

A positive ThreeAgent proof requires:

```text
real hosted HTML is reachable;
Website Parse callback succeeds;
LLM Inference consumes JSON facts + parsed website content;
GrantRound receives final bounded verdict;
receipts/events prove the full path.
```

## Limitations

- Public evidence URLs were not reachable at the time of this run.
- Live TwoAgent callbacks were skipped.
- No request IDs were produced.
- No callback tx hashes were produced.
- Manual screening was used only as recovery metadata for the contract-only proof.
- Four-applicant and negative live scenarios were skipped to avoid unnecessary testnet gas until evidence hosting is fixed.
- ThreeAgent remains gated/future.

## Recommended Next Demo

After pushing or hosting the evidence files:

```bash
make grant-demo-create-round GRANT_SCREENING_MODE=0 GRANT_MAX_WINNERS=3 GRANT_PRIZE_AMOUNT_WEI=1000000000000000000
make grant-demo-fund-round GRANT_ROUND_ID=<round>

make grant-demo-submit-complete GRANT_ROUND_ID=<round> GRANT_APPLICANT_INDEX=1
make grant-demo-request-screening-complete GRANT_APPLICATION_ID=<app1>

make grant-demo-submit-needs-review GRANT_ROUND_ID=<round> GRANT_APPLICANT_INDEX=2
make grant-demo-request-screening-needs-review GRANT_APPLICATION_ID=<app2>

make grant-demo-submit-complete GRANT_ROUND_ID=<round> GRANT_APPLICANT_INDEX=3
make grant-demo-request-screening-complete GRANT_APPLICATION_ID=<app3>

make grant-demo-submit-incomplete GRANT_ROUND_ID=<round> GRANT_APPLICANT_INDEX=4
make grant-demo-request-screening-incomplete GRANT_APPLICATION_ID=<app4>

make grant-demo-inspect GRANT_ROUND_ID=<round>
make grant-demo-select-finalists GRANT_ROUND_ID=<round> GRANT_APPLICATION_IDS=<app1>,<app2>,<app3>
make grant-demo-finalize-round GRANT_ROUND_ID=<round>
make grant-demo-claim-prize GRANT_APPLICATION_ID=<app1>
make grant-demo-claim-prize GRANT_APPLICATION_ID=<app2>
make grant-demo-claim-prize GRANT_APPLICATION_ID=<app3>
```
