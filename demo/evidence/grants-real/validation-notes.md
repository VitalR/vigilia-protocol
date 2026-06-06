# Validation Notes

Positive facts in `evidence-real-complete.json` are generated only after Foundry validation checks.

## Raw Inputs

- repoURI: https://github.com/VitalR/vigilia-protocol
- contractAddress: 0x5aE1918Dcaa0A00a1d647e1c9946F7FF3fB61679
- docsURI: https://raw.githubusercontent.com/VitalR/vigilia-protocol/main/docs/15_GRANT_ROUND_RUNBOOK.md
- proofURI: https://raw.githubusercontent.com/VitalR/vigilia-protocol/main/docs/proofs/2026-06-03-grant-round-three-agent-proof.md
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
