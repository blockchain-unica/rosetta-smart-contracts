# Auction

## States

The contract defines three states:

```cairo
pub enum State {
    #[default]
    WaitStart,    // auction has not started yet
    WaitClosing,  // auction is running, accepting bids
    Closed,       // auction has ended
}
```

| State         | Meaning                            |
| ------------- | ---------------------------------- |
| `WaitStart`   | Auction deployed but not started   |
| `WaitClosing` | Auction running and accepting bids |
| `Closed`      | Auction finished                   |

## Storage variables

```cairo
struct Storage {
        seller: ContractAddress,
        token: ContractAddress,
        object: felt252,           // notarization string as felt252
        state: u8,
        highest_bidder: ContractAddress,
        highest_bid: u256,
        end_block: u64,
        bids: Map<ContractAddress, u256>,  // mapping of pending withdrawals
    }
```

- seller: address of the auction creator
- token: ERC20 token used for bidding
- object: notarization string identifying the auctioned item
- state: current state of the auction lifecycle
- highest_bidder: address of the current highest bidder
- highest_bid: current highest bid amount
- end_block: block number at which bidding closes
- bids: pending withdrawals for outbid participants

## Constructor

```cairo
#[constructor]
fn constructor(
    ref self: ContractState,
    object: felt252,
    starting_bid: u256,
    token: ContractAddress,
)
```

Parameters:

| Parameter      | Description                                     |
| -------------- | ----------------------------------------------- |
| `object`       | Identifier or description of the auctioned item |
| `starting_bid` | Minimum initial bid                             |
| `token`        | ERC20 token used for payments                   |

Deployment effects:

- The deployer becomes the **seller**
- Initial state is `WAIT_START`
- The auction is not active yet

## Start

```cairo
fn start(ref self: ContractState, duration: u64) {
    assert(get_caller_address() == self.seller.read(), Errors::ONLY_SELLER);
    assert(self.state.read() == State::WaitStart, Errors::ALREADY_STARTED);
    let current_block = get_block_info().unbox().block_number;
    self.end_block.write(current_block + duration);
    self.state.write(State::WaitClosing);
}
```

Callable only by the **seller**.

Actions:

- Sets the auction deadline:

```cair
    end_block = current_block + duration
```

- Changes state to `WAIT_CLOSING`

## Bid

```cairo
fn bid(ref self: ContractState, amount: u256) {
    assert(self.state.read() == State::WaitClosing, Errors::NOT_OPEN);
    let current_block = get_block_info().unbox().block_number;
    assert(current_block < self.end_block.read(), Errors::BIDDING_EXPIRED);
    assert(amount > self.highest_bid.read(), Errors::BID_TOO_LOW);
    let caller = get_caller_address();
    let token  = IERC20Dispatcher { contract_address: self.token.read() };
    // pull the new bid from the caller into the contract
    let success = token.transfer_from(caller, get_contract_address(), amount);
    assert(success, Errors::TRANSFER_FAILED);
    // store previous highest bidder's bid so they can withdraw
    let prev_highest_bidder = self.highest_bidder.read();
    if prev_highest_bidder != starknet::contract_address_const::<0>() {
        let prev_amount = self.highest_bid.read();
        let existing   = self.bids.read(prev_highest_bidder);
        self.bids.write(prev_highest_bidder, existing + prev_amount);
    }
    // if caller had a pending withdrawal, refund it automatically
    let pending = self.bids.read(caller);
    if pending > 0 {
        self.withdraw();
    }
    self.highest_bidder.write(caller);
    self.highest_bid.write(amount);
}
```

Requirements:

- Auction must be **running**
- Current block must be **before end_block**
- Bid must be **greater than current highest bid**

Actions:

1. Transfers the bid amount from the bidder to the contract.
2. Previous highest bidder’s amount is stored for withdrawal.
3. If the caller had pending withdrawals, they are refunded automatically.
4. Updates:
   - `highest_bidder`
   - `highest_bid`

Bidder must call:

```py
    token.approve(auction_address, amount)
```

before bidding.

## Withdraw

```py
fn withdraw(ref self: ContractState) {
    assert(self.state.read() != State::WaitStart, Errors::NOT_STARTED);
    let caller = get_caller_address();
    let bal    = self.bids.read(caller);
    assert(bal > 0, Errors::NOTHING_TO_WITHDRAW);
    self.bids.write(caller, 0);
    let token   = IERC20Dispatcher { contract_address: self.token.read() };
    let success = token.transfer(caller, bal);
    assert(success, Errors::TRANSFER_FAILED);
}
```

Allows bidders to withdraw funds if they were **outbid**.

Conditions:

- Caller must have a positive withdrawable balance.

Actions:

- Transfers stored bid back to the bidder.

---

## End

```cairo
fn end(ref self: ContractState) {
    assert(get_caller_address() == self.seller.read(), Errors::ONLY_SELLER);
    assert(self.state.read() == State::WaitClosing, Errors::NOT_STARTED);
    let current_block = get_block_info().unbox().block_number;
    assert(current_block >= self.end_block.read(), Errors::AUCTION_NOT_ENDED);
    self.state.write(State::Closed);
    let highest_bid    = self.highest_bid.read();
    let token          = IERC20Dispatcher { contract_address: self.token.read() };
    let success        = token.transfer(self.seller.read(), highest_bid);
    assert(success, Errors::TRANSFER_FAILED);
}
```

Callable only by the **seller**.

Requirements:

- Auction must be active.
- Current block must be **greater or equal to end_block**.

Actions:

- Sets state to `CLOSED`
- Transfers the **highest bid** to the seller.
