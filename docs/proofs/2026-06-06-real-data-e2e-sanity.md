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

`evidence-real-conservative.json` is the canonical conservative output and
should not be treated as a guarantee that agents will return Complete.

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

GrantRound live E2E: completed.

The `evidence-real-verified-complete.json` files are public on GitHub raw URLs
and are suitable for Somnia JSON API and Website Parse agents.

## Remaining Live Run

Escrow can be run later with the public verified-complete file:

1. Set `VIGILIA_EVIDENCE_JSON_URL` to the public Escrow
   `evidence-real-verified-complete.json` URL.
2. Run the Escrow immediate-claim TwoAgent path with `0.36 STT` and record task
   ID, evidence URL, request ID, callback transactions, claim transaction, and
   final state.

## Live Transaction Records

Escrow task ID: not available.

Escrow request ID: not available.

Escrow callback tx: not available.

Escrow claim tx: not available.

Escrow final state: not available.

GrantRound round ID: `12`.

GrantRound application ID: `23`.

GrantRound request IDs:

- root / JSON facts request: `0x00000000000000000000000000000000000000000000000000000000004e7570`
  (`5141872`)
- JSON websiteURI request: `5141882`
- Website Parse request: `5141883`
- final LLM request: `5141971`

GrantRound lifecycle transactions:

- create round:
  `0x2dbd2be17e113c5080ce14c0bad28dc6b657e540612effc44f937e948bddd45b`
- fund round:
  `0x0ef56a46ce999297362b48814edd97b549aeff6a0e89c2554a7dea670fdc7859`
- excluded fixture application `22` submission:
  `0xc9cea78e95bda66a6ce0941ae4a362aba1e3eecba8abbef71ab5db60215d846f`
- real-data application `23` submission:
  `0x1300a61357d1a851c57358f6ddb4e8e75717cb26789a751179efc19cf8ff61f7`
- ThreeAgent screening request:
  `0xb7845f3292a72534f31e79c50fcbd5e84ea7bc8400598234da31fbbc9b9210ca`
- select finalist:
  `0xb9565bd735c743ea671ffd92fd5512a20af9930150db1ef95715a3e40f59f443`
- finalize round:
  `0xbe2f4978d42af79a4b7a3bf8a029e74ac81464f2df074965288ce1aab598f035`
- claim prize:
  `0x885064219c4dbda66b01bfc95573d907deb853a4b24ae2147915c6ad906c19a4`

GrantRound callback transactions:

- JSON facts callback and JSON websiteURI request:
  `0x223b0679d798eac89bfa8f1b5ed030d3f8a82fa76f7887c593888c38ef700ae0`
- JSON websiteURI callback and Website Parse request:
  `0x4ce80b3b797ea74659128a59ae9b4e1974e8d618691f88b31199b9eacc7a3a1f`
- Website Parse callback and LLM request:
  `0xc7b20acc048a47c44a7262f932baf9cceccd2111f300468a76f5948f746d7704`
- LLM callback, `MultiAgentVerificationSucceeded`, and
  `ApplicationVerdictRecorded`:
  `0x82aad2c68c0fd92c20d290a3a074aef0271d7e6fd288d045c54e80f259072a90`

GrantRound final state:

- round state: `Finalized`
- round screening mode: `ThreeAgent`
- round prize amount: `0.1 STT`
- round max winners: `1`
- application evidence URI:
  `https://raw.githubusercontent.com/VitalR/vigilia-protocol/main/demo/evidence/grants-real/evidence-real-verified-complete.json`
- application verdict: `Complete`
- application status: `Claimed`
- application selected: `true`
- application claimed: `true`
- application notes URI: `somnia-agent-request:5141971`
- claim succeeded: yes

Operational note: application `22` was accidentally submitted through a wrapper
target that defaulted to the old fixture bundle. It was not screened, selected,
or claimed. The real-data proof application is application `23`.

## Limitations

This is a live smoke/proof workflow, not deterministic CI. Normal CI should keep
unit and mocked integration tests. Frontend evidence generation should use this
schema as the canonical model: transaction success does not mean evidence is
valid, and summary text cannot override false or unknown objective facts.
