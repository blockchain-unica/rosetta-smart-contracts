use anchor_lang::prelude::*;

declare_id!("7sX7Ym3hB7oTNeA17fjZcU57r4rzUYJpMvB1jSathXgF");

#[program]
pub mod vesting {
    use super::*;

    pub fn initialize(
        ctx: Context<InitializeCtx>,
        start_slot: u64,
        duration: u64,
        lamports_amount: u64,
    ) -> Result<()> {
        require!(
            start_slot > Clock::get()?.slot,
            CustomError::InvalidStartSlot
        );
        require!(duration > 0, CustomError::InvalidDuration);

        let vesting_info = &mut ctx.accounts.vesting_info;
        vesting_info.funder = *ctx.accounts.funder.key;
        vesting_info.beneficiary = *ctx.accounts.beneficiary.key;
        vesting_info.start_slot = start_slot;
        vesting_info.duration = duration;
        vesting_info.released = 0;

        msg!("Transfering lamports to the vesting account");
        let transfer_instruction = anchor_lang::solana_program::system_instruction::transfer(
            &ctx.accounts.funder.key(),
            &ctx.accounts.vesting_info.key(),
            lamports_amount,
        );

        anchor_lang::solana_program::program::invoke(
            &transfer_instruction,
            &[
                ctx.accounts.funder.to_account_info(),
                ctx.accounts.vesting_info.to_account_info(),
            ],
        )
        .unwrap();

        Ok(())
    }

    pub fn release(ctx: Context<ReleaseCtx>) -> Result<()> {
        let beneficiary = &mut ctx.accounts.beneficiary;
        let vesting_info = &mut ctx.accounts.vesting_info;

        let rent_lamports = Rent::get()?.minimum_balance(vesting_info.to_account_info().data_len());
        let balance = **vesting_info.to_account_info().try_borrow_lamports()? - rent_lamports;
        let amount = releasable(
            vesting_info.released,
            balance,
            vesting_info.start_slot,
            vesting_info.duration,
        )?;

        msg!("Releasing {} lamports to {}", amount, beneficiary.key());
        vesting_info.released += amount;
        **beneficiary.to_account_info().try_borrow_mut_lamports()? += amount;
        **vesting_info.to_account_info().try_borrow_mut_lamports()? -= amount;

        if **vesting_info.to_account_info().lamports.borrow() <= rent_lamports {
            msg!("Closing the vesting account and returning the rent fees to the funder");
            let funder = &mut ctx.accounts.funder;
            **funder.to_account_info().try_borrow_mut_lamports()? +=
                **vesting_info.to_account_info().try_borrow_mut_lamports()?;
            **vesting_info.to_account_info().try_borrow_mut_lamports()? = 0;
        }

        Ok(())
    }
}

#[account]
#[derive(InitSpace)]
pub struct VestingInfo {
    pub released: u64,       // 8 bytes
    pub funder: Pubkey,      // 32 bytes
    pub beneficiary: Pubkey, // 32 bytes
    pub start_slot: u64,     // 8 bytes
    pub duration: u64,       // 8 bytes
}

#[derive(Accounts)]
pub struct InitializeCtx<'info> {
    #[account(mut)]
    pub funder: Signer<'info>,
    pub beneficiary: SystemAccount<'info>,
    #[account(
        init, 
        payer = funder, 
        seeds = [beneficiary.key().as_ref()],
        bump,
        space = 8 + VestingInfo::INIT_SPACE
    )]
    pub vesting_info: Account<'info, VestingInfo>,
    pub system_program: Program<'info, System>,
}

#[derive(Accounts)]
pub struct ReleaseCtx<'info> {
    #[account(mut)]
    pub beneficiary: Signer<'info>,
    #[account(mut)] // mutable to return the rent fees back
    pub funder: SystemAccount<'info>,
    #[account(
        mut,
        seeds = [beneficiary.key().as_ref()],
        bump,
        constraint = vesting_info.beneficiary == *beneficiary.key @ CustomError::InvalidBeneficiary,
        constraint = vesting_info.funder == *funder.key @ CustomError::InvalidFunder,
    )]
    pub vesting_info: Account<'info, VestingInfo>,
}

fn releasable(released: u64, balance: u64, start_slot: u64, duration: u64) -> Result<u64> {
    let current_slot = Clock::get()?.slot;
    Ok(vested_amount(current_slot, released, balance, start_slot, duration)? - released)
}

fn vested_amount(
    timestamp: u64,
    released: u64,
    balance: u64,
    start_slot: u64,
    duration: u64,
) -> Result<u64> {
    Ok(vesting_schedule(
        balance + released,
        timestamp,
        start_slot,
        duration,
    ))
}

fn vesting_schedule(total_allocation: u64, timestamp: u64, start_slot: u64, duration: u64) -> u64 {
    if timestamp < start_slot {
        return 0;
    } else if timestamp > start_slot + duration {
        return total_allocation;
    } else {
        return (total_allocation * (timestamp - start_slot)) / duration;
    }
}

#[error_code]
pub enum CustomError {
    #[msg("Invalid start slot, must be in the future")]
    InvalidStartSlot,

    #[msg("Invalid duration, must be greater than 0")]
    InvalidDuration,

    #[msg("Invalid beneficiary")]
    InvalidBeneficiary,

    #[msg("Invalid funder")]
    InvalidFunder,
}
