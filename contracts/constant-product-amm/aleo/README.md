# Constant Product AMM Contract in Leo (Aleo)

This is an implementation of the Constant Product AMM contract on the [Aleo](https://aleo.org) blockchain, written in the [Leo](https://leo-lang.org) programming language. For a general introduction to Leo and the Aleo execution model, refer to the Bet contract README.

## Implementation Notes

The implementation is coherent with the specification. 

### Token Registry 

Custom tokens on Aleo are managed by `token_registry.aleo`, a singleton program implementing the ARC-21 standard. Unlike Ethereum where each ERC-20 is a separate contract identified by its address, all Aleo custom tokens share one program and are distinguished by a `token_id: field`. The AMM stores the token IDs of the two pool assets as `storage t0: field` and `storage t1: field`, and all token transfers are dispatched to `token_registry.aleo`.

### LP Tokens as Internal Mapping

The specification requires liquidity tokens to be minted to the depositor and burned on redemption. The natural design question for Aleo is whether to represent LP tokens as private records or as a public mapping.

I considered a record-based design where each deposit would produce an `LpToken { owner: address, amount: u64 }` record. This would give LP token holders genuine privacy over their position size and pool participation. However, two concrete problems forced me to abandon it.

First, the AMM's core logic (ratio checks, liquidity calculation, reserve updates) must live inside the `final { }` block, because it needs to read the current pool reserves from storage. The `final { }` block executes on-chain and cannot operate on records, which are private and processed off-chain. Because an AMM needs to know up-to-date pool reserves, most of its code has to be placed in a finalize function, which is executed on chain and cannot operate on Records.

Second, Leo's compiler does not support optional records as function parameters (`LpToken?` is rejected), which would have been necessary to write a single `deposit` function handling both first-time and subsequent depositors.

The production AMMs on Aleo all use public mappings for LP token accounting. This implementation follows the same pattern, consistent with the Solidity reference which uses `mapping(address => uint) public minted`.

### r0 and r1 as u128

The pool reserves `r0` and `r1` are stored as `u128` rather than `u64`. This choice is motivated by two factors: token amounts in the ARC-21 standard (`token_registry.aleo`) are represented as `u128`, so keeping reserves as `u128` avoids lossy casts at the boundary; and intermediate products in the constant-product formula (`r_out * amount_in`) can overflow `u64` for realistically sized pools, making `u128` the natural working type throughout.

### liquidity_minted Computed On-Chain

In the `deposit` function, the number of LP tokens to mint (`liquidity_minted`) is not passed as a parameter but computed directly inside the `final { }` block. This is possible because LP tokens are tracked in a mapping, not in a record (which would need to be constructed off-chain before the `final` block, requiring the amount to be known in the transition body).

This eliminates one source of race conditions: the client does not need to pre-compute `liquidity_minted` and verify it matches on-chain. The contract computes it atomically from the current reserves and the amounts deposited.

### Bootstrap of the First Deposit

The Solidity reference initializes liquidity as `toMint = x0` on the first deposit (`ever_deposited == false`). This implementation follows the same convention: the first depositor receives LP tokens equal to `x0`, fixing the unit of account.

### Amount-as-Parameter for Outputs

The `redeem` function takes `x0_` and `x1_` (the amounts of t0 and t1 to return to the caller) as parameters, and the `swap` function takes `x1_` (the output amount) as a parameter. These cannot be computed on-chain because `token_registry.aleo::transfer_public` must be called in the off-chain part of the transition, before the `final { }` block is entered, and storage is not readable at that point. The `final { }` block verifies the proposed values against the formula.

### No Balance Verification

The Solidity reference includes `assert(t0.balanceOf(address(this)) == r0)` after each operation as a sanity check. This cannot be replicated in Leo because reading the `balances` mapping of `token_registry.aleo` from our program would require a cross-program storage read, which Leo does not support. The consistency between `r0`/`r1` and the actual token balances held by the contract is guaranteed by construction: every transfer that changes the actual balance has a corresponding symmetric update to the stored reserves.

### Race Conditions

The `deposit` function enforces the pool ratio strictly: `x0_ * r1_curr == x1_ * r0_curr`. If another swap changes the reserves between the client's calculation and the transaction's processing, this assertion fails and the transaction reverts. The Solidity reference uses the same strict check.

The `swap` function's output amount check (`x1_ == r_out * x0_ / (r_in + x0_)`) has the same fragility. The `min_amount_out_` parameter required by the specification provides the client with a second line of defense: even if the strict equality check passes, the swap reverts if the computed output falls below the minimum. 

The `redeem` function does not have this race condition because `x0_` and `x1_` are computed inside the `final { }` block from the current reserves, and the client-proposed values are verified against that computation.

### Rounding

All division in the formulas is integer division (truncation toward zero). As in the Solidity reference, this leaves small residuals in the pool over time: the sum of all redeemable amounts can be slightly less than the total deposited. These amounts accumulate in the pool and benefit remaining liquidity providers proportionally.

---

## Contract Design

### State

| Variable | Type | Description |
|---|---|---|
| `t0` | `field` | Token ID of the first pool asset in `token_registry.aleo`. |
| `t1` | `field` | Token ID of the second pool asset. |
| `r0` | `u128` | Current reserve of t0 held by the pool. |
| `r1` | `u128` | Current reserve of t1 held by the pool. |
| `total_liquidity` | `u64` | Total LP tokens in circulation. |
| `initialized` | `bool` | `true` after `initialize`, used as a re-initialization guard. |
| `liquidity_balance` | `mapping address => u64` | LP token balance of each liquidity provider. |

### Functions

#### `initialize(t0_, t1_)`

Called by **anyone** to register the two pool tokens and open the pool for deposits. Can only be called once.

On-chain checks:
- Contract must not be already initialized (`initialized == false`).
- `t0_` must differ from `t1_`.

#### `deposit(t0_, t1_, x0_, x1_)`

Called by **any liquidity provider** to deposit `x0_` of t0 and `x1_` of t1 into the pool. The number of LP tokens minted is computed on-chain and credited to `liquidity_balance[caller]`.

| Parameter | Type | Description |
|---|---|---|
| `t0_` | `field` | Token ID of t0, needed off-chain for the transfer call. |
| `t1_` | `field` | Token ID of t1, needed off-chain for the transfer call. |
| `x0_` | `u128` | Amount of t0 to deposit. |
| `x1_` | `u128` | Amount of t1 to deposit. |

On-chain checks:
- Contract must be initialized.
- `t0_` and `t1_` must match the stored token IDs.
- `x0_` and `x1_` must be greater than `0`.
- If the pool is not empty: `x0_ * r1 == x1_ * r0` (ratio preservation).
- Computed `liquidity_minted` must be greater than `0`.

#### `redeem(t0_, t1_, x0_, x1_, x_)`

Called by **any liquidity provider** to burn `x_` LP tokens and receive the proportional amounts of t0 and t1.

| Parameter | Type | Description |
|---|---|---|
| `t0_` | `field` | Token ID of t0, needed off-chain for the transfer call. |
| `t1_` | `field` | Token ID of t1. |
| `x0_` | `u128` | Proposed amount of t0 to receive. Must equal `x_ * r0 / total_liquidity`. |
| `x1_` | `u128` | Proposed amount of t1 to receive. Must equal `x_ * r1 / total_liquidity`. |
| `x_` | `u64` | Number of LP tokens to burn. |

On-chain checks:
- Contract must be initialized.
- `t0_` and `t1_` must match the stored token IDs.
- `x_`, `x0_`, and `x1_` must be greater than `0`.
- `x_` must be strictly less than `total_liquidity` (prevents draining the pool entirely).
- Caller must hold at least `x_` LP tokens.
- `x0_` must equal `(x_ as u128) * r0 / (total_liquidity as u128)`.
- `x1_` must equal `(x_ as u128) * r1 / (total_liquidity as u128)`.

#### `swap(t0_, t1_, token_in_, x0_, x1_, min_amount_out_)`

Called by **any trader** to swap `x0_` of `token_in_` for `x1_` of the other token, subject to the constant-product formula and a minimum output constraint.

| Parameter | Type | Description |
|---|---|---|
| `t0_` | `field` | Token ID of t0, needed off-chain. |
| `t1_` | `field` | Token ID of t1. |
| `token_in_` | `field` | Token ID of the token being sold (must be `t0_` or `t1_`). |
| `x0_` | `u128` | Amount of `token_in_` to sell. |
| `x1_` | `u128` | Proposed output amount. Must equal `r_out * x0_ / (r_in + x0_)`. |
| `min_amount_out_` | `u128` | Minimum acceptable output; the swap reverts if `x1_ < min_amount_out_`. |

On-chain checks:
- Contract must be initialized.
- `t0_` and `t1_` must match the stored token IDs.
- `token_in_` must be `t0_` or `t1_`.
- `x0_` and `x1_` must be greater than `0`.
- `x1_` must equal `r_out * x0_ / (r_in + x0_)` where `r_in` and `r_out` are the reserves of the input and output tokens respectively.
- `x1_` must be greater than or equal to `min_amount_out_`.