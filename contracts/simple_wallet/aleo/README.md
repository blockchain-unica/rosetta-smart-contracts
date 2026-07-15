# Simple Wallet Contract in Leo (Aleo)

This is an implementation of the Simple Wallet contract on the [Aleo](https://aleo.org) blockchain, written in the [Leo](https://leo-lang.org) programming language. For a general introduction to Leo and the Aleo execution model, refer to the Bet contract README.

## Implementation Notes

The implementation is coherent with the specification, with one adaptation: the `data` field of each transaction is purely informational and is not interpreted at execution time, because Leo does not support arbitrary contract calls with payload like Solidity. The transaction's `to` and `amount` are still transferred via `credits.aleo::transfer_public`, but the `data` is only stored on-chain alongside the transaction record. The `data` field is also bounded to a fixed size of 256 bytes due to Leo's static array constraints.

This contract presented a design choice between two different approaches: a **private record-based** implementation that leverages Aleo's distinctive privacy features, and a **public mapping-based** implementation that mirrors the Solidity reference more closely. The mapping-based design was the one chosen for this implementation; both are described in detail below, along with the reasoning behind the choice.

---

## Two Possible Implementations

This contract is essentially a state machine that holds a list of pending transactions. The way that list is stored on-chain has profound implications on privacy, scalability, and code complexity. In Aleo there are two natural primitives for representing such a list: **records** (private, owned, encrypted) and **mappings** (public, persistent, indexed). 

### A. Record-Based Design (Private)

In this design, the entire wallet (owner, the list of transactions, the executed flags), is encapsulated inside a single private record:

```leo
struct PendingTx {
    to: address,
    amount: u64,
    data: [u8; 256],
    data_length: u32,
}

record WalletState {
    owner: address,
    transactions: [PendingTx; 10],
    executed: [bool; 10],
    count: u32,
}
```

The `WalletState` record is owned by the wallet's owner address. Only the owner can read it, modify it, or pass it to a function. Pending transactions, including their recipient, amount, and data, are completely hidden from anyone watching the chain. The chain only sees that "some record was consumed and some new record was produced", but the contents are encrypted and inaccessible.

When the owner wants to create a new transaction, they call `create_transaction(state, to, amount, data, data_length)`, which takes the current `WalletState`, returns an updated one with the new transaction appended, and consumes the old record. When they want to execute a transaction, they call `execute_transaction(state, tx_id)`, which marks the transaction as executed in the new record and triggers a public transfer for the `amount` to the `to` address.

This design has very strong privacy properties. The list of pending transactions, including any sensitive metadata in the `data` field, never appears in plaintext on-chain. An external observer cannot tell whether a wallet has zero or ten pending transactions, who the recipients are, or how much is queued for transfer. The fact that the owner is making transfers becomes visible only at the moment of execution, when `transfer_public` reveals `to` and `amount` to the public chain, but even then, it's not possible to correlate the executed transfer with the moment the transaction was originally created.

This is a level of privacy that is impossible in Solidity. In Solidity, `Transaction[] public transactions` is a public array readable by anyone. In Aleo, the same wallet can run on a publicly auditable chain while keeping its operational details opaque.

### B. Mapping-Based Design (Public)

In this design, transactions live in a public on-chain mapping indexed by a sequential counter:

```leo
struct PendingTx {
    to: address,
    amount: u64,
    data: [u8; 256],
    data_length: u32,
    executed: bool,
}

storage owner: address;
storage tx_counter: u32;
mapping transactions: u32 => PendingTx;
```

`create_transaction` writes a new entry at key `tx_counter` and increments the counter. `execute_transaction` reads the entry at the given `tx_id`, performs the transfer, and rewrites the entry with `executed: true`. This is essentially a one-to-one transliteration of the Solidity reference, with the same semantics and the same publicly auditable behavior.

With this implementation anyone watching the chain can read the full list of pending transactions, including the recipient, the amount, and the data field. On the other hand, this is exactly what is expected from a Solidity-like wallet, and for many use cases public state is a feature.

---

## Why the Mapping-Based Design Was Chosen

The privacy advantages of the record-based design are real, and in a different setting it would be the more interesting implementation. The reason it was rejected for this contract comes down to an important limitation of Leo: **arrays cannot be indexed with a runtime-computed value**. This is a constraint of the underlying zkSNARK circuit model and it has consequences for any record-based design that needs to store more than a handful of transactions.

### The Dynamic Indexing Constraint

A program in Leo is compiled into an arithmetic circuit: a static structure where every operation must be known at compile time. When you write `arr[3]`, the compiler can hardwire the access to the third position of the array. When you write `arr[count]`, where `count` is a runtime value, the compiler has no way to know which slot will be touched, so it cannot generate a circuit for that operation.

The same problem applies to writes. Concretely, the following intuitive code is rejected by the compiler:

```leo
new_txs[state.count] = new_tx;  
```

This is an intrinsic property of the zero-knowledge execution model. To "modify a position chosen at runtime", the only available technique is to **rebuild the entire array** using a chain of conditional expressions, where each slot is statically considered and conditionally replaced:

```leo
let new_txs: [PendingTx; 10] = [
    state.count == 0u32 ? new_tx : state.transactions[0u32],
    state.count == 1u32 ? new_tx : state.transactions[1u32],
    state.count == 2u32 ? new_tx : state.transactions[2u32],
    state.count == 3u32 ? new_tx : state.transactions[3u32],
    state.count == 4u32 ? new_tx : state.transactions[4u32],
    state.count == 5u32 ? new_tx : state.transactions[5u32],
    state.count == 6u32 ? new_tx : state.transactions[6u32],
    state.count == 7u32 ? new_tx : state.transactions[7u32],
    state.count == 8u32 ? new_tx : state.transactions[8u32],
    state.count == 9u32 ? new_tx : state.transactions[9u32],
];
```

For a wallet with capacity N, every operation that needs to touch the array writes N lines of ternary expressions. Reading at a runtime index is no better:

```leo
let tx_to_execute: PendingTx =
    tx_id_ == 0u32 ? state.transactions[0u32] :
    tx_id_ == 1u32 ? state.transactions[1u32] :
    tx_id_ == 2u32 ? state.transactions[2u32] :
    // ... 6 more lines
    state.transactions[9u32];
```

`execute_transaction` alone needs three of these chains: one to read the transaction, one to read the executed flag, and one to write the updated executed flag. That is 3N hand-written ternary lines in a single function. For N = 10, this means 30 lines of brittle, repetitive code. For N = 50 it would mean 150. The code becomes unmaintainable, and any modification — adding a new field, changing a check — has to be reflected in every line.

### The Capacity Trade-off

The array size is part of the record's static type signature (`[PendingTx; 10]`), so the circuit is sized once at compile time and cannot grow at runtime. Increasing the capacity means rewriting all the ternary chains by hand. There is also no clean way to free and reuse slots: recycling would require overwriting executed entries, which would break the meaning of the transaction ID. After 10 transactions, the wallet would either have to refuse new operations..

### Why the Mapping Has No Such Limit

A mapping in Leo lives outside the circuit, in the persistent state of the chain. Reading and writing at a dynamic key is a single statement, and the mapping can hold as many entries as the chain is willing to store. The cost is the loss of privacy: every write is visible on-chain, but for this contract, the gain in scalability and code clarity is decisive.

The privacy benefit of the record-based design is significant, but for a contract with these specifications, the mapping-based version is the more faithful and practical choice.

---

## Mapping-Based Design — Implementation Details

### The `data` Field Is Informational

In Solidity, `executeTransaction` performs `transaction.to.call{value}(data)`, which can invoke arbitrary contract code at the target. Leo has no equivalent: cross-program calls are explicit and statically known at compile time, and `credits.aleo::transfer_public` only accepts `to` and `amount`.

### Parameter Verification in `execute_transaction`

`credits.aleo::transfer_public` requires `to` and `amount` to be known off-chain when the transition is built, so the client must pass them as parameters even though they are already stored in the mapping.

### `withdraw` Race Condition

`withdraw` asserts `amount_ == bal`, where `bal` is the current contract balance read on-chain. If a deposit lands between the client's balance read and the transaction's processing, the assertion fails. In practice this is rare because only the owner can deposit, but it should be noted.

---

## Contract Design

### State

| Variable | Type | Description |
|---|---|---|
| `owner` | `address` | The wallet's owner. Only this address can call any function. |
| `tx_counter` | `u32` | The next available transaction ID. |
| `transactions` | `mapping u32 => PendingTx` | The pending and executed transactions, indexed by ID. |

The `PendingTx` struct contains:

| Field | Type | Description |
|---|---|---|
| `to` | `address` | Recipient of the transaction. |
| `amount` | `u64` | Amount of microcredits to transfer. |
| `data` | `[u8; 256]` | Arbitrary payload (informational only, not used in transfer). |
| `data_length` | `u32` | Number of significant bytes in `data`. |
| `executed` | `bool` | True once the transaction has been executed. |

### Functions

#### `initialize(owner_)`

Sets the wallet's owner and initializes the transaction counter to zero. Can only be called once.

On-chain checks:
- `owner` must be unset (prevents double initialization).
- `owner_` must not be the zero address.

#### `deposit(amount_)`

Transfers `amount_` microcredits from the signer (the owner) to the contract.

On-chain checks:
- Contract must be initialized.
- Caller must be the stored `owner`.
- `amount_` must be greater than `0`.

#### `create_transaction(to_, amount_, data_, data_length_)`

Creates a new pending transaction at the next available ID, increments `tx_counter`, and stores the entry in the `transactions` mapping.

On-chain checks:
- Contract must be initialized.
- Caller must be the stored `owner`.
- `to_` must not be the zero address.
- `amount_` must be greater than `0`.
- `data_length_` must be less than or equal to `256`.

#### `execute_transaction(tx_id_, to_, amount_)`

Executes a previously created transaction. The client passes `to_` and `amount_` (read from the mapping off-chain), and the contract verifies they match the stored transaction before transferring. The `executed` flag is then set to `true`.

On-chain checks:
- Contract must be initialized.
- Caller must be the stored `owner`.
- `tx_id_` must be less than `tx_counter` (transaction must exist).
- The stored transaction must not have been already executed.
- `to_` and `amount_` must match the stored transaction.
- The contract balance must be at least `amount_`.

#### `withdraw(amount_)`

Transfers the entire contract balance back to the owner. The client passes the current balance as `amount_`, which is verified on-chain.

On-chain checks:
- Contract must be initialized.
- Caller must be the stored `owner`.
- `amount_` must equal the contract's current balance.