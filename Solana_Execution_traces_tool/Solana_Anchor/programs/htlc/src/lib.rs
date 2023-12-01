use anchor_lang::prelude::*;

declare_id!("CXMv5rvhxqcrEQGzdEcjNMoUMq67NzaW3ZBAFbS633cF");

#[program]
pub mod htlc {
    use super::*;

    pub fn initialize(
        ctx: Context<InitializeCtx>,
        hashed_secret: [u8; 32],
        delay: u64,
        amount: u64,
    ) -> Result<()> {
        let htlc_info = &mut ctx.accounts.htlc_info;
        htlc_info.owner = *ctx.accounts.owner.key;
        htlc_info.verifier = *ctx.accounts.verifier.key;
        htlc_info.hashed_secret = hashed_secret;
        htlc_info.reveal_timeout = Clock::get()?.slot + delay;

        let transfer_instruction = anchor_lang::solana_program::system_instruction::transfer(
            &ctx.accounts.owner.key(),
            &htlc_info.key(),
            amount,
        );
        anchor_lang::solana_program::program::invoke(
            &transfer_instruction,
            &[
                ctx.accounts.owner.to_account_info(),
                htlc_info.to_account_info(),
            ],
        )
        .unwrap();

        Ok(())
    }

    pub fn reveal(ctx: Context<RevealCtx>, secret: String) -> Result<()> {
        let hash = anchor_lang::solana_program::keccak::hash(&secret.into_bytes()).to_bytes();
        let htlc_info = &mut ctx.accounts.htlc_info;
        require!(hash == htlc_info.hashed_secret, CustomError::InvalidSecret);
        **ctx
            .accounts
            .owner
            .to_account_info()
            .try_borrow_mut_lamports()? +=
            **htlc_info.to_account_info().try_borrow_mut_lamports()?;
        **htlc_info.to_account_info().try_borrow_mut_lamports()? = 0;
        Ok(())
    }

    pub fn timeout(ctx: Context<TimeoutCtx>) -> Result<()> {
        let htlc_info = &mut ctx.accounts.htlc_info;
        require!(
            Clock::get()?.slot > htlc_info.reveal_timeout,
            CustomError::TimeoutNotReached
        );
        **ctx
            .accounts
            .verifier
            .to_account_info()
            .try_borrow_mut_lamports()? +=
            **htlc_info.to_account_info().try_borrow_mut_lamports()?;
        **htlc_info.to_account_info().try_borrow_mut_lamports()? = 0;
        Ok(())
    }
}

#[account]
#[derive(InitSpace)]
pub struct HtlcPDA {
    pub owner: Pubkey,           // 32 bytes
    pub verifier: Pubkey,        // 32 bytes
    pub hashed_secret: [u8; 32], // 32 bytes
    pub reveal_timeout: u64,     // 8 bytes
    pub amount: u64,             // 8 bytes
}

#[derive(Accounts)]
pub struct InitializeCtx<'info> {
    #[account(mut)]
    pub owner: Signer<'info>,
    pub verifier: SystemAccount<'info>,
    pub system_program: Program<'info, System>,
    #[account(
        init, 
        payer = owner, 
        seeds = [owner.key().as_ref(), verifier.key().as_ref()],
        bump,
        space = 8 + HtlcPDA::INIT_SPACE
    )]
    pub htlc_info: Account<'info, HtlcPDA>,
}

#[derive(Accounts)]
pub struct RevealCtx<'info> {
    #[account(mut)]
    pub owner: Signer<'info>,
    pub verifier: SystemAccount<'info>,
    #[account(
        mut, 
        seeds = [owner.key().as_ref(), verifier.key().as_ref()],
        bump,
        constraint = htlc_info.verifier == verifier.key() @ CustomError::InvalidVerifier,
        constraint = htlc_info.owner == owner.key() @ CustomError::InvalidOwner,
    )]
    pub htlc_info: Account<'info, HtlcPDA>,
}

#[derive(Accounts)]
pub struct TimeoutCtx<'info> {
    #[account(mut)]
    pub verifier: Signer<'info>,
    pub owner: SystemAccount<'info>,
    #[account(
        mut, 
        seeds = [owner.key().as_ref(), verifier.key().as_ref()],
        bump,
        constraint = htlc_info.verifier == verifier.key() @ CustomError::InvalidVerifier,
        constraint = htlc_info.owner == owner.key() @ CustomError::InvalidOwner,
    )]
    pub htlc_info: Account<'info, HtlcPDA>,
}

#[error_code]
pub enum CustomError {
    #[msg("Invalid verifier")]
    InvalidVerifier,

    #[msg("Invalid owner")]
    InvalidOwner,

    #[msg("Invalid secret")]
    InvalidSecret,

    #[msg("The reveal timeout is not reached yet")]
    TimeoutNotReached,
}
