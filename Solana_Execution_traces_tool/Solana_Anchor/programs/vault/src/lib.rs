use anchor_lang::prelude::*;
use borsh::{BorshDeserialize, BorshSerialize};

declare_id!("7BEre5a4UcJpNUzmoJvxUcWpaw4LrYE8pVhmLxWDrqsS");

#[program]
pub mod vault {
    use super::*;

    pub fn initialize(
        ctx: Context<InitializeCtx>,
        wait_time: u64,
        initial_amount: u64,
    ) -> Result<()> {
        require!(wait_time > 0, CustomError::InvalidWaitTime);

        let vault_info = &mut ctx.accounts.vault_info;
        vault_info.owner = *ctx.accounts.owner.key;
        vault_info.recovery = *ctx.accounts.recovery.key;
        vault_info.receiver = Pubkey::default(); // temporal
        vault_info.wait_time = wait_time;
        vault_info.request_time = 0;
        vault_info.amount = 0;
        vault_info.state = State::Idle;

        // Transfer lamports
        let transfer_instruction = anchor_lang::solana_program::system_instruction::transfer(
            &ctx.accounts.owner.key(),
            &ctx.accounts.vault_info.key(),
            initial_amount,
        );

        anchor_lang::solana_program::program::invoke(
            &transfer_instruction,
            &[
                ctx.accounts.owner.to_account_info(),
                ctx.accounts.vault_info.to_account_info(),
            ],
        )
        .unwrap();

        Ok(())
    }

    pub fn withdraw(ctx: Context<WithdrawCtx>, amount: u64) -> Result<()> {
        let vault_info = &mut ctx.accounts.vault_info;
        let min_rent_lamports =
            Rent::get()?.minimum_balance(vault_info.to_account_info().data_len());

        require!(vault_info.state == State::Idle, CustomError::InvalidState);
        require!(amount > 0, CustomError::InvalidAmount);
        require!(
            vault_info.to_account_info().lamports() - amount >= min_rent_lamports,
            CustomError::InvalidAmount
        );

        vault_info.amount = amount;
        vault_info.request_time = Clock::get()?.slot;
        vault_info.receiver = *ctx.accounts.receiver.key;
        vault_info.state = State::Req;

        Ok(())
    }

    pub fn finalize(ctx: Context<FinalizeCtx>) -> Result<()> {
        require!(
            ctx.accounts.vault_info.state == State::Req,
            CustomError::InvalidState
        );

        require!(
            Clock::get()?.slot
                >= ctx.accounts.vault_info.request_time + ctx.accounts.vault_info.wait_time,
            CustomError::EndSlotWasNotReached
        );

        let vault_info = &mut ctx.accounts.vault_info;
        vault_info.state = State::Idle;

        let receiver = &mut ctx.accounts.receiver;

        // Transfer lamports
        **receiver.to_account_info().try_borrow_mut_lamports()? += vault_info.amount;
        **vault_info.to_account_info().try_borrow_mut_lamports()? -= vault_info.amount;

        Ok(())
    }

    pub fn cancel(ctx: Context<CancelCtx>) -> Result<()> {
        require!(
            ctx.accounts.vault_info.state == State::Req,
            CustomError::InvalidState
        );
        ctx.accounts.vault_info.state = State::Idle;
        Ok(())
    }
}

#[derive(BorshSerialize, BorshDeserialize, Debug, PartialEq, Clone, InitSpace)]
pub enum State {
    Idle = 0,
    Req = 1,
}

#[account]
#[derive(InitSpace)]
pub struct VaultInfo {
    pub owner: Pubkey,     // 32 bytes
    pub recovery: Pubkey,  // 32 bytes
    pub receiver: Pubkey,  // 32 bytes
    pub wait_time: u64,    // 8 bytes
    pub request_time: u64, // 8 bytes
    pub amount: u64,       // 8 bytes
    pub state: State,      // see: https://www.anchor-lang.com/docs/space
}

#[derive(Accounts)]
pub struct InitializeCtx<'info> {
    #[account(mut)]
    pub owner: Signer<'info>,
    pub recovery: SystemAccount<'info>,
    #[account(
        init, 
        payer = owner, 
        seeds = [owner.key().as_ref()],
        bump,
        space = 8 + VaultInfo::INIT_SPACE
    )]
    pub vault_info: Account<'info, VaultInfo>,
    pub system_program: Program<'info, System>,
}

#[derive(Accounts)]
pub struct WithdrawCtx<'info> {
    #[account(mut)]
    pub owner: Signer<'info>,
    pub receiver: SystemAccount<'info>,
    #[account(
        mut,
        seeds = [owner.key().as_ref()],
        bump,
        constraint = vault_info.owner == *owner.key @ CustomError::InvalidOwner,
    )]
    pub vault_info: Account<'info, VaultInfo>,
}

#[derive(Accounts)]
pub struct FinalizeCtx<'info> {
    #[account(mut)]
    pub owner: Signer<'info>,
    #[account(mut, constraint = vault_info.receiver == *receiver.key @ CustomError::InvalidReceiver)]
    pub receiver: SystemAccount<'info>,
    #[account(
        mut,
        seeds = [owner.key().as_ref()],
        bump,
        constraint = vault_info.owner == *owner.key @ CustomError::InvalidOwner,
    )]
    pub vault_info: Account<'info, VaultInfo>,
}

#[derive(Accounts)]
pub struct CancelCtx<'info> {
    #[account(mut)]
    pub recovery: Signer<'info>,
    pub owner: SystemAccount<'info>,
    #[account(
        mut,
        seeds = [owner.key().as_ref()],
        bump,
        constraint = vault_info.owner == *owner.key @ CustomError::InvalidOwner,
        constraint = vault_info.recovery == *recovery.key @ CustomError::InvalidRecovery,
    )]
    pub vault_info: Account<'info, VaultInfo>,
}

#[error_code]
pub enum CustomError {
    #[msg("Invalid wait time, must be greater than 0")]
    InvalidWaitTime,

    #[msg("Invalid amount, must be greater than 0 and preserve the rent exemption")]
    InvalidAmount,

    #[msg("Invalid state")]
    InvalidState,

    #[msg("Invalid owner")]
    InvalidOwner,

    #[msg("Invalid receiver")]
    InvalidReceiver,

    #[msg("Invalid recovery")]
    InvalidRecovery,

    #[msg("The end slot (request time + wait time) was not reached")]
    EndSlotWasNotReached,
}
