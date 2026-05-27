# Skill — Solidity Style Standard for Project

Apply this style to all Solidity code in the project.

## Compiler
- Use `pragma solidity 0.8.34;`

## Parameter naming
- Prefix function parameters with underscore
- Examples:
  - `_user`
  - `_amount`
  - `_positionId`
  - `_newPrice`

## Error handling
- Prefer custom errors over revert strings
- For simple guard checks, prefer:
  - `require(<condition>, SomeError(...));`
- For richer branching, comparisons, or more expressive failure paths, prefer:
  - `if (<condition>) revert SomeError(...);`

Examples:
```solidity
require(_user != address(0), InvalidUser());
```

```solidity
if (_nextUsed > _cap) {
    revert WithdrawCapExceeded(_nextUsed, _cap);
}
```

## NatSpec
Add rich NatSpec for:
- every external function
- every public function
- important structs/enums when useful
- constructor if relevant

NatSpec should explain:
- what the function does
- what params mean
- what it returns
- any important behavior or restrictions

## File layout
Use this structure where applicable:

1. SPDX + pragma
2. imports
3. contract-level NatSpec
4. events
5. errors
6. types / enums / structs
7. state variables
8. constructor
9. external/public functions
10. internal/private functions
11. view/pure helpers

## Events
Emit events for all meaningful state transitions:
- deposits
- borrows
- repays
- withdrawals
- rescue requests
- rescue completion
- liquidation
- admin simulation actions
- agent registration / status changes

## Readability
- optimize for clarity, not compactness
- avoid dense nested conditionals when a clearer split is possible
- use internal helper functions when they improve readability
- use explicit variable names

## Comments
- use comments sparingly and only where they add value
- do not narrate obvious code
- prefer good naming over excessive inline comments

## Testing expectations
When implementing a contract, also think about:
- positive paths
- negative paths
- authorization
- accounting correctness
- boundary conditions
- event emission

Do not write fake tests or empty assertions.

### Test naming convention
- Use `test_Action_Expectation` naming
- Keep the action first and the expected behavior second
- Examples:
  - `test_SetWriterAuthorization_OwnerUpdatesAuthorization`
  - `test_AppendRecord_AuthorizedWriterCanAppend`
  - `test_AppendRecord_UnauthorizedWriterReverts`

### Test style
- Prefer `public` for `setUp()` and test functions
- Prefix internal test-scoped state variables with underscores
- Keep fixtures and assertions explicit rather than overly abstracted
