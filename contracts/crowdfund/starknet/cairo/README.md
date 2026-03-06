# Crowdfund

## Storage variables

```cairo
struct Storage {
        receiver: ContractAddress,
        goal: u256,
        end_block: u64,
        token: ContractAddress,
        donors: Map<ContractAddress, u256>,
}
```

| Field       | Type                         | Description                                                    |
| ----------- | ---------------------------- | -------------------------------------------------------------- |
| `receiver`  | `ContractAddress`            | Address that can withdraw funds if the goal is met             |
| `goal`      | `u256`                       | Target donation amount in ERC20 tokens                         |
| `end_block` | `u64`                        | Absolute block number after which the campaign closes          |
| `token`     | `ContractAddress`            | ERC20 token used for donations                                 |
| `donors`    | `Map<ContractAddress, u256>` | Amount donated per address — used for reclaims if goal not met |

## Constructor

```cairo
#[constructor]
fn constructor(
    ref self: ContractState,
    receiver: ContractAddress,          // who receives the funds on success
    end_block: u64,                     // absolute block number — campaign closes at this block
    goal: u256,                         // minimum token amount to consider campaign successful
    token: ContractAddress,             // ERC20 token address
){
    self.receiver.write(receiver);
    self.end_block.write(end_block);
    self.goal.write(goal);
    self.token.write(token);
}
```

Deployment effects:

- The crowdfunding campaign is created.
- Donations are accepted until `end_block`.

## Donate

```cairo
fn donate(ref self: ContractState, amount: u256) {
    let current_block = get_block_info().unbox().block_number;
    assert(current_block <= self.end_block.read(), Errors::DEADLINE_PASSED);
    let caller  = get_caller_address();
    let token   = IERC20Dispatcher { contract_address: self.token.read() };
    let success = token.transfer_from(caller, get_contract_address(), amount);
    assert(success, Errors::TRANSFER_FAILED);
    let prev = self.donors.read(caller);
    self.donors.write(caller, prev + amount);
}
```

Requirements:

- Current block must be **before or equal to `end_block`**

Actions:

- Transfers `amount` of tokens from the donor to the contract
- Updates the donor’s contribution in storage

Donors must approve the contract before donating:

```cairo
    token.approve(crowdfund_address, amount)
    crowdfund.donate(amount)
```

---

## Withdraw

```cairo
fn withdraw(ref self: ContractState) {
    assert(
        get_caller_address() == self.receiver.read(),
        Errors::ONLY_RECEIVER
    );
    let current_block = get_block_info().unbox().block_number;
    assert(current_block >= self.end_block.read(), Errors::DEADLINE_NOT_REACHED);
    let token   = IERC20Dispatcher { contract_address: self.token.read() };
    let balance = token.balance_of(get_contract_address());
    assert(balance >= self.goal.read(), Errors::GOAL_NOT_REACHED);
    let success = token.transfer(self.receiver.read(), balance);
    assert(success, Errors::TRANSFER_FAILED);
}
```

Callable only by the **receiver**.

Requirements:

- Current block must be **greater than or equal to `end_block`**
- Contract balance must be **greater than or equal to the funding goal**

Actions:

- Transfers the entire contract balance to the receiver

## Reclaim

```cairo
fn reclaim(ref self: ContractState) {
    let current_block = get_block_info().unbox().block_number;
    assert(current_block >= self.end_block.read(), Errors::DEADLINE_NOT_REACHED);
    let token   = IERC20Dispatcher { contract_address: self.token.read() };
    let balance = token.balance_of(get_contract_address());
    assert(balance < self.goal.read(), Errors::GOAL_REACHED);
    let caller = get_caller_address();
    let amount = self.donors.read(caller);
    assert(amount > 0, Errors::NOTHING_TO_RECLAIM);
    self.donors.write(caller, 0);
    let success = token.transfer(caller, amount);
    assert(success, Errors::TRANSFER_FAILED);
}
```

Allows donors to reclaim their contributions if the campaign fails.

Requirements:

- Current block must be **greater than or equal to `end_block`**
- Contract balance must be **less than the funding goal**
- Caller must have donated previously

Actions:

- Returns the donor’s contribution
- Resets their stored donation to zero
