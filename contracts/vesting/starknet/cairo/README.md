# Vesting

## Storage vars

```cairo
struct Storage {
    beneficiary: ContractAddress,
    start: u64,       // block number from which vesting begins
    duration: u64,    // duration in blocks
    released: u256,   // total already released to beneficiary
    token: ContractAddress,
}
```

| Field         | Type              | Description                                          |
| ------------- | ----------------- | ---------------------------------------------------- |
| `beneficiary` | `ContractAddress` | Address that receives vested tokens — cannot be zero |
| `start`       | `u64`             | Block number at which vesting begins                 |
| `duration`    | `u64`             | Number of blocks over which tokens vest fully        |
| `released`    | `u256`            | Cumulative amount already claimed by the beneficiary |
| `token`       | `ContractAddress` | ERC20 token being vested                             |

## Events

### `Released`

Emitted after every successful `release()` call.

| Field         | Type              | Indexed | Description                        |
| ------------- | ----------------- | ------- | ---------------------------------- |
| `beneficiary` | `ContractAddress` | yes     | Address that received the tokens   |
| `amount`      | `u256`            | no      | Amount transferred in this release |

## Constructor

```cairo
fn constructor(
    ref self: ContractState,
    beneficiary: ContractAddress,
    start: u64,
    duration: u64,
    initial_amount: u256,
    token: ContractAddress,
) {
    assert(
        beneficiary != starknet::contract_address_const::<0>(),
        Errors::ZERO_BENEFICIARY
    );
    self.beneficiary.write(beneficiary);
    self.start.write(start);
    self.duration.write(duration);
    self.token.write(token);
    // deposit initial balance at creation — deployer must approve first
    if initial_amount > 0 {
        let token_dispatcher = IERC20Dispatcher { contract_address: token };
        let success = token_dispatcher.transfer_from(
            get_caller_address(),
            get_contract_address(),
            initial_amount
        );
        assert(success, Errors::TRANSFER_FAILED);
    }
}
```

- Deployer must have approved the contract for `initial_amount` tokens before deploying
- If `initial_amount` is zero no deposit is made — tokens can be sent later via ERC20 transfer
- `start` is an **absolute** block number — deployer must compute `current_block + offset` off-chain if needed

## Release

```cairo
fn release(ref self: ContractState) {
    assert(get_caller_address() == self.beneficiary.read(), Errors::ONLY_BENEFICIARY);
    let amount = Self::releasable(@self);
    assert(amount > 0, Errors::NOTHING_TO_RELEASE);
    // update released BEFORE transfer — CEI pattern
    self.released.write(self.released.read() + amount);
    let token   = IERC20Dispatcher { contract_address: self.token.read() };
    let success = token.transfer(self.beneficiary.read(), amount);
    assert(success, Errors::TRANSFER_FAILED);
    self.emit(Released { beneficiary: self.beneficiary.read(), amount });
}
```

Callable only by the **beneficiary**.

Actions:

1. Calculates the amount currently releasable.
2. Transfers that amount to the beneficiary.
3. Updates the released amount.
4. Emits a `Released` event.

## Releasable Amount

```cairo
fn releasable(self: @ContractState) -> u256 {
    Self::vested_amount(self) - self.released.read()
}
```

Returns the number of tokens currently available for withdrawal.

```py
releasable = vested_amount - released
```

## Total Vested Amount

```cairo
fn vested_amount(self: @ContractState) -> u256 {
    let token    = IERC20Dispatcher { contract_address: self.token.read() };
    let balance  = token.balance_of(get_contract_address());
    let total    = balance + self.released.read();
    // mirrors: _vestingSchedule(address(this).balance + _released, timestamp)
    let current_block = get_block_info().unbox().block_number;
    let start         = self.start.read();
    let duration      = self.duration.read();
    if current_block < start {
        0
    } else if current_block > start + duration {
        total
    } else {
        let elapsed: u256 = (current_block - start).into();
        (total * elapsed) / duration.into()
    }
}
```

Returns the total amount vested so far according to the linear schedule.

- Read-only — no state changes
- Uses `block_number` as the time reference
- `total = current_balance + released` — accounts for tokens added after deployment
