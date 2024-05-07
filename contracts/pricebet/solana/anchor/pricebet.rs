use anchor_lang::prelude::*;
use anchor_lang::system_program;
use pyth_sdk_solana::load_price_feed_from_account_info;
use std::str::FromStr;

// Pyth oracle
// https://www.quicknode.com/guides/solana-development/3rd-party-integrations/pyth-price-feeds
// https://docs.rs/crate/pyth-sdk-solana/latest/source/src/lib.rs

declare_id!("J5hRaCiXinCxGG2kYJf6943YCGShKVQYC9N8PT3K4Tmz");

const BTC_USDC_FEED: &str = "HovQMDrbAgAYPCmHVSrezcSmkMtXSSUsLDFANExrZh2J"; // only for the devnet cluster
const BTC_USDC_FEED_OWNER: &str = "gSbePebfvPy7tRqimPoVecS2UsBvYv46ynrzWocc92s"; // only for the devnet cluster
const STALENESS_THRESHOLD: u64 = 60; // staleness threshold in seconds

#[program]
pub mod price_bet {

    use super::*;

    pub fn init(ctx: Context<InitCtx>, delay: u64, wager: u64, rate: u64) -> Result<()> {
        let owner = ctx.accounts.owner.to_account_info();

        let bet_info = &mut ctx.accounts.bet_info;

        bet_info.owner = *owner.key;
        bet_info.player = Pubkey::default();
        bet_info.deadline = Clock::get()?.slot + delay;
        bet_info.wager = wager;
        bet_info.rate = rate;

        system_program::transfer(
            CpiContext::new(
                ctx.accounts.system_program.to_account_info(),
                system_program::Transfer {
                    from: owner.clone(),
                    to: bet_info.to_account_info().clone(),
                },
            ),
            bet_info.wager,
        )?;

        Ok(())
    }

    pub fn join(ctx: Context<JoinCtx>) -> Result<()> {
        let bet_info = &mut ctx.accounts.bet_info;
        let player = ctx.accounts.player.to_account_info();

        require!(
            bet_info.player == Pubkey::default(),
            CustomError::GameAlreadyJoined
        );

        bet_info.player = *player.key;

        system_program::transfer(
            CpiContext::new(
                ctx.accounts.system_program.to_account_info(),
                system_program::Transfer {
                    from: player.clone(),
                    to: bet_info.to_account_info().clone(),
                },
            ),
            bet_info.wager,
        )?;

        Ok(())
    }

    pub fn win(ctx: Context<WinCtx>) -> Result<()> {
        let bet_info = &mut ctx.accounts.bet_info;

        let price_account_info = &ctx.accounts.price_feed;

        require!(
            *price_account_info.owner == Pubkey::from_str(BTC_USDC_FEED_OWNER).unwrap(),
            CustomError::InvalidPriceFeedOwner
        );

        require!(
            bet_info.deadline > Clock::get()?.slot,
            CustomError::DeadlineReached
        );

        let price_feed = load_price_feed_from_account_info(&price_account_info).unwrap();
        let current_timestamp = Clock::get()?.unix_timestamp;
        let current_price = price_feed
            .get_price_no_older_than(current_timestamp, STALENESS_THRESHOLD)
            .unwrap();

        let price = u64::try_from(current_price.price).unwrap()
            / 10u64.pow(u32::try_from(-current_price.expo).unwrap());
        let display_confidence = u64::try_from(current_price.conf).unwrap()
            / 10u64.pow(u32::try_from(-current_price.expo).unwrap());

        msg!("BTC/USD price: ({} +- {})", price, display_confidence);

        require!(price > bet_info.rate, CustomError::NoWin);

        **ctx
            .accounts
            .player
            .to_account_info()
            .try_borrow_mut_lamports()? += bet_info.to_account_info().lamports();

        **bet_info.to_account_info().try_borrow_mut_lamports()? = 0;

        Ok(())
    }

    pub fn timeout(ctx: Context<TimeoutCtx>) -> Result<()> {
        let bet_info = &mut ctx.accounts.bet_info;
        let owner = ctx.accounts.owner.to_account_info();

        require!(
            bet_info.deadline < Clock::get()?.slot,
            CustomError::DeadlineNotReached
        );

        **owner.to_account_info().try_borrow_mut_lamports()? +=
            bet_info.to_account_info().lamports();

        **bet_info.to_account_info().try_borrow_mut_lamports()? = 0;

        Ok(())
    }
}

#[account]
#[derive(InitSpace)]
pub struct OracleBetInfo {
    pub owner: Pubkey,
    pub player: Pubkey,
    pub wager: u64,
    pub deadline: u64,
    pub rate: u64,
}

#[derive(Accounts)]
pub struct InitCtx<'info> {
    #[account(mut)]
    pub owner: Signer<'info>,
    #[account(
        init, 
        payer = owner, 
        seeds = [owner.key().as_ref()], 
        bump,
        space = 8 + OracleBetInfo::INIT_SPACE
    )]
    pub bet_info: Account<'info, OracleBetInfo>,
    pub system_program: Program<'info, System>,
}

#[derive(Accounts)]
pub struct JoinCtx<'info> {
    #[account(mut)]
    pub player: Signer<'info>,
    #[account(mut)]
    pub owner: SystemAccount<'info>,
    #[account(
        mut, 
        has_one = owner @ CustomError::InvalidParticipant, 
        seeds = [owner.key().as_ref()],  
        bump,
    )]
    pub bet_info: Account<'info, OracleBetInfo>,
    pub system_program: Program<'info, System>,
}

#[derive(Accounts)]
pub struct WinCtx<'info> {
    #[account(mut)]
    pub player: Signer<'info>,
    pub owner: SystemAccount<'info>,
    #[account(
        mut, 
        has_one = owner @ CustomError::InvalidParticipant, 
        has_one = player @ CustomError::InvalidParticipant,
        seeds = [owner.key().as_ref()],  
        bump,
    )]
    pub bet_info: Account<'info, OracleBetInfo>,
    /// CHECK
    #[account(address = Pubkey::from_str(BTC_USDC_FEED).unwrap() @ CustomError::InvalidPriceFeed)]
    pub price_feed: AccountInfo<'info>,
    pub system_program: Program<'info, System>,
}

#[derive(Accounts)]
pub struct TimeoutCtx<'info> {
    #[account(mut)]
    pub owner: Signer<'info>,
    #[account(
        mut,
        seeds = [owner.key().as_ref()], 
        bump,
    )]
    pub bet_info: Account<'info, OracleBetInfo>,
    pub system_program: Program<'info, System>,
}

#[error_code]
pub enum CustomError {
    #[msg("Invalid participant")]
    InvalidParticipant,

    #[msg("The deadline was not reached yet")]
    DeadlineNotReached,

    #[msg("The game was already joined by a player")]
    GameAlreadyJoined,

    #[msg("The deadline was reached")]
    DeadlineReached,

    #[msg("No win")]
    NoWin,

    #[msg("Invalid Price Feed")]
    InvalidPriceFeed,

    #[msg("Invalid Price Feed Owner")]
    InvalidPriceFeedOwner,
}
