# Atomic Transactions in Leo (Aleo)

This use case **is not implemented in Leo/Aleo**, since transaction batching with atomic execution is natively supported by the platform.


## Native Batching in Aleo

Aleo provides transaction batching natively at two distinct layers.

### Protocol Level

A single Aleo transaction can contain multiple **transitions**, distinct function executions, including invocations of different programs. The snarkVM consensus rules treat all transitions in a transaction as a single atomic unit:

- All transitions either commit together or fail together.
- A failed `assert` in any `final { }` block, an insufficient balance, or any execution error reverts the entire transaction.
- No partial application of state changes is possible.

This is structurally the same primitive that the Solidity reference simulates: a sealed batch of calls, executed atomically. In Aleo it is the standard transaction format, not a contract pattern.

### SDK Level

The `@provablehq/sdk` JavaScript library exposes this capability directly. Users construct multi-transition transactions off-chain through `ProgramManager.buildTransaction` (or equivalent APIs), passing an ordered list of calls:

```javascript
const tx = await programManager.buildTransaction([
  { program: 'tokenA.aleo',   function: 'transfer', inputs: [...] },
  { program: 'tokenB.aleo',   function: 'swap',     inputs: [...] },
  { program: 'protocol.aleo', function: 'stake',    inputs: [...] },
]);
```

The SDK produces a single zero-knowledge proof covering all transitions, signs the transaction, and broadcasts it. The network verifies the proof and applies the state changes atomically.

## Why the Solidity Pattern Cannot Be Replicated 

Even setting aside the native equivalence, Leo lacks the language features that would be needed to faithfully reproduce the Solidity reference.

- **No dynamic arrays.** Leo compiles to fixed-size zero-knowledge circuits, so a growing list of pending transactions cannot be represented. The same constraint applies to mapping-based workarounds combined with the snarkVM 32-operation budget per `finalize` block.

- **No generic dynamic dispatch.** Leo 4.0 supports calling programs determined at runtime, but the dispatched function's signature must be known at compile time. There is no equivalent of Solidity's `bytes` calldata + `call()` that lets a contract dispatch to arbitrary functions with arbitrary parameter types decided after deployment.

- **No `delegatecall`.** The specification requires that batched transactions execute "while preserving the context of the caller". In Solidity this is provided by `delegatecall`. In Aleo, every cross-program call updates `self.caller` to the calling program, so the original user's identity cannot be propagated through the orchestrator.

