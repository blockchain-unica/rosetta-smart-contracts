use anchor_lang::prelude::*;

declare_id!("GXGCxuXmztgTRPAfuYF72eU6eTkdEKG8Amu81NCSSkPX");

#[program]
pub mod simple_transfer {
    use super::*;

    pub fn deposit(ctx: Context<DepositCtx>, amount_to_deposit: u64) -> Result<()> {
        require!(amount_to_deposit > 0, CustomError::InvalidAmount);

        let transfer_instruction = anchor_lang::solana_program::system_instruction::transfer(
            &ctx.accounts.sender.key(),
            &ctx.accounts.balance_holder_pda.key(),
            amount_to_deposit,
        );

        msg!("Transferring {} lamports from {} to the balance holder PDA", amount_to_deposit, ctx.accounts.sender.key());
        anchor_lang::solana_program::program::invoke(
            &transfer_instruction,
            &[
                ctx.accounts.sender.to_account_info(),
                ctx.accounts.balance_holder_pda.to_account_info(),
            ],
        )
        .unwrap();

        let balance_holder_pda = &mut ctx.accounts.balance_holder_pda;
        balance_holder_pda.sender = *ctx.accounts.sender.key;
        balance_holder_pda.recipient = ctx.accounts.recipient.key();
        balance_holder_pda.amount = amount_to_deposit;

        Ok(())
    }

    pub fn withdraw(ctx: Context<WithdrawCtx>, amount_to_withdraw: u64) -> Result<()> {
        require!(amount_to_withdraw > 0, CustomError::InvalidAmount);

        let from = ctx.accounts.balance_holder_pda.to_account_info();
        let to = ctx.accounts.recipient.to_account_info();

        **from.try_borrow_mut_lamports()? -= amount_to_withdraw;
        **to.try_borrow_mut_lamports()? += amount_to_withdraw;

        ctx.accounts.balance_holder_pda.amount -= amount_to_withdraw;

        let remain_lamports = **from.try_borrow_mut_lamports()?;
        if ctx.accounts.balance_holder_pda.amount == 0 {
            msg!("All the lamports have been withdrawn, closing the lamports holder account account");
            **from.try_borrow_mut_lamports()? = 0;
            **ctx
                .accounts
                .sender
                .to_account_info()
                .try_borrow_mut_lamports()? += remain_lamports;
        }

        Ok(())
    }
}

#[derive(Accounts)]
pub struct DepositCtx<'info> {
    #[account(
        init, 
        payer = sender, 
        seeds = [recipient.key().as_ref(), sender.key().as_ref()],
        bump,
        space = 8 + BalanceHolderPDA::INIT_SPACE
    )]
    pub balance_holder_pda: Account<'info, BalanceHolderPDA>,
    #[account(mut)]
    pub sender: Signer<'info>,
    pub recipient: SystemAccount<'info>,
    pub system_program: Program<'info, System>,
}

#[derive(Accounts)]
pub struct WithdrawCtx<'info> {
    #[account(mut)]
    pub recipient: Signer<'info>,
    #[account(mut)]
    pub sender: SystemAccount<'info>, // The sender is needed to close the account if the remaining lamports are 0
    #[account(
        mut, 
        seeds = [recipient.key().as_ref(), sender.key().as_ref()],
        bump,
        constraint = balance_holder_pda.recipient == recipient.key() @ CustomError::InvalidRecipient
    )]
    pub balance_holder_pda: Account<'info, BalanceHolderPDA>,
    pub rent: Sysvar<'info, Rent>,
}

#[account]
#[derive(InitSpace)]
pub struct BalanceHolderPDA {
    pub sender: Pubkey,
    pub recipient: Pubkey,
    pub amount: u64,
}

#[error_code]
pub enum CustomError {
    #[msg("Invalid amount, must be greater than 0")]
    InvalidAmount,

    #[msg("Invalid recipient")]
    InvalidRecipient,
}
