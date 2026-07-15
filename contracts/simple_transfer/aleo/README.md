# Simple Transfer Contract in Leo (Aleo)

## Overview
 
This is an implementation of the **Simple Transfer contract** on the [Aleo](https://aleo.org) blockchain, written in the [Leo](https://leo-lang.org) programming language. For a general introduction to Leo and the Aleo execution model, refer to the Bet contract README.
 
## Implementation Notes
 
The implementation is coherent with the specification. Deployment and initialization are separate steps, as Aleo does not support a deploy-time constructor for state initialization, the `constructor` keyword in Leo serves only to define the upgrade policy (set to `@noupgrade` here).
 
The contract maintains an internal `balance` storage variable to track the deposited amount. This is necessary because the contract cannot read `credits.aleo::account` (the actual on-chain balance) during the off-chain execution phase of a `fn`. As a consequence, only funds deposited through the `deposit` function are tracked, any direct transfer to the contract address would not be reflected in `balance`.
 
Due to the fn/final model, the `amount_` to deposit or withdraw must be passed explicitly as a parameter by the caller, since storage is not accessible in the off-chain execution phase. The `final { }` block then verifies the provided value against stored state.
 
## Contract Design
 
### State
 
| Variable | Type | Description |
|---|---|---|
| `owner` | `address` | Address of the owner, set at initialization. |
| `recipient` | `address` | Address of the recipient, set at initialization. |
| `balance` | `u64` | Internal balance tracker (in microcredits). |
 
### Functions
 
#### `initialize(recipient_)`
 
Called by the **owner** to set up the contract. Stores the caller as `owner` and the provided address as `recipient`. Can only be called once.

On-chain checks:
- `owner` must be the zero address (prevents double initialization).
- `recipient` must be the zero address (prevents double initialization).
 
#### `deposit(amount_)`
 
Called by the **owner** to deposit `amount_` microcredits into the contract via `transfer_public_as_signer`. The internal `balance` is incremented accordingly.
 
On-chain checks:
- Caller must be the stored `owner`.
 
#### `withdraw(amount_)`
 
Called by the **recipient** to withdraw `amount_` microcredits from the contract via `transfer_public`. The internal `balance` is decremented accordingly.
 
On-chain checks:
- Caller must be the stored `recipient`.
- `amount_` must be greater than 0.
- `balance` must be ≥ `amount_`.