# PriceBet Contract in Leo (Aleo)

This is an implementation of the PriceBet contract on the [Aleo](https://aleo.org) blockchain, written in the [Leo](https://leo-lang.org) programming language. For a general introduction to Leo and the Aleo execution model, refer to the Bet contract README.

## Implementation Notes

The implementation is coherent with the specification, with one adaptation due to a Leo type-system constraint: the oracle's program identifier is stored as a `field` rather than as an `identifier`, because Leo does not allow `identifier` to be used as a storage type. This change is transparent to the user, who passes the `field` value at initialization just as they would pass an address in Solidity.

The contract is split into two programs:
- **`oracle_pricebet.aleo`**: a minimal oracle exposing a `rate: u64` storage variable. It implements the `Oracle` interface, which is also what the PriceBet uses to read the rate dynamically.
- **`pricebet.aleo`**: the bet contract itself, which references the oracle through a `field` stored at initialization.

### The Oracle as a Separate Program

The specification requires the oracle to be a separate contract that the PriceBet queries for the exchange rate. In Solidity this is straightforward: the oracle is deployed at an address, and the PriceBet stores that address and dispatches a method call to it at runtime via the contract's interface.

In Leo, cross-program interactions are typically static, to allow the oracle to be chosen at deployment time of the PriceBet, this implementation uses Leo's **dynamic call** feature: the PriceBet imports the oracle's interface but reads its `rate` storage through a runtime-resolved program identifier.

### The `Oracle` Interface

The oracle program declares an interface that captures the structural contract:

```leo
interface Oracle {
    storage rate: u64;
}
```

Any program implementing `Oracle` must expose a `storage rate: u64`. The `oracle_pricebet.aleo` program implements this interface:

```leo
program oracle_pricebet.aleo : Oracle {
    storage rate: u64;
    // ...
}
```

### Why `field` Instead of `identifier`

The natural type for storing a "program reference" in Leo is `identifier` (a value that names a program at runtime, with literals like `'my_program'`). However, Leo's type system rejects `identifier` as a valid storage type:

```
Error: identifier is an invalid storage type
```

Looking at the Leo documentation's examples of dynamic calls, the standard workaround is to use `field` instead, the `field` value is the hash of the program ID, which uniquely identifies the program on the network and can both be stored and used as the target of a dynamic call:

```leo
storage oracle: field;

fn win(...) -> Final {
    return final {
        let rate_opt: u64? = oracle_pricebet.aleo::Oracle@(oracle.unwrap())::rate;
        // ...
    };
}
```

The user passes the precomputed `field` value to `initialize`.
In a real-world deployment this conversion is handled transparently by higher-level tooling (e.g. the Aleo JavaScript SDK in a frontend), so the user only ever sees the program name; the `field` representation never surfaces in the user-facing flow.

### Reading Oracle State Without a Function Call

Notice that `pricebet.aleo` does not invoke a getter function on the oracle. Instead it reads the storage variable `rate` directly through the dynamic interface:

```leo
let rate_opt: u64? = oracle_pricebet.aleo::Oracle@(oracle.unwrap())::rate;
```

This is a feature of Leo's dynamic-storage-read mechanism: an interface that declares a storage variable allows dynamic reads of that variable on any program implementing the interface, without needing to dispatch a function call. This is cheaper than a transition (no proof generation for a getter) and simpler than defining and calling an explicit function.

### The Amount Parameter Pattern

As in other contracts that transfer native credits (Vesting, SimpleWallet), the client must pass the amount to transfer as a parameter to `win` and `timeout`, even though it is already stored in the contract. The `final { }` block re-reads the stored `pot` and asserts that the parameter matches:

```leo
assert(pot_ == pot.unwrap());
```

## Contract Design

### `oracle_pricebet.aleo`

#### State

| Variable | Type | Description |
|---|---|---|
| `rate` | `u64` | The current exchange rate. |


#### Functions

##### `initialize(initial_rate_)`

Sets the the initial rate.

---

### `pricebet.aleo`

#### State

| Variable | Type | Description |
|---|---|---|
| `owner` | `address` | The bet's owner who deposited the initial pot. |
| `pot` | `u64` | The current total pot (initial after `initialize`, doubled after `join`). |
| `oracle` | `field` | The `field` value identifying the oracle program. |
| `deadline` | `u32` | The block height after which the player loses and the owner can reclaim. |
| `rate` | `u64` | The target exchange rate that the player is betting on. |
| `player` | `address` | The address that joined the bet (set after `join`). |

#### Functions

##### `initialize(pot_, oracle_, deadline_, rate_)`

Called by the **owner** to deposit the initial pot, set the oracle, the deadline, and the target rate. Can only be called once.

On-chain checks:
- `owner` must be unset (prevents double initialization).
- `pot_` must be greater than `0`.
- `deadline_` must be greater than `0` (it's the offset, the actual deadline is `block.height + deadline_`).
- `rate_` must be greater than `0`.

##### `join(pot_)`

Called by the **player** to join the bet by depositing an amount equal to the initial pot. After this, the contract holds twice the initial pot.

On-chain checks:
- Contract must be initialized.
- No player has joined yet.
- `pot_` must equal the stored `pot` (initial pot).

##### `win(pot_)`

Called by the **player** to claim the entire pot if the oracle's rate has reached the target before the deadline.

On-chain checks:
- Contract must be initialized.
- A player must have joined.
- Caller must be the stored `player`.
- `pot_` must equal the stored `pot` (the doubled total).
- `block.height` must be less than the `deadline`.
- The oracle's current rate (read dynamically) must be greater than or equal to the target rate.

##### `timeout(pot_)`

Called by the **owner** to reclaim the entire pot after the deadline. Can be called even if no player has joined, in which case the owner reclaims the initial pot.

On-chain checks:
- Contract must be initialized.
- Caller must be the stored `owner`.
- `pot_` must equal the stored `pot` (the initial pot, or the doubled total if a player has joined).
- `block.height` must be greater than or equal to the `deadline`.