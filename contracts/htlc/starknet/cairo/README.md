# HTLC (Hash Time Locked Contract) – Cairo / Starknet

## Storage variables

```cairo
struct Storage {
    owner: ContractAddress,       // committer
    receiver: ContractAddress,    // gets funds if timeout
    token: ContractAddress,       // ERC20 collateral token
    hash: u256,                // Poseidon hash of the secret
    reveal_timeout: u64,          // block number deadline
}
```

| Field            | Type              | Description                                                          |
| ---------------- | ----------------- | -------------------------------------------------------------------- |
| `owner`          | `ContractAddress` | Caller at deployment — the only one who can reveal the secret        |
| `receiver`       | `ContractAddress` | Receives all funds if the deadline passes without a reveal           |
| `token`          | `ContractAddress` | ERC20 token used as collateral                                       |
| `hash`           | `u256`            | `keccak256` hash of the secret — provided at deployment              |
| `reveal_timeout` | `u64`             | Absolute block number deadline — computed as `current_block + delay` |

## Constructor

```cairo
fn constructor(
    ref self: ContractState,
    receiver: ContractAddress,
    hash: u256,
    delay: u64,
    amount: u256,
    token: ContractAddress,
) {
    assert(amount >= MIN_DEPOSIT, Errors::BELOW_MIN_DEPOSIT);
    let owner = get_caller_address();
    let current_block = get_block_info().unbox().block_number;
    self.owner.write(owner);
    self.receiver.write(receiver);
    self.token.write(token);
    self.hash.write(hash);
    self.reveal_timeout.write(current_block + delay);
    // Lock collateral immediately at deploy time
    let token_dispatcher = IERC20Dispatcher { contract_address: token };
    let success = token_dispatcher.transfer_from(owner, get_contract_address(), amount);
    assert(success, Errors::TRANSFER_FAILED);
}
```

- Constructor immediately locks collateral.
- Owner must call `approve()` before deploying.

1. The deployer becomes the **owner**.
2. The owner provides:
   - `receiver`
   - `hash` = `keccak256(secret_bytes)`
   - `delay` (in blocks)
   - `amount` (collateral)
   - `token` (ERC20 contract address)
3. The contract:
   - Requires `amount >= MIN_DEPOSIT`
   - Stores parameters in storage
   - Computes `reveal_timeout = current_block + delay`
   - Pulls collateral using `transfer_from`

---

### Minimum Deposit

```cairo
const MIN_DEPOSIT: u256 = 1_000_000_000_000_000_000_u256;
```

Equivalent to:

```solidity
require(msg.value >= 1 ether);
```

## Reveal

```cairo
fn reveal(ref self: ContractState, secret: felt252)
    let caller = get_caller_address();
    assert(caller == self.owner.read(), Errors::ONLY_OWNER);

    // hash the secret and compare
    let computed = poseidon_hash_span(array![secret].span());
    assert(computed == self.hash.read(), Errors::INVALID_SECRET);

    let token = IERC20Dispatcher { contract_address: self.token.read() };
    let balance = token.balance_of(get_contract_address());

    let success = token.transfer(self.owner.read(), balance);
    assert(success, Errors::TRANSFER_FAILED);
```

Conditions:

- Caller must be the **owner**
- `keccak256(secret_bytes)` must equal the stored `hash`

Behavior:

- Transfers the **entire** contract token balance to the owner
- Reverts if the caller is not owner or the secret does not match

## Timeout

```cairo
fn timeout(ref self: ContractState) {
    let current_block = get_block_info().unbox().block_number;
    assert(current_block > self.reveal_timeout.read(), Errors::DEADLINE_NOT_REACHED);

    let token = IERC20Dispatcher { contract_address: self.token.read() };
    let balance = token.balance_of(get_contract_address());

    let success = token.transfer(self.receiver.read(), balance);
    assert(success, Errors::TRANSFER_FAILED);
}
```

Conditions:

- `block_number > reveal_timeout`

Behavior:

- Transfers entire balance to receiver
- Reverts if deadline not reached
