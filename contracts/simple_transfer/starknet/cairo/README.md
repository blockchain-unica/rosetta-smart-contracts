# SimpleTransfer (Cairo / Starknet)

> On Starknet, ETH is an ERC20 token. This contract works with any ERC20 token (e.g. Starknet ETH).

## The flow

At deployment:

- The deployer becomes the **owner**
- A **recipient** address is set
- An ERC20 **token address** is set (e.g. Starknet ETH)

After deployment:

- `deposit(amount)`
  - Only callable by **owner**
  - Transfers `amount` tokens from owner to contract
  - Requires prior ERC20 `approve`

- `withdraw(amount)`
  - Only callable by **recipient**
  - Transfers `amount` tokens from contract to recipient
  - `amount` must be ≤ contract token balance

## Constructor

```py
cairo
constructor(
    recipient: ContractAddress,
    token: ContractAddress
)
```

Parameters:

- recipient — address allowed to withdraw
- token — ERC20 token used for deposits/withdrawals

Called once at deployment. The deployer automatically becomes the owner.

## Deposit

```py
fn deposit(ref self: ContractState, amount: u256) {
    let caller = get_caller_address();
    assert(caller == self.owner.read(), Errors::ONLY_OWNER);

    let token = IERC20Dispatcher { contract_address: self.token.read() };
    let success = token.transfer_from(caller, get_contract_address(), amount);
    assert(success, Errors::TRANSFER_FAILED);
}
```

- Guards that only the owner can call it
- Uses transfer_from to pull tokens from the owner's wallet into the contract — this is why the owner must call approve(contract_address, amount) on the token before calling deposit

## Withdraw

```py
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

- Guards that only the recipient can call it
- Checks the contract actually holds enough tokens before attempting the transfer
- Uses `transfer` to push tokens out from the contract to the recipient — no `approve` needed here since the contract is spending its own tokens
