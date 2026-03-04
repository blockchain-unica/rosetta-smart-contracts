# Constant-product AMM

## Constructor

```cairo
constructor(
    ref self: ContractState,
    t0: ContractAddress,
    t1: ContractAddress,
)
```

Parameters:

| Parameter | Description                    |
| --------- | ------------------------------ |
| `t0`      | ERC20 token address for token0 |
| `t1`      | ERC20 token address for token1 |

After deployment the pool starts **empty**.  
Liquidity must be added through the `deposit` function.

## First Deposit

```cairo
deposit(x0: u256, x1: u256)
```

Adds liquidity to the pool.

Requirements:

- `x0 > 0`
- `x1 > 0`

The first liquidity provider initializes the pool.

```cairo
minted_liquidity = x0
```

Deposits must maintain the pool price:

```
r0 * x1 == r1 * x0
```

Liquidity minted:

```
minted = (x0 * total_supply) / r0
```

### Token Transfer

The function pulls tokens using:

```
transfer_from(user, contract, amount)
```

So users must approve the contract first.

## Redeeming

```cairo
redeem(x: u256)
```

Redeems liquidity tokens and withdraws the corresponding share of the reserves.

Requirements:

- User must own at least `x` liquidity tokens
- `x > 0`
- `x < total_supply`

Withdrawal amounts:

```
x0 = (x * r0) / supply
x1 = (x * r1) / supply
```

The tokens are transferred back to the user.

---

## Swapping

```cairo
swap(t: ContractAddress, x_in: u256, x_out_min: u256)
```

Swaps one token for the other.

Parameters:

| Parameter   | Description                                 |
| ----------- | ------------------------------------------- |
| `t`         | Address of the token being sent to the pool |
| `x_in`      | Amount of input tokens                      |
| `x_out_min` | Minimum acceptable output amount            |

```cairo
x_out = (x_in * r_out) / (r_in + x_in)
```

This follows the **constant product pricing rule**.

The transaction fails if:

```
x_out < x_out_min
```
