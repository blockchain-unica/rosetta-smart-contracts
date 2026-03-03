# Crowdfund

## Constructor

```cairo
#[constructor]
fn constructor(
    ref self: ContractState,
    receiver: ContractAddress,
    end_block: u64,
    goal: u256,
    token: ContractAddress,
)
```

Parameters:

| Parameter   | Description                                        |
| ----------- | -------------------------------------------------- |
| `receiver`  | Address that will receive funds if goal is reached |
| `end_block` | Block number when the campaign ends                |
| `goal`      | Minimum funding goal                               |
| `token`     | ERC20 token used for donations                     |

Deployment effects:

- The crowdfunding campaign is created.
- Donations are accepted until `end_block`.

## Donate

```cairo
fn donate(amount: u256)
```

Requirements:

- Current block must be **before or equal to `end_block`**

Actions:

- Transfers `amount` of tokens from the donor to the contract
- Updates the donor’s contribution in storage

Donors must approve the contract before donating:

```py
    token.approve(crowdfund_address, amount)
    crowdfund.donate(amount)
```

---

## Withdraw

```py
fn withdraw()
```

Callable only by the **receiver**.

Requirements:

- Current block must be **greater than or equal to `end_block`**
- Contract balance must be **greater than or equal to the funding goal**

Actions:

- Transfers the entire contract balance to the receiver

## Reclaim

```py
fn reclaim()
```

Allows donors to reclaim their contributions if the campaign fails.

Requirements:

- Current block must be **greater than or equal to `end_block`**
- Contract balance must be **less than the funding goal**
- Caller must have donated previously

Actions:

- Returns the donor’s contribution
- Resets their stored donation to zero
