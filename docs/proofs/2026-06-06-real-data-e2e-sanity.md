# Real Data E2E Sanity

## Purpose

This proof note separates realistic evidence generation from deterministic demo
fixtures. The frontend issue showed that raw user input such as `sdfsdf` could
become positive facts. The real-data folders are canonical examples for failing
closed: raw fields are preserved, and positive facts are emitted only after the
matching validation succeeds.

## Evidence

Generated with:

```bash
make build-real-evidence
make build-web-validated-evidence
```

Folders:

- `demo/evidence/escrow-real/`
- `demo/evidence/grants-real/`

Conservative evidence:

- Escrow:
  `https://raw.githubusercontent.com/VitalR/vigilia-protocol/main/demo/evidence/escrow-real/evidence-real-conservative.json`
- GrantRound:
  `https://raw.githubusercontent.com/VitalR/vigilia-protocol/main/demo/evidence/grants-real/evidence-real-conservative.json`

Verified-complete evidence:

- Escrow:
  `https://raw.githubusercontent.com/VitalR/vigilia-protocol/main/demo/evidence/escrow-real/evidence-real-verified-complete.json`
- GrantRound:
  `https://raw.githubusercontent.com/VitalR/vigilia-protocol/main/demo/evidence/grants-real/evidence-real-verified-complete.json`

Raw public inputs:

- repo: `https://github.com/VitalR/vigilia-protocol`
- Escrow docs:
  `https://raw.githubusercontent.com/VitalR/vigilia-protocol/main/docs/13_TWO_AGENT_SETTLEMENT_RUNBOOK.md`
- GrantRound docs:
  `https://raw.githubusercontent.com/VitalR/vigilia-protocol/main/docs/15_GRANT_ROUND_RUNBOOK.md`
- Escrow proof:
  `https://raw.githubusercontent.com/VitalR/vigilia-protocol/main/docs/proofs/2026-06-01-two-agent-settlement-hardened-rpc-proof.md`
- GrantRound proof:
  `https://raw.githubusercontent.com/VitalR/vigilia-protocol/main/docs/proofs/2026-06-03-grant-round-three-agent-proof.md`
- Escrow contract: `0x1FA22E3a97dabB9a8C6de3a5B59eF6cCD5B2F4b9`
- Escrow verifier: `0xdE0aC9700E591b54A418665575f2e1d329D78f3D`
- GrantRound v0.4: `0x5aE1918Dcaa0A00a1d647e1c9946F7FF3fB61679`
- GrantRound v0.4 verifier: `0xb0a1cdf062B4c295fC2A00F4bf1C84062F40d8e4`

## Conservative Result

`make build-real-evidence` uses the Foundry script
`script/demo/BuildRealEvidence.s.sol`.

The Foundry builder checked:

- repo URL has GitHub repository shape;
- docs/proof/website fields have HTTP(S) URL shape;
- deployed contract addresses are nonzero EVM addresses;
- live RPC bytecode exists for the Escrow and GrantRound contracts.

The builder does not mark HTTP reachability as true. Foundry scripts do not
perform HTTP requests without FFI, so repo/docs/proof/website reachability
remains `unknown` in `evidence-real-conservative.json`.

The legacy `evidence-real-complete.json` path is a compatibility copy of this
conservative output. It should not be treated as a guarantee that agents will
return Complete.

## Verified-Complete Result

`make build-web-validated-evidence` uses
`app/evidence-tool/scripts/build-real-evidence.mjs`.

The web validator checked:

- GitHub repo URL format;
- GitHub repo reachable through the public GitHub API;
- GitHub README reachable through the public GitHub API;
- docs raw URL returns HTTP 200;
- proof raw URL returns HTTP 200;
- website raw URL returns HTTP 200;
- deployed contract address format;
- live RPC bytecode exists for the Escrow and GrantRound contracts.

Generated true facts:

- `repo_url_valid=true`
- `repo_exists=true`
- `readme_exists=true`
- `docs_url_valid=true`
- `docs_reachable=true`
- `proof_url_valid=true`
- `proof_reachable=true`
- `deployment_address_format_valid=true`
- `deployment_has_code=true`
- `website_url_valid=true`
- `website_reachable=true`

Remaining unknown facts:

- `demo_url_valid=unknown`
- `demo_url_reachable=unknown`

Reason: `VIGILIA_DASHBOARD_URL` was not configured in local `.env` during this
generation pass. The helper intentionally leaves optional dashboard/demo checks
unknown instead of fabricating positive facts.

## Live E2E Status

Escrow live E2E: not executed in this pass.

GrantRound live E2E: not executed in this pass.

Reason: the new `evidence-real-verified-complete.json` files are generated in
this working tree and must be pushed before the raw GitHub URLs above can be used
by Somnia JSON API and Website Parse agents. No live transaction was sent against
local evidence or self-attested fixture facts.

## Required Next Live Run

After publishing the verified-complete files to the public raw URLs:

1. Set `VIGILIA_EVIDENCE_JSON_URL` to the public Escrow
   `evidence-real-verified-complete.json` URL.
2. Run the Escrow immediate-claim TwoAgent path with `0.36 STT` and record task
   ID, evidence URL, request ID, callback transactions, claim transaction, and
   final state.
3. Set `GRANT_EVIDENCE_URI` to the public GrantRound
   `evidence-real-verified-complete.json` URL.
4. Create a fresh GrantRound v0.4 ThreeAgent round with `maxWinners=1`, submit
   one application, request screening with `0.81 STT`, wait for JSON facts,
   `websiteURI`, Website Parse, and LLM callbacks, then select, finalize, and
   claim.

## Live Transaction Records

Escrow task ID: not available.

Escrow request ID: not available.

Escrow callback tx: not available.

Escrow claim tx: not available.

Escrow final state: not available.

GrantRound round ID: not available.

GrantRound application ID: not available.

GrantRound request ID: not available.

GrantRound callback txs: not available.

GrantRound claim tx: not available.

GrantRound final state: not available.

## Limitations

This is a live smoke/proof workflow, not deterministic CI. Normal CI should keep
unit and mocked integration tests. Frontend evidence generation should use this
schema as the canonical model: transaction success does not mean evidence is
valid, and summary text cannot override false or unknown objective facts.
