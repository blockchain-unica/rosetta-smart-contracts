# Bet Contract in Anchor

This is an implementation of the contract in [Anchor](https://www.anchor-lang.com), a [Rust](https://www.rust-lang.org)-based framework for Solana smart contracts. The purpose of this document is to simplify the understanding of the code by providing a high-level overview of the implementation.

The full specification and possible deviations from it are described in the [specification](../../README.md). Here we describe the implementation details.

⚠️ A deeper dive into Anchor is advised by reading the [Anchor documentation](https://www.anchor-lang.com). Additionally, understanding concepts such as 
- [Solana stateless account model](https://solanacookbook.com/core-concepts/accounts.html#facts)
- [Rent exemption](https://solanacookbook.com/core-concepts/accounts.html#rent)
- [Program Derived Addresses (PDA)](https://solanacookbook.com/core-concepts/pdas.html#facts)

is recommended for a complete understanding.

### Main Logic

Let's start by crafting the main contract logic. 


```rust
use anchor_lang::prelude::*;

declare_id!("8SqaUJsbWV1FHAanDG3MEfeq4EtCx2izrKdHDc5u6mjP");

#[program]
pub mod oracle_bet {
    use super::*;

    pub fn bet(ctx: Context<BetCtx>, delay: u64, wager: u64) -> Result<()> {
        // Bet logic
    }

    pub fn win(ctx: Context<OracleSetResultCtx>) -> Result<()> {
        // Win logic
    }

    pub fn timeout(ctx: Context<TimeoutCtx>) -> Result<()> {
        // 
    }
}

#[account]
#[derive(InitSpace)]
pub struct OracleBetInfo {
    pub oracle: Pubkey,
    pub participant1: Pubkey,
    pub participant2: Pubkey,
    pub wager: u64,
    pub deadline: u64,
}

impl OracleBetInfo {
    pub fn initialize(...) {...}
}

#[derive(Accounts)]
pub struct BetCtx<'info> {
    // Accounts involved in the bet action
}

#[derive(Accounts)]
pub struct OracleSetResultCtx<'info> {
    // Accounts involved in the win action
}

#[derive(Accounts)]
pub struct TimeoutCtx<'info> {
    // Accounts involved in the timeout action
}
```