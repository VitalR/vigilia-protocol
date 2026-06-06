# Validation Notes

Positive facts in `evidence-real-complete.json` are generated only after Foundry validation checks.

## Raw Inputs

- repoURI: https://github.com/VitalR/vigilia-protocol
- contractAddress: 0x1FA22E3a97dabB9a8C6de3a5B59eF6cCD5B2F4b9
- docsURI: https://raw.githubusercontent.com/VitalR/vigilia-protocol/main/docs/13_TWO_AGENT_SETTLEMENT_RUNBOOK.md
- proofURI: https://raw.githubusercontent.com/VitalR/vigilia-protocol/main/docs/proofs/2026-06-01-two-agent-settlement-hardened-rpc-proof.md
- dashboardURI: not configured

## Validation

- repoUrlValid: true
- repoReachable: unknown
- docsUrlValid: true
- docsReachable: unknown
- proofUrlValid: true
- proofReachable: unknown
- deploymentAddressFormatValid: true
- deploymentHasCode: true
- demoUrlValid: unknown
- demoUrlReachable: unknown
- websiteUrlValid: true
- websiteReachable: unknown

Foundry-native scripts do not perform HTTP requests without FFI. HTTP reachability is `unknown`, never `true`.
