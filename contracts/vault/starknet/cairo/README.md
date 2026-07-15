# Vault Contract

## States

The contract defines two states:

```cairo
    const IDLE: u8 = 0;
    const REQ: u8  = 1;
```

| State  | Meaning                                                          |
| ------ | ---------------------------------------------------------------- |
| `IDLE` | No withdrawal request is pending                                 |
| `REQ`  | A withdrawal request is active and waiting for the delay to pass |

## Storage

```cairo
struct Storage {
    owner: ContractAddress,
    recovery: ContractAddress,
    token: ContractAddress,
    wait_time: u64,
    state: u8,
    receiver: ContractAddress,
    request_block: u64,
    amount: u256,
}
```

| Field           | Type              | Description                                                          |
| --------------- | ----------------- | -------------------------------------------------------------------- |
| `owner`         | `ContractAddress` | Deployer — issues and finalizes withdrawal requests                  |
| `recovery`      | `ContractAddress` | Trusted backup key — can cancel pending withdrawals                  |
| `token`         | `ContractAddress` | ERC20 token held by the vault                                        |
| `wait_time`     | `u64`             | Number of blocks that must pass before a withdrawal can be finalized |
| `state`         | `State`           | Current vault state — `Idle` or `Req`                                |
| `receiver`      | `ContractAddress` | Destination address for the pending withdrawal                       |
| `request_block` | `u64`             | Block number at which the current withdrawal was requested           |
| `amount`        | `u256`            | Token amount pending in the current withdrawal request               |

## Constructor

```cairo
fn constructor(
    ref self: ContractState,
    recovery: ContractAddress,
    wait_time: u64,
    token: ContractAddress,
) {
    self.owner.write(get_caller_address());
    self.recovery.write(recovery);
    self.wait_time.write(wait_time);
    self.token.write(token);
    self.state.write(IDLE);
}
```

- Caller becomes the `owner`
- Initial state is `Idle`
- Initial deposit is made separately via `receive()`

## Receive

```cairo
fn receive(ref self: ContractState, amount: u256) {
    let caller  = get_caller_address();
    let token   = IERC20Dispatcher { contract_address: self.token.read() };
    let success = token.transfer_from(caller, get_contract_address(), amount);
    assert(success, Errors::TRANSFER_FAILED);
}
```

Anyone can deposit tokens into the vault.

Requirements:

- Caller must approve the vault contract to transfer tokens.

Example:

```py
token.approve(vault_address, amount)
vault.receive(amount)
```

Actions:

- Transfers tokens from caller to the vault.

## Withdraw

```cairo
fn withdraw(ref self: ContractState, receiver: ContractAddress, amount: u256) {
    assert(get_caller_address() == self.owner.read(), Errors::ONLY_OWNER);
    assert(self.state.read() == State::Idle, Errors::NOT_IDLE);
    let token   = IERC20Dispatcher { contract_address: self.token.read() };
    let balance = token.balance_of(get_contract_address());
    assert(amount <= balance, Errors::INSUFFICIENT_BALANCE);
    let current_block = get_block_info().unbox().block_number;
    self.request_block.write(current_block);
    self.amount.write(amount);
    self.receiver.write(receiver);
    self.state.write(State::Req);
}
```

Callable only by the **owner**.

Requirements:

- Vault must be in `IDLE` state.
- Vault must have sufficient balance.

Actions:

- Records:
  - withdrawal amount
  - receiver address
  - current block number
- Changes state from `IDLE` → `REQ`.

This begins the **time-lock waiting period**.

## Finalize

```cairo
fn finalize(ref self: ContractState) {
    assert(get_caller_address() == self.owner.read(), Errors::ONLY_OWNER);
    assert(self.state.read() == State::Req, Errors::NOT_REQ);
    let current_block = get_block_info().unbox().block_number;
    assert(
        current_block >= self.request_block.read() + self.wait_time.read(),
        Errors::WAIT_NOT_ELAPSED
    );
    self.state.write(State::Idle);
    let amount   = self.amount.read();
    let receiver = self.receiver.read();
    let token    = IERC20Dispatcher { contract_address: self.token.read() };
    let success  = token.transfer(receiver, amount);
    assert(success, Errors::TRANSFER_FAILED);
}
```

Callable only by the **owner**.

Requirements:

- Vault must be in `REQ` state.
- The waiting period must have elapsed:

```py
current_block >= request_block + wait_time
```

Actions:

- Transfers tokens to the requested receiver.
- Resets state to `IDLE`.

## Cancel

```cairo
fn cancel(ref self: ContractState) {
    assert(get_caller_address() == self.recovery.read(), Errors::ONLY_RECOVERY);
    assert(self.state.read() == State::Req, Errors::NOT_REQ);
    self.state.write(State::Idle);
}
```

Callable only by the **recovery key** address.

Requirements:

- Vault must be in `REQ` state.

Actions:

- Cancels the pending withdrawal.
- Returns vault state to `IDLE`.

This mechanism protects funds if the owner account is compromised.
