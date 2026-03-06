# PaymentSplitter

## Storage var

```cairo
struct Storage {
    token: ContractAddress,
    total_shares: u256,
    total_released: u256,
    shares: Map<ContractAddress, u256>,
    released: Map<ContractAddress, u256>,
    payees: Vec<ContractAddress>,
}
```

| Field            | Type                         | Description                                      |
| ---------------- | ---------------------------- | ------------------------------------------------ |
| `token`          | `ContractAddress`            | ERC20 token used for deposits and payments       |
| `total_shares`   | `u256`                       | Sum of all payee shares                          |
| `total_released` | `u256`                       | Cumulative amount released to all payees so far  |
| `shares`         | `Map<ContractAddress, u256>` | Share weight assigned to each payee              |
| `released`       | `Map<ContractAddress, u256>` | Cumulative amount already released to each payee |
| `payees`         | `Vec<ContractAddress>`       | Ordered list of all payee addresses              |

## Constructor

```cairo
fn constructor(
    ref self: ContractState,
    payees: Array<ContractAddress>,
    shares: Array<u256>,
    token: ContractAddress,
) {
    assert(payees.len() == shares.len(), Errors::LENGTH_MISMATCH);
    assert(payees.len() > 0, Errors::NO_PAYEES);
    self.token.write(token);
    let mut i = 0;
    while i < payees.len() {
        self._add_payee(*payees.at(i), *shares.at(i));
        i += 1;
    }
}
```

- `payees` and `shares` arrays must have equal length
- At least one payee is required
- Each payee must be a non-zero address
- Each share must be greater than zero
- No payee can appear twice

## Deposit

```cairo
fn receive(ref self: ContractState, amount: u256) {
    let caller  = get_caller_address();
    let token   = IERC20Dispatcher { contract_address: self.token.read() };
    let success = token.transfer_from(caller, get_contract_address(), amount);
    assert(success, Errors::TRANSFER_FAILED);
}
```

Anyone can deposit tokens into the contract.

Before calling:

```cairo
token.approve(contract_address, amount)
```

Then:

```cairo
payment_splitter.receive(amount)
```

The contract will hold the tokens and distribute them proportionally when released.

## Release

```cairo
fn release(ref self: ContractState, account: ContractAddress) {
    assert(self.shares.read(account) > 0, Errors::NO_SHARES);
    let payment = Self::releasable(@self, account);
    assert(payment > 0, Errors::NOT_DUE);
    // update totals before transfer — CEI pattern
    self.total_released.write(self.total_released.read() + payment);
    self.released.write(account, self.released.read(account) + payment);
    let token   = IERC20Dispatcher { contract_address: self.token.read() };
    let success = token.transfer(account, payment);
    assert(success, Errors::TRANSFER_FAILED);
}
```

Transfers the owed amount to a specific payee.

Requirements:

- `account` must have shares
- `account` must have a pending payment

Behavior:

1. Calculate how much the payee is owed
2. Update internal accounting
3. Transfer tokens to the payee

Anyone can call this function — not just the payee.

## Releasable Amount

```cairo
fn releasable(self: @ContractState, account: ContractAddress) -> u256 {
    let token = IERC20Dispatcher { contract_address: self.token.read() };
    let balance = token.balance_of(get_contract_address());
    let total_received = balance + Self::total_released(self);
    self._pending_payment(account, total_received, self.released.read(account))
}
```

Returns how many tokens a payee can currently withdraw.

This does **not transfer tokens**, it only calculates the amount.
