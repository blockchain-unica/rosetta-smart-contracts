# Crowdfund Contract in Leo (Aleo)

This is an implementation of the Crowdfund contract on the [Aleo](https://aleo.org) blockchain, written in the [Leo](https://leo-lang.org) programming language. For a general introduction to Leo and the Aleo execution model, refer to the Bet contract README.

## Implementation Notes

The implementation is coherent with the specification.

### Reading the Contract Balance On-Chain

Unlike Solidity where `address(this).balance` is readable anywhere, in Leo the contract's balance can only be read inside a `final { }` block using:

```leo
let bal: u64 = credits.aleo::account.get_or_use(self.address, 0u64);
```

This is used in both `withdraw` and `reclaim` to verify whether the goal has been reached, without needing a separate `total_donated` storage variable. The balance read this way reflects the actual on-chain state, including any direct transfers to the contract address.

### Parameter Design

Due to the fn/final model, `amount_` must be passed explicitly as a parameter in `withdraw` and `reclaim`, since transfers must be initiated in the off-chain part of the `fn` where storage is not readable. The `final { }` block verifies the provided amount against the on-chain balance or the donor's recorded contribution.

### Preventing Double Reclaim

After a successful `reclaim`, the donor's entry in the `donors` mapping is reset to `0u64`. This prevents a donor from calling `reclaim` multiple times and withdrawing more than they donated.

---

## Contract Design

### State

| Variable | Type | Description |
|---|---|---|
| `recipient` | `address` | Address that receives the funds if the goal is reached. |
| `deadline` | `u32` | Block height after which withdraw and reclaim become active. |
| `goal` | `u64` | Minimum amount (in microcredits) required for the campaign to succeed. |
| `donors` | `mapping address => u64` | Amount donated by each address. |

### Functions

#### `initialize(recipient_, deadline_, goal_)`

Called by anyone to set up the campaign. Stores the recipient address, deadline block height, and goal amount. Can only be called once.

On-chain checks:
- `recipient` must be unset (prevents double initialization).
- `goal_` must be greater than `0`.

#### `donate(amount_)`

Called by **any user** to donate `amount_` microcredits to the campaign. The donation is recorded in the `donors` mapping so the donor can reclaim it if the goal is not reached. Multiple donations from the same address are accumulated.

On-chain checks:
- Current block height must be ≤ `deadline`.

#### `withdraw(amount_)`

Called by the **recipient** after the deadline to collect all donated funds, provided the goal has been reached.

On-chain checks:
- Current block height must be > `deadline`.
- Caller must be the stored `recipient`.
- Contract balance must be ≥ `goal`.
- `amount_` must equal the full contract balance.

#### `reclaim(amount_)`

Called by a **donor** after the deadline to recover their donation, if the goal has not been reached.


On-chain checks:
- Current block height must be > `deadline`.
- Contract balance must be < `goal` (goal not reached).
- Caller must have a non-zero entry in `donors`.
- `amount_` must equal the caller's recorded donation.



