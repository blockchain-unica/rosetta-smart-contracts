# Bet Contract in Leo (Aleo)

## Overview

This is an implementation of a **Bet contract** on the [Aleo](https://aleo.org) blockchain, written in the [Leo](https://leo-lang.org) programming language. 

The contract involves two players and a trusted oracle. Each player deposits a wager into the contract. The oracle must declare a winner, who will receive the entire pot. If the oracle fails to declare a winner by the deadline, both players may individually request a refund of their bets.



## The Leo Language and the Aleo Blockchain

Leo is a statically typed programming language, inspired by Rust, designed for writing zero-knowledge programs on the Aleo blockchain. Aleo's core principle is programmable privacy: computations are performed off-chain and verified on-chain using zero-knowledge proofs (ZKPs), meaning sensitive data must never be exposed publicly.
This impacts contract implementations.

### The Async/Transition Model

The most distinctive architectural feature of Leo (and the one with the greatest impact on smart contract design) is the strict separation between **off-chain** and **on-chain** execution:

- **`async transition`**: Executes off-chain on the user's machine. It generates a ZK proof of the computation. This is where external calls (e.g., token transfers) are initiated and where inputs can remain **private**.
- **`async function`** (finalize block): Executes on-chain by the network validators. It has access to persistent on-chain storage (mappings and storage variables) but cannot access private data. All inputs to this block are **public**.

This separation has a major practical implication: **storage variables can only be read inside the `async function`**, not inside the `async transition`. This means that any value needed for an off-chain computation (e.g., the amount to transfer) must be passed explicitly as a parameter by the caller, and then verified on-chain against the stored state. 
This is a fundamental difference compared to most smart contract languages.

### Native Token Transfers

Aleo uses `credits.aleo` as the standard program for its native token. Two key functions are used in this contract:

- **`credits.aleo/transfer_public_as_signer`**: Transfers tokens **from the transaction signer** (i.e., the player calling the function) to a recipient. Used when players deposit their wager.
- **`credits.aleo/transfer_public`**: Transfers tokens **from the contract's own public balance** to a recipient. Used when paying out the winner or refunding players.

Both calls return a `Future` that must be passed to the `async function` and explicitly `await`-ed, ensuring atomicity: if any on-chain assertion fails, the entire transaction is reverted.

### Storage Variables vs. Mappings

Leo supports two forms of persistent on-chain storage:

- **`mapping`**: A key-value store (e.g., `mapping balances: address => u64`). Suitable for collections.
- **`storage`**: A single-value variable (e.g., `storage player1: address`). Semantically cleaner for singleton values.

Storage variables are read with `.unwrap()` (panics if uninitialized) or `.unwrap_or(default)` (returns a default value if uninitialized).

### The Zero Address Pattern

Leo's `address` type has no native `Option` or null equivalent. To represent "not yet set" for addresses, this contract uses the canonical **zero address**:

```
aleo1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq3ljyzc
```

This address is the standard placeholder for an uninitialized address in the Aleo ecosystem.

### Upgrade Policy (Constructor)

Since ConsensusVersion V9, every Leo program deployed on Aleo **must include a constructor** that defines its upgrade policy. This contract uses the `@noupgrade` annotation, which permanently prevents any future upgrades. This is the appropriate choice for a betting contract, since players must be able to trust that the rules cannot be changed after they have committed their funds.

```leo
@noupgrade
async constructor() {}
```

## Contract Design
 
### No Deploy-Time Initialization
 
A key architectural difference between Aleo and most other smart contract platforms is that **Aleo does not support a traditional constructor** — that is, a function that executes automatically at deployment time to initialize the contract state.
 
In Aleo, the `constructor` keyword exists but serves an entirely different purpose: it defines the **upgrade policy** of the program (see the Upgrade Policy section above). It does not execute arbitrary initialization logic.
 
As a consequence, **deployment and initialization are two separate steps** in this contract:
 
1. **Deploy** — the contract bytecode is published on-chain with no state. All storage variables are unset.
2. **Initialize** — Player 1 calls `initialize(...)` in a separate transaction to set the oracle, wager, and deadline, and deposit their funds.
 
This means that between deployment and the first `initialize` call, the contract exists on-chain but is in an empty, unusable state. The `initialize` function itself guards against being called twice by checking that `player1` is still the zero address.
 
### State
 
The contract stores the following state variables:
 
| Variable | Type | Description |
|---|---|---|
| `player1` | `address` | Address of the first player (initializer). Zero address if not yet set. |
| `player2` | `address` | Address of the second player. Zero address if not yet joined. |
| `oracle` | `address` | Address of the trusted oracle. |
| `wager` | `u64` | Amount wagered by each player (in microcredits). |
| `deadline` | `u32` | Block height after which the timeout becomes active. |
| `winner_declared` | `bool` | True if the oracle has already declared a winner. |
| `redeemer` | `address` | Address of the player who has already claimed a timeout refund, to prevent double-claiming. |
 
### Functions
 
#### `initialize(oracle_addr, timeout_, bet_amount)`
 
Called by **Player 1** to initialize the bet. This is the functional equivalent of a constructor in other platforms. Player 1 transfers `bet_amount` microcredits from their own public balance to the contract's address using `transfer_public_as_signer`. The deadline is computed on-chain as `block.height + timeout_`. 
 
On-chain checks:
- `player1` must be the zero address (prevents double initialization).
 
#### `join(bet_amount)`
 
Called by **Player 2** to join the bet. Player 2 transfers the same `bet_amount` to the contract using `transfer_public_as_signer`.
 
On-chain checks:
- `player1` must not be the zero address (bet must be initialized).
- `player2` must be the zero address (prevents double joining).
- `bet_amount` must equal the stored `wager`.
- Current block height must be ≤ `deadline` (joining after the deadline is not allowed).
 
#### `win(winner, winner_addr, pot)`
 
Called by the **oracle** to declare the winner and transfer the full pot to the winner's address. The transfer is initiated off-chain via `transfer_public`, which draws from the contract's own public balance.
 
**Why `winner_addr` and `pot` are parameters:** the oracle must read `player1`, `player2`, and `wager` from the public chain state (e.g., via the REST API) before submitting the transaction, and pass these values explicitly. The `async transition` cannot read storage, so it cannot determine the winner's address or the pot amount on its own. The `async function` then verifies that the provided values match what is stored on-chain, making the caller's inputs trustless.
 
The `winner` parameter (0 or 1) is an index: 0 selects `player1`, 1 selects `player2`. This avoids exposing addresses in the transition inputs while still being verifiable on-chain.
 
On-chain checks:
- Caller must be the stored `oracle`.
- Current block height must be ≤ `deadline`.
- `player2` must not be the zero address (both players must have joined).
- `pot` must equal `wager * 2`.
- `winner` must be 0 or 1.
- `winner_addr` must match `player1` (if `winner == 0`) or `player2` (if `winner == 1`).
 
#### `timeout(bet_amount)`
 
Called by **either player** after the deadline has passed to reclaim their individual wager. Each player must submit a separate transaction. The `redeemer` storage variable tracks who has already claimed, preventing double-spending.
 
**Why `bet_amount` is a parameter:** the transfer back to the caller is initiated off-chain via `transfer_public`. Since the `async transition` cannot read the stored `wager`, the caller must pass the amount they expect to receive. The `async function` verifies this against the stored value.
 
**Why two separate transactions instead of one:** in Solidity or Vyper, a single `timeout` call can refund both players atomically. In Aleo, a single `transfer_public` call can only send to one recipient (the signer of the transition). Sending to two different addresses would require two separate `transfer_public` calls, each generating its own Future — which would require two `await` calls in sequence. While this is technically possible, it raises a practical issue: the contract cannot know at transition time whether `player2` has joined, since storage is not readable off-chain. The chosen design (one transaction per player), avoids this problem entirely.

On-chain checks:
- Current block height must be > `deadline`.
- No winner must have been declared (`winner_declared` must be false).
- `player1` must not be the zero address (bet must have been initialized).
- Caller must be `player1` or `player2`.
- Caller must not have already claimed (`redeemer` must not equal the caller).
- `bet_amount` must equal the stored `wager`.