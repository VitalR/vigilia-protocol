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
```

Vercel static hosting, Cloudflare Pages, Netlify, and GitHub Gist raw URLs are also fine.

GrantRound TwoAgent evidence must use the `facts-*.json` files in this folder:

```text
JSON API facts -> LLM Inference bounded verdict -> judge-selected finalists -> claims
```

The old `demo/evidence/escrow/*.json` files with a top-level `verdict` are for the v0.1 JSON API smoke flow, not GrantRound.

The HTML files are preparation assets for Website Parse / `ThreeAgent` testing. They do not prove Website Parse is live by themselves; a real proof needs hosted HTML, a successful Website Parse callback, LLM consumption of the extracted content, and a final GrantRound verdict callback.
