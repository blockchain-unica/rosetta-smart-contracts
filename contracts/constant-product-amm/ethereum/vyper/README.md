# Constant-product AMM in Vyper

## Interface

```py
interface IERC20:
    def transfer(_to : address, _value : uint256) -> bool : nonpayable
    def transferFrom(_from : address, _to : address, _value : uint256) -> bool: nonpayable
    def balanceOf(_to: address) -> uint256: view 
```

This contract interacts with ERC-20 tokens through a minimal interface that exposes the essential functions required for deposits, redemptions, and swaps.

- `transfer(to, value)` — Transfers **value** tokens from the AMM contract to the specified to address.
Used when returning tokens during redemptions or after swaps.

- `transferFrom(from, to, value)` — Moves **value** tokens from a user’s address into the AMM contract.
This is used when users `deposit` liquidity or provide input tokens for a `swap`.
The user must have approved the AMM contract beforehand.

- `balanceOf(owner)` — Returns the number of tokens held by the **owner** address.
This is a standard ERC-20 view function used to verify that the AMM holds correct token balances.
<br>

## State variables

```py
# Token addresses
t0: public(immutable(address))
t1: public(immutable(address))

r0: public(uint256)
r1: public(uint256)

is_first_deposit: bool 
token_supply: public(uint256)
minted: public(HashMap[address, uint256])   # Amount of LP tokens for each user
```

- `is_first_deposit` — A boolean flag indicating whether the pool has already been initialized. The very first deposit sets the initial token ratio and defines the starting price between t0 and t1.
- `r0, r1` — The reserves of token t0 and t1 held inside the liquidity pool. These values are continuously updated during deposits, redemptions, and swaps, and they maintain the constant-product invariant.
- `minted` — A mapping that tracks how many Liquidity Provider (LP) tokens each user owns. LP tokens represent a user’s proportional share of the pool and are minted or burned during deposits and redemptions.
<br>

## tokenBalance (Helper function)

```py
@view
@internal
def tokenBalance(token: address, user: address) -> uint256:
    result: Bytes[32] = raw_call(
        token,
        concat(
            method_id("balanceOf(address)"),
            convert(user, bytes32),
        ),
        max_outsize=32,
        is_static_call=True,
    )
    return convert(result, uint256)
```

The **tokenBalance** helper function performs a `staticcall` to the given ERC-20 token contract and retrieves the token balance associated with the specified `user`.

> **Note**: A `staticcall` is an EVM-level read-only call that guarantees no state changes can occur during execution. Vyper requires `staticcall` when interacting with external **view** or **pure** functions. A _staticcall_ is implemented by using the `raw_call` syntax, setting the flag `is_static_call=True`.
<br>

## deposit

```py
@external
def deposit(x0: uint256, x1: uint256):
...
```
The **deposit** function allows users to provide liquidity to the AMM by depositing proportional amounts of tokens t0 and t1. In return, the user receives Liquidity Provider (LP) tokens that represent their share of the pool.

The function follows these steps:
- **Validate deposit amounts**
  - Both token amounts must be strictly greater than zero. This prevents empty deposits and ensures meaningful updates to the pool.
 
- **Transfer tokens** from the user to the AMM with:
```py
 # Transfer tokens
    extcall IERC20(t0).transferFrom(msg.sender, self, x0)
    extcall IERC20(t1).transferFrom(msg.sender, self, x1)
```
where `t0, t1` are the addresses of the ERC20 contracts. 

> **Note**: The user must have previously approved the AMM contract to spend these tokens.

- **Determine the amount of LP tokens to mint**
  - The number of LP tokens minted depends on whether the pool is being initialized or already active
  - If it's the very first deposit, the minted amount is equal to the amount of `t0` sent.
  - Otherwise the current pool ratio must be maintained (`r0 / r1  ==  x0 / x1`).
 
- **Update LP accounting and reserves**
  - The user's LP token balance (stored in `minted[msg.sender]`) is increased
  - The total LP supply (token_supply) is updated
  - The pool reserves (r0, r1) are increased by x0 and x1

- **Internal balance consistency checks**
  - To ensure the contract’s internal state remains correct, the function retrieves the actual token balances of t0 and t1 from the ERC20 contracts (`tokenBalance()`). It then verifies that these match the updated reserves r0 and r1.

These consistency checks are also implemented inside the other functions of the AMM contract (**redeem** and **swap**).

> **Note**:
> - `extcall` is Vyper's **safe**, high-level external call helper. It automatically: ABI-encodes arguments, checks return values, reverts on failure, and works only
> with external contract calls. Works for **nonpayable** and **payable** external functions.
<br>

## redeem

```py
@nonreentrant
@external
def redeem(amount: uint256):
...
```

The **redeem** function allows a liquidity provider to burn their LP tokens and withdraw their proportional share of t0 and t1 from the AMM. It is marked as **@external** and **@nonreentrant** to prevent reentrancy attacks during token transfers. The functions only takes one parameter which is the `amount` of LP tokens to withdraw.

The function workflow is the following:
- **Validate redemption conditions**: before withdrawing funds, the function ensures:
  - The redeemed amount is greater than zero.
  - The caller owns at least that many LP tokens.
  - The amount does not exceed the total LP token supply.
 
- **Compute the share of tokens to return**:
```py
x0 = amount * r0 / token_supply
x1 = amount * r1 / token_supply
```
(LP tokens always represent a fixed percentage of the pool.)

- **Transfer the tokens**
```py
 # Transfer tokens to user
    extcall IERC20(t0).transfer(msg.sender, x0)
    extcall IERC20(t1).transfer(msg.sender, x1)
```
- **Update pool state**
- **Verify token balances**
<br>

## swap

```py
@external
def swap(tokenAddress: address, x_in: uint256, x_min_out: uint256):
...
```

This **@external** functions allows to swap the tokens managed by the AMM, following the **constant product formula**. The parameters are:
- `tokenAddress` — the address of the token contract
- `x_in` — the amount of tokens of type `tokenAddress` sent to the contract
- `x_min_out` — the minimum amount of token of the other type expected in return. If `x_min_out` is not available the call reverts.

The function ensures:
- The provided token address matches either `t0` or `t1`
- `x_in` is strictly positive.

When these conditions hold, the AMM contract:
- Determines the direction of the swap
```py
# User sends in t0 and receives t1 tokens 
  if is_t0:
      t_in = t0 
      t_out = t1 
      r_in = self.r0 
      r_out = self.r1 

# User sends in t1 and receives t0 tokens
  else:
      t_in = t1
      t_out = t0
      r_in = self.r1
      r_out = self.r0
```
- Transfers the input tokens to the contract
```py
extcall IERC20(t_in).transferFrom(msg.sender, self, x_in)
```
- Computes the appropriate output of `t_out` token (`x_out: uint256 = x_in * r_out // (r_in + x_in)`)
- Checks the minimum-output requirement (`assert x_out >= x_min_out, "Token request not met"`)
- Transfer ouput tokens
- Updates the pool state
- Verifies the ERC20 balances to match the internal state of the contract

## Differences between the Vyper and Solidity implementations

The implementation is similar to Solidity, but with a few notable differences:
- Vyper requires **more manual handling of low-level details**, such as:
  - Explicit **ABI-encoding** of function arguments
  - Manual **construction of calldata payloads** (using `concat(...)`)
  - Manually specifying when a call is a _staticcall_ (`is_static_call=True`)
  - Manual **decoding** of returned values (e.g., converting `Bytes[32]` to `uint256`)
 
- Solidity allows interface-typed state variables (e.g. `IERC20 public immutable t0`). The compiler knows at compile time:
  - that `t0` supports `transfer`, `balanceOf`, etc.
  - that `t0.transfer(...)` is a valid method call.
- Vyper does not support all this, and the interface is specified at the moment of the call (`extcall IERC20(t0).transferFrom(...)`). 
 
## Note
The ERC20 token implementation is taken from "https://github.com/vyperlang/vyper/blob/master/examples/tokens/ERC20.vy"

