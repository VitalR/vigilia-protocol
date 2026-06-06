# Vigilia Evidence Tools

Small helper scripts for building public, web-validated evidence examples.

This workspace is intentionally separate from the Foundry scripts and from the
future frontend under `app/web/`. It performs checks that Solidity/Foundry should
not do, such as HTTP/GitHub reachability checks.

Run from the repository root:

```bash
make build-web-validated-evidence
```

Or directly:

```bash
npm --prefix app/evidence-tools run build
```

The builder writes:

- `demo/evidence/escrow-real/evidence-real-verified-complete.json`
- `demo/evidence/grants-real/evidence-real-verified-complete.json`
- `demo/evidence/*-real/validation-report-web.md`

Facts are marked `true` only after the specific HTTP/GitHub/RPC check succeeds.
If a check cannot be performed, the generated fact is `unknown`, not `true`.
