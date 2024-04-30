use anchor_lang::prelude::*;
use pyth_sdk_solana::load_price_feed_from_account_info;
use std::str::FromStr;
use anchor_lang::system_program;

// Pyth oracle
// https://www.quicknode.com/guides/solana-development/3rd-party-integrations/pyth-price-feeds
// https://docs.rs/crate/pyth-sdk-solana/latest/source/src/lib.rs

declare_id!("CL23ttCn79XGd99jYure1HCPzjGDtEgmESo1JJN5p59Q");

const BTC_USDC_FEED: &str = "HovQMDrbAgAYPCmHVSrezcSmkMtXSSUsLDFANExrZh2J"; // only for the devnet cluster
const BTC_USDC_FEED_OWNER: &str = "gSbePebfvPy7tRqimPoVecS2UsBvYv46ynrzWocc92s"; // only for the devnet cluster
const STALENESS_THRESHOLD: u64 = 60; // staleness threshold in seconds

#[program]
pub mod price_bet {

    use super::*;

    pub fn join(ctx: Context<JoinCtx>, delay: u64, wager: u64, rate: u64) -> Result<()> {
        let oracle_bet_info = &mut ctx.accounts.oracle_bet_info;

        oracle_bet_info.initialize(
            *ctx.accounts.participant1.key,
            *ctx.accounts.participant2.key,
            Clock::get()?.slot + delay,
            wager,
            rate,
        );

        let participant1 = ctx.accounts.participant1.to_account_info();
        system_program::transfer(
            CpiContext::new(
                ctx.accounts.system_program.to_account_info(),
                system_program::Transfer {
                    from: participant1.clone(),
                    to: oracle_bet_info.to_account_info().clone(),
                },
            ),
            oracle_bet_info.wager,
        )?;

        let participant2 = ctx.accounts.participant2.to_account_info();
        system_program::transfer(
            CpiContext::new(
                ctx.accounts.system_program.to_account_info(),
                system_program::Transfer {
                    from: participant2.clone(),
                    to: oracle_bet_info.to_account_info().clone(),
                },
            ),
            oracle_bet_info.wager,
        )?;

        Ok(())
    }

    pub fn win(ctx: Context<WinCtx>) -> Result<()> {
        let oracle_bet_info = &mut ctx.accounts.oracle_bet_info;

        let price_account_info = &ctx.accounts.price_feed;

        require!(
            *price_account_info.owner == Pubkey::from_str(BTC_USDC_FEED_OWNER).unwrap(),
            CustomError::InvalidPriceFeedOwner
        );

        require!(
            oracle_bet_info.deadline > Clock::get()?.slot,
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

        require!(price > oracle_bet_info.rate, CustomError::NoWin);

        **ctx
            .accounts
            .participant2
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

        require!(
            oracle_bet_info.deadline < Clock::get()?.slot,
            CustomError::DeadlineNotReached
        );

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
    pub participant1: Pubkey,
    pub participant2: Pubkey,
    pub wager: u64,
    pub deadline: u64,
    pub rate: u64,
}

impl OracleBetInfo {
    pub fn initialize(
        &mut self,
        participant1: Pubkey,
        participant2: Pubkey,
        deadline: u64,
        wager: u64,
        rate: u64,
    ) {
        self.participant1 = participant1;
        self.participant2 = participant2;
        self.deadline = deadline;
        self.wager = wager;
        self.rate = rate;
    }
}

#[derive(Accounts)]
pub struct JoinCtx<'info> {
    #[account(mut)]
    pub participant1: Signer<'info>,
    #[account(mut)]
    pub participant2: Signer<'info>,
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
    pub participant1: SystemAccount<'info>,
    #[account(mut)]
    pub participant2: Signer<'info>,
    #[account(
        mut, 
        has_one = participant1 @ CustomError::InvalidParticipant, 
        has_one = participant2 @ CustomError::InvalidParticipant,
        seeds = [participant1.key().as_ref(), participant2.key().as_ref()], 
        bump,
    )]
    pub oracle_bet_info: Account<'info, OracleBetInfo>,
    /// CHECK
    #[account(address = Pubkey::from_str(BTC_USDC_FEED).unwrap() @ CustomError::InvalidPriceFeed)]
    pub price_feed: AccountInfo<'info>,
    pub system_program: Program<'info, System>,
}

#[derive(Accounts)]
pub struct TimeoutCtx<'info> {
    #[account(mut, constraint =  *participant1.key == oracle_bet_info.participant1  @ CustomError::InvalidParticipant)]
    pub participant1: Signer<'info>,
    #[account(constraint =  *participant2.key == oracle_bet_info.participant2 @ CustomError::InvalidParticipant)]
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

    #[msg("The deadline was not reached yet")]
    DeadlineNotReached,

    #[msg("The deadline was reached")]
    DeadlineReached,

    #[msg("No win")]
    NoWin,

    #[msg("Invalid Price Feed")]
    InvalidPriceFeed,

    #[msg("Invalid Price Feed Owner")]
    InvalidPriceFeedOwner,
}
