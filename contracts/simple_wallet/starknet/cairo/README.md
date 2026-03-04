# SimpleWallet

## Data Structure

### Transaction

```cairo
pub struct Transaction {
    pub to: ContractAddress,
    pub value: u256,
    pub data: ByteArray,
    pub executed: bool,
}
```

Fields:

| Field      | Description                                          |
| ---------- | ---------------------------------------------------- |
| `to`       | Recipient address                                    |
| `value`    | Amount of tokens to transfer                         |
| `data`     | Arbitrary metadata payload (stored but not executed) |
| `executed` | Marks if the transaction has already been executed   |

> Note: `data` is stored for auditing/metadata purposes. In this implementation it is **not used to perform a contract call** (only the token transfer is executed).

## Constructor

```cairo
#[constructor]
fn constructor(
    ref self: ContractState,
    owner: ContractAddress,
    token: ContractAddress,
)
```

Rules:

- `owner` must not be the zero address.
- The deployer is not automatically the owner; the owner is explicitly provided.

## Deposit

Owner deposits tokens into the wallet.

```cairo
fn deposit(ref self: ContractState, amount: u256)
```

Requirements:

- Caller must be `owner`.

Behavior:

- Pulls tokens from `owner` into the contract using `transfer_from`.

The owner must approve first:

```text
token.approve(wallet_address, amount)
wallet.deposit(amount)
```

## Create transaction

Creates a new transaction entry (does not execute it).

```cairo
fn create_transaction(
    ref self: ContractState,
    to: ContractAddress,
    value: u256,
    data: ByteArray,
)
```

Requirements:

- Caller must be `owner`.

Behavior:

- Appends a new `Transaction` to `transactions` with `executed = false`.

## Execute transaction

Executes a previously created transaction by ID.

```cairo
fn execute_transaction(ref self: ContractState, tx_id: u64)
```

Requirements:

- Caller must be `owner`
- `tx_id` must exist
- Transaction must not be executed already
- Wallet balance must be sufficient

Behavior:

- Marks the transaction as executed
- Transfers `tx.value` tokens to `tx.to`

## Withdraw

Withdraws the entire wallet balance back to the owner.

```cairo
fn withdraw(ref self: ContractState)
```

Requirements:

- Caller must be `owner`

Behavior:

- Transfers **all** wallet token balance to the owner.
