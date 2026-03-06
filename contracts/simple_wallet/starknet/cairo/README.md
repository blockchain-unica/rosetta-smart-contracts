# SimpleWallet

## Data Structure Transaction

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

## Storage vars

```cairo
struct Storage {
    owner: ContractAddress,
    token: ContractAddress,
    transactions: Vec<Transaction>,
}
```

| Field          | Type               | Description                                   |
| -------------- | ------------------ | --------------------------------------------- |
| `owner`        | `ContractAddress`  | The only address allowed to call any function |
| `token`        | `ContractAddress`  | ERC20 token used for all transfers            |
| `transactions` | `Vec<Transaction>` | Append-only list of all created transactions  |

## Constructor

```cairo
fn constructor(
    ref self: ContractState,
    owner: ContractAddress,
    token: ContractAddress,
) {
    assert(
        owner != starknet::contract_address_const::<0>(),
        Errors::INVALID_ADDRESS
    );
    self.owner.write(owner);
    self.token.write(token);
}
```

Rules:

- `owner` must not be the zero address.
- The deployer is not automatically the owner; the owner is explicitly provided.

## Deposit

Owner deposits tokens into the wallet.

```cairo
fn deposit(ref self: ContractState, amount: u256) {
    let caller = get_caller_address();
    assert(caller == self.owner.read(), Errors::ONLY_OWNER);
    let token   = IERC20Dispatcher { contract_address: self.token.read() };
    let success = token.transfer_from(caller, get_contract_address(), amount);
    assert(success, Errors::TRANSFER_FAILED);
}
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
) {
    assert(get_caller_address() == self.owner.read(), Errors::ONLY_OWNER);
    self.transactions.push(Transaction { to, value, data, executed: false });
}
```

Requirements:

- Caller must be `owner`.

Behavior:

- Appends a new `Transaction` to `transactions` with `executed = false`.

## Execute transaction

Executes a previously created transaction by ID.

```cairo
fn execute_transaction(ref self: ContractState, tx_id: u64) {
    assert(get_caller_address() == self.owner.read(), Errors::ONLY_OWNER);
    assert(tx_id < self.transactions.len(), Errors::TX_NOT_FOUND);
    let tx = self.transactions.at(tx_id).read();
    assert(!tx.executed, Errors::ALREADY_EXECUTED);
    let token   = IERC20Dispatcher { contract_address: self.token.read() };
    let balance = token.balance_of(get_contract_address());
    assert(tx.value < balance, Errors::INSUFFICIENT_FUNDS);
    self.transactions.at(tx_id).write(
        Transaction { to: tx.to, value: tx.value, data: tx.data, executed: true }
    );
    let success = token.transfer(tx.to, tx.value);
    assert(success, Errors::TRANSFER_FAILED);
}
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
fn withdraw(ref self: ContractState) {
    assert(get_caller_address() == self.owner.read(), Errors::ONLY_OWNER);
    let token   = IERC20Dispatcher { contract_address: self.token.read() };
    let balance = token.balance_of(get_contract_address());
    let success = token.transfer(self.owner.read(), balance);
    assert(success, Errors::TRANSFER_FAILED);
}
```

Requirements:

- Caller must be `owner`

Behavior:

- Transfers **all** wallet token balance to the owner.
