# Vesting

## Constructor

```cairo
#[constructor]
fn constructor(
    ref self: ContractState,
    beneficiary: ContractAddress,
    start: u64,
    duration: u64,
    initial_amount: u256,
    token: ContractAddress,
)
```

Parameters:

| Parameter        | Description                       |
| ---------------- | --------------------------------- |
| `beneficiary`    | Address receiving vested tokens   |
| `start`          | Block number when vesting starts  |
| `duration`       | Number of blocks for full vesting |
| `initial_amount` | Tokens deposited at deployment    |
| `token`          | ERC20 token used for vesting      |

Deployment behavior:

- The beneficiary and vesting schedule are set.
- If `initial_amount > 0`, the deployer transfers tokens to the contract.
- The deployer must call `approve()` before deployment if tokens are deposited.

Example:

```py
    token.approve(vesting_address, initial_amount)
```

# Vesting

The contract uses **linear vesting**:

- Before `start` → **0 tokens vested**
- Between `start` and `start + duration` → tokens vest gradually
- After `start + duration` → **100% of tokens vested**

Formula used:

```py
vested = total_tokens * elapsed_time / duration
```

Where:

```py
total_tokens = current_balance + already_released
```

## Beneficiary Releases

```cairo
fn release()
```

Callable only by the **beneficiary**.

Actions:

1. Calculates the amount currently releasable.
2. Transfers that amount to the beneficiary.
3. Updates the released amount.
4. Emits a `Released` event.

## Releasable Amount

```cairo
fn releasable() -> u256
```

Returns the number of tokens currently available for withdrawal.

```py
releasable = vested_amount - released
```

## Total Vested Amount

```cairo
fn vested_amount() -> u256
```

Calculates the total tokens that should be vested according to the schedule.
