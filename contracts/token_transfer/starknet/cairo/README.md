# TokenTransfer

A Cairo smart contract on Starknet that allows an **owner** to deposit ERC20 tokens and a **recipient** to withdraw them.

## Relationship to SimpleTransfer

In Solidity, `SimpleTransfer` and `TokenTransfer` are meaningfully different contracts:

- `SimpleTransfer` operates on **native ETH** (`msg.value`, `address.call{value}`)
- `TokenTransfer` operates on an **ERC20 token** (`transferFrom`, `transfer`)

On Starknet there is no native currency opcode — everything goes through ERC20 contracts. This means the Cairo translation of `SimpleTransfer` already had to use ERC20 under the hood, making the two contracts structurally identical.

The only behavioural differences in this contract are:

| Behaviour                  | SimpleTransfer | TokenTransfer                               |
| -------------------------- | -------------- | ------------------------------------------- |
| Withdraw amount > balance  | Reverts        | Caps withdrawal to available balance        |
| Withdraw on empty contract | No check       | Reverts with `the contract balance is zero` |
| Withdraw event             | None           | Emits `Withdraw(sender, amount)`            |

## Storage

```cairo
struct Storage {
    owner: ContractAddress,
    recipient: ContractAddress,
    token: ContractAddress,
}
```

| Field       | Type              | Description                                    |
| ----------- | ----------------- | ---------------------------------------------- |
| `owner`     | `ContractAddress` | Deployer — the only address allowed to deposit |
| `recipient` | `ContractAddress` | The only address allowed to withdraw           |
| `token`     | `ContractAddress` | ERC20 token used for deposits and withdrawals  |

## Events

### `Withdraw`

Emitted after every successful withdrawal.

| Field    | Type              | Indexed | Description                                            |
| -------- | ----------------- | ------- | ------------------------------------------------------ |
| `sender` | `ContractAddress` | yes     | Address that called `withdraw` — always the recipient  |
| `amount` | `u256`            | no      | Actual amount transferred — may be less than requested |

## Constructor

```cairo
fn constructor(
    ref self: ContractState,
    recipient: ContractAddress,
    token: ContractAddress,
) {
    self.owner.write(get_caller_address());
    self.recipient.write(recipient);
    self.token.write(token);
}
```

- Caller becomes the `owner`
- `recipient` and `token` are fixed after deployment

## Deposit

```cairo
fn deposit(ref self: ContractState, amount: u256) {
    let caller = get_caller_address();
    assert(caller == self.owner.read(), Errors::ONLY_OWNER);
    let token = IERC20Dispatcher { contract_address: self.token.read() };
    let success = token.transfer_from(caller, get_contract_address(), amount);
    assert(success, Errors::DEPOSIT_FAILED);
}
```

Owner deposits tokens into the contract.

- Only callable by the `owner`
- Transfers `amount` from owner to the contract via `transfer_from`
- Owner must have approved the contract to spend `amount` beforehand
- Can be called multiple times — balances accumulate

```cairo
contract.deposit(1000_u256);
// → 1000 tokens transferred from owner to contract
```

---

## Withdraw

```cairo
fn withdraw(ref self: ContractState, amount: u256) {
    let caller = get_caller_address();
    assert(caller == self.recipient.read(), Errors::ONLY_RECIPIENT);
    let token = IERC20Dispatcher { contract_address: self.token.read() }
    let balance = token.balance_of(get_contract_address());
    assert(balance > 0, Errors::ZERO_BALANCE);
    let actual_amount = if amount > balance { balance } else { amount };
    let success = token.transfer(self.recipient.read(), actual_amount);
    assert(success, Errors::TRANSFER_FAILED);
    self.emit(Withdraw { sender: caller, amount: actual_amount });
}
```

Recipient withdraws tokens from the contract.

- Only callable by the `recipient`
- Contract balance must be greater than zero
- Transfers `min(amount, balance)` — never reverts due to over-requesting
- Emits a `Withdraw` event with the actual transferred amount

```cairo
contract.withdraw(300_u256);
// → if balance >= 300: transfers 300 to recipient
// → if balance < 300:  transfers full balance to recipient
```
