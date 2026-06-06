# Escrow Real Evidence

This folder contains real-data evidence for live Somnia-agent sanity scenarios.

Unlike deterministic demo fixtures, these files are built from public Vigilia repository artifacts and deployed contract code checks.

Run:

```bash
forge script script/demo/BuildRealEvidence.s.sol:BuildRealEvidence --rpc-url "$SOMNIA_RPC_URL"
```

The builder marks deployed code facts as `true` only after RPC bytecode validation. HTTP reachability remains `unknown` in this Foundry-native script.
