# Real Data E2E Sanity

## Purpose

This proof note separates realistic evidence generation from deterministic demo
fixtures. The frontend issue showed that raw user input such as `sdfsdf` could
become positive facts. The real-data folders are canonical examples for failing
closed: raw fields are preserved, but positive facts are emitted only after
validation.

## Evidence

Generated with:

```bash
make build-real-evidence
```

Folders:

- `demo/evidence/escrow-real/`
- `demo/evidence/grants-real/`

Raw public inputs:

- repo: `https://github.com/VitalR/vigilia-protocol`
- Escrow docs: `https://raw.githubusercontent.com/VitalR/vigilia-protocol/main/docs/13_TWO_AGENT_SETTLEMENT_RUNBOOK.md`
- GrantRound docs: `https://raw.githubusercontent.com/VitalR/vigilia-protocol/main/docs/15_GRANT_ROUND_RUNBOOK.md`
- Escrow contract: `0x1FA22E3a97dabB9a8C6de3a5B59eF6cCD5B2F4b9`
- Escrow verifier: `0xdE0aC9700E591b54A418665575f2e1d329D78f3D`
- GrantRound v0.4: `0x5aE1918Dcaa0A00a1d647e1c9946F7FF3fB61679`
- GrantRound v0.4 verifier: `0xb0a1cdf062B4c295fC2A00F4bf1C84062F40d8e4`

## Validation Performed

The Foundry builder checked:

- repo URL has GitHub repository shape;
- docs/proof/website fields have HTTP(S) URL shape;
- deployed contract addresses are nonzero EVM addresses;
- live RPC bytecode exists for the Escrow and GrantRound contracts.

The builder did not mark HTTP reachability as true. Foundry scripts do not
perform HTTP requests without FFI, so repo/docs/website reachability remains
`unknown` in the generated JSON.

## Live E2E Status

Escrow live E2E: not executed in this pass.

GrantRound live E2E: not executed in this pass.

Reason: the generated evidence files are local until this branch is pushed or
published. Somnia JSON API and Website Parse agents need public URLs. Using local
files or self-attested fixture facts would repeat the weakness this task is meant
to avoid.

## Required Next Live Run

After publishing the generated files to a public raw URL:

1. Set `VIGILIA_EVIDENCE_JSON_URL` to the public
   `demo/evidence/escrow-real/evidence-real-complete.json` URL.
2. Run the Escrow immediate-claim TwoAgent path and record task ID, request ID,
   callback transactions, claim transaction, and final state.
3. Set `GRANT_EVIDENCE_URI` to the public
   `demo/evidence/grants-real/evidence-real-complete.json` URL.
4. Create a fresh GrantRound v0.4 ThreeAgent round with `maxWinners=1`, submit
   one application, request screening with `0.81 STT`, wait for JSON facts,
   `websiteURI`, Website Parse, and LLM callbacks, then select, finalize, and
   claim.

## Limitations

This is a live smoke/proof workflow, not deterministic CI. Normal CI should keep
unit and mocked integration tests. Frontend evidence generation should use this
schema as the canonical model: transaction success does not mean evidence is
valid, and summary text cannot override false or unknown objective facts.
