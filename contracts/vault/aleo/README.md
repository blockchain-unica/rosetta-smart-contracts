# Vault Contract in Leo (Aleo)

This is an implementation of the Vault contract on the [Aleo](https://aleo.org) blockchain, written in the [Leo](https://leo-lang.org) programming language. For a general introduction to Leo and the Aleo execution model, refer to the Bet contract README.

## Implementation Notes

The implementation is coherent with the specification.

### State Management Without Enums

The Solidity implementation uses an enum with two states (`IDLE`, `REQ`). Leo does not support enums, so the state is inferred from the `request_time` storage variable:

- `request_time == 0` → IDLE (no pending withdraw request)
- `request_time != 0` → REQ (withdraw request pending since block `request_time`)

This avoids the need for an additional boolean state variable.


### Parameter Design

Due to the fn/final model, `receiver_` and `amount_` must be passed explicitly as parameters in `finalize_withdraw`, since the transfer must be initiated in the off-chain part of the `fn` where storage is not readable. The `final { }` block verifies both values against the stored request.

### Balance Check in `withdraw`

The contract verifies that the requested amount does not exceed the vault's balance at the time of the request, using `credits.aleo::account.get_or_use` inside the `final { }` block. This prevents issuing a withdraw request for more funds than are available.

---

## Contract Design

### State

| Variable | Type | Description |
|---|---|---|
| `owner` | `address` | Address of the vault owner. |
| `recovery` | `address` | Address of the recovery key — can cancel pending withdraw requests. |
| `wait_time` | `u32` | Number of blocks that must elapse between a withdraw request and finalization. |
| `receiver` | `address` | Address that will receive the funds upon finalization. |
| `desired_amount` | `u64` | Amount (in microcredits) requested for withdrawal. |
| `request_time` | `u32` | Block height at which the withdraw request was issued. `0` if no pending request. |

### Functions

#### `initialize(recovery_, wait_time_)`

Called by the **owner** to set up the vault. Stores the caller as `owner`, the recovery address, and the wait time. Can only be called once.

On-chain checks:
- `owner` must be unset (prevents double initialization).
- `recovery_` must not be the zero address.
- `wait_time_` must be greater than `0`.

#### `receive(amount_)`

Called by **anyone** to deposit `amount_` microcredits into the vault.

On-chain checks:
- Contract must be initialized (`recovery` must not be zero address).

#### `withdraw(receiver_, desired_amount_)`

Called by the **owner** to issue a withdraw request. Records the receiver, amount, and current block height. Transitions from IDLE to REQ.

On-chain checks:
- Caller must be the stored `owner`.
- No pending request (`request_time` must be `0`).
- `receiver_` must not be the zero address.
- `desired_amount_` must not exceed the vault's current balance.

#### `finalize_withdraw(receiver_, amount_)`

Called by the **owner** after the wait time has elapsed to finalize the transfer. Transitions from REQ back to IDLE.


On-chain checks:
- Caller must be the stored `owner`.
- A pending request must exist (`request_time` must not be `0`).
- Current block height must be > `request_time + wait_time`.
- `receiver_` must match the stored `receiver`.
- `amount_` must match the stored `desired_amount`.

#### `cancel()`

Called by the **recovery key** to cancel a pending withdraw request. Transitions from REQ back to IDLE without transferring any funds.

On-chain checks:
- Caller must be the stored `recovery`.
- A pending request must exist (`request_time` must not be `0`).
- Current block height must be ≤ `request_time + wait_time` (wait time not yet elapsed).

