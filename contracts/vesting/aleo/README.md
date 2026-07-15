# Vesting Contract in Leo (Aleo)

This is an implementation of the Vesting contract on the [Aleo](https://aleo.org) blockchain, written in the [Leo](https://leo-lang.org) programming language. For a general introduction to Leo and the Aleo execution model, refer to the Bet contract README.

## Implementation Notes

The implementation is coherent with the specification, with one adaptation: releasing the vested amount requires passing the exact releasable value as a parameter, so to mitigate race conditions on networks with fast block times the vesting uses a **step-based schedule**. 

### Step-Based Vesting

Since the releasable amount changes at every block, on fast networks there isn't enough time to compute the correct amount and broadcast the transaction before the block height advances, causing the exact-match assertion (amount_ == releasable) to fail.

To mitigate this, the contract uses a step-based release: the releasable amount only changes every STEP_SIZE blocks (15 by default), and remains constant within each step. This gives the client a full step window to compute the amount and broadcast the transaction safely.

The formula is:

```
steps_elapsed = (block.height - start) / STEP_SIZE
total_steps   = duration / STEP_SIZE
vested        = total_allocation * steps_elapsed / total_steps
releasable    = vested - already_released
```

Where `total_allocation = contract_balance + already_released`, this reconstructs the original deposit amount even as the balance decreases through successive releases.

The three cases are implemented inline with a ternary expression:
- `block.height < start` → `0` (nothing vested yet)
- `block.height > start + duration` → `total_allocation` (fully vested)
- Otherwise → proportional amount based on `steps_elapsed`

`duration` is required to be a multiple of `STEP_SIZE` for the formula to distribute the total allocation evenly. The constraint is `duration >= STEP_SIZE`;

### Why the Ternary Is Inline

Leo's function call rules prevent extracting the vesting formula into a helper function:
- A `final fn` can only be called from inside a `final { }` block, but `final fn` cannot have an explicit return type (it always returns `Final`).
- A regular `fn` helper can be called off-chain, but the formula depends on `block.height` and storage variables that are only readable inside `final { }`.

As a result, the conditional logic must be expressed inline with a ternary expression inside the `final { }` block. This is more verbose than Solidity's `if/else` structure but is the only viable pattern in Leo.

### Avoiding Underflow on `block.height - start`

The expression `block.height - start` would cause a `u32` underflow if `block.height < start`. To avoid this, `sub_wrapped` is used:

```leo
let elapsed: u32 = block.height.sub_wrapped(start.unwrap());
```

The wrapped value is only used when `block.height >= start` (thanks to the ternary branching), so its potentially incorrect value in the underflow case is never read.

### The Amount Parameter Problem

Because Leo requires transfers to be initiated off-chain with a fixed amount, the beneficiary must pass the exact `amount_` to release as a parameter. The `final { }` block then recomputes `releasable` on-chain and asserts that `amount_ == releasable`.

**This creates a race condition in practice:** the `releasable` amount depends on `block.height`, which advances as blocks are produced. Between the moment the client calculates the amount and the moment the transaction is processed, the block height may have changed, causing the assertion to fail.

**In Solidity this problem does not exist** because `block.number` and the transfer amount are atomic within the same transaction execution.

The step-based design mitigates the problem: inside a step window the releasable is constant, so the client has `STEP_SIZE` blocks to compute and broadcast before the value changes.

### Native Credits vs Custom Tokens

This contract uses native Aleo credits via `credits.aleo`, as required by the specification. An important consequence: the amount to transfer must be known off-chain because `credits.aleo::transfer_public` is an external program call.

If the contract were using **custom tokens** (records defined in the same program), the amount could be computed on-chain and the token record created with the correct value, eliminating the amount parameter problem entirely. This is the trade-off of using native credits.

---

## Contract Design

### Constants

| Constant | Value | Description |
|---|---|---|
| `STEP_SIZE` | `15u32` | Number of blocks per vesting step. The releasable amount is constant within a step. |

### State

| Variable | Type | Description |
|---|---|---|
| `beneficiary` | `address` | Address entitled to receive the vested funds. |
| `start` | `u32` | Block height at which the vesting schedule begins. |
| `duration` | `u32` | Number of blocks over which the vesting is linear (must be `>= STEP_SIZE`). |
| `already_released` | `u64` | Cumulative amount (in microcredits) already released to the beneficiary. |

### Functions

#### `initialize(beneficiary_, start_, duration_, initial_balance_)`

Called by the **funder** to set up the vesting schedule and deposit the initial balance. Stores the beneficiary address, start block, and duration, and transfers `initial_balance_` microcredits from the signer to the contract. Can only be called once.

On-chain checks:
- `beneficiary` must be unset (prevents double initialization).
- `beneficiary_` must not be the zero address.
- `start_` must be greater than `0`.
- `duration_` must be greater than or equal to `STEP_SIZE`.
- `initial_balance_` must be greater than `0`.

#### `release(amount_)`

Called by the **beneficiary** to withdraw the currently releasable amount. Computes `releasable` from the step-based formula and asserts that `amount_` matches exactly.

On-chain checks:
- Contract must be initialized (`beneficiary` must not be zero address).
- Caller must be the stored `beneficiary`.
- `releasable` must be greater than `0`.
- `amount_` must equal the computed `releasable`.