# Two-Agent Settlement Hardened RPC Proof - 2026-06-01

Source of truth: official Somnia testnet RPC, `https://api.infra.testnet.somnia.network/`.

## Deployment (v0.2.3 hardened)

| Field | Value |
|---|---|
| Chain ID | `50312` |
| Escrow | `0x1FA22E3a97dabB9a8C6de3a5B59eF6cCD5B2F4b9` |
| Verifier | `0xdE0aC9700E591b54A418665575f2e1d329D78f3D` |
| Artifact | `deployments/somnia-testnet-50312-two-agent-settlement-hardened.json` |
| Workflow | `JsonFactsToLlmVerdict` |
| Workflow deposit | `360000000000000000 wei` (`TWO_AGENT_WORKFLOW_DEPOSIT_WEI`) |
| Enabled settlement agents | `json-api,llm-inference` |
| Disabled settlement agent | `llm-parse-website` |

Deployment receipts:

| Step | Tx | Block | Status |
|---|---|---:|---|
| Deploy verifier | `0x237cd8fa61d006c9d4f887710f2cb3a5356eb54e68ba68e55ff1fee3eb32079d` | `397335031` | success |
| Deploy escrow | `0x234899fea3a3ef53bb5fd5a0c02214004a347b7a99756f8b79dc97762267e859` | `397335031` | success |
| Initial bind | `0x361bad226ca97132420aadd84791ab1202323f3e7285bb4078bdeed1cabf622d` | `397335031` | failed: low gas cap |
| Replacement bind | `0xa08b11bdd2303a743949ea4ddbd7950f6b0d7f444b8c7a3fbdb4f05b59f7e27c` | `397335877` | success |

Wiring reads:

```text
verifier.escrow() = 0x1FA22E3a97dabB9a8C6de3a5B59eF6cCD5B2F4b9
escrow.verifier() = 0xdE0aC9700E591b54A418665575f2e1d329D78f3D
minimumRequestDepositForWorkflow(3) = 360000000000000000
agentConfigs(1).settlementEnabled = true
agentConfigs(2).settlementEnabled = true
agentConfigs(3).settlementEnabled = false
```

Blockscout verification (2026-06-01):

```bash
make multi-settlement-verify-escrow
make multi-settlement-verify-verifier
```

Both contracts returned `Response: OK` after the explorer indexer caught up (escrow GUID
`1fa22e3a97dabb9a8c6de3a5b59ef6ccd5b2f4b96a1cd503`, verifier GUID
`de0ac9700e591b54a418665575f2e1d329d78f3d6a1cd505`).

## Makefile E2E runs

All scenarios below used the Makefile demo targets with `.env` pointed at the v0.2.3 addresses and
`TWO_AGENT_WORKFLOW_DEPOSIT_WEI=360000000000000000`. Submit targets use `--skip-simulation`; local forge simulation may
log `local submit simulation failed` while the on-chain broadcast still succeeds.

### Case 1: Complete + ImmediateAutoClaim (task 4)

| Step | Tx | Block |
|---|---|---:|
| Create (`make multi-agent-demo-create-task-immediate-claim`) | `0xb6f1948d81a063b72f045ab9dab15b1e29a09481e5f548a61c8657877120866e` | `397344050` |
| Fund (`make multi-settlement-demo-fund-task`) | `0x923b1c4e16cdca7ea1e95ac552a643318a872ae308613f28b1b6021a7ec2224e` | `397344129` |
| Submit complete facts | `0x405fb1c16947f71e2e2e01871153c6d77bd603c313f0a4ab4e9eddd1a9bfcc64` | `397344208` |
| JSON callback | `0x452417dfa3a4f8da6b9326e93a87910f4b9965dbbbdbe2077420fc444d6984f9` | `397344225` |
| LLM callback | `0xc7466e87561b2d092c4c847fc0d5d5e51f3389ea95089d5d49305f064062e3c9` | `397344232` |
| Claim (`make multi-settlement-demo-claim-task`) | `0xeb25226ccd8ee5d23f7f555f65efd012709a20201d2162de6ae34bb8a38d8384` | `397344400` |

Decoded values:

```text
taskId: 4
submissionId: 2
claimPolicy: ImmediateAutoClaim (2)
JSON platformRequestId: 3649675 / 0x37888b
LLM platformRequestId: 3649679 / 0x37888f
JSON facts: repo_exists=true; readme_setup=true; deployment_address_present=true; demo_url_present=true; tests_passed=true
LLM raw bytes: 0x436f6d706c657465
LLM decoded verdict: Complete
Final state: Claimed
```

### Case 2: Malformed facts + recovery (task 6)

| Step | Tx | Block |
|---|---|---:|
| Create (`make multi-agent-demo-create-task-immediate-claim`) | `0xb37161d109173049e78dfedc78f83e981bfac276c65fe1ca9f3f1ce67f3e5b94` | `397345535` |
| Fund | `0x9110311781353f9458de7ec48f509871a3d0db057f407951a0bd04dff20173ad` | `397345617` |
| Submit malformed facts | `0xa08de61046dc469f9b3081526598f074bf01743bf7fd9a5a1dca7f029127f6ef` | `397345712` |
| JSON failure callback | `0x96080692c68d80390a369344f0437d988dbf1a51b5f3635eb62ee82c37a67b84` | `397345725` |
| Resubmit complete facts | `0x63c8194368bad016d6c9387dc8c711299d6731541c2791240f0a9e64b81d8503` | `397346820` |
| Recovery JSON callback | `0x6ee85d8f19cd7ac6aca11fe9c349a0725a71d18f966481d0a8d8bf3340a8ceee` | `397346836` |
| Recovery LLM callback | `0xd154cd0f9eefe1d557e5309554a1c7f65c213023eddabab45a7c7ae6df74f896` | `397346843` |
| Claim | `0x5938a39f07d23a0e2613372b9089d1d13e0421233016a38d9a1b67a97b1fdf1e` | `397346945` |

Decoded values:

```text
taskId: 6
malformed submissionId: 5
recovery submissionId: 6
Malformed JSON platformRequestId: 3649879 / 0x378a57
Failure notesURI: somnia-agent-request:3649879
Recovery JSON platformRequestId: 3649957 / 0x378ba5
Recovery LLM platformRequestId: 3649964 / 0x378bac
Recovery LLM raw bytes: 0x436f6d706c657465
Recovery LLM decoded verdict: Complete
State after malformed submit: VerificationFailed
claim(6) before recovery eth_call reverts with InvalidState
Final state: Claimed
```

### Case 3: NeedsReview (task 7)

| Step | Tx | Block |
|---|---|---:|
| Create (`make multi-settlement-demo-create-task`) | `0xeb3138ea371935e08e20c550d608ce5699414b4d83d3a37ce79a37592fd4d123` | `397347024` |
| Fund | `0xc2a99bafa3398179e275b5d244532954c5c1938f01042bb68874f80bc9c3ca65` | `397347109` |
| Submit needs-review facts | `0x6c2386252f7c9278edbf1f1f5a42a0ede3681bc3d64557960f2be443400badd1` | `397347188` |
| JSON callback | `0x286f845d5c01056b7f706d8308110c6d17af4ca3c708e9e72423ff389e51dbf5` | `397347203` |
| LLM callback | `0x4c58f5e0f4b7680499abeee3765fba2792e9f19610169ab95d1908132830c9f3` | `397347209` |
| Approve (`make multi-settlement-demo-approve-task`) | `0x3a43f754e45e48027eae9468d7fc7763226fadb323cf66d1813c87a2e613f3a7` | `397347758` |
| Claim | `0xaf35789dcfa477636f2689e36bb52a7dae8568c3d1d42379c0707a4701299346` | `397347784` |

Decoded values:

```text
taskId: 7
submissionId: 7
JSON platformRequestId: 3650585 / 0x378c19
LLM platformRequestId: 3650589 / 0x378c1d
JSON facts: repo_exists=true; readme_setup=true; deployment_address_present=unclear; demo_url_present=true; tests_passed=unknown
LLM raw bytes: 0x4e65656473526576696577
LLM decoded verdict: NeedsReview
State before approval: NeedsReview
claim(7) before approval eth_call reverts with InvalidState
Final state: Claimed
```

JSON and LLM callback transactions target the Somnia Agent Platform (`0x037Bb9C718F3f7fe5eCBDB0b600D607b52706776`), not
the verifier or escrow directly. Verifier and escrow events appear inside those callback receipts.

## Proof boundary

This proves live v0.2.3 hardened settlement: JSON API facts, LLM Inference bounded verdict, escrow timeout/claimTo liveness,
unused LLM budget refunds on JSON-stage failure, and pull-based cancel/claim paths in source. It does not prove LLM Parse
Website settlement or arbitrary website parsing as a settlement-critical path.

Historical v0.2.2 proof remains in `docs/proofs/2026-06-01-two-agent-settlement-rpc-proof.md` and must not be overwritten.
