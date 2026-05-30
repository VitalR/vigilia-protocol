# Demo Evidence

These JSON files are local examples for the v0.1.0 JSON API smoke flow.

For live Somnia JSON API tests, serve the selected JSON file from a public URL. Good options are a GitHub raw URL, a Vercel static file, or another public static host.

The first smoke test should use an endpoint returning exactly:

```json
{"verdict":"Complete"}
```

The verifier selector must match:

```text
SOMNIA_VERDICT_SELECTOR=verdict
```

`malformed.json` intentionally omits the `verdict` field so the live callback can exercise the retryable `VerificationFailed` path.
