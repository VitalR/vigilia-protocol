# GrantRound v0.4 TwoAgent and ThreeAgent Proof

Date: 2026-06-03

Network: Somnia testnet, chain ID 50312

## Summary

This pass implemented, deployed, verified, and exercised a fresh GrantRound/verifier pair that supports both GrantRound screening modes:

- `TwoAgent`: JSON API facts -> LLM Inference bounded verdict -> GrantRound callback.
- `ThreeAgent`: JSON API facts -> JSON `websiteURI` -> Website Parse -> LLM Inference bounded verdict -> GrantRound callback.

TwoAgent and ThreeAgent both reached GrantRound bounded verdict callbacks on the v0.4 deployment. Agents screened applications; judges/sponsors selected finalists. Agents did not select winners or move prize funds.

The first live ThreeAgent request failed closed at the root JSON API stage when using a temporary `httpbin` bundle URL. After the committed `bundle-*.json` files were available through raw GitHub URLs, ThreeAgent completed the full GrantRound path.

Full E2E criteria met for the quick ThreeAgent proof: `ScreeningMode.ThreeAgent` round, public bundle evidence, JSON facts callback, JSON `websiteURI` callback, Website Parse callback, LLM bounded verdict, GrantRound `recordVerdict`, judge/sponsor finalist selection, finalization, and applicant claim.

## Deployment

Artifact:

```text
deployments/somnia-testnet-50312-grant-round-three-agent.json
```

Addresses:

```text
GrantRound: 0x5aE1918Dcaa0A00a1d647e1c9946F7FF3fB61679
Verifier:   0xb0a1cdf062B4c295fC2A00F4bf1C84062F40d8e4
Platform:   0x037Bb9C718F3f7fe5eCBDB0b600D607b52706776
```

Deployment transactions:

```text
Verifier create:    0x6da32d43b7acad4eb72bd1064b74d022c44263bfb2196c2271fdd23e4ce7d6aa
GrantRound create:  0xdd5c2e50d9585bf21e03a56e03e49568f97e091c7fd938a98f0843362212016a
Initial bind failed: 0x20afe9177598a499b1faad7b204e27833bf8ae5362e23f87f89c0801b023c033
Manual bind success: 0xe2bff0cc1c9c9ee8509f68af263cbc1fd4548ab41860bdbca39453d507903984
```

The initial deployment-script bind ran out of gas. A later manual `bindEscrow` call succeeded. State verification confirmed:

```text
verifier.escrow() == 0x5aE1918Dcaa0A00a1d647e1c9946F7FF3fB61679
grantRound.verifier() == 0xb0a1cdf062B4c295fC2A00F4bf1C84062F40d8e4
```

Workflow deposits:

```text
JsonFactsToLlmVerdict:              360000000000000000 wei
JsonFactsAndWebsiteToLlmVerdict:    810000000000000000 wei
```

Blockscout verification was submitted:

```text
Verifier:   https://somnia.w3us.site/address/0xb0a1cdf062b4c295fc2a00f4bf1c84062f40d8e4
GrantRound: https://somnia.w3us.site/address/0x5ae1918dcaa0a00a1d647e1c9946f7ff3fb61679
```

## Evidence URL Preflight

All final evidence URLs returned HTTP 200 before live requests:

```text
grant-requirements.md
facts-complete.json
facts-needs-review.json
facts-incomplete.json
facts-malformed.json
bundle-complete.json
bundle-needs-review.json
bundle-incomplete.json
bundle-malformed.json
complete-project.html
needs-review-project.html
incomplete-project.html
```

The `bundle-complete.json`, `bundle-needs-review.json`, and `bundle-incomplete.json` files contain top-level `facts` and `websiteURI`. `bundle-malformed.json` intentionally omits both for negative testing.

## Failed ThreeAgent Temporary-URL Attempt

Round:

```text
Round ID: 1
Screening mode: ThreeAgent
Prize amount: 1 STT
Max winners: 1
```

Application:

```text
Application ID: 1
Applicant: 0x110C2cfaC2Df847FBC98cc0c514A11d0e2046c13
Evidence: temporary https://httpbin.org/base64/... bundle containing facts and websiteURI
Website URI inside bundle: https://raw.githubusercontent.com/VitalR/vigilia-protocol/main/demo/evidence/grants/complete-project.html
```

Transactions:

```text
Create round:      0x61b17d13419b5b52077cf4e0ee8fac53c508c86ddf9cc8542f7123f27c41e432
Fund round:        0x5fe70d72bdeb4957e6bdaa9f45282cfe40db26306a4eea588d3017d53b6c7cbb
Submit app:        0xc8626154d97edb0156aad59b818a67b0d6d4ba57e9a3d42d9b29425a733bfdb6
Request screening: 0x06c3716f2fcad45e75f9bec657e2c68d605f7311fc2ae6bc8faef8bd07365c15
Failure callback:  0x744712a7dea2416ed063ba57609cf0316e7e4c9526447d010df8e034950e4ac2
```

Request IDs:

```text
Root JSON facts request: 4307187
GrantRound requestId: 0x000000000000000000000000000000000000000000000000000000000041b8f3
```

Final observed application state:

```text
verdict: Unknown
status: VerificationFailed
selected: false
claimed: false
notesURI: somnia-agent-request:4307187
```

Verifier event:

```text
MultiAgentVerificationFailed(rootRequestId=4307187, taskId=1, submissionId=1, kind=JsonApi, workflow=JsonFactsAndWebsiteToLlmVerdict, status=Failed)
```

GrantRound event:

```text
ApplicationVerificationFailed(roundId=1, applicationId=1, requestId=4307187, notesURI=somnia-agent-request:4307187)
```

Interpretation:

The fresh contract/verifier pair correctly accepted a ThreeAgent request and failed closed. The request did not reach the JSON `websiteURI`, Website Parse, or LLM stages because the root JSON API request failed. The likely operational cause was the temporary `httpbin` evidence bundle URL.

## v0.4 TwoAgent Quick Proof

Status: passed.

```text
Round ID: 2
Application ID: 2
Mode: TwoAgent
Evidence: facts-complete.json
Request tx: 0x292e4e4c63a311520d25486112989ba52fd36f13c93e2722809c348da11d8827
Root request ID: 4326201 / 0x41e339
Final verdict: Complete
Final status: Claimed
```

## v0.4 TwoAgent Four-Applicant Proof

Status: passed.

```text
Round ID: 4
Mode: TwoAgent
Prize amount: 1 STT
Max winners: 3
Funding: 3 STT
```

Applications:

```text
App 5: facts-complete.json      -> Complete, selected, claimed
App 6: facts-needs-review.json -> NeedsReview, selected, claimed
App 7: facts-complete.json      -> Complete, selected, claimed
App 8: facts-incomplete.json    -> Incomplete, not selected, not claimed
```

Screening requests:

```text
App 5: tx 0x70a6ab738b4765498a40e90d72eb85b8981675a4820634e576689c8ac3fecdc4, root request 4327005 / 0x41e65d
App 6: tx 0xb7305db2e2b57e43a87e826860d3ec55232655131117ff1e647346db7c176c54, root request 4327046 / 0x41e686
App 7: tx 0x100e317fa01fe2a56270bc7457e00df9a831048590a59ca92da7e71b73bcca8a, root request 4327159 / 0x41e6f7
App 8: tx 0x81effb2611d467720ca14f5b206dfdd8cfbe80e493dcb5b25f404ad1ab96ba92, root request 4327240 / 0x41e748
```

Final lifecycle transactions:

```text
Select apps 5,6,7: 0xa3c93723f20934aa7268d35fffc9eb263140106d1d9d1ebe533f587acdf9e6ee
Finalize round 4:  0xbb5a2fdbd03ef586a7ebaf11ecde7f695d4875ba3eddc54874df3886327bba8e
Claim app 5:       0xbd4fc4234ea5e2868a1941b268b27b27565c9933f4e87981de329555d985b5c5
Claim app 6:       0x73a9ae228d7f4ed1cb11f1a2f0b58328642c69e6f995cf2385515d470f395680
Claim app 7:       0xbc720245ed28498270adb163739be9408292809cab830d08f72882a6931d523d
```

Final round state:

```text
state: Finalized
selectedCount: 3
claimedCount: 3
totalClaimed: 3000000000000000000 wei
unallocatedAmount: 0
```

## v0.4 ThreeAgent Quick Proof

Status: passed.

The sponsor did not have enough balance left for another 1 STT proof round after prior scenario funding, so this proof used a lower 0.01 STT prize. The screening workflow deposit remained the real ThreeAgent deposit: `810000000000000000` wei.

```text
Round ID: 6
Application ID: 9
Mode: ThreeAgent
Prize amount: 0.01 STT
Evidence: bundle-complete.json
```

Transactions:

```text
Create round:      0xa774278a95557e5027fb4ecc1c3eda3a325d9b4adb9bfff1e9c97a263799f896
Fund round:        0xa4a684ba5882bdcb3d10915e4646d8263cbf89b8c193d38e06ac6cb66388a83f
Submit app:        0xc599c9e49ef8570805d6de2f9b1910b734ae907eaa49fe0b47424a11a52a32a2
Request screening: 0xe652fd85dca19d04030a63a72db775cd56bccc14c14236363ecce84cfc5e8fff
Select finalist:   0x6fd4df62985f52eede2d6c2c1b669f6f9be703ee164ecb0cc0f2cc445557784c
Finalize:          0x37b9e97f0ee4cee305073c1a24441db89fa77e1a4dfcccb0a4739e6f6673534d
Claim:             0xe12a26f8637998287b5accd20c2da827e88751244cfe450b3a7884a411b27fd5
```

Request and final state:

```text
Root request ID: 4328261 / 0x41eb45
Final LLM notesURI: somnia-agent-request:4320114
Final verdict: Complete
Final status: Claimed
```

This proves the full ThreeAgent GrantRound path for one applicant: JSON facts, JSON `websiteURI`, Website Parse, LLM bounded verdict, GrantRound callback, judge/sponsor selection, finalization, and pull claim.

## v0.4 ThreeAgent Four-Applicant Proof

Status: passed.

```text
Round ID: 7
Mode: ThreeAgent
Prize amount: 0.01 STT
Max winners: 3
Funding: 0.03 STT
```

Applications:

```text
App 10: bundle-complete.json      -> Complete, selectable
App 11: bundle-needs-review.json -> NeedsReview, selectable
App 12: bundle-complete.json      -> Complete, selectable
App 13: bundle-incomplete.json    -> Incomplete, not selectable
```

Application transactions:

```text
Create round 7: 0xa2a56badae259ee21106ebe14fec2694db9d952a13bea878bed69fa278471532
Fund round 7:   0x8f93ccc7a1afda25475d74510e894f9d8cc5a20a214d8be8a471c500a4d66922
Submit app 10:  0xa79641fffe96df37f011fe8d819bd9b2ba6021fb0e367cdee009c65a72ce5db8
Submit app 11:  0x3fbca69d217ecc39381bc1b21e9bbb3672c112f9a2513c471833e402e8cdba1c
Submit app 12:  0x8bb342b0b3d5469b81222e486cfe743a8a948aab51a3bf2c164911d04149b91a
Submit app 13:  0x0c0f817430f7562c04a2fc896e3aa6d070d22132de4a4d2ef8eb7fa1a82b997e
```

Screening requests:

```text
App 10: tx 0xb9ec75c3495fe0515973b5d5348b61a81592e6feeb8275143421c89594cd99f3, root request 4329726 / 0x41f0fe
App 11: tx 0x7eb03ca8bc599f59e737fb48b649fa06cc4aaa17fdc3d61270b2d61ede12b272, root request 4329795 / 0x41f143
App 12: tx 0x4156e6738efda9701ce60bb2e6d43f5a37f489012827ddd9ad9564901e6b3411, root request 4329849 / 0x41f179
App 13: tx 0x88fb88c732d233f44717802cf6bb4577e8e174c5c7a1d3c8d5126b800aaf8b90, root request 4329893 / 0x41f1a5
```

Final callback notes:

```text
App 10: somnia-agent-request:4321578
App 11: somnia-agent-request:4321675
App 12: somnia-agent-request:4321691
App 13: somnia-agent-request:4321734
```

Final lifecycle transactions:

```text
Select apps 10,11,12: 0x44eb3d78ffb66fed768f6b1e5fd32d6f2a4c30e80dcff852af6f227ae5031f1c
Finalize round 7:     0xae068573eac925e89d4e9ee3802b2cba67a3d468270d0e76c5245c150f9c32fa
Claim app 10:         0x1bddab63e3c47831222a33d35ffa02811e0c97e6e668bc6ef1dd87e91ed4ffb1
Claim app 11:         0x73778f7a61f1ddafde88c4ba49b4dc45f546c6075df889ad6c4dc8a8d1b775e8
Claim app 12:         0xf9a0da3de87293aede63694c881c80943cbb26249f34cdd78c7e308e3dd71077
```

Final round state:

```text
state: Finalized
selectedCount: 3
claimedCount: 3
totalClaimed: 30000000000000000 wei
unallocatedAmount: 0
App 13: Incomplete, selected=false, claimed=false, canSelect=false
```

## Safety Result

The failed ThreeAgent temporary-URL callback did not select a finalist and did not move funds. Successful TwoAgent and ThreeAgent callbacks also did not select finalists or move prize funds. Finalist selection remained a judge/sponsor action, and claims remained applicant pull payments after finalization.

## Recommended Demo Mode

ThreeAgent is now proven end to end on the fresh v0.4 deployment and can be the flagship GrantRound demo mode. TwoAgent remains the safe fallback because it is also proven on the same v0.4 deployment.

Use v0.4 addresses for final demos:

```bash
export VIGILIA_GRANT_ROUND=0x5aE1918Dcaa0A00a1d647e1c9946F7FF3fB61679
export VIGILIA_GRANT_ROUND_VERIFIER=0xb0a1cdf062B4c295fC2A00F4bf1C84062F40d8e4
export GRANT_SCREENING_MODE=1
export GRANT_ROUND_THREE_AGENT_WORKFLOW_DEPOSIT_WEI=810000000000000000
```
