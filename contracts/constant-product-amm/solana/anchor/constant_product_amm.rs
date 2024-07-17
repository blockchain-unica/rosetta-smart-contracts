use anchor_lang::prelude::*;
use anchor_spl::associated_token::AssociatedToken;
use anchor_spl::token::{self, Mint, SetAuthority, Token, TokenAccount, Transfer};
pub use spl_token::instruction::AuthorityType::AccountOwner;

declare_id!("ADY3EuA5hCthUru7JDWrTB1CqqxZxthZGWmvYGUw96rn");

#[program]
pub mod constant_product_amm {
    use super::*;

    pub fn initialize(ctx: Context<InitializeCtx>) -> Result<()> {
        let (amm_info_pda, _amm_bump) = Pubkey::find_program_address(
            &[
                b"amm",
                ctx.accounts.mint0.to_account_info().key.as_ref(),
                ctx.accounts.mint1.to_account_info().key.as_ref(),
            ],
            ctx.program_id,
        );

        msg!("Transferring the token_account0 to the holder_PDA");
        let cpi_accounts = SetAuthority {
            current_authority: ctx.accounts.initializer.to_account_info().clone(),
            account_or_mint: ctx.accounts.token_account0.to_account_info().clone(),
        };
        token::set_authority(
            CpiContext::new(ctx.accounts.token_program.to_account_info(), cpi_accounts),
            spl_token::instruction::AuthorityType::AccountOwner,
            Some(amm_info_pda),
        )?;

        msg!("Transferring the token_account1 to the holder_PDA");
        let cpi_accounts = SetAuthority {
            current_authority: ctx.accounts.initializer.to_account_info().clone(),
            account_or_mint: ctx.accounts.token_account1.to_account_info().clone(),
        };
        token::set_authority(
            CpiContext::new(ctx.accounts.token_program.to_account_info(), cpi_accounts),
            spl_token::instruction::AuthorityType::AccountOwner,
            Some(amm_info_pda),
        )?;

        msg!("Initializing the data for the AMM info");
        let amm_info = &mut ctx.accounts.amm_info;
        amm_info.mint0 = *ctx.accounts.mint0.to_account_info().key;
        amm_info.mint1 = *ctx.accounts.mint1.to_account_info().key;
        amm_info.token_account0 = *ctx.accounts.token_account0.to_account_info().key;
        amm_info.token_account1 = *ctx.accounts.token_account1.to_account_info().key;
        amm_info.ever_deposited = false;
        amm_info.reserve0 = 0;
        amm_info.reserve1 = 0;
        amm_info.supply = 0;

        Ok(())
    }

    pub fn deposit(ctx: Context<DepositCtx>, amount0: u64, amount1: u64) -> Result<()> {
        require!(amount0 > 0, CustomError::InvalidAmount);
        require!(amount1 > 0, CustomError::InvalidAmount);

        let amm_info = &mut ctx.accounts.amm_info;

        token::transfer(
            CpiContext::new(
                ctx.accounts.token_program.to_account_info(),
                Transfer {
                    from: ctx
                        .accounts
                        .senders_token_account0
                        .to_account_info()
                        .clone(),
                    to: ctx.accounts.pdas_token_account0.to_account_info().clone(),
                    authority: ctx.accounts.sender.to_account_info().clone(),
                },
            ),
            amount0 * 10u64.pow(ctx.accounts.mint0.decimals as u32),
        )?;

        token::transfer(
            CpiContext::new(
                ctx.accounts.token_program.to_account_info(),
                Transfer {
                    from: ctx
                        .accounts
                        .senders_token_account1
                        .to_account_info()
                        .clone(),
                    to: ctx.accounts.pdas_token_account1.to_account_info().clone(),
                    authority: ctx.accounts.sender.to_account_info().clone(),
                },
            ),
            amount1 * 10u64.pow(ctx.accounts.mint1.decimals as u32),
        )?;

        // Calculate the amount of tokens to mint
        let to_mint: u64;

        if amm_info.ever_deposited {
            if (amm_info.reserve0 * amount1) != (amm_info.reserve1 * amount0) {
                return err!(CustomError::DepPreconditionFailed);
            }
            to_mint = (amount0 * amm_info.supply) / amm_info.reserve0;
        } else {
            amm_info.ever_deposited = true;
            to_mint = amount0;
        }

        if to_mint <= 0 {
            return err!(CustomError::DepPreconditionFailed);
        }

        amm_info.supply += to_mint;
        amm_info.reserve0 += amount0;
        amm_info.reserve1 += amount1;

        let minted_pda = &mut ctx.accounts.minted_pda;
        minted_pda.minted += to_mint;

        Ok(())
    }

    pub fn redeem(ctx: Context<RedeemOrSwapCtx>, amount: u64) -> Result<()> {
        let amm_info = &mut ctx.accounts.amm_info;
        let minted_pda = &mut ctx.accounts.minted_pda;

        require!(
            minted_pda.minted >= amount,
            CustomError::InvalidAmountForRedeem
        );
        require!(
            amount <= amm_info.supply,
            CustomError::InvalidAmountForRedeem
        );

        let amount0: u64 = (amount * amm_info.reserve0) / amm_info.supply;
        let amount1: u64 = (amount * amm_info.reserve1) / amm_info.supply;

        // Transfer the tokens to the sender
        let (amm_info_pda, amm_bump) = Pubkey::find_program_address(
            &[
                b"amm",
                ctx.accounts.mint0.to_account_info().key.as_ref(),
                ctx.accounts.mint1.to_account_info().key.as_ref(),
            ],
            ctx.program_id,
        );

        let amm_pda_signer_seeds: &[&[&[u8]]] = &[&[
            "amm".as_bytes(),
            amm_info.mint0.as_ref(),
            amm_info.mint1.as_ref(),
            &[amm_bump],
        ]];

        anchor_lang::solana_program::program::invoke_signed(
            &spl_token::instruction::transfer(
                &anchor_spl::token::ID,
                &ctx.accounts.pdas_token_account0.key(),
                &ctx.accounts.senders_token_account0.key(),
                &amm_info_pda, //owner
                &[&amm_info_pda],
                amount0 * 10u64.pow(ctx.accounts.mint0.decimals as u32),
            )?,
            &[
                ctx.accounts.pdas_token_account0.to_account_info().clone(),
                ctx.accounts
                    .senders_token_account0
                    .to_account_info()
                    .clone(),
                amm_info.to_account_info().clone(),
                ctx.accounts.token_program.to_account_info().clone(),
            ],
            &amm_pda_signer_seeds,
        )?;

        anchor_lang::solana_program::program::invoke_signed(
            &spl_token::instruction::transfer(
                &anchor_spl::token::ID,
                &ctx.accounts.pdas_token_account1.key(),
                &ctx.accounts.senders_token_account1.key(),
                &amm_info_pda, //owner
                &[&amm_info_pda],
                amount1 * 10u64.pow(ctx.accounts.mint1.decimals as u32),
            )?,
            &[
                ctx.accounts.pdas_token_account1.to_account_info().clone(),
                ctx.accounts
                    .senders_token_account1
                    .to_account_info()
                    .clone(),
                amm_info.to_account_info().clone(),
                ctx.accounts.token_program.to_account_info().clone(),
            ],
            &amm_pda_signer_seeds,
        )?;

        // Update the AMM info data
        amm_info.supply -= amount;
        amm_info.reserve0 -= amount0;
        amm_info.reserve1 -= amount1;

        // Update the minted_pda data
        minted_pda.minted -= amount;

        Ok(())
    }

    pub fn swap(
        ctx: Context<RedeemOrSwapCtx>,
        is_mint0: bool,
        amount_in: u64,
        min_out_amount: u64,
    ) -> Result<()> {
        require!(amount_in > 0, CustomError::InvalidAmount);

        let amm_info = &mut ctx.accounts.amm_info;
        let senders_token_account0 = ctx
            .accounts
            .senders_token_account0
            .to_account_info()
            .clone();
        let senders_token_account1 = ctx
            .accounts
            .senders_token_account1
            .to_account_info()
            .clone();
        let pdas_token_account0 = ctx.accounts.pdas_token_account0.to_account_info().clone();
        let pdas_token_account1 = ctx.accounts.pdas_token_account1.to_account_info().clone();

        let (reserve_in, reserve_out) = if is_mint0 {
            (amm_info.reserve0, amm_info.reserve1)
        } else {
            (amm_info.reserve1, amm_info.reserve0)
        };

        let (source, destination) = if is_mint0 {
            (senders_token_account0.clone(), pdas_token_account0.clone())
        } else {
            (senders_token_account1.clone(), pdas_token_account1.clone())
        };

        token::transfer(
            CpiContext::new(
                ctx.accounts.token_program.to_account_info(),
                Transfer {
                    from: source,
                    to: destination,
                    authority: ctx.accounts.sender.to_account_info().clone(),
                },
            ),
            amount_in * 10u64.pow(ctx.accounts.mint1.decimals as u32),
        )?;

        msg!("amount_in: {}", amount_in);
        msg!("reserve_out: {}", reserve_out);
        msg!("reserve_in: {}", reserve_in);
        msg!("amount_in: {}", min_out_amount);
        let amount_out = amount_in * reserve_out / (reserve_in + amount_in);

        msg!("Amount out: {}", amount_out);

        if amount_out < min_out_amount {
            return err!(CustomError::AmountLessThanMinOutAmount);
        }

        let (source, destination) = if is_mint0 {
            (pdas_token_account1, senders_token_account1)
        } else {
            (pdas_token_account0, senders_token_account0)
        };

        let (amm_info_pda, amm_bump) = Pubkey::find_program_address(
            &[
                b"amm",
                ctx.accounts.mint0.to_account_info().key.as_ref(),
                ctx.accounts.mint1.to_account_info().key.as_ref(),
            ],
            ctx.program_id,
        );

        let amm_pda_signer_seeds: &[&[&[u8]]] = &[&[
            "amm".as_bytes(),
            amm_info.mint0.as_ref(),
            amm_info.mint1.as_ref(),
            &[amm_bump],
        ]];

        anchor_lang::solana_program::program::invoke_signed(
            &spl_token::instruction::transfer(
                &anchor_spl::token::ID,
                &source.key(),
                &destination.key(),
                &amm_info_pda, //owner
                &[&amm_info_pda],
                amount_out * 10u64.pow(ctx.accounts.mint1.decimals as u32),
            )?,
            &[
                source.to_account_info().clone(),
                destination.to_account_info().clone(),
                amm_info.to_account_info().clone(),
                ctx.accounts.token_program.to_account_info().clone(),
            ],
            &amm_pda_signer_seeds,
        )?;

        if is_mint0 {
            amm_info.reserve0 = amm_info.reserve0 + amount_in;
            amm_info.reserve1 = amm_info.reserve1 - amount_out;
        } else {
            amm_info.reserve0 = amm_info.reserve0 - amount_out;
            amm_info.reserve1 = amm_info.reserve1 + amount_in;
        }

        Ok(())
    }
}

#[account]
#[derive(InitSpace)]
pub struct AmmInfo {
    pub mint0: Pubkey,          // 32 bytes
    pub mint1: Pubkey,          // 32 bytes
    pub token_account0: Pubkey, // 32 bytes
    pub token_account1: Pubkey, // 32 bytes
    pub reserve0: u64,          // 8 bytes
    pub reserve1: u64,          // 8 bytes
    pub ever_deposited: bool,   // 1 byte
    pub supply: u64,            // 8 bytes
}

#[account]
#[derive(InitSpace)]
pub struct MintedPDA {
    pub minted: u64, // 8 bytes
}

#[derive(Accounts)]
pub struct InitializeCtx<'info> {
    #[account(mut)]
    pub initializer: Signer<'info>,
    #[account(
        init_if_needed, 
        payer = initializer, 
        seeds = ["amm".as_ref(), mint0.key().as_ref(), mint1.key().as_ref()],
        bump,
        space = 8 + AmmInfo::INIT_SPACE
    )]
    pub amm_info: Account<'info, AmmInfo>,
    pub mint0: Account<'info, Mint>,
    pub mint1: Account<'info, Mint>,
    #[account(constraint = token_account0.mint == mint0.key() @ CustomError::InvalidMint)]
    pub token_account0: Account<'info, TokenAccount>,
    #[account(constraint = token_account1.mint == mint1.key() @ CustomError::InvalidMint)]
    pub token_account1: Account<'info, TokenAccount>,
    // Programs and other
    pub token_program: Program<'info, Token>,
    pub system_program: Program<'info, System>,
    pub associated_token_program: Program<'info, AssociatedToken>,
}

#[derive(Accounts)]
pub struct DepositCtx<'info> {
    #[account(mut)]
    pub sender: Signer<'info>,
    pub mint0: Account<'info, Mint>,
    pub mint1: Account<'info, Mint>,
    #[account(
        mut,
        seeds = ["amm".as_ref(), mint0.key().as_ref(), mint1.key().as_ref()],
        bump,
    )]
    pub amm_info: Box<Account<'info, AmmInfo>>, // Box is needed to avoid stack overflow (see: https://stackoverflow.com/questions/70747729/how-do-i-avoid-my-anchor-program-throwing-an-access-violation-in-stack-frame)
    #[account(
        init_if_needed,
        payer = sender, 
        seeds = ["minted".as_ref(), sender.key().as_ref()],
        bump,
        space = 8 + MintedPDA::INIT_SPACE
    )]
    pub minted_pda: Account<'info, MintedPDA>,
    #[account(
        mut, 
        associated_token::mint = mint0,
        associated_token::authority = sender
    )]
    pub senders_token_account0: Account<'info, TokenAccount>,
    #[account(
        mut, 
        associated_token::mint = mint1,
        associated_token::authority = sender
    )]
    pub senders_token_account1: Account<'info, TokenAccount>,
    #[account(
        mut, 
        constraint = pdas_token_account0.mint == mint0.key() @ CustomError::InvalidMint,
        constraint = pdas_token_account0.key() == amm_info.token_account0 @ CustomError::InvalidTokenAccount
    )]
    pub pdas_token_account0: Account<'info, TokenAccount>,
    #[account(
        mut, 
        constraint = pdas_token_account1.mint == mint1.key() @ CustomError::InvalidMint,
        constraint = pdas_token_account1.key() == amm_info.token_account1 @ CustomError::InvalidTokenAccount
    )]
    pub pdas_token_account1: Account<'info, TokenAccount>,
    // Programs and other
    pub token_program: Program<'info, Token>,
    pub system_program: Program<'info, System>,
    pub associated_token_program: Program<'info, AssociatedToken>,
}

#[derive(Accounts)]
pub struct RedeemOrSwapCtx<'info> {
    #[account(mut)]
    pub sender: Signer<'info>,
    pub mint0: Account<'info, Mint>,
    pub mint1: Account<'info, Mint>,
    #[account(
        mut,
        seeds = ["amm".as_ref(), mint0.key().as_ref(), mint1.key().as_ref()],
        bump,
    )]
    pub amm_info: Account<'info, AmmInfo>,
    #[account(
        seeds = ["minted".as_ref(), sender.key().as_ref()],
        bump,
    )]
    pub minted_pda: Account<'info, MintedPDA>,
    #[account(
        mut, 
        associated_token::mint = mint0,
        associated_token::authority = sender
    )]
    pub senders_token_account0: Account<'info, TokenAccount>,
    #[account(
        mut, 
        associated_token::mint = mint1,
        associated_token::authority = sender
    )]
    pub senders_token_account1: Account<'info, TokenAccount>,
    #[account(
        mut, 
        constraint = pdas_token_account0.mint == mint0.key() @ CustomError::InvalidMint,
        constraint = pdas_token_account0.key() == amm_info.token_account0 @ CustomError::InvalidTokenAccount
    )]
    pub pdas_token_account0: Account<'info, TokenAccount>,
    #[account(
        mut, 
        constraint = pdas_token_account1.mint == mint1.key() @ CustomError::InvalidMint,
        constraint = pdas_token_account1.key() == amm_info.token_account1 @ CustomError::InvalidTokenAccount
    )]
    pub pdas_token_account1: Account<'info, TokenAccount>,
    // Programs and other
    pub token_program: Program<'info, Token>,
    pub system_program: Program<'info, System>,
    pub associated_token_program: Program<'info, AssociatedToken>,
}

#[error_code]
pub enum CustomError {
    #[msg("Invalid amount")]
    InvalidAmount,

    #[msg("Invalid amount for redeem, must be less or equal than the amount minted and also less than the supply")]
    InvalidAmountForRedeem,

    #[msg("Invalid mint")]
    InvalidMint,

    #[msg("Dep precondition failed")]
    DepPreconditionFailed,

    #[msg("Invalid token account")]
    InvalidTokenAccount,

    #[msg("Amount less than the min out amount")]
    AmountLessThanMinOutAmount,
}
