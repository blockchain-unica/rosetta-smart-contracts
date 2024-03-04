use anchor_lang::prelude::*;
use anchor_spl::associated_token::AssociatedToken;
use anchor_spl::token::{self, Mint, SetAuthority, Token, TokenAccount};
pub use spl_token::instruction::AuthorityType::AccountOwner;

declare_id!("CxkwtHKHwiLRHZgPVrjc2QALiiCEK2xTu25rN5wWh9Fc");

#[program]
pub mod token_transfer {
    use super::*;

    pub fn deposit(ctx: Context<DepositCtx>) -> Result<()> {
        msg!("Transferring the ATA to the holder_PDA");
        let (atas_holder_pda, _nonce) =
            Pubkey::find_program_address(&[b"atas_holder"], ctx.program_id);
        let token_program = &ctx.accounts.token_program;

        let cpi_accounts = SetAuthority {
            current_authority: ctx.accounts.sender.to_account_info().clone(),
            account_or_mint: ctx.accounts.temp_ata.to_account_info().clone(),
        };

        token::set_authority(
            CpiContext::new(token_program.to_account_info(), cpi_accounts),
            spl_token::instruction::AuthorityType::AccountOwner,
            Some(atas_holder_pda),
        )?;

        msg!("Setting the deposit information");
        let deposit_info = &mut ctx.accounts.deposit_info;
        deposit_info.recipient = *ctx.accounts.recipient.to_account_info().key;
        deposit_info.temp_ata = *ctx.accounts.temp_ata.to_account_info().key;

        Ok(())
    }

    pub fn withdraw(ctx: Context<WithdrawCtx>, amount_to_withdraw: u64) -> Result<()> {
        let multiplied_amount_to_withdraw =
            amount_to_withdraw * 10u64.pow(ctx.accounts.mint.decimals as u32);
        let temp_ata = &ctx.accounts.temp_ata;
        require!(
            amount_to_withdraw > 0 && temp_ata.amount >= multiplied_amount_to_withdraw,
            CustomError::InvalidAmount
        );

        let (atas_holder_pda, nonce) =
            Pubkey::find_program_address(&[b"atas_holder"], ctx.program_id);

        // Transfer
        // Why using invoke_signed instead of invoke?
        // Because the temp_ata account is owned by the atas_holder_pda, so the transfer instruction
        // must be signed by the atas_holder_pda
        // In Anchor we don't se the possibility to pass the authority as non AccountInfo
        msg!("Transferring the tokens to the recipient");
        anchor_lang::solana_program::program::invoke_signed(
            &spl_token::instruction::transfer(
                &anchor_spl::token::ID,
                &temp_ata.key(),
                &ctx.accounts.recipient_ata.key(),
                &atas_holder_pda, //owner
                &[&atas_holder_pda],
                amount_to_withdraw * 10u64.pow(ctx.accounts.mint.decimals as u32),
            )?,
            &[
                ctx.accounts.temp_ata.to_account_info().clone(),
                ctx.accounts.recipient_ata.to_account_info().clone(),
                ctx.accounts.atas_holder_pda.to_account_info().clone(),
                ctx.accounts.token_program.to_account_info().clone(),
            ],
            &[&[&b"atas_holder"[..], &[nonce]]],
        )?;

        msg!("temp amount: {}", temp_ata.amount);
        if temp_ata.amount == multiplied_amount_to_withdraw {
            msg!("Closing the temp_ata account");
            anchor_lang::solana_program::program::invoke_signed(
                &spl_token::instruction::close_account(
                    &anchor_spl::token::ID,
                    &temp_ata.key(),
                    &ctx.accounts.sender.to_account_info().key,
                    &atas_holder_pda,
                    &[&atas_holder_pda],
                )?,
                &[
                    ctx.accounts.temp_ata.to_account_info().clone(),
                    ctx.accounts.sender.to_account_info().clone(),
                    ctx.accounts.atas_holder_pda.to_account_info().clone(),
                    ctx.accounts.token_program.to_account_info().clone(),
                ],
                &[&[&b"atas_holder"[..], &[nonce]]],
            )?;

            msg!("Closing the deposit info account");
            let deposit_info = ctx.accounts.deposit_info.to_account_info();
            let sender = ctx.accounts.sender.to_account_info();
            let remain_lamports = **deposit_info.try_borrow_mut_lamports()?;
            **deposit_info.try_borrow_mut_lamports()? -= remain_lamports;
            **sender.try_borrow_mut_lamports()? += remain_lamports;
        }

        Ok(())
    }
}

#[account]
#[derive(InitSpace)]
pub struct DepositInfo {
    pub temp_ata: Pubkey,  // 32 bytes
    pub recipient: Pubkey, // 32 bytes
}

#[derive(Accounts)]
pub struct DepositCtx<'info> {
    #[account(mut)]
    pub sender: Signer<'info>,
    pub recipient: SystemAccount<'info>,
    pub mint: Account<'info, Mint>,
    #[account(
        constraint = temp_ata.mint == mint.key() @ CustomError::InvalidMint,
        constraint = temp_ata.amount > 0 @ CustomError::InvalidAmount
    )]
    pub temp_ata: Account<'info, TokenAccount>,
    #[account(
        init, 
        payer = sender, 
        seeds = [temp_ata.key().as_ref()],
        bump,
        space = 8 + DepositInfo::INIT_SPACE
    )]
    pub deposit_info: Account<'info, DepositInfo>,
    // Programs and other
    pub token_program: Program<'info, Token>,
    pub system_program: Program<'info, System>,
    pub associated_token_program: Program<'info, AssociatedToken>,
}

#[derive(Accounts)]
pub struct WithdrawCtx<'info> {
    pub mint: Account<'info, Mint>,
    #[account(mut)]
    pub recipient: Signer<'info>,
    #[account(mut)]
    pub sender: SystemAccount<'info>, // The sender is needed to close some accounts and to send back the remaining lamports
    #[account(
        mut,
        associated_token::mint = mint,
        associated_token::authority = recipient
    )]
    pub recipient_ata: Account<'info, TokenAccount>,
    #[account(
        mut,
        constraint = temp_ata.mint == mint.key() @ CustomError::InvalidMint,
    )]
    pub temp_ata: Account<'info, TokenAccount>,
    #[account(
        mut, 
        seeds = [temp_ata.key().as_ref()],
        bump,
        constraint = deposit_info.recipient == recipient.key() @ CustomError::InvalidRecipient
    )]
    pub deposit_info: Account<'info, DepositInfo>,
    /// CHECK: This is not dangerous because we don't read or write from this account
    #[account(
        mut,
        seeds = [b"atas_holder"],
        bump,
    )]
    pub atas_holder_pda: AccountInfo<'info>,
    // Programs and other
    pub token_program: Program<'info, Token>,
    pub system_program: Program<'info, System>,
    pub associated_token_program: Program<'info, AssociatedToken>,
    pub rent: Sysvar<'info, Rent>,
}

#[error_code]
pub enum CustomError {
    #[msg("Invalid amount, must be greater than 0 or in case of withdraw must be less than the amount in the temp_ata account")]
    InvalidAmount,

    #[msg("Invalid mint")]
    InvalidMint,

    #[msg("Invalid recipient")]
    InvalidRecipient,
}
