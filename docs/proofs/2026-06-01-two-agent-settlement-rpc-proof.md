# Two-Agent Settlement RPC Proof - 2026-06-01

Source of truth: official Somnia testnet RPC, `https://api.infra.testnet.somnia.network/`.

## Deployment

| Field | Value |
|---|---|
| Chain ID | `50312` |
| Escrow | `0x16F9B1e1e732DFeE1e2231E52b399e9d2344F568` |
| Verifier | `0x79d94c986c64C69fDea935a2Ee6c303Dae852AE2` |
| Somnia Agent Platform | `0x037Bb9C718F3f7fe5eCBDB0b600D607b52706776` |
| JSON API Agent ID | `13174292974160097713` |
| LLM Inference Agent ID | `12847293847561029384` |
| Workflow | `JsonFactsToLlmVerdict` |
| Workflow deposit | `360000000000000000 wei` |

Deployment receipts:

| Step | Tx | Block | Status |
|---|---|---:|---|
| Deploy verifier | `0xbfcd49ec825ab130e8059cd468b0614850bbdd028d6505bbc52be5d0b95b372e` | `397241733` | success |
| Deploy escrow | `0x84babe092f40ee217a2e1ba167471f3b3e1b8065b7fbb2d65d4b836371e78490` | `397241733` | success |
| Initial bind | `0x5bcc0e11aa5a2ae05553efe5049efc0fa631f5ec28c815d353a59b7673f3aa6b` | `397241733` | failed: low gas cap |
| Replacement bind | `0xfcd78e88fada0f964e858a4a808e5c15599a182acb20bcc3c3a23586d0405716` | `397242373` | success |

Wiring reads:

```text
verifier.escrow() = 0x16F9B1e1e732DFeE1e2231E52b399e9d2344F568
escrow.verifier() = 0x79d94c986c64C69fDea935a2Ee6c303Dae852AE2
minimumRequestDepositForWorkflow(3) = 360000000000000000
```

Blockscout verification was attempted after deployment. The API returned `Address is not a smart-contract` for both
new addresses even though official RPC calls and live receipts prove both contracts exist and execute. Treat this as an
explorer/indexer lag until re-verification succeeds.

## Happy Path

Task `1`, submission `1`, `ImmediateAutoClaim`.

| Step | Tx | Block | Receipt fact |
|---|---|---:|---|
| Create | `0x2ec214e2403ee9ab3a5f78495235555b4059435506eecafde0c8653f9d336f86` | `397242936` | `TaskCreated`, policy `2` |
| Fund | `0x8732826ec8bf3c3c532806263f0385db0aa1895837ff17cc828cd453cfbeef6e` | `397243290` | `TaskFunded` |
| Submit | `0x96008cdb73f9373024a173597864baaa2059d1e09be41ebca6c6acde7fca3449` | `397243710` | tx `to` escrow, request `3608591` |
| JSON callback | `0x9885604845585700ebbdfbb1b419b48e050a0c731977de384e5ce034101d1c4a` | `397243725` | tx `to` Somnia platform; emitted `JsonFactsReceived` and `LlmVerdictRequested` |
| LLM callback | `0x730da5ef5571b8429ee902e96e5993477c63eb71f7404ed053222817f0599e69` | `397243732` | tx `to` Somnia platform; emitted `MultiAgentVerificationSucceeded` and escrow `VerdictRecorded` |
| Claim | `0x43677eb5be49e481294e0a1e64cf265b0b60222bd2b00899321df561b94fa13a` | `397244093` | `TaskClaimed` |

Decoded values:

```text
JSON platformRequestId: 3608591 / 0x37100f
LLM platformRequestId: 3608598 / 0x371016
facts: repo_exists=true; readme_setup=true; deployment_address_present=true; demo_url_present=true; tests_passed=true
LLM raw bytes: 0x436f6d706c657465
LLM decoded string: Complete
Final task state: Claimed
```

The LLM callback transaction `to` is `0x037Bb9C718F3f7fe5eCBDB0b600D607b52706776`, not the verifier or escrow.

## Non-Happy Path

Task `2`, submission `2`, incomplete facts.

| Step | Tx | Block | Result |
|---|---|---:|---|
| Create | `0x1bed475e65f54a1ead0d8560307134d3be873cacb796a60317aa51acf5050002` | `397244354` | success |
| Fund | `0xac7b11b701f323c63b4e5ecf3a12aed095e6c181a1bd256afb25e417753ba65f` | `397244464` | success |
| Submit | `0x5a74e62d020df45051b156d1668b92b230f8f868a853e1f6dab65e87caf6a4b9` | `397244650` | JSON request `3608878` |
| JSON callback | `0xc35aaaa7f13fd79b5ef32a45494541beab4733f7d89a241901b6709e90781371` | `397244664` | LLM request `3608882` |
| LLM callback | `0x24775942de67f82884b304703e2aaf39e4050e7cf05791d162aa7e8d1b3431f4` | `397244671` | `Incomplete` |

Decoded values:

```text
JSON platformRequestId: 3608878 / 0x37112e
LLM platformRequestId: 3608882 / 0x371132
LLM raw bytes: 0x496e636f6d706c657465
LLM decoded string: Incomplete
Final task state: Incomplete
claim(2) eth_call reverted with InvalidState(2, 6)
```

## Additional Edge-Case Runs

All rows below were collected from official RPC receipts/logs on 2026-06-01 against the same v0.2.2 deployment.
Callback transactions target the Somnia Agent Platform, while verifier and escrow events appear inside those callback
receipts.

### NeedsReview With Manual Approval

Task `3`, submission `3`, `ReviewWindowAutoClaim`.

| Step | Tx | Block | Result |
|---|---|---:|---|
| Create | `0x50c9e61c1f9c22c679cd333777a30fa17ccebf029060ce9ef114bbf1ab9dead8` | `397275442` | policy `1`, review window `300` |
| Fund | `0x0f0b028aad04e8af764a820d0f984461aa31e898555c3149d6f55a87a10e3bdb` | `397275875` | success |
| Submit needs-review facts | `0xcaca53dabfe66dad9fb7607124faa0b0c20c560c7bc5b76e1b855e0c730ac2e6` | `397276155` | JSON request `3618482` |
| JSON callback | `0xb6569a659b507e0cd38372c7878d6675a94b963f3c64717e6fbb4a939fcf983e` | `397276165` | LLM request `3618486` |
| LLM callback | `0x31ea65802f23c6ade073c243e618b06395c3110ad5b527b474228cdac310854d` | `397276172` | `NeedsReview` |
| Approve | `0x18d677ac55b2c8f3762a10206de91bef4b9e07ccb640cb402d800bf419f7a810` | `397276645` | client override |
| Claim | `0x09fd63577307aa6ea40e11a3682ed96bc126661fd615ac4da7ab4e03ffc3ba29` | `397276763` | `TaskClaimed` |

Decoded values:

```text
JSON platformRequestId: 3618482 / 0x3736b2
LLM platformRequestId: 3618486 / 0x3736b6
facts: repo_exists=true; readme_setup=true; deployment_address_present=unclear; demo_url_present=true; tests_passed=unknown
LLM raw bytes: 0x4e65656473526576696577
LLM decoded string: NeedsReview
State before approval: NeedsReview
claim(3) eth_call reverted with InvalidState(3, 5)
Final task state: Claimed
```

### Malformed Facts Failure And Recovery

Task `4` first submitted an endpoint missing the `facts` field, then recovered with complete facts.

| Step | Tx | Block | Result |
|---|---|---:|---|
| Create | `0xd396409141251800c4613e87bdb219e8b261da809bead54d555249746b508e36` | `397276943` | policy `2` |
| Fund | `0x517844094231e05da174e7fccec7dd7712950112011802d6d2e4a53321273932` | `397277052` | success |
| Submit malformed facts | `0xbf6e8947a06b5a6fa30aab1ff35165c0402480da1d554c14858326c7b3646416` | `397277433` | JSON request `3618871` |
| Failure callback | `0x875f5822e3792dbe7376d1eaf8cfa6ef91bbfec5fbe4d79344b5693fe8c95b5c` | `397277443` | `VerificationFailed` |
| Recovery submit | `0xadb2a24b93ebb798470ab47c00b98329121b4bdf4b702494cece2462396174e7` | `397278068` | JSON request `3619064` |
| Recovery JSON callback | `0x5bd3b67a36d09f4ba129eeb6cd89469f66383ba5bfd6b951e55cea900ef95563` | `397278080` | LLM request `3619068` |
| Recovery LLM callback | `0xdd358352a38f63c8d35406e3e8e65fbc08471183917c2834df67ad212d74c18f` | `397278087` | `Complete` |
| Claim | `0x0bd258b061c989fdf937987aa59463f5a1e69a55f3730de77bb0e03a98488a25` | `397278648` | `TaskClaimed` |

Decoded values:

```text
Malformed JSON platformRequestId: 3618871 / 0x373837
Failure notesURI: somnia-agent-request:3618871
Platform callback input included: key "facts" not found in object
claim(4) after failure eth_call reverted with InvalidState(4, 7)
Recovery JSON platformRequestId: 3619064 / 0x3738f8
Recovery LLM platformRequestId: 3619068 / 0x3738fc
Recovery LLM raw bytes: 0x436f6d706c657465
Recovery LLM decoded string: Complete
Final task state: Claimed
```

### ClientApprovalOnly Complete

Task `5`, submission `6`, `ClientApprovalOnly`.

| Step | Tx | Block | Result |
|---|---|---:|---|
| Create | `0x54663001c9ab986f29a2793ac176249eb5eb653cdf1a530c8a193fd1d7b39ef1` | `397278795` | policy `0` |
| Fund | `0xd3daa7775cdd8852b590fdaca0ef19ade8e2bf4024e1e62030936bb452a5598f` | `397278912` | success |
| Submit complete facts | `0x8a0c5fedb5e967ab08ca4319fa16dae63ec0863ed883970abf29446577178434` | `397279056` | JSON request `3619363` |
| JSON callback | `0x3f7e8b9a79726d1c072636feb4958307c4d1b48cd409d03953349d93d237a26f` | `397279072` | LLM request `3619370` |
| LLM callback | `0xd4ff494f31c20e9327939b248c8537711052c8667eb7c5ddd340bdfefb1ebbef` | `397279078` | `Complete` |
| Approve | `0xd9de4c9065af7d260266df3d40e8c2c814983d3fc667f3fd172598b63407e47c` | `397279517` | client approval |
| Claim | `0x6f1434f4a73c818e0d0ef2edaf341184e56aeeb123d16b1edd61d92d5c8d59ef` | `397279652` | `TaskClaimed` |

Decoded values:

```text
JSON platformRequestId: 3619363 / 0x373a23
LLM platformRequestId: 3619370 / 0x373a2a
LLM raw bytes: 0x436f6d706c657465
LLM decoded string: Complete
State before approval: VerifiedComplete
claim(5) before approval eth_call reverted with InvalidState(5, 4)
Final task state: Claimed
```

### ReviewWindowAutoClaim Complete

Task `6`, submission `7`, `ReviewWindowAutoClaim` with a `60` second review window.

| Step | Tx | Block | Result |
|---|---|---:|---|
| Create | `0x954b65d4272032d98d607323aba21defd838df419653b99426525dbfe5184cbd` | `397279795` | policy `1`, review window `60` |
| Fund | `0x64c277b03654f8a410f1e7d54d4e6d10e11f6ba1266013e46188a2f9680e94b3` | `397279897` | success |
| Submit complete facts | `0xb09a20d50e878738c1a986b3e2da0dda5b13ce3c7a64f3876500a16e57afbece` | `397280053` | JSON request `3619668` |
| JSON callback | `0x7cfd9a742ff70213b5f45678f87fee1f37330441329dac9702dc117f5785789d` | `397280073` | LLM request `3619675` |
| LLM callback | `0x4943b0223d4d1c652be7c576a919b5a69557c815dc0045aa652af844b9120975` | `397280080` | `Complete` |
| Auto-claim after window | `0x28ac936950578e8f97c9e6835de62f66001b96bc8070af24c0c1d82c09c9d01e` | `397281464` | `TaskClaimed` |

Decoded values:

```text
JSON platformRequestId: 3619668 / 0x373b54
LLM platformRequestId: 3619675 / 0x373b5b
LLM raw bytes: 0x436f6d706c657465
LLM decoded string: Complete
claim(6) before review window eth_call reverted with ReviewWindowActive(6, 1780268125, 1780268097)
Final task state: Claimed
```

## Contract Verification Retry

Official RPC proves bytecode exists at both deployed addresses:

```bash
cast code 0x79d94c986c64C69fDea935a2Ee6c303Dae852AE2 --rpc-url https://api.infra.testnet.somnia.network/
cast code 0x16F9B1e1e732DFeE1e2231E52b399e9d2344F568 --rpc-url https://api.infra.testnet.somnia.network/
```

Blockscout verification was retried:

```bash
make multi-settlement-verify-verifier
make multi-settlement-verify-escrow
```

Both retries returned `Address is not a smart-contract`. Verification remains pending due to explorer/indexer lag; do
not mark these contracts verified until Blockscout accepts the submissions.

## Proof Boundary

This proves live v0.2.2 settlement for JSON API facts plus LLM Inference bounded verdicts. It does not prove LLM Parse
Website settlement, GitHub-native verification, or arbitrary website parsing as a settlement-critical path.
