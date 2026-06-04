# Escrow Retry Failure Investigation

Recorded: 2026-06-04
Network: Somnia testnet, chain ID 50312

Failed tx:

- `0x54729c183d0e34c72ea309d3a81a55ee3e8bc118357cdaf67701d0a56d595e22`
- Contract: `0x1FA22E3a97dabB9a8C6de3a5B59eF6cCD5B2F4b9`
- Function selector: `0x9e29c255`
- Decoded calldata: `retryVerification(11)`
- Sender: `0x5a122Bb8Ade6EAfa9a6fB22a573C09f7E68Ac28a`
- Value: `0`
- Status: failed

Task `11` direct read:

- Client: `0xb660a8c28Dc66626957afE21127a18E9bF0f0723`
- Contractor: `0x5a122Bb8Ade6EAfa9a6fB22a573C09f7E68Ac28a`
- Resolver: `0xb660a8c28Dc66626957afE21127a18E9bF0f0723`
- Amount: `1200000000000000000`
- Funded amount: `1200000000000000000`
- Active submission: `8`
- State: `7` (`VerificationFailed`)

Active submission `8`:

- Submitter: `0x5a122Bb8Ade6EAfa9a6fB22a573C09f7E68Ac28a`
- Evidence URI: JSON payload stored as a string
- Request ID: `0x000000000000000000000000000000000000000000000000000000000040dbfd`
- Verdict: `0` (`Unknown`)

Simulation:

- `retryVerification(11)` with value `0` reverted.
- Revert selector: `0xfb6bcbec`
- Decoded as `InvalidVerificationDeposit(uint256,uint256)`.
- Required: `360000000000000000`
- Actual: `0`
- `retryVerification(11)` with value `360000000000000000` returned request ID `0x00000000000000000000000000000000000000000000000000000000004395eb` in `eth_call`.

Conclusion:

The failure was caused by the dapp submitting `retryVerification(11)` with no verification deposit. Task state and caller authorization were valid. This is a frontend transaction construction issue, not a fundamental escrow/verifier failure.

Recommended fix:

- Query the verifier workflow deposit for `JsonFactsToLlmVerdict`, or use fallback `360000000000000000` wei.
- Pass that amount as transaction `value`.
- Disable Retry unless the task is `VerificationFailed`.
- Disable Retry unless the connected wallet is the task client or contractor.
- Show a specific message when value is missing: `Retry requires a new verification deposit of 0.36 STT.`

Makefile diagnostics:

```bash
make escrow-retry-decode
make escrow-retry-inspect-task
make escrow-retry-simulate-zero
make escrow-retry-simulate-with-deposit
make escrow-retry-diagnose
```

The zero-value simulation is expected to revert. The with-deposit simulation is
an `eth_call` and should return a request ID when task state, caller, and stored
evidence remain valid.

Optional recovery broadcast:

```bash
make escrow-retry-with-deposit CONFIRM_BROADCAST=1
```

This target is guarded on purpose. Use it only after confirming that the task is
still `VerificationFailed`, the caller is the client or contractor, and retrying
the active stored evidence URI is still desired.

No recovery retry was broadcast in this investigation because the request was diagnostic and the prompt only required confirmation of the root cause.
