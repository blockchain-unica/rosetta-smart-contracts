# Bet Contract in Anchor

This is an implementation of the contract in [Anchor](https://www.anchor-lang.com), a [Rust](https://www.rust-lang.org)-based framework for Solana smart contracts. The purpose of this document is to simplify the understanding of the code by providing a high-level overview of the implementation. We'll omit some implementation details, such as crate imports and error definitions, for brevity.

The full specification and possible deviations from it are described in the [specification](../../README.md). Here we describe the implementation details.

⚠️ A deeper dive into Anchor is advised by reading the [Anchor documentation](https://www.anchor-lang.com). Additionally, understanding concepts such as:

- [Solana stateless account model](https://solanacookbook.com/core-concepts/accounts.html#facts)
- [Rent exemption](https://solanacookbook.com/core-concepts/accounts.html#rent)
- [Program Derived Addresses (PDA)](https://solanacookbook.com/core-concepts/pdas.html#facts)

is recommended for a complete understanding.

## Main Logic

The use case involves two players and an oracle. Two participants join the contract by depositing 1 SOL each and setting the deadline. The oracle is expected to determine the winner between the two players. The winner can redeem the whole pot. If the oracle does not choose the winner by the deadline, then both players can redeem their bets.

Let's start by crafting the main contract logic. We have three actions: `join`, `win`, and `timeout`, each with its own context of associated accounts and parameters. We also define the account structure `OracleBetInfo`, which holds the information about the bet.

```rust
#[program]
pub mod bet {
    use super::*;

    pub fn join(ctx: Context<JoinCtx>, delay: u64, wager: u64) -> Result<()> {
        // Bet logic
    }

    pub fn win(ctx: Context<WinCtx>) -> Result<()> {
        // Win logic
    }

    pub fn timeout(ctx: Context<TimeoutCtx>) -> Result<()> {
        // Timeout logic
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

#[derive(Accounts)]
pub struct JoinCtx<'info> {
    // Accounts involved in the join action
}

#[derive(Accounts)]
pub struct WinCtx<'info> {
    // Accounts involved in the win action
}

#[derive(Accounts)]
pub struct TimeoutCtx<'info> {
    // Accounts involved in the timeout action
}
```

## Join Context and Logic

Once we've defined the main logic, let's implement the accounts context of the join action.

The `join` action involves two participants and the oracle. Both participants are required to join simultaneously. For this purpose they are typed as `Signer` accounts, contrary to the oracle.

Since Solana smart contracts are [stateless]((https://solanacookbook.com/core-concepts/accounts.html#facts)), the third account is the `oracle_bet_info`, a [PDA](https://solanacookbook.com/core-concepts/pdas.html#facts) account with the associated type `OracleBetInfo`, that will hold information such as the deposited balance and the actors. The account is initialized with the `init` attribute with `participant1` as the payer. The address of this account is derived through seeds in a way to establish a mapping between the couple (`participant1`, `participant2`) and their storage account. 
An alternative mapping can be achieved by including also the `oracle` in the seeds, in this case a single couple (`participant1`, `participant2`) can have multiple bets with different oracles.
The space is calculated using the `OracleBetInfo::INIT_SPACE` constant to cover the [Rent exemption](https://solanacookbook.com/core-concepts/accounts.html#rent) with 8 bytes allocated for Anchor [discriminator](https://book.anchor-lang.com/anchor_bts/discriminator.html). 

The last account is the `system_program` account, a native contract, required in instructions containing account initializations.

```rust
#[derive(Accounts)]
pub struct JoinCtx<'info> {
    #[account(mut)]
    pub participant1: Signer<'info>,

    #[account(mut)]
    pub participant2: Signer<'info>,

    pub oracle: SystemAccount<'info>,

    #[account(
        init, 
        payer = participant1, 
        seeds = [participant1.key().as_ref(), participant2.key().as_ref()], 
        bump,
        space = 8 + OracleBetInfo::INIT_SPACE
    )]
    pub oracle_bet_info: Account<'info, OracleBetInfo>,

    pub system_program: Program<'info, System>,
}
```

![Contract Accounts](./OracleBet.png)

Once we have the context, we can implement the logic of the `join` action. The logic involves initializing the `oracle_bet_info` account with the information about the bet, and both participants transferring the wager to the `oracle_bet_info` account.

```rust
pub fn join(ctx: Context<JoinCtx>, delay: u64, wager: u64) -> Result<()> {
    let participant1 = ctx.accounts.participant1.to_account_info();
    let participant2 = ctx.accounts.participant2.to_account_info();
    let oracle = ctx.accounts.oracle.to_account_info();
    let oracle_bet_info = &mut ctx.accounts.oracle_bet_info;

    oracle_bet_info.oracle = *oracle.key;
    oracle_bet_info.participant1 = *participant1.key;
    oracle_bet_info.participant2 = *participant2.key;
    oracle_bet_info.deadline = Clock::get()?.slot + delay;
    oracle_bet_info.wager = wager;

    system_program::transfer(
        CpiContext::new(
            ctx.accounts.system_program.to_account_info(),
            system_program::Transfer {
                from: participant1.clone(),
                to: oracle_bet_info.to_account_info().clone(),
            },
        ),
        oracle_bet_info.wager,
    )?;

    system_program::transfer(
        CpiContext::new(
            ctx.accounts.system_program.to_account_info(),
            system_program::Transfer {
                from: participant2.clone(),
                to: oracle_bet_info.to_account_info().clone(),
            },
        ),
        oracle_bet_info.wager,
    )?;

    Ok(())
}
```

## Win Context and Logic

The `win` context involves the oracle and the winner. The oracle is constrained to sign the transaction to avoid the [Missing signer check vulnerability](https://neodyme.io/en/blog/solana_common_pitfalls/#missing-signer-check). The winner is constrained to be one of the players of the bet. The storage account `oracle_bet_info` is retrieved via the seed used in the `join` action. 

```rust
#[derive(Accounts)]
pub struct WinCtx<'info> {
    #[account(mut)]
    pub oracle: Signer<'info>,

    #[account(
        mut, 
        constraint =  *winner.key == oracle_bet_info.participant1 || *winner.key == oracle_bet_info.participant2 @ Error::InvalidParticipant
    )]
    pub winner: SystemAccount<'info>,

    #[account(
        mut, 
        has_one = oracle @ Error::InvalidOracle,
        seeds = [participant1.key().as_ref(), participant2.key().as_ref()], 
        bump,
    )]
    pub oracle_bet_info: Account<'info, OracleBetInfo>,

    pub participant1: SystemAccount<'info>,

    pub participant2: SystemAccount<'info>,

    pub system_program: Program<'info, System>,
}
```

The logic of the `win` action involves transferring the balance of the `oracle_bet_info` account to the winner.


In the `join` action we were constrained to invoke the system program to transfer the assets. This is because the assets were provided by the participants, whose accounts are [owned](https://solanacookbook.com/core-concepts/accounts.html#account-model) by the system program. In the `win` action, the assets are transferred to the winner from a PDA account, which is owned by the program itself. This is why we can directly manipulate the assets in the PDA account.

```rust
pub fn win(ctx: Context<WinCtx>) -> Result<()> {
    let oracle_bet_info = &mut ctx.accounts.oracle_bet_info;
    let winner = ctx.accounts.winner.to_account_info();

    **winner
        .to_account_info()
        .try_borrow_mut_lamports()? += oracle_bet_info.to_account_info().lamports();

    **oracle_bet_info
        .to_account_info()
        .try_borrow_mut_lamports()? = 0;

    Ok(())
}
```

## Timeout Context and Logic

In the `timeout` action, besides the correctness of the addresses of the participants, we do not require any signature. The `oracle_bet_info` account is retrieved with the same seeds used in the `join` action.

```rust
#[derive(Accounts)]
pub struct TimeoutCtx<'info> {
    #[account(mut)]
    pub participant1: SystemAccount<'info>,

    #[account(mut)]
    pub participant2: SystemAccount<'info>,

    #[account(
        mut,
        seeds = [participant1.key().as_ref(), participant2.key().as_ref()], 
        bump,
    )]
    pub oracle_bet_info: Account<'info, OracleBetInfo>,

    pub system_program: Program<'info, System>,
}
```

The logic of the `timeout` action involves refunding the participants with the wager and the participant1 also with the remaining lamports since it was the initializer of the `oracle_bet_info` account. The deadline is checked against the current slot, in case the deadline is not reached, the transaction is aborted.

```rust
pub fn timeout(ctx: Context<TimeoutCtx>) -> Result<()> {
    let oracle_bet_info = &mut ctx.accounts.oracle_bet_info;
    let participant1 = ctx.accounts.participant1.to_account_info();
    let participant2 = ctx.accounts.participant2.to_account_info();

    require!(
        oracle_bet_info.deadline < Clock::get()?.slot,
        Error::DeadlineNotReached
    );

    **participant2.to_account_info().try_borrow_mut_lamports()? += oracle_bet_info.wager;
    **oracle_bet_info
        .to_account_info()
        .try_borrow_mut_lamports()? -= oracle_bet_info.wager;

    **participant1.to_account_info().try_borrow_mut_lamports()? +=
        oracle_bet_info.to_account_info().lamports();
    **oracle_bet_info
        .to_account_info()
        .try_borrow_mut_lamports()? = 0;

    Ok(())
}
```
