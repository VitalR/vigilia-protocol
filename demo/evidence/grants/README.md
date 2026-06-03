# Vigilia GrantRound Evidence Fixtures

These files are examples for GrantRound demos.

For live Somnia JSON API screening, host the JSON files at public HTTPS URLs.
Raw GitHub URLs are the simplest option after the branch is pushed:

```bash
GRANT_REQUIREMENTS_URI=https://raw.githubusercontent.com/<org>/<repo>/<branch>/demo/evidence/grants/grant-requirements.md
GRANT_COMPLETE_EVIDENCE_URI=https://raw.githubusercontent.com/<org>/<repo>/<branch>/demo/evidence/grants/facts-complete.json
GRANT_NEEDS_REVIEW_EVIDENCE_URI=https://raw.githubusercontent.com/<org>/<repo>/<branch>/demo/evidence/grants/facts-needs-review.json
GRANT_INCOMPLETE_EVIDENCE_URI=https://raw.githubusercontent.com/<org>/<repo>/<branch>/demo/evidence/grants/facts-incomplete.json
GRANT_MALFORMED_EVIDENCE_URI=https://raw.githubusercontent.com/<org>/<repo>/<branch>/demo/evidence/grants/facts-malformed.json
GRANT_COMPLETE_BUNDLE_EVIDENCE_URI=https://raw.githubusercontent.com/<org>/<repo>/<branch>/demo/evidence/grants/bundle-complete.json
GRANT_NEEDS_REVIEW_BUNDLE_EVIDENCE_URI=https://raw.githubusercontent.com/<org>/<repo>/<branch>/demo/evidence/grants/bundle-needs-review.json
GRANT_INCOMPLETE_BUNDLE_EVIDENCE_URI=https://raw.githubusercontent.com/<org>/<repo>/<branch>/demo/evidence/grants/bundle-incomplete.json
GRANT_MALFORMED_BUNDLE_EVIDENCE_URI=https://raw.githubusercontent.com/<org>/<repo>/<branch>/demo/evidence/grants/bundle-malformed.json
```

Vercel static hosting, Cloudflare Pages, Netlify, and GitHub Gist raw URLs are also fine.

GrantRound TwoAgent evidence must use the `facts-*.json` files in this folder:

```text
JSON API facts -> LLM Inference bounded verdict -> judge-selected finalists -> claims
```

GrantRound ThreeAgent evidence must use the `bundle-*.json` files in this folder:

```text
JSON API facts + JSON API websiteURI -> Website Parse real HTML -> LLM Inference bounded verdict -> judge-selected finalists -> claims
```

Each bundle contains a top-level `facts` string and a top-level `websiteURI` string. Missing or empty `facts`,
missing or empty `websiteURI`, Website Parse failure, or an unbounded LLM result must fail closed as
`VerificationFailed`.

The old `demo/evidence/escrow/*.json` files with a top-level `verdict` are for the v0.1 JSON API smoke flow, not GrantRound.

The HTML files are Website Parse inputs. Raw GitHub HTML worked for a standalone canary, but Vercel,
Cloudflare Pages, or Netlify are still better final demo hosts because the parser receives normal web pages.

A Website Parse canary alone does not prove ThreeAgent GrantRound. The proof requires the full GrantRound path:
`ScreeningMode.ThreeAgent` round, bundle evidence, Website Parse callback, LLM final bounded verdict,
GrantRound `recordVerdict`, judge/sponsor finalist selection, finalization, and claim.
