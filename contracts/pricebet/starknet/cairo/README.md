# PriceBet & Oracle

| Contract   | Role                                                        |
| ---------- | ----------------------------------------------------------- |
| `Oracle`   | Stores and exposes a fixed exchange rate — read by PriceBet |
| `PriceBet` | Manages the bet lifecycle — join, win, timeout              |

## Oracle Contract

### Storage vars

```cairo
struct Storage {
    exchange_rate: u256,
}
```

| Field           | Type   | Description                                                  |
| --------------- | ------ | ------------------------------------------------------------ |
| `exchange_rate` | `u256` | Exchange rate value set at deployment — fixed, never updated |

### Constructor

```cairo
fn constructor(ref self: ContractState, initial_rate: u256) {
    self.exchange_rate.write(initial_rate);
}
```

Sets the exchange rate. This value never changes after deployment.

### Get exchange rate

```cairo
fn get_exchange_rate(self: @ContractState) -> u256 {
    self.exchange_rate.read()
}
```

Returns the stored exchange rate.

- Read-only — no caller restriction
- Called by `PriceBet.win()` to evaluate the bet outcome

```cairo
let rate = oracle.get_exchange_rate();
```

---

## PriceBet Contract

### Storage vars

```cairo
struct Storage {
    owner: ContractAddress,
    player: ContractAddress,       // zero address means no player yet
    oracle: ContractAddress,
    token: ContractAddress,
    initial_pot: u256,
    deadline_block: u64,
    exchange_rate: u256,
}
```

| Field            | Type              | Description                                                             |
| ---------------- | ----------------- | ----------------------------------------------------------------------- |
| `owner`          | `ContractAddress` | Deployer — deposits the initial pot and reclaims on timeout             |
| `player`         | `ContractAddress` | Address that joined the bet — zero until `join()` is called             |
| `oracle`         | `ContractAddress` | Oracle contract address — queried for the current exchange rate         |
| `token`          | `ContractAddress` | ERC20 token used for the bet                                            |
| `initial_pot`    | `u256`            | Amount each party must deposit — player must match exactly              |
| `deadline_block` | `u64`             | Absolute block number deadline — computed as `current_block + deadline` |
| `exchange_rate`  | `u256`            | Target rate the player must meet or beat to win                         |

### Constructor

```cairo
fn constructor(
    ref self: ContractState,
    oracle: ContractAddress,
    deadline: u64,
    exchange_rate: u256,
    initial_pot: u256,
    token: ContractAddress,
) {
    let owner         = get_caller_address();
    let current_block = get_block_info().unbox().block_number;
    self.owner.write(owner);
    self.oracle.write(oracle);
    self.token.write(token);
    self.initial_pot.write(initial_pot);
    self.deadline_block.write(current_block + deadline);
    self.exchange_rate.write(exchange_rate);
    let token_dispatcher = IERC20Dispatcher { contract_address: token };
    let success = token_dispatcher.transfer_from(owner, get_contract_address(), initial_pot);
    assert(success, Errors::TRANSFER_FAILED);
}
```

- Caller becomes the `owner`
- `deadline_block = current_block + deadline`
- Transfers `initial_pot` tokens from owner to the contract immediately
- Owner must have approved the contract to spend `initial_pot` before deploying

---

### Join

```cairo
fn join(ref self: ContractState, amount: u256) {
    let caller = get_caller_address();
    assert(
        self.player.read() == starknet::contract_address_const::<0>(),
        Errors::ALREADY_JOINED
    );
    assert(amount == self.initial_pot.read(), Errors::WRONG_AMOUNT);
    let token  = IERC20Dispatcher { contract_address: self.token.read() };
    // player must approve(contract, initial_pot) before calling join
    let success = token.transfer_from(caller, get_contract_address(), amount);
    assert(success, Errors::TRANSFER_FAILED);
    self.player.write(caller);
}
```

Player joins the bet by depositing the same amount as the owner.

- Only one player can join — reverts if a player has already joined
- `amount` must equal `initial_pot` exactly
- Transfers `amount` from caller to the contract
- Caller must have approved the contract to spend `amount` beforehand

```cairo
contract.join(initial_pot);
// → player deposits initial_pot tokens
// → pot is now 2 × initial_pot
```

---

### Win

```cairo
fn win(ref self: ContractState) {
    let oracle_rate = IOracleDispatcher { contract_address: self.oracle.read() }
        .get_exchange_rate();
    let caller        = get_caller_address();
    let current_block = get_block_info().unbox().block_number;
    assert(current_block < self.deadline_block.read(), Errors::DEADLINE_EXPIRED);
    assert(caller == self.player.read(), Errors::ONLY_PLAYER);

    assert(oracle_rate >= self.exchange_rate.read(), Errors::YOU_LOST);
    let token   = IERC20Dispatcher { contract_address: self.token.read() };
    let balance = token.balance_of(get_contract_address());
    let success = token.transfer(self.player.read(), balance);
    assert(success, Errors::TRANSFER_FAILED);
}
```

Player claims the full pot if the oracle rate meets the target.

- Only callable by the `player`
- Must be called **before** `deadline_block` (strict)
- Reads current rate from oracle — reverts if `oracle_rate < exchange_rate`
- Transfers the full contract balance to the player on success

```cairo
contract.win();
// → oracle_rate >= exchange_rate
// → full pot (2 × initial_pot) transferred to player
```

---

### Timeout

```cairo
fn timeout(ref self: ContractState) {
    let current_block = get_block_info().unbox().block_number;
    assert(current_block >= self.deadline_block.read(), Errors::DEADLINE_NOT_EXPIRED);
    let token   = IERC20Dispatcher { contract_address: self.token.read() };
    let balance = token.balance_of(get_contract_address());
    let success = token.transfer(self.owner.read(), balance);
    assert(success, Errors::TRANSFER_FAILED);
}
```

Owner reclaims the full pot after the deadline.

- Callable by **anyone** — no caller restriction
- Requires `current_block >= deadline_block`
- Transfers the full contract balance to the owner
- Works whether or not a player joined

```cairo
contract.timeout();
// → deadline passed
// → full balance transferred to owner
```
