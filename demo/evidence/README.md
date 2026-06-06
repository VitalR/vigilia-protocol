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

The `*-real/` folders are different from deterministic fixtures. They are built
with `make build-real-evidence` and only mark deployed-code facts as true after
RPC bytecode checks. Foundry-native scripts do not perform HTTP requests without
FFI, so repo/docs/website reachability is recorded as `unknown` unless a separate
publisher/checker validates the public URL. Use these files as canonical
frontend examples for conservative evidence generation.

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
