# HTLC (Hash Time Locked Contract) – Cairo / Starknet

## Constructor

```py
#[constructor]
fn constructor(
    ref self: ContractState,
    receiver: ContractAddress,
    hash: u256,
    delay: u64,
    amount: u256,
    token: ContractAddress,
)
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

```py
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

```py
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
