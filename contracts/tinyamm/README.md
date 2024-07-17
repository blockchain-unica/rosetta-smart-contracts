# Constant-product AMM

## Specification

Tiny AMM (Automated Market Maker) allows users to deposit, redeem, and swap a
pair of ERC20 tokens in a decentralized manner. 

The **constructor** takes two addresses, representing the pair of ERC20 tokens to
be used in the exchange (`t0`,`t1`). 

To make a **deposit** `x0` and `x1` must be provided, which are the amount of `t0`
and `t1` tokens, respectively. The specified amounts of tokens are transferred
from the sender's address to the contract. If deposits have been made before,
the current exchange rate between `t0` and `t1` tokens must be maintained.
Based on the deposit conditions, the number of liquidity tokens is calculated
to be minted and are assigned to the sender's address. 

To **redeem** the previously provided liquidity and receive the corresponding
amounts of `t0` and `t1` tokens from the decentralized exchange, users must
provide a positive value for `x`, representing the amount of liquidity tokens
they want to redeem. The proportional amounts of `t0` and `t1` are calculated
to be returned to the sender. The calculated amounts of tokens if transferred
from the contract to the sender's address.

Users can perform a token **swap** between `t0` and `t1` tokens by specifying
the token to be swapped, the input amount, and the minimum desired output
amount. The input tokens are transferred from the sender's address to the
contract and the output amount based on the input amount and the exchange rates
is calculated. Subsequently, the output tokens are transferred to the sender's
address. The token balances in the liquidity pool, represented by `r0` and
`r1`, are updated based on the direction of the swap. Finally, it is ensured
that the contract holds the correct balances of `t0` and `t1` tokens to
maintain the integrity of the exchange.

## Expected Features
- Custom tokens
- Revert transactions
- Rational arithmetics / arbitrary-precision arithmetics

## Implementations

- **Solidity/Ethereum**: 
- **Anchor/Solana**: a step has been added for initializing the data of the AMM contract (supply, if ever deposited, resources, mints, etc.).
- **Aiken/Cardano**: 
- **PyTeal/Algorand**: <!--- https://github.com/algorand-devrel/beaker/blob/master/examples/amm/amm.py --->
- **SmartPy/Tezos**:
- **Move/Aptos**: <!--- https://github.com/Miketalent/MyAptosAutomatedMarketMaker/blob/main/liquidity_pool.move --->
