# PaymentSplitter

## Constructor

```cairo
#[constructor]
fn constructor(
    ref self: ContractState,
    payees: Array<ContractAddress>,
    shares: Array<u256>,
    token: ContractAddress,
)
```

Parameters:

| Parameter | Description                         |
| --------- | ----------------------------------- |
| `payees`  | List of payee addresses             |
| `shares`  | Corresponding shares for each payee |
| `token`   | ERC20 token used for payments       |

Requirements:

- `payees.length == shares.length`
- At least one payee must exist

Example:

| Payee   | Shares |
| ------- | ------ |
| Alice   | 50     |
| Bob     | 30     |
| Charlie | 20     |

Total shares = **100**

## Deposit

```cairo
fn receive(amount: u256)
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
fn release(account: ContractAddress)
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

---

# Payment Calculation

Payments are distributed proportionally using this formula:

```cairo
payment = (total_received * account_shares / total_shares) - already_released
```

Where:

```cairo
total_received = contract_balance + total_released
```

This ensures:

- accurate accounting
- no double payments
- proportional distribution

# Releasable Amount

```cairo
fn releasable(account: ContractAddress) -> u256
```

Returns how many tokens a payee can currently withdraw.

This does **not transfer tokens**, it only calculates the amount.
