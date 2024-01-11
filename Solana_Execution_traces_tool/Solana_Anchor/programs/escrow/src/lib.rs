use anchor_lang::prelude::*;
use borsh::{BorshDeserialize, BorshSerialize};

declare_id!("BjnzdLZze5AvqMKoPJ3UYo8ruAWspVMKo258TCeTuQ55");

#[program]
pub mod escrow {
    use super::*;

    pub fn initialize(
        ctx: Context<InitializeCtx>,
        amount_in_lamports: u64,
        escrow_name: String,
    ) -> Result<()> {
        msg!("Escrow name: {}", escrow_name);
        require!(amount_in_lamports > 0, CustomError::ZeroAmount);

        let escrow_info = &mut ctx.accounts.escrow_info;
        escrow_info.seller = *ctx.accounts.seller.key;
        escrow_info.buyer = *ctx.accounts.buyer.key;
        escrow_info.amount_in_lamports = amount_in_lamports;
        escrow_info.state = State::WaitDeposit;

        Ok(())
    }

    pub fn deposit(ctx: Context<DepositCtx>, escrow_name: String) -> Result<()> {
        msg!("Escrow name: {}", escrow_name);
        require!(
            ctx.accounts.escrow_info.state == State::WaitDeposit,
            CustomError::InvalidState
        );

        ctx.accounts.escrow_info.state = State::WaitRecipient;

        let transfer_instruction = anchor_lang::solana_program::system_instruction::transfer(
            &ctx.accounts.buyer.key(),
            &ctx.accounts.escrow_info.key(),
            ctx.accounts.escrow_info.amount_in_lamports,
        );

        anchor_lang::solana_program::program::invoke(
            &transfer_instruction,
            &[
                ctx.accounts.buyer.to_account_info(),
                ctx.accounts.escrow_info.to_account_info(),
            ],
        )
        .unwrap();

        Ok(())
    }

    pub fn pay(ctx: Context<PayCtx>, escrow_name: String) -> Result<()> {
        msg!("Escrow name: {}", escrow_name);
        let escrow_info = &mut ctx.accounts.escrow_info;
        let seller = &ctx.accounts.seller;
        require!(
            escrow_info.state == State::WaitRecipient,
            CustomError::InvalidState
        );
        escrow_info.state = State::Closed;
        let escrow_info = &mut ctx.accounts.escrow_info;

        **seller.to_account_info().try_borrow_mut_lamports()? +=
            **escrow_info.to_account_info().try_borrow_mut_lamports()?;
        **escrow_info.to_account_info().try_borrow_mut_lamports()? = 0;

        Ok(())
    }

    pub fn refund(ctx: Context<RefundCtx>, escrow_name: String) -> Result<()> {
        msg!("Escrow name: {}", escrow_name);
        let escrow_info = &mut ctx.accounts.escrow_info;
        require!(
            escrow_info.state == State::WaitRecipient,
            CustomError::InvalidState
        );

        escrow_info.state = State::Closed;

        let escrow_info = &mut ctx.accounts.escrow_info;
        let seller = &ctx.accounts.seller;
        let buyer = &ctx.accounts.buyer;

        // Return the amount to the buyer
        **buyer.to_account_info().try_borrow_mut_lamports()? += escrow_info.amount_in_lamports;
        **escrow_info.to_account_info().try_borrow_mut_lamports()? -=
            escrow_info.amount_in_lamports;

        // Return the remain (rent) lamports back to the seller
        let remain_lamports = **escrow_info.to_account_info().try_borrow_mut_lamports()?;
        **seller.to_account_info().try_borrow_mut_lamports()? += remain_lamports;
        **escrow_info.to_account_info().try_borrow_mut_lamports()? -= remain_lamports;

        Ok(())
    }
}

#[derive(BorshSerialize, BorshDeserialize, Debug, PartialEq, Clone, InitSpace)]
pub enum State {
    WaitDeposit = 0,
    WaitRecipient = 1,
    Closed = 2,
}

#[account]
#[derive(InitSpace)]
pub struct EscrowInfo {
    pub seller: Pubkey,          // 32 bytes
    pub buyer: Pubkey,           // 32 bytes
    pub amount_in_lamports: u64, // 8 bytes
    pub state: State,            // see: https://www.anchor-lang.com/docs/space
}

#[derive(Accounts)]
#[instruction(amount_in_lamports: u64, escrow_name: String)]
pub struct InitializeCtx<'info> {
    #[account(mut)]
    pub seller: Signer<'info>,
    pub buyer: SystemAccount<'info>,
    pub system_program: Program<'info, System>,
    #[account(
        init, 
        payer = seller, 
        seeds = [escrow_name.as_ref(), seller.key().as_ref(), buyer.key().as_ref()],
        bump,
        space = 8 + EscrowInfo::INIT_SPACE
    )]
    pub escrow_info: Account<'info, EscrowInfo>,
}

#[derive(Accounts)]
#[instruction(escrow_name: String)]
pub struct DepositCtx<'info> {
    #[account(
        mut,
        constraint = buyer.key() == escrow_info.buyer,
    )]
    pub buyer: Signer<'info>,
    #[account(
        constraint = seller.key() == escrow_info.seller,
    )]
    pub seller: SystemAccount<'info>,
    #[account(
        mut,
        seeds = [escrow_name.as_ref(), seller.key().as_ref(), buyer.key().as_ref()],
        bump,
    )]
    pub escrow_info: Account<'info, EscrowInfo>,
    pub system_program: Program<'info, System>,
}

#[derive(Accounts)]
#[instruction(escrow_name: String)]
pub struct PayCtx<'info> {
    #[account(
        mut,
        constraint = buyer.key() == escrow_info.buyer,
    )]
    pub buyer: Signer<'info>,
    #[account(
        mut,
        constraint = seller.key() == escrow_info.seller,
    )]
    pub seller: SystemAccount<'info>,
    #[account(
        mut,
        seeds = [escrow_name.as_ref(), seller.key().as_ref(), buyer.key().as_ref()],
        bump,
    )]
    pub escrow_info: Account<'info, EscrowInfo>,
}

#[derive(Accounts)]
#[instruction(escrow_name: String)]
pub struct RefundCtx<'info> {
    #[account(
        mut,
        constraint = seller.key() == escrow_info.seller,
    )]
    pub seller: Signer<'info>,
    #[account(
        mut, // mutable to return the rent lamports back
        constraint = seller.key() == escrow_info.seller,
    )]
    pub buyer: SystemAccount<'info>,
    #[account(
        mut,
        seeds = [escrow_name.as_ref(), seller.key().as_ref(), buyer.key().as_ref()],
        bump,
    )]
    pub escrow_info: Account<'info, EscrowInfo>,
}

#[error_code]
pub enum CustomError {
    #[msg("Invalid amount, must be greater than 0")]
    ZeroAmount,

    #[msg("Invalid amount")]
    InvalidAmount,

    #[msg("Invalid state")]
    InvalidState,
}
