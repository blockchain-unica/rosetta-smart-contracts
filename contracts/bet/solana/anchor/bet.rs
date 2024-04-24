use anchor_lang::prelude::*;

declare_id!("CgUzgJgmYN5VnQmwJuLRqwXwpaRLktt2ic61dHcPif9k");

#[program]
pub mod oracle_bet {
    use super::*;

    pub fn join(ctx: Context<JoinCtx>, delay: u64, wager: u64) -> Result<()> {
        let oracle_bet_info = &mut ctx.accounts.oracle_bet_info;

        oracle_bet_info.initialize(
            *ctx.accounts.oracle.key,
            *ctx.accounts.participant1.key,
            *ctx.accounts.participant2.key,
            Clock::get()?.slot + delay,
            wager,
        );

        msg!("Transfering funds");
        anchor_lang::solana_program::program::invoke(
            &anchor_lang::solana_program::system_instruction::transfer(
                &ctx.accounts.participant1.key(),
                &oracle_bet_info.key(),
                oracle_bet_info.wager,
            ),
            &[
                ctx.accounts.participant1.to_account_info(),
                oracle_bet_info.to_account_info(),
            ],
        )
        .unwrap();

        anchor_lang::solana_program::program::invoke(
            &anchor_lang::solana_program::system_instruction::transfer(
                &ctx.accounts.participant2.key(),
                &oracle_bet_info.key(),
                oracle_bet_info.wager,
            ),
            &[
                ctx.accounts.participant2.to_account_info(),
                oracle_bet_info.to_account_info(),
            ],
        )
        .unwrap();

        Ok(())
    }

    pub fn win(ctx: Context<WinCtx>) -> Result<()> {
        let oracle_bet_info = &mut ctx.accounts.oracle_bet_info;

        msg!("Winner: {:?}", ctx.accounts.winner.key);

        **ctx
            .accounts
            .winner
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
            CustomError::DeadlineNotReached
        );

        msg!("Transfering funds to participant2");
        **participant2.to_account_info().try_borrow_mut_lamports()? += oracle_bet_info.wager;
        **oracle_bet_info
            .to_account_info()
            .try_borrow_mut_lamports()? -= oracle_bet_info.wager;

        msg!("Transfering the rent to participant1");
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

impl OracleBetInfo {
    pub fn initialize(
        &mut self,
        oracle: Pubkey,
        participant1: Pubkey,
        participant2: Pubkey,
        deadline: u64,
        wager: u64,
    ) {
        self.oracle = oracle;
        self.participant1 = participant1;
        self.participant2 = participant2;
        self.deadline = deadline;
        self.wager = wager;
    }
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
    #[account(mut, constraint =  *winner.key == oracle_bet_info.participant1 || *winner.key == oracle_bet_info.participant2 @ CustomError::InvalidParticipant)]
    pub winner: SystemAccount<'info>,
    #[account(
        mut, 
        has_one = oracle @ CustomError::InvalidOracle,
        has_one = participant1 @ CustomError::InvalidParticipant, 
        has_one = participant2 @ CustomError::InvalidParticipant,
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
    #[account(mut, constraint =  *participant1.key == oracle_bet_info.participant1  @ CustomError::InvalidParticipant)]
    pub participant1: SystemAccount<'info>,
    #[account(mut, constraint =  *participant2.key == oracle_bet_info.participant2 @ CustomError::InvalidParticipant)]
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
pub enum CustomError {
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
