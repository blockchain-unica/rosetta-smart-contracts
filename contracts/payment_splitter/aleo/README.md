# Payment Splitter Contract in Leo (Aleo)

This is an implementation of the Payment Splitter contract on the [Aleo](https://aleo.org) blockchain, written in the [Leo](https://leo-lang.org) programming language. For a general introduction to Leo and the Aleo execution model, refer to the Bet contract README.

## Implementation Notes

The implementation is coherent with the specification, with one limitation: the maximum number of shareholders is fixed at compile time to `MAX_PAYEES = 10`. 

### Why a Fixed Maximum on Payees

The Solidity reference takes two dynamic-length arrays as constructor arguments (`address[] payees`, `uint256[] shares_`) and iterates over them with a runtime-bounded loop. Leo does not support either dynamic arrays or loops with runtime bounds, every `for` loop must have integer bounds known at compile time, and array accessors must be constant. To replicate the constructor in a single atomic call, the implementation uses fixed-size input arrays of length 10, padded by the caller with the zero address (`aleo1qqq...3ljyzc`) and zero shares for unused slots. A separate `count_` parameter tells the contract how many of the 10 slots are valid.

The same constraint affects **Fe/Ethereum** and **Vyper/Ethereum**, both of which require array sizes to be set at compile time.

### Loop Unrolling and Conditional Logic Inside `final` Blocks
 
Two Leo rules shape how `initialize` is written. First, `for` loops must have compile-time bounds, so the loop is declared as `for i in 0u32..10u32` and an inner `if i < count_` selects which iterations are active. Second, a local `let` declared outside an `if` cannot be re-assigned from inside it within a `final { }` block: the compiler rejects this with `cannot re-assign from a conditional scope to an outer scope in a final block`.
 
The combined effect is that local-variable updates must use a ternary outside any conditional, while on-chain side effects can stay inside `if` blocks:
 
```leo
for i: u32 in 0u32..10u32 {
    running_total += i < count_ ? shares_[i] : 0u64;
    if i < count_ {
        Mapping::set(shares, payees_[i], shares_[i]);
        // ...
    }
}
```
 
Local accumulation uses the ternary (always executed, neutral identity for padding slots); assertions and mapping writes stay inside the `if` because side effects are not subject to the same restriction.

### Pull Payment Model

The contract follows the pull payment model required by the specification: each shareholder receives their share through a separate call to `release`. This naturally fits Aleo because `credits.aleo::transfer_public` only sends to one recipient per call. Anyone can call `release(account_, amount_)` for any registered shareholder.

### The Amount Parameter Pattern

As in other contracts that transfer native credits (Vesting, SimpleWallet, Vault, Crowdfund ...), the client must pass the amount to transfer as a parameter to `release`, even though it can be computed from on-chain state. Because `credits.aleo::transfer_public` must be called in the off-chain part of the transition (where storage is not readable), the `amount_` to transfer must be known before entering the `final { }` block. The on-chain logic then recomputes the expected `releasable` and asserts that `amount_` matches exactly:

```leo
let earned: u64 = total_received * account_shares / total_shares.unwrap();
let releasable: u64 = earned - account_released;
assert(amount_ == releasable);
```

The client is responsible for computing `releasable` off-chain by querying the relevant storage variables and mappings via the REST API. The full formula is `(balance + total_released) * shares[account] / total_shares - released[account]`.


### Rounding Residue

The Solidity reference uses integer division and inherits a small rounding behavior: due to truncating divisions in `(total_received * shares) / total_shares`, the sum of all released amounts can be slightly less than the total deposited at any given time. Any rounding remainder stays in the contract until the next deposit, when it is folded into subsequent releases. The Leo implementation behaves identically.

### State Layout

The Solidity reference also keeps an `address[] _payees` array used for the `payee(index)` getter. This array is omitted in the Leo implementation: storing it would consume additional mapping operations at initialize time, and any payee can be queried directly via the REST API by address. If an off-chain client needs to enumerate the shareholders, it must keep its own list, populated from the `initialize` transaction data.

---

## Contract Design

### Constants

| Constant | Value | Description |
|---|---|---|
| `MAX_PAYEES` | `10u32` | Maximum number of shareholders the contract can hold. |

### State

| Variable | Type | Description |
|---|---|---|
| `shares` | `mapping address => u64` | Number of shares assigned to each shareholder. |
| `released` | `mapping address => u64` | Amount (in microcredits) already released to each shareholder. |
| `total_shares` | `u64` | Sum of all shares assigned at initialization. |
| `total_released` | `u64` | Total amount released so far across all shareholders. |
| `initialized` | `bool` | `true` after a successful `initialize`, used as a guard against re-initialization. |

### Functions

#### `initialize(payees_, shares_, count_)`

Called by the **deployer** to set up the shareholder list. Accepts two fixed-size arrays of length 10 and a `count_` parameter indicating how many slots are valid. Can only be called once.

On-chain checks:
- Contract must not be already initialized (`initialized == false`).
- `count_` must be greater than `0` and less than or equal to `MAX_PAYEES`.
- For each valid slot `i` (i.e. `i < count_`):
    - `payees_[i]` must not be the zero address.
    - `shares_[i]` must be greater than `0`.
    - `payees_[i]` must not already have shares (no duplicates).

#### `receive(amount_)`

Called by **anyone** to deposit `amount_` microcredits into the contract.

On-chain checks:
- Contract must be initialized.
- `amount_` must be greater than `0`.

#### `release(account_, amount_)`

Called by **anyone** to release the currently releasable amount to `account_`. Computes the expected `releasable` from the formula `(balance + total_released) * shares[account_] / total_shares - released[account_]` and asserts that `amount_` matches exactly.

On-chain checks:
- Contract must be initialized.
- `account_` must be a registered shareholder (`Mapping::contains(shares, account_) == true`).
- `amount_` must be greater than `0`.
- `amount_` must equal the computed `releasable`.