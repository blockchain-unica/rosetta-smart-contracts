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
        let bet_info = &mut ctx.accounts.bet_info;

        bet_info.oracle = *oracle.key;
        bet_info.participant1 = *participant1.key;
        bet_info.participant2 = *participant2.key;
        bet_info.deadline = Clock::get()?.slot + delay;
        bet_info.wager = wager;

        system_program::transfer(
            CpiContext::new(
                ctx.accounts.system_program.to_account_info(),
                system_program::Transfer {
                    from: participant1.clone(),
                    to: bet_info.to_account_info().clone(),
                },
            ),
            bet_info.wager,
        )?;

        system_program::transfer(
            CpiContext::new(
                ctx.accounts.system_program.to_account_info(),
                system_program::Transfer {
                    from: participant2.clone(),
                    to: bet_info.to_account_info().clone(),
                },
            ),
            bet_info.wager,
        )?;

        Ok(()) // Execution completed successfully without errors
    }

    pub fn win(ctx: Context<WinCtx>) -> Result<()> {
        let bet_info = ctx.accounts.bet_info.to_account_info();
        let winner = ctx.accounts.winner.to_account_info();

        **winner.try_borrow_mut_lamports()? += bet_info.to_account_info().lamports();
        **bet_info.try_borrow_mut_lamports()? = 0;

        Ok(()) // Execution completed successfully without errors
    }

    pub fn timeout(ctx: Context<TimeoutCtx>) -> Result<()> {
        let bet_info = &mut ctx.accounts.bet_info;
        let participant1 = ctx.accounts.participant1.to_account_info();
        let participant2 = ctx.accounts.participant2.to_account_info();

        require!(
            bet_info.deadline < Clock::get()?.slot,
            Error::DeadlineNotReached
        );

        **participant2.try_borrow_mut_lamports()? += bet_info.wager;
        **bet_info
            .to_account_info()
            .try_borrow_mut_lamports()? -= bet_info.wager;

        **participant1.try_borrow_mut_lamports()? += bet_info.to_account_info().lamports();
        **bet_info
            .to_account_info()
            .try_borrow_mut_lamports()? = 0;

        Ok(()) // Execution completed successfully without errors
    }
}

#[account]
#[derive(InitSpace)]
pub struct BetInfo {
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
        space = 8 + BetInfo::INIT_SPACE
    )]
    pub bet_info: Account<'info, BetInfo>,

    pub system_program: Program<'info, System>,
}

#[derive(Accounts)]
pub struct WinCtx<'info> {
    #[account(mut)]
    pub oracle: Signer<'info>,

    #[account(
        mut, 
        constraint =  *winner.key == bet_info.participant1 || *winner.key == bet_info.participant2 @ Error::InvalidParticipant
    )]
    pub winner: SystemAccount<'info>,

    #[account(
        mut, 
        has_one = oracle @ Error::InvalidOracle, // The provided oracle must match the oracle_bet_info.oracle
        seeds = [participant1.key().as_ref(), participant2.key().as_ref()], 
        bump,
    )]
    pub bet_info: Account<'info, BetInfo>,

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
    pub bet_info: Account<'info, BetInfo>,

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
