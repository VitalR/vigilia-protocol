# Deployments

Canonical public deployments for Vigilia Protocol on Somnia testnet.

Network:

| Field | Value |
|---|---|
| Network | Somnia testnet |
| Chain ID | `50312` |
| RPC | `https://api.infra.testnet.somnia.network/` |
| Explorer | `https://shannon-explorer.somnia.network/` |
| Somnia Agent Platform | `0x037Bb9C718F3f7fe5eCBDB0b600D607b52706776` |
| Live app | https://vigilia-protocol.vercel.app/ |
| Dashboard | https://vigilia-protocol.vercel.app/dashboard |

Explorer/indexer caveat: Somnia explorer views can lag recent transactions. Direct RPC reads, deployment artifacts, and proof docs are the source of truth when explorer pages are incomplete.

## Final Live Stack

| Product surface | Contract | Address | Workflow | Deposit | Artifact |
|---|---|---|---|---:|---|
| Milestone Escrow | `VigiliaEscrow` | [`0x1FA22E3a97dabB9a8C6de3a5B59eF6cCD5B2F4b9`](https://shannon-explorer.somnia.network/address/0x1FA22E3a97dabB9a8C6de3a5B59eF6cCD5B2F4b9) | TwoAgent settlement | `0.36 STT` | [`deployments/somnia-testnet-50312-two-agent-settlement-hardened.json`](../deployments/somnia-testnet-50312-two-agent-settlement-hardened.json) |
| Milestone verifier | `VigiliaMultiAgentVerifier` | [`0xdE0aC9700E591b54A418665575f2e1d329D78f3D`](https://shannon-explorer.somnia.network/address/0xdE0aC9700E591b54A418665575f2e1d329D78f3D) | JSON facts -> LLM verdict | `0.36 STT` | [`deployments/somnia-testnet-50312-two-agent-settlement-hardened.json`](../deployments/somnia-testnet-50312-two-agent-settlement-hardened.json) |
| Grant rounds | `VigiliaGrantRound` | [`0x5aE1918Dcaa0A00a1d647e1c9946F7FF3fB61679`](https://shannon-explorer.somnia.network/address/0x5aE1918Dcaa0A00a1d647e1c9946F7FF3fB61679) | ThreeAgent screening | `0.81 STT` | [`deployments/somnia-testnet-50312-grant-round-three-agent.json`](../deployments/somnia-testnet-50312-grant-round-three-agent.json) |
| Grant verifier | `VigiliaMultiAgentVerifier` | [`0xb0a1cdf062B4c295fC2A00F4bf1C84062F40d8e4`](https://shannon-explorer.somnia.network/address/0xb0a1cdf062B4c295fC2A00F4bf1C84062F40d8e4) | JSON facts -> Website Parse -> LLM verdict | `0.81 STT` | [`deployments/somnia-testnet-50312-grant-round-three-agent.json`](../deployments/somnia-testnet-50312-grant-round-three-agent.json) |

## Deployment Transactions

### Milestone Escrow v0.2.3

Deployment name: `vigilia-two-agent-settlement-hardened`

| Item | Tx hash |
|---|---|
| Verifier deploy | `0x237cd8fa61d006c9d4f887710f2cb3a5356eb54e68ba68e55ff1fee3eb32079d` |
| Escrow deploy | `0x234899fea3a3ef53bb5fd5a0c02214004a347b7a99756f8b79dc97762267e859` |
| Successful bind | `0xa08b11bdd2303a743949ea4ddbd7950f6b0d7f444b8c7a3fbdb4f05b59f7e27c` |

Proof and runbook:

- [`docs/13_TWO_AGENT_SETTLEMENT_RUNBOOK.md`](./13_TWO_AGENT_SETTLEMENT_RUNBOOK.md)
- [`docs/proofs/2026-06-01-two-agent-settlement-hardened-rpc-proof.md`](./proofs/2026-06-01-two-agent-settlement-hardened-rpc-proof.md)
- [`docs/proofs/2026-06-08-final-demo-data.md`](./proofs/2026-06-08-final-demo-data.md)

### GrantRound v0.4.0

Deployment name: `vigilia-grant-round-three-agent`

| Item | Tx hash |
|---|---|
| Verifier deploy | `0x6da32d43b7acad4eb72bd1064b74d022c44263bfb2196c2271fdd23e4ce7d6aa` |
| GrantRound deploy | `0xdd5c2e50d9585bf21e03a56e03e49568f97e091c7fd938a98f0843362212016a` |
| Successful manual bind | `0xe2bff0cc1c9c9ee8509f68af263cbc1fd4548ab41860bdbca39453d507903984` |

The artifact also records failed bind attempts from deployment-script gas/old-verifier paths. Those failed attempts did not become the live binding. The successful binding is the manual bind above.

Proof and runbook:

- [`docs/15_GRANT_ROUND_RUNBOOK.md`](./15_GRANT_ROUND_RUNBOOK.md)
- [`docs/proofs/2026-06-03-grant-round-three-agent-proof.md`](./proofs/2026-06-03-grant-round-three-agent-proof.md)
- [`docs/proofs/2026-06-08-final-demo-data.md`](./proofs/2026-06-08-final-demo-data.md)

## Workflows

### TwoAgent Milestone Settlement

```text
JSON API facts
-> LLM Inference bounded verdict
-> VigiliaEscrow records verdict
-> claim / review / resubmit policy
```

Current minimum workflow deposit: `360000000000000000 wei`.

### ThreeAgent GrantRound Screening

```text
JSON API facts
-> Website Parse real HTML extraction
-> LLM Inference bounded verdict
-> VigiliaGrantRound records screening status
-> judges/sponsors select finalists
-> finalists claim prizes
```

Current minimum workflow deposit: `810000000000000000 wei`.

## Public Evidence Examples

| Surface | URL |
|---|---|
| Escrow evidence | `https://raw.githubusercontent.com/VitalR/vigilia-protocol/main/demo/evidence/escrow-real/evidence-real-verified-complete.json` |
| Grant evidence | `https://raw.githubusercontent.com/VitalR/vigilia-protocol/main/demo/evidence/grants-real/evidence-real-verified-complete.json` |
| Grant website evidence | `https://raw.githubusercontent.com/VitalR/vigilia-protocol/main/demo/evidence/grants-real/website-real-complete.html` |

## Historical Artifacts

Older artifacts are retained for auditability and should not be overwritten:

| Artifact | Purpose |
|---|---|
| [`deployments/somnia-testnet-50312.json`](../deployments/somnia-testnet-50312.json) | v0.1 JSON API smoke |
| [`deployments/somnia-testnet-50312-multi-agent-canary.json`](../deployments/somnia-testnet-50312-multi-agent-canary.json) | v0.2 canary requests |
| [`deployments/somnia-testnet-50312-multi-agent-settlement.json`](../deployments/somnia-testnet-50312-multi-agent-settlement.json) | v0.2.1 JSON-only settlement |
| [`deployments/somnia-testnet-50312-two-agent-settlement.json`](../deployments/somnia-testnet-50312-two-agent-settlement.json) | v0.2.2 TwoAgent settlement |
| [`deployments/somnia-testnet-50312-grant-round.json`](../deployments/somnia-testnet-50312-grant-round.json) | earlier GrantRound deployment |

## No-Overclaim Notes

- Vigilia is a testnet hackathon MVP, not an audited production protocol.
- Agents screen evidence and return bounded verdicts.
- Agents do not choose winners and do not directly move funds.
- Grant finalists are selected by judges or sponsors.
- Escrow claims follow deterministic contract policy.
