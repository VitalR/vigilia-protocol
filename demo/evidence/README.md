# Demo Evidence

This folder separates evidence fixtures by product flow:

```text
escrow/       v0.1 JSON API smoke and v0.2 two-agent escrow fixtures
escrow-real/  real-data Escrow sanity evidence generated from public repo/deployment data
grants/       GrantRound campaign fixtures
grants-real/  real-data GrantRound sanity evidence generated from public repo/deployment data
```

The old v0.1 JSON API smoke flow uses `escrow/complete.json`,
`escrow/needs-review.json`, `escrow/incomplete.json`, and `escrow/malformed.json`.
Those files contain a top-level `verdict`.

GrantRound demos use `grants/facts-*.json`. Those files contain a top-level
`facts` field for `JsonFactsToLlmVerdict`.

The `*-real/` folders are different from deterministic fixtures. They contain
two real-data evidence classes:

- `evidence-real-conservative.json` is built with `make build-real-evidence`.
  It marks deployed-code facts as true only after RPC bytecode checks. Foundry
  does not perform HTTP requests without FFI, so repo/docs/website reachability
  is intentionally `unknown`, not true.
- `evidence-real-verified-complete.json` is built with
  `make build-web-validated-evidence`. It marks GitHub, README, docs, proof,
  website, and deployed-code facts true only after the matching public
  HTTP/GitHub/RPC check succeeds.

The legacy `evidence-real-complete.json` path is a compatibility copy of the
conservative file and should not be treated as a guarantee that agents will
return Complete.

For live Somnia JSON API tests, serve the selected JSON file from a public URL. Good options are a GitHub raw URL, a Vercel static file, or another public static host.

The first smoke test should use an endpoint returning exactly:

```json
{"verdict":"Complete"}
```

The verifier selector must match:

```text
SOMNIA_VERDICT_SELECTOR=verdict
```

`escrow/malformed.json` intentionally omits the `verdict` field so the live callback can exercise the retryable `VerificationFailed` path.
