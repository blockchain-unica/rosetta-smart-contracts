# Auction

## States

The contract defines three states:

```cairo
const WAIT_START: u8   = 0;
const WAIT_CLOSING: u8 = 1;
const CLOSED: u8       = 2;
```

| State          | Meaning                            |
| -------------- | ---------------------------------- |
| `WAIT_START`   | Auction deployed but not started   |
| `WAIT_CLOSING` | Auction running and accepting bids |
| `CLOSED`       | Auction finished                   |

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

```py
    fn start(duration: u64)
```

Callable only by the **seller**.

Actions:

- Sets the auction deadline:

```py
    end_block = current_block + duration
```

- Changes state to `WAIT_CLOSING`

## Bid

```py
    fn bid(amount: u256)
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
    fn withdraw()
```

Allows bidders to withdraw funds if they were **outbid**.

Conditions:

- Caller must have a positive withdrawable balance.

Actions:

- Transfers stored bid back to the bidder.

---

## End

```py
    fn end()
```

Callable only by the **seller**.

Requirements:

- Auction must be active.
- Current block must be **greater or equal to end_block**.

Actions:

- Sets state to `CLOSED`
- Transfers the **highest bid** to the seller.
