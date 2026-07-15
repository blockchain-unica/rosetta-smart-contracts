# Lottery Contract in Leo (Aleo)

This is an implementation of the Lottery contract on the [Aleo](https://aleo.org) blockchain, written in the [Leo](https://leo-lang.org) programming language. For a general introduction to Leo and the Aleo execution model, refer to the Bet contract README.

## Implementation Notes

The implementation is coherent with the specification, with the same multisig-split adopted by Solidity, since Aleo does not support multi-signature verification natively, the join phase is divided into two separate actions. 

### State Machine

The contract is organized around an explicit state machine encoded in a single `status: u8` storage variable, with constants `STATUS_JOIN0`, `STATUS_JOIN1`, `STATUS_REVEAL0`, `STATUS_REVEAL1`, `STATUS_WIN`, `STATUS_END`. Each function asserts the required state on entry and advances it on success. This mirrors the Solidity reference's `enum Status`. The state machine makes the protocol's preconditions explicit at every step and prevents invalid transitions (for instance, calling `reveal0` after a timeout has already closed the lottery).

A sentinel value `STATUS_UNSET = 99u8` is used as the default in `unwrap_or` calls to detect the pre-initialization state. Any value outside `0..5` would work;

### Deadlines Computed on Player Actions, Not at Initialization

The Solidity reference computes both `end_join` and `end_reveal` inside the constructor, fixing them at deploy time. This means the time available for player1 to join, or for the reveal phase, depends on when the contract was deployed, not on when the players actually start playing. If player0 joins close to `end_join`, player1 may have very little time to respond.

The Leo implementation stores the **durations** (`join_duration`, `reveal_duration`) at `initialize` time, but **computes the deadlines dynamically** when each action occurs:

- `end_commit` is set in `join0` to `block.height + commit_duration`, so player1 always has the full `commit_duration` to respond.
- `end_reveal` is set in `join1` to `block.height + reveal_duration`, so the reveal window starts when the second player joins.

This is more flexible than the Solidity model and avoids the timing pathology where the response window depends on contract deploy timing.

### Hash Function: Poseidon2

The Solidity reference uses `keccak256(abi.encodePacked(s))` to commit secrets. The Leo implementation uses `Poseidon2::hash_to_field`, the native Aleo hash function. Reasons:

- Poseidon2 is the canonical hash function inside Aleo's circuits and is significantly cheaper than Keccak256.
- This contract has no cross-chain interaction that would justify the cost of Keccak256.
- The output type of `Poseidon2::hash_to_field` is `field`, which fits naturally as the type for both stored hashes (`hash0`, `hash1`) and the secret inputs.


### Secret Type: `field`

The Solidity reference stores secrets as `string`. The Leo implementation uses `field` (Aleo's native finite-field type, ~254 bits). Reasons:

- Leo does not have a native string type; emulating one with `[u8; N]` plus a separate `length: u32` would add complexity for no functional benefit.
- `field` is large enough (~2^254 values) to make brute-force preimage attacks infeasible, even with cheap fast hashes.
- `field` is the natural input type for `Poseidon2::hash_to_field`, eliminating any conversion overhead.

### Fairness Function

The Solidity reference computes the winner from the **lengths** of the two secret strings: `(length(secret0) + length(secret1)) % 2 == 0 ? player0 : player1`. This is a peculiar choice tied to Solidity's string handling and would be unnatural in Leo where the secrets are not strings.

The Leo implementation derives the winner directly from the secret values:

```leo
let combined: u8 = Poseidon2::hash_to_u8(s0 + s1);
let winner: address = combined % 2u8 == 0u8 ? player0 : player1;
```

The two secrets are summed in field arithmetic, then hashed down to a `u8`, whose parity selects the winner. This is functionally equivalent to the Solidity scheme as a fair binary selection: neither player can predict or influence the outcome at commit time, since each commits without knowing the other's secret. The hashing step is not strictly necessary (the parity of `s0 + s1` would already be unbiased when the secrets are pseudo-random) but smooths the distribution and is convenient because `%` is not defined on `field` in Leo.

### The `compute_hash` Helper

Solidity exposes `keccak256` as an EVM opcode that any client (web3.js, ethers, etc.) can invoke off-chain without interacting with a contract. Aleo offers no equivalent off-chain primitive, to compute `Poseidon2::hash_to_field(secret)` outside the chain, a user must either invoke the Aleo SDK or run a Leo program.

To make off-chain hash computation accessible during testing and from any Leo CLI, the contract includes a pure helper:

```leo
fn compute_hash(secret_: field) -> field {
    return Poseidon2::hash_to_field(secret_);
}
```

This function does not touch storage, transfer credits, or modify state; it is purely a convenience for clients to compute commitments via `leo run compute_hash <secret>field`. It does not affect the protocol's security and could be omitted in a deployment that always relies on the Aleo SDK for off-chain operations.

### Amount Parameter Pattern

As in other contracts that transfer native credits (Vesting, SimpleWallet, Vault, Crowdfund, PaymentSplitter), all functions that perform a `transfer_public` accept the amount as a parameter and verify it on-chain. This is unavoidable in Leo because `credits.aleo::transfer_public` must be invoked in the off-chain part of the transition (where storage is not readable), so the amount must be known before entering the `final { }` block.

For `redeem` functions the expected amount is either `bet_amount` (for the single-bet timeout) or `bet_amount * 2` (for the full-pot timeouts). For `win` the amount is always `bet_amount * 2`, and additionally the `winner_` address itself is passed as a parameter and verified against the on-chain computation:

```leo
assert(winner_ == winner);
```

If the caller proposes the wrong winner, the assertion fails and the transaction reverts.

### Considered Alternative: Record-Based Anonymous Lottery

An alternative design would represent each player's participation as a private `Ticket` record owned by the player, instead of public storage variables. This would hide the players' identities until they reveal or claim a payout. We considered this design but decided against it for two reasons:

- The commit-reveal protocol already provides the cryptographic privacy that matters for fairness: the secrets stay off-chain until reveal, and the public hashes leak nothing. Record-based ownership would only hide *who is playing*, not the secrets themselves.
- For a lottery to function, the contract must eventually pay the winner, which forces the winner's address to become public on-chain at the moment of payout. Record-based players would gain anonymity until the very end, but lose it at the only moment where it would matter for plausible deniability.

The mapping-based public design is simpler, faithful to the Solidity reference, and does not sacrifice any meaningful privacy.

---

## Contract Design

### Constants

| Constant | Value | Description |
|---|---|---|
| `STATUS_JOIN0` | `0u8` | Waiting for player0 to join. |
| `STATUS_JOIN1` | `1u8` | Player0 joined; waiting for player1. |
| `STATUS_REVEAL0` | `2u8` | Both joined; waiting for player0 to reveal. |
| `STATUS_REVEAL1` | `3u8` | Player0 revealed; waiting for player1 to reveal. |
| `STATUS_WIN` | `4u8` | Both revealed; winner can claim the pot. |
| `STATUS_END` | `5u8` | Lottery closed (paid out or refunded). |
| `STATUS_UNSET` | `99u8` | Sentinel for "not yet initialized". |

### State

| Variable | Type | Description |
|---|---|---|
| `status` | `u8` | Current state of the lottery state machine. |
| `join_duration` | `u32` | Number of blocks player1 has to join after player0. |
| `reveal_duration` | `u32` | Number of blocks the reveal phase lasts. |
| `end_commit` | `u32` | Block height by which player1 must join (set at `join0`). |
| `end_reveal` | `u32` | Block height by which both reveals must occur (set at `join1`). |
| `player0` | `address` | Address of the first player. |
| `player1` | `address` | Address of the second player. |
| `hash0` | `field` | Player0's commitment, `Poseidon2::hash_to_field(secret0)`. |
| `hash1` | `field` | Player1's commitment. |
| `secret0` | `field` | Player0's revealed secret. |
| `secret1` | `field` | Player1's revealed secret. |
| `bet_amount` | `u64` | Amount (in microcredits) each player must deposit. |

### Functions

#### `initialize(join_duration_, reveal_duration_)`

Called by **anyone** to set up the lottery. Stores the phase durations and sets the state machine to `STATUS_JOIN0`. Can only be called once.

On-chain checks:
- Contract must not be already initialized (`status == STATUS_UNSET`).
- `commit_duration_` must be greater than `0`.
- `reveal_duration_` must be greater than `0`.

#### `join0(hash_, bet_amount_)`

Called by the **first player** to deposit the bet, register the commitment, and start the lottery. Sets `end_commit` to `block.height + join_duration`.

On-chain checks:
- State must be `STATUS_JOIN0`.
- `bet_amount_` must be greater than `0`.

#### `join1(hash_, bet_amount_)`

Called by the **second player** to match the bet and register the commitment. Sets `end_reveal` to `block.height + reveal_duration`.

On-chain checks:
- State must be `STATUS_JOIN1`.
- `block.height` must be less than `end_commit`.
- `bet_amount_` must equal the stored `bet_amount` (matching player0's bet).
- `hash_` must be different from `hash0` (no commitment duplication).

#### `redeem0_nojoin1(bet_amount_)`

Called by **player0** to reclaim their bet if player1 never joins.

On-chain checks:
- State must be `STATUS_JOIN1`.
- `block.height` must be greater than `end_commit`.
- Caller must be `player0`.
- `bet_amount_` must equal the stored `bet_amount`.

#### `reveal0(secret_)`

Called by **player0** to reveal their secret.

On-chain checks:
- State must be `STATUS_REVEAL0`.
- `block.height` must be less than `end_reveal`.
- Caller must be `player0`.
- `Poseidon2::hash_to_field(secret_)` must equal `hash0`.

#### `redeem1_noreveal0(amount_)`

Called by **player1** to claim the entire pot if player0 fails to reveal in time.

On-chain checks:
- State must be `STATUS_REVEAL0`.
- `block.height` must be greater than `end_reveal`.
- Caller must be `player1`.
- `amount_` must equal `bet_amount * 2`.

#### `reveal1(secret_)`

Called by **player1** to reveal their secret after player0 has revealed.

On-chain checks:
- State must be `STATUS_REVEAL1`.
- `block.height` must be less than `end_reveal`.
- Caller must be `player1`.
- `Poseidon2::hash_to_field(secret_)` must equal `hash1`.

#### `redeem0_noreveal1(amount_)`

Called by **player0** to claim the entire pot if player1 fails to reveal after player0 has revealed.

On-chain checks:
- State must be `STATUS_REVEAL1`.
- `block.height` must be greater than `end_reveal`.
- Caller must be `player0`.
- `amount_` must equal `bet_amount * 2`.

#### `win(winner_, amount_)`

Called by **anyone** to pay out the pot to the winner, computed as a fair function of both revealed secrets.

On-chain checks:
- State must be `STATUS_WIN`.
- `amount_` must equal `bet_amount * 2`.
- `winner_` must equal the on-chain computed winner: `Poseidon2::hash_to_u8(secret0 + secret1) % 2 == 0 ? player0 : player1`.

#### `compute_hash(secret_) -> field`

Pure helper function that returns `Poseidon2::hash_to_field(secret_)`. Used off-chain by clients (e.g. via `leo run compute_hash <secret>field`) to compute commitments before calling `join0` or `join1`. Does not modify state and does not produce a transaction when invoked via `leo run`.