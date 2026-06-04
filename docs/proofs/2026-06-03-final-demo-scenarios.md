# Final Demo Scenarios

Recorded: 2026-06-04
Network: Somnia testnet, chain ID 50312
RPC: https://api.infra.testnet.somnia.network/

These runs are intended for the final dashboard demo. Explorer/indexer views may lag recent transactions, so direct tx hashes, contract reads, `make grant-demo-inspect`, and `cast call` are the source of truth.

## GrantRound v0.4 ThreeAgent Flagship

Contracts:

- GrantRound v0.4: `0x5aE1918Dcaa0A00a1d647e1c9946F7FF3fB61679`
- GrantRound verifier v0.4: `0xb0a1cdf062B4c295fC2A00F4bf1C84062F40d8e4`
- ThreeAgent deposit: `810000000000000000` wei

Campaign:

- Round ID: `8`
- Screening mode: `ThreeAgent`
- Prize amount: `3000000000000000000` wei
- Max winners: `3`
- Funded pool: `9000000000000000000` wei
- Requirements URI: `https://raw.githubusercontent.com/VitalR/vigilia-protocol/main/demo/evidence/grants/grant-requirements.md`

Evidence URL preflight returned HTTP 200 for:

- `bundle-complete.json`
- `bundle-needs-review.json`
- `bundle-incomplete.json`
- `complete-project.html`
- `needs-review-project.html`
- `incomplete-project.html`

Transactions:

| Step | Tx |
| --- | --- |
| Create round 8 | `0x59afb9f3fb501c480da45bbea5b36a74fffac2b014cd23161bfdc52dda24a305` |
| Fund round 8 with 9 STT | `0x82f0b446a2d6252dd17ee172b4b11f5c97b800c2f624869278f206f936256e5a` |
| Submit app 14, Complete bundle, applicant one | `0x0de18efe752344a48f2bd291302a6171374ff9335ea67a4a2ca478305fba2df8` |
| Submit app 15, Complete bundle, applicant three | `0x88cdc873ad1686242a3f49ed6392e0f370def15e7af50d95b4ac9dadbe398d0e` |
| Submit app 16, Incomplete bundle, applicant four | `0x03713b8295a186d7b61b837332f526c64ffe25c2fc7afd79841ede04b37826ec` |
| Submit app 17, NeedsReview bundle, applicant two | `0x90e2d458d4a71e4a8143ff41fc0a2843f63e329034ffc0e1a6d099b0c7350fec` |
| Request ThreeAgent screening, app 14 | `0xbdae8145be07091e6f6bfd1c9e413087d52facfe999a72d5bd7acb60b2404d23` |
| Request ThreeAgent screening, app 15 | `0xe34690c2e4c251027bd61997a77fddbb0efc0b2ac518cfb5ea93b63d3c1cb9cc` |
| Request ThreeAgent screening, app 17 | `0x695d5927ff15d6152595adbfc2fc0a31800854738fb9abed84e5204f46e69ef4` |
| Request ThreeAgent screening, app 16 | `0x55eee94cd07fb784c0e70f9c39a2480beca2f47f1537365b5618cb429aec6651` |
| Final verdict callback, app 14 | `0xe3db45ee1ad42717c9afb4a77686b7523533b83bfd945f930b3738ee229a84f2` |
| Final verdict callback, app 15 | `0x0f1dc2fd90370b13b065d6dbc60cc69192b83e00027bf1b01e8c4dd6054eb9e3` |
| Final verdict callback, app 17 | `0xa295e2e286a18de717021422b14531989d5edb2baa2a0881b763eb18694411ac` |
| Final verdict callback, app 16 | `0x83809ff128eafd11efbf5652b149d041687824bb943904c786dcb117ceef9821` |
| Select finalists 14, 15, 17 | `0x38d355270f4bbbf4598bf3c756d78b7e15dbc77bff9c31c36349f6bb72c66e6b` |
| Finalize round 8 | `0xc5ae2bc5461472bf229d929c9382b852acdf6411cbf9751dc1bf73b9e2d5a1a1` |
| Claim app 14 prize | `0x6e8feebaae0509ff736851d458699bf576a4eff22d3a5d94addaa2b8036069e5` |
| Claim app 15 prize | `0x944104f7b125fa66f0863a265f7e6833b05221507d5bd272c068055b4f42fc52` |
| Claim app 17 prize | `0xe6ce579544b4535e29f50e3b83d89a03fd3827e7d53f8e4b63a25988995d9b0e` |

Final application statuses:

| Application | Verdict/status | Selected | Claimed | Notes |
| --- | --- | --- | --- | --- |
| `14` | Complete / Claimed | true | true | `somnia-agent-request:4427479` |
| `15` | Complete / Claimed | true | true | `somnia-agent-request:4427487` |
| `17` | NeedsReview / Claimed | true | true | `somnia-agent-request:4427529` |
| `16` | Incomplete | false | false | `somnia-agent-request:4427951`; `canSelect=false` |

Final round state by contract read:

- `state = Finalized`
- `selectedCount = 3`
- `claimedCount = 3`
- `totalClaimed = 9000000000000000000`
- `selectedAllocation = 9000000000000000000`
- `unallocatedAmount = 0`

Product wording for this proof: agents screened applications; judges/sponsors selected finalists; the contract enforced the winner cap and pull claims. Agents did not choose winners and did not move prize funds.

Operational Makefile wrappers:

```bash
make final-demo-grant-env
make final-demo-grant-preflight
make final-demo-grant-inspect

make final-demo-grant-create-round
make final-demo-grant-fund-round GRANT_ROUND_ID=<round id>

make final-demo-grant-submit-complete-one GRANT_ROUND_ID=<round id>
make final-demo-grant-submit-needs-review GRANT_ROUND_ID=<round id>
make final-demo-grant-submit-complete-two GRANT_ROUND_ID=<round id>
make final-demo-grant-submit-incomplete GRANT_ROUND_ID=<round id>

make final-demo-grant-request-complete-one GRANT_APPLICATION_ID=<complete app 1>
make final-demo-grant-request-needs-review GRANT_APPLICATION_ID=<needs review app>
make final-demo-grant-request-complete-two GRANT_APPLICATION_ID=<complete app 2>
make final-demo-grant-request-incomplete GRANT_APPLICATION_ID=<incomplete app>

make final-demo-grant-select-finalists \
  GRANT_ROUND_ID=<round id> \
  GRANT_APPLICATION_IDS=<complete app 1>,<complete app 2>,<needs review app>
make final-demo-grant-finalize GRANT_ROUND_ID=<round id>
make final-demo-grant-claim-complete-one GRANT_APPLICATION_ID=<complete app 1>
make final-demo-grant-claim-complete-two GRANT_APPLICATION_ID=<complete app 2>
make final-demo-grant-claim-needs-review GRANT_APPLICATION_ID=<needs review app>
```

For the recorded proof, the default wrapper IDs are round `8`, finalists `14`,
`15`, and `17`, and incomplete app `16`.

## Escrow Fixed-Work Flagship

Contracts:

- Hardened v0.2.3 escrow: `0x1FA22E3a97dabB9a8C6de3a5B59eF6cCD5B2F4b9`
- Hardened v0.2.3 verifier: `0xdE0aC9700E591b54A418665575f2e1d329D78f3D`
- TwoAgent deposit: `360000000000000000` wei

Task:

- Task ID: `13`
- Client: `0x8998a83a6192dD5500EEbb666cad0bC2Ab0258E7`
- Contractor: `0x110C2cfaC2Df847FBC98cc0c514A11d0e2046c13`
- Amount: `5000000000000000000` wei
- Claim policy: `2` (`ImmediateAutoClaim`)
- Evidence URI: `https://raw.githubusercontent.com/VitalR/vigilia-protocol/main/demo/evidence/grants/facts-complete.json`

Transactions:

| Step | Tx |
| --- | --- |
| Create task 13 | `0x665c4e1753bb84e9493899b73f8419407722e254b842e0ce795d3cad84ada584` |
| Fund task 13 with 5 STT | `0x4dc57d7c3ceb265dd3a2238ca112aaed3779494ad3f21ca60a4f09112803f9b0` |
| Submit complete facts evidence | `0x2280714367b28ccc5b0a6c6496c4648b40e07acf6519e4e547d4ab8dd851c30c` |
| Complete verdict callback | `0x0efb80d79dadaa92554752fb6534cd171e95c9743927a015ee0217fd08481709` |
| Contractor claim | `0xe83f968a96852a624caa140de671509f89eedeb5da97b7793b87bbae76039a87` |

Final task state by direct `cast call tasks(13)`:

- `state = 9` (`Claimed`)
- `amount = 5000000000000000000`
- `fundedAmount = 0`
- `activeSubmissionId = 9`
- `submissionCount = 1`

The two-agent escrow path remains the fixed-work proof: JSON API facts plus LLM Inference bounded verdict plus escrow policy.

Operational Makefile wrappers:

```bash
make final-demo-escrow-env
make final-demo-escrow-preflight
make final-demo-escrow-inspect-task

make final-demo-escrow-create-task
make final-demo-escrow-fund-task DEMO_TASK_ID=<task id>
make final-demo-escrow-submit-complete DEMO_TASK_ID=<task id>
make final-demo-escrow-inspect-task DEMO_TASK_ID=<task id>
make final-demo-escrow-claim-task DEMO_TASK_ID=<task id>
```

For the recorded proof, the default wrapper task is `13`.

## Retry Failure Investigation

Failed tx:

- `0x54729c183d0e34c72ea309d3a81a55ee3e8bc118357cdaf67701d0a56d595e22`
- Function: `retryVerification(uint256)`
- Task ID: `11`
- Sender: `0x5a122Bb8Ade6EAfa9a6fB22a573C09f7E68Ac28a`
- Value: `0`
- Status: failed

Task `11` was in `VerificationFailed` and the failed tx sender was the contractor, so authorization and state were valid. The zero-value retry reverted with:

- Error selector: `0xfb6bcbec`
- Error: `InvalidVerificationDeposit(uint256,uint256)`
- Required: `360000000000000000`
- Actual: `0`

An `eth_call` simulation with `--value 360000000000000000` returned request ID `0x00000000000000000000000000000000000000000000000000000000004395eb`, confirming the likely root cause is frontend retry transaction construction with missing deposit value.

Recommended dapp fix:

- Query `minimumRequestDepositForWorkflow(JsonFactsToLlmVerdict)` or use fallback `360000000000000000`.
- Send retry transaction with `value = deposit`.
- Disable retry unless task state is `VerificationFailed`.
- Disable retry unless caller is client or contractor.
- Show a clear error: `Retry requires a new verification deposit of 0.36 STT.`

Operational Makefile wrappers:

```bash
make escrow-retry-decode
make escrow-retry-inspect-task
make escrow-retry-simulate-zero
make escrow-retry-simulate-with-deposit
make escrow-retry-diagnose
```

The optional broadcast wrapper is guarded and must not be used as a casual
diagnostic:

```bash
make escrow-retry-with-deposit CONFIRM_BROADCAST=1
```

## Recommended Final Demo Route

1. Show GrantRound v0.4 ThreeAgent round `8`: four applicants, 9 STT pool, three claimed finalists, one incomplete unselected.
2. Show fixed-work escrow task `13`: separate client/contractor, 5 STT, TwoAgent verification, contractor claim.
3. Mention resilience: failed verification does not unlock funds; retry exists, and the investigated failed retry was a missing deposit in the frontend call rather than a contract accounting failure.
