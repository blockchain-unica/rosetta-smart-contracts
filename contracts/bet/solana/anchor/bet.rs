use anchor_lang::prelude::*;
use anchor_lang::system_program;

declare_id!("7mMf8y3WnKREkqkUG96viUvsMfpwfaPHqxBSxbMUMJQN");

#[program]
pub mod bet {
    use super::*;

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

#[error_code]
pub enum Error {
    #[msg("Invalid participant")]
    InvalidParticipant,

    #[msg("Invalid oracle")]
    InvalidOracle,

    #[msg("The deadline was not reached yet")]
    DeadlineNotReached,

    #[msg("The deadline was reached")]
    DeadlineReached,

    #[msg("The winner was already chosen")]
    WinnerWasChosen,

    #[msg("All participants have deposited")]
    AllParticipantsHaveDeposited,

    #[msg("Not all participants have deposited")]
    ParticipantsHaveNotDeposited,
}
