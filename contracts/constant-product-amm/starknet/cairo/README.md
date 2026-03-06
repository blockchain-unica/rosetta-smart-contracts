# Constant-product AMM

## Storage variables

```cairo
struct Storage {
    t0: ContractAddress,
    t1: ContractAddress,
    r0: u256,
    r1: u256,
    ever_deposited: bool,
    supply: u256,
    minted: Map<ContractAddress, u256>,
}
```

| Field            | Type                         | Description                                                       |
| ---------------- | ---------------------------- | ----------------------------------------------------------------- |
| `t0`             | `ContractAddress`            | Address of the first ERC20 token in the pair                      |
| `t1`             | `ContractAddress`            | Address of the second ERC20 token in the pair                     |
| `r0`             | `u256`                       | Reserve of `t0` held by the pool                                  |
| `r1`             | `u256`                       | Reserve of `t1` held by the pool                                  |
| `ever_deposited` | `bool`                       | Whether a deposit has ever been made — guards first-deposit logic |
| `supply`         | `u256`                       | Total supply of liquidity tokens outstanding                      |
| `minted`         | `Map<ContractAddress, u256>` | Liquidity tokens minted per address                               |

## Constructor

```cairo
fn constructor(
        ref self: ContractState,
        t0: ContractAddress,
        t1: ContractAddress,
) {
    self.t0.write(t0);
    self.t1.write(t1);
}
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
fn deposit(ref self: ContractState, x0: u256, x1: u256) {
    assert(x0 > 0 && x1 > 0, Errors::ZERO_AMOUNT);
    let caller     = get_caller_address();
    let this       = get_contract_address();
    let t0         = IERC20Dispatcher { contract_address: self.t0.read() };
    let t1         = IERC20Dispatcher { contract_address: self.t1.read() };

    // pull tokens from sender
    let s0 = t0.transfer_from(caller, this, x0);
    assert(s0, Errors::TRANSFER_FAILED);
    let s1 = t1.transfer_from(caller, this, x1);
    assert(s1, Errors::TRANSFER_FAILED);
    let to_mint: u256 = if self.ever_deposited.read() {
        let r0 = self.r0.read();
        let r1 = self.r1.read();
        assert(r0 * x1 == r1 * x0, Errors::WRONG_RATIO);
        (x0 * self.supply.read()) / r0
    } else {
        self.ever_deposited.write(true);
        x0
    };

    assert(to_mint > 0, Errors::ZERO_MINT);
    self.minted.write(caller, self.minted.read(caller) + to_mint);
    self.supply.write(self.supply.read() + to_mint);
    self.r0.write(self.r0.read() + x0);
    self.r1.write(self.r1.read() + x1);
    assert(t0.balance_of(this) == self.r0.read(), Errors::BALANCE_MISMATCH);
    assert(t1.balance_of(this) == self.r1.read(), Errors::BALANCE_MISMATCH);
}

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
/// Redeem x liquidity tokens for proportional amounts of t0 and t1.
fn redeem(ref self: ContractState, x: u256) {
    let caller = get_caller_address();
    assert(self.minted.read(caller) >= x, Errors::INSUFFICIENT_MINTED);
    assert(x > 0, Errors::ZERO_X);
    assert(x < self.supply.read(), Errors::SUPPLY_EXCEEDED);

    let supply = self.supply.read();
    let r0     = self.r0.read();
    let r1     = self.r1.read();

    let x0 = (x * r0) / supply;
    let x1 = (x * r1) / supply;
    let this = get_contract_address();
    let t0   = IERC20Dispatcher { contract_address: self.t0.read() };
    let t1   = IERC20Dispatcher { contract_address: self.t1.read() };

    // in Cairo we use transfer (contract is the sender)
    let s0 = t0.transfer(caller, x0);
    assert(s0, Errors::TRANSFER_FAILED);
    let s1 = t1.transfer(caller, x1);
    assert(s1, Errors::TRANSFER_FAILED);
    self.r0.write(r0 - x0);
    self.r1.write(r1 - x1);
    self.supply.write(supply - x);
    self.minted.write(caller, self.minted.read(caller) - x);
    assert(t0.balance_of(this) == self.r0.read(), Errors::BALANCE_MISMATCH);
    assert(t1.balance_of(this) == self.r1.read(), Errors::BALANCE_MISMATCH);
}
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
fn swap(ref self: ContractState, t: ContractAddress, x_in: u256, x_out_min: u256){
    let t0_addr = self.t0.read();
    let t1_addr = self.t1.read();
    assert(t == t0_addr || t == t1_addr, Errors::INVALID_TOKEN);
    assert(x_in > 0, Errors::ZERO_AMOUNT);
    let caller   = get_caller_address();
    let this     = get_contract_address();
    let is_t0    = t == t0_addr;
    let (t_in_addr, t_out_addr, r_in, r_out) = if is_t0 {
        (t0_addr, t1_addr, self.r0.read(), self.r1.read())
    } else {
        (t1_addr, t0_addr, self.r1.read(), self.r0.read())
    };
    let t_in  = IERC20Dispatcher { contract_address: t_in_addr };
    let t_out = IERC20Dispatcher { contract_address: t_out_addr };

    // pull input tokens
    let s_in = t_in.transfer_from(caller, this, x_in);
    assert(s_in, Errors::TRANSFER_FAILED);

    let x_out = x_in * r_out / (r_in + x_in);
    assert(x_out >= x_out_min, Errors::SLIPPAGE);

    // push output tokens
    let s_out = t_out.transfer(caller, x_out);
    assert(s_out, Errors::TRANSFER_FAILED);
    if is_t0 {
        self.r0.write(self.r0.read() + x_in);
        self.r1.write(self.r1.read() - x_out);
    } else {
        self.r0.write(self.r0.read() - x_out);
        self.r1.write(self.r1.read() + x_in);
    }
    let t0 = IERC20Dispatcher { contract_address: t0_addr };
    let t1 = IERC20Dispatcher { contract_address: t1_addr };
    assert(t0.balance_of(this) == self.r0.read(), Errors::BALANCE_MISMATCH);
    assert(t1.balance_of(this) == self.r1.read(), Errors::BALANCE_MISMATCH);
}
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
