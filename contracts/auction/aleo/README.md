# Auction Contract in Leo (Aleo)

This is an implementation of an English Auction contract on the [Aleo](https://aleo.org) blockchain, written in the [Leo](https://leo-lang.org) programming language. For a general introduction to Leo and the Aleo execution model, refer to the Bet contract README.

## Implementation Notes

Deployment and initialization are separate steps, as Aleo does not support a deploy-time constructor for state initialization (see the Bet contract README).
Rebidding requires a manual withdrawal step, as Leo cannot perform two transfers in the same fn. If no bids are placed before the deadline, end does not need to be called since the contract has no balance to transfer..
 

### Singleton Contract

Unlike Solidity, where each deployment of a contract creates an independent instance with its own state, Leo contracts are singletons — there is exactly one instance of `auction.aleo` per network. This means the contract can only manage one auction at a time. To run a new auction after one has ended, the seller must reinitialize the contract after `end` has been called.

### State Management Without Enums

The Solidity implementation uses an enum with three states (`WAIT_START`, `WAIT_CLOSING`, `CLOSED`). Leo does not support enums, so the contract state is inferred entirely from the `deadline` storage variable:

- `deadline` unset or `0` → auction initialized but not yet started
- `deadline != 0` and `block.height <= deadline` → auction in progress
- `deadline != 0` and `block.height > deadline` → auction expired, waiting for `end`
- `deadline == 0` after `end` → auction closed and reset

This avoids the need for additional boolean state variables.

### The `bids` Mapping

The contract uses a `mapping bids: address => u64` to track the deposits of outbid participants. A bid is added to this mapping only when it is outbid by a higher offer. The current highest bid is always stored in `highest_bid`/`highest_bidder` and never in the mapping.

This design means:
- `highest_bid` / `highest_bidder` → the currently winning bid
- `bids[address]` → funds to be refunded to outbid participants

### The `starting_bid` Variable

The contract separates the starting bid from the highest bid by introducing a dedicated `starting_bid` storage variable. `highest_bid` starts at `0u64` and only increases when real bids are placed. This allows the contract to distinguish between "no bids placed yet" (`highest_bid == 0`) and "at least one bid placed" (`highest_bid > 0`), which is necessary for the `end` function to handle the no-bid case correctly.

### No-Bid Case

If no bids are placed before the deadline, the seller does not need to call `end`. The contract's balance in `credits.aleo::account` is `null` because no funds were ever deposited, and calling `transfer_public` from a `null` account would fail. This is not a limitation specific to Leo — the Solidity implementation has the same behavior, since `end()` would attempt to transfer `highestBid` (the starting bid) which was never deposited in the contract.

### Rebidding Requires Prior Withdrawal

Unlike the Solidity implementation where a rebid automatically triggers a withdrawal of the previous bid, in Leo a bidder must explicitly call `withdraw` before placing a new bid. This is because Leo cannot perform two transfers in the same `fn`. The contract enforces this with an assert in `bid`:

```leo
assert(bids.get_or_use(caller_, 0u64) == 0u64);
```

In practice, a client application can handle this transparently by checking the mapping before submitting a new bid and calling `withdraw` first if needed.

### Parameter Design

Due to the fn/final model, `bid_amount_` must be passed explicitly as a parameter in `withdraw` and `end`, since transfers must be initiated in the off-chain part of the `fn` where storage is not readable. The `final { }` block then verifies these values against stored state.

### The `object` Field

The `object` field is a `[u8; 64]` array used for notarization purposes only.

---

## Contract Design

### State

| Variable | Type | Description |
|---|---|---|
| `seller` | `address` | Address of the seller. |
| `deadline` | `u32` | Block height deadline. `0` before start and after end, non-zero during auction. |
| `object` | `[u8; 64]` | Description of the auctioned item (notarization only). |
| `starting_bid` | `u64` | Minimum bid amount set at initialization. |
| `highest_bidder` | `address` | Address of the current highest bidder. Zero address if no bids yet. |
| `highest_bid` | `u64` | Amount of the current highest real bid (in microcredits). `0` if no bids placed. |
| `bids` | `mapping address => u64` | Deposits of outbid participants, available for withdrawal. |

### Functions

#### `initialize(starting_bid_, object_)`

Called by the **seller** to set up the auction. Stores the caller as `seller`, sets the starting bid, and records the object description. Can only be called once.

On-chain checks:
- `seller` must be unset (prevents double initialization).
- `highest_bid` must be `0` (prevents double initialization).
- `starting_bid_` must be greater than `0`.

#### `start(duration_)`

Called by the **seller** to start the auction. Sets the deadline to `block.height + duration_`.

On-chain checks:
- Contract must be initialized (`seller` must not be zero address).
- `deadline` must be `0` (prevents double start).
- Caller must be the stored `seller`.
- `duration_` must be greater than `0`.

#### `bid(bid_amount_)`

Called by **any user** to place a bid. Transfers `bid_amount_` microcredits from the bidder to the contract. If the bid is higher than the current highest, the previous highest bidder's funds are moved to the `bids` mapping for later withdrawal.

On-chain checks:
- Auction must be started (`deadline != 0`).
- Current block height must be ≤ `deadline`.
- Caller must not have an existing bid in the mapping (must withdraw first).
- `bid_amount_` must be greater than `starting_bid`.
- `bid_amount_` must be greater than the current `highest_bid`.

#### `withdraw(bid_amount_)`

Called by **any outbid participant** to reclaim their deposited funds. Can be called at any time after being outbid, even after the auction has ended.

On-chain checks:
- Caller must not be the current `highest_bidder`.
- Caller must have a non-zero entry in the `bids` mapping.
- `bid_amount_` must match the stored value in `bids`.

#### `end(bid_amount_)`

Called by the **seller** after the auction has expired to collect the highest bid. Only valid if at least one bid was placed (`highest_bid > 0`). Resets the contract state so a new auction can be initialized.

On-chain checks:
- Caller must be the stored `seller`.
- `deadline` must be non-zero (auction must have been started).
- Current block height must be > `deadline`.
- `bid_amount_` must equal the stored `highest_bid`.