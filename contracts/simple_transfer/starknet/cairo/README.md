# SimpleTransfer

## Storage

```cairo
struct Storage {
    owner: ContractAddress,
    recipient: ContractAddress,
    token: ContractAddress, // e.g. Starknet ETH token address
}
```

| Field       | Type              | Description                                    |
| ----------- | ----------------- | ---------------------------------------------- |
| `owner`     | `ContractAddress` | Deployer — the only address allowed to deposit |
| `recipient` | `ContractAddress` | The only address allowed to withdraw           |
| `token`     | `ContractAddress` | ERC20 token used for deposits and withdrawals  |

## Constructor

```cairo
fn constructor(ref self: ContractState, recipient: ContractAddress, token: ContractAddress,) {
    self.recipient.write(recipient);
    self.owner.write(get_caller_address());
    self.token.write(token);
}
```

Parameters:

- recipient — address allowed to withdraw
- token — ERC20 token used for deposits/withdrawals

- Caller becomes the `owner`
- `recipient` and `token` are fixed — cannot be changed after deployment

## Deposit

```cairo
fn deposit(ref self: ContractState, amount: u256) {
    let caller = get_caller_address();
    assert(caller == self.owner.read(), Errors::ONLY_OWNER);

    let token = IERC20Dispatcher { contract_address: self.token.read() };
    let success = token.transfer_from(caller, get_contract_address(), amount);
    assert(success, Errors::TRANSFER_FAILED);
}
```

Owner deposits tokens into the contract.

- Only callable by the `owner`
- Transfers `amount` from owner to the contract via `transfer_from`
- Owner must have approved the contract to spend `amount` beforehand
- Can be called multiple times — balances accumulate

## Withdraw

```cairo
fn withdraw(ref self: ContractState, amount: u256) {
    let caller = get_caller_address();
    assert(caller == self.recipient.read(), Errors::ONLY_RECIPIENT);

    let token = IERC20Dispatcher { contract_address: self.token.read() };
    let balance = token.balance_of(get_contract_address());
    assert(amount <= balance, Errors::INSUFFICIENT_BALANCE);

    let success = token.transfer(self.recipient.read(), amount);
    assert(success, Errors::TRANSFER_FAILED);
}
```

Recipient withdraws tokens from the contract.

- Only callable by the `recipient`
- `amount` must be less than or equal to the current contract balance
- Transfers exactly `amount` tokens to the recipient
