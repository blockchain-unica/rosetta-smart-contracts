use anchor_lang::prelude::*;

declare_id!("8Bk7qQpQxqBz5XVX3LqV3vbpnNuZLhCnKq316UHThMHV");

#[program]
pub mod crowdfund {
    use super::*;

    pub fn initialize(
        ctx: Context<InitializeCtx>,
        campaign_name: String,
        end_donate_slot: u64,
        goal_in_lamports: u64,
    ) -> Result<()> {
        require!(goal_in_lamports > 0, CustomError::InvalidAmount);
        require!(
            Clock::get()?.slot < end_donate_slot,
            CustomError::InvalidEndSlot
        );

        let campaign_pda = &mut ctx.accounts.campaign_pda;
        campaign_pda.campaign_name = campaign_name;
        campaign_pda.campaign_owner = *ctx.accounts.campaign_owner.key;
        campaign_pda.end_donate_slot = end_donate_slot;
        campaign_pda.goal_in_lamports = goal_in_lamports;
        Ok(())
    }

    pub fn donate(
        ctx: Context<DonateCtx>,
        _campaign_name: String, // prefixed because not used in instruction, but used for seeds in context
        donated_lamports: u64,
    ) -> Result<()> {
        let campaign_pda = &mut ctx.accounts.campaign_pda;
        let donor = &mut ctx.accounts.donor;
        let deposit_pda = &mut ctx.accounts.deposit_pda;

        require!(donated_lamports > 0, CustomError::InvalidAmount);
        require!(
            Clock::get()?.slot <= campaign_pda.end_donate_slot,
            CustomError::TimeoutReached
        );

        deposit_pda.total_donated += donated_lamports;

        let transfer_instruction = anchor_lang::solana_program::system_instruction::transfer(
            &donor.key(),
            &campaign_pda.key(),
            donated_lamports,
        );

        anchor_lang::solana_program::program::invoke(
            &transfer_instruction,
            &[donor.to_account_info(), campaign_pda.to_account_info()],
        )
        .unwrap();

        Ok(())
    }

    pub fn withdraw(
        ctx: Context<WithdrawCtx>,
        _campaign_name: String, // prefixed because not used in instruction, but used for seeds in context
    ) -> Result<()> {
        let campaign_pda = &mut ctx.accounts.campaign_pda;
        let campaign_owner = &mut ctx.accounts.campaign_owner;

        require!(
            Clock::get()?.slot >= campaign_pda.end_donate_slot,
            CustomError::TimeoutNotReached
        );

        let balance = **campaign_pda.to_account_info().try_borrow_mut_lamports()?;
        let rent_exemption =
            Rent::get()?.minimum_balance(campaign_pda.to_account_info().data_len());
        let lamports_reached = balance - rent_exemption;
        require!(
            lamports_reached >= campaign_pda.goal_in_lamports,
            CustomError::GoalNotReached
        );

        **campaign_owner.to_account_info().try_borrow_mut_lamports()? +=
            **campaign_pda.to_account_info().try_borrow_mut_lamports()?;
        **campaign_pda.to_account_info().try_borrow_mut_lamports()? = 0;

        Ok(())
    }

    pub fn reclaim(
        ctx: Context<ReclaimCtx>,
        _campaign_name: String, // prefixed because not used in instruction, but used for seeds in context
    ) -> Result<()> {
        let donor = &mut ctx.accounts.donor;
        let campaign_pda = &mut ctx.accounts.campaign_pda;
        let deposit_pda = &mut ctx.accounts.deposit_pda;

        require!(
            Clock::get()?.slot >= campaign_pda.end_donate_slot,
            CustomError::TimeoutNotReached
        );

        let balance = **campaign_pda.to_account_info().try_borrow_mut_lamports()?;
        let rent_exemption =
            Rent::get()?.minimum_balance(campaign_pda.to_account_info().data_len());
        let lamports_reached = balance - rent_exemption;
        require!(
            lamports_reached < campaign_pda.goal_in_lamports,
            CustomError::GoalReached
        );

        // Close the deposit_pda account and return the rent to the donor
        **donor.to_account_info().try_borrow_mut_lamports()? +=
            **deposit_pda.to_account_info().try_borrow_mut_lamports()?;
        **deposit_pda.to_account_info().try_borrow_mut_lamports()? = 0;

        // Return the donated amount to the donor
        **donor.to_account_info().try_borrow_mut_lamports()? += deposit_pda.total_donated;
        **campaign_pda.to_account_info().try_borrow_mut_lamports()? -= deposit_pda.total_donated;

        Ok(())
    }
}

#[derive(Accounts)]
#[instruction(campaign_name: String)]
pub struct InitializeCtx<'info> {
    #[account(mut)]
    pub campaign_owner: Signer<'info>,
    #[account(
        init, 
        payer = campaign_owner, 
        seeds = [campaign_name.as_ref()],
        bump,
        space = 8 + CampaignPDA::INIT_SPACE
    )]
    pub campaign_pda: Account<'info, CampaignPDA>,
    pub system_program: Program<'info, System>,
}

#[derive(Accounts)]
#[instruction(_campaign_name: String)]
pub struct DonateCtx<'info> {
    #[account(mut)]
    pub donor: Signer<'info>,
    #[account(mut, seeds = [_campaign_name.as_ref()], bump )]
    pub campaign_pda: Account<'info, CampaignPDA>,
    #[account(
        init_if_needed,
        payer = donor, 
        seeds = ["deposit".as_ref(), _campaign_name.as_ref(), donor.key().as_ref()],
        bump,
        space = 8 + DepositPDA::INIT_SPACE
    )]
    pub deposit_pda: Account<'info, DepositPDA>,
    pub system_program: Program<'info, System>,
}

#[derive(Accounts)]
#[instruction(_campaign_name: String)]
pub struct WithdrawCtx<'info> {
    #[account(mut)]
    pub campaign_owner: Signer<'info>,
    #[account(mut, seeds = [_campaign_name.as_ref()], bump )]
    pub campaign_pda: Account<'info, CampaignPDA>,
}

#[derive(Accounts)]
#[instruction(_campaign_name: String)]
pub struct ReclaimCtx<'info> {
    #[account(mut)]
    pub donor: Signer<'info>,
    #[account(mut, seeds = [_campaign_name.as_ref()], bump )]
    pub campaign_pda: Account<'info, CampaignPDA>,
    #[account( 
        mut, 
        seeds = ["deposit".as_ref(), _campaign_name.as_ref(), donor.key().as_ref()],
        bump,
    )]
    pub deposit_pda: Account<'info, DepositPDA>,
}

#[account]
#[derive(InitSpace)]
pub struct CampaignPDA {
    #[max_len(30)]
    pub campaign_name: String,
    pub campaign_owner: Pubkey, // 32 bytes
    pub end_donate_slot: u64,   // 8 bytes
    pub goal_in_lamports: u64,  // 8 bytes
}

#[account]
#[derive(InitSpace)]
pub struct DepositPDA {
    pub total_donated: u64, // 8 bytes
}

#[error_code]
pub enum CustomError {
    #[msg("The end slot must be greater than the current slot")]
    InvalidEndSlot,

    #[msg("Invalid amount, must be greater than 0")]
    InvalidAmount,

    #[msg("The timeout slot was reached")]
    TimeoutReached,

    #[msg("The timeout slot was not reached")]
    TimeoutNotReached,

    #[msg("The goal was not reached")]
    GoalNotReached,

    #[msg("The goal was reached")]
    GoalReached,
}
