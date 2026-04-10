# Escrow Contract in Leo (Aleo)

This is an implementation of the Escrow contract on the [Aleo](https://aleo.org) blockchain, written in the [Leo](https://leo-lang.org) programming language. For a general introduction to Leo and the Aleo execution model, refer to the Bet contract README.

## Implementation Notes

The implementation is coherent with the specification. Deployment and initialization are separate steps, as Aleo does not support a deploy-time constructor for state initialization (see the Bet contract README).

The contract uses two boolean storage variables, `deposit_done` and `pay_or_refund_done`, to track the contract state and enforce the correct sequence of actions.

Due to the async/transition model, `seller_`, `buyer_`, and `amount_` must be passed explicitly as parameters in `pay` and `refund`, since transfers must be initiated off-chain where storage is not readable. The `async function` then verifies these values against stored state.

---

## Contract Design

### State

| Variable | Type | Description |
|---|---|---|
| `seller` | `address` | Address of the seller. |
| `buyer` | `address` | Address of the buyer. |
| `required_amount` | `u64` | Amount of microcredits required as payment. |
| `deposit_done` | `bool` | True after the buyer has deposited. |
| `pay_or_refund_done` | `bool` | True after pay or refund has been executed. Prevents double execution. |

### Functions

#### `initialize(buyer_, required_amount_)`

Called by the **seller** to set up the contract. Stores the caller as `seller`, the provided address as `buyer`, and the required payment amount. Can only be called once.

On-chain checks:
- `seller` must be the zero address (prevents double initialization).
- `buyer` must be the zero address (prevents double initialization).

#### `deposit(amount_)`

Called by the **buyer** to deposit the required amount into the contract via `transfer_public_as_signer`.

On-chain checks:
- `deposit_done` must be false (prevents double deposit).
- Contract must be initialized (`seller` must not be the zero address).
- Caller must be the stored `buyer`.
- `amount_` must equal the stored `required_amount`.

#### `pay(seller_, amount_)`

Called by the **buyer** to transfer the contract balance to the seller, confirming that the goods have been received.

On-chain checks:
- `deposit_done` must be true.
- `pay_or_refund_done` must be false (prevents double execution).
- Caller must be the stored `buyer`.
- `seller_` must equal the stored `seller`.
- `amount_` must equal the stored `required_amount`.

#### `refund(buyer_, amount_)`

Called by the **seller** to transfer the contract balance back to the buyer, in case the goods were not delivered.

On-chain checks:
- `deposit_done` must be true.
- `pay_or_refund_done` must be false (prevents double execution).
- Caller must be the stored `seller`.
- `buyer_` must equal the stored `buyer`.
- `amount_` must equal the stored `required_amount`.
