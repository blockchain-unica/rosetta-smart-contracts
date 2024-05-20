use anchor_lang::prelude::*;

declare_id!("ArpHisvZS1EECpwisEM32EXMz2hoqmdhaQwY2TxWLiD7");

#[program]
pub mod auction {
    use super::*;

    pub fn start(
        ctx: Context<StartCtx>,
        auctioned_object: String,
        duration_slots: u64,
        starting_bid: u64,
    ) -> Result<()> {
        let auction_info = &mut ctx.accounts.auction_info;
        auction_info.seller = *ctx.accounts.seller.key;
        auction_info.highest_bidder = *ctx.accounts.seller.key; // The seller is the first bidder at the beginning
        auction_info.end_time = Clock::get()?.slot + duration_slots;
        auction_info.highest_bid = starting_bid;
        auction_info.object = auctioned_object;
        emit!(Start {});
        Ok(())
    }

    pub fn bid(
        ctx: Context<BidCtx>,
        auctioned_object: String,
        amount_to_deposit: u64,
    ) -> Result<()> {
        let auction_info = &mut ctx.accounts.auction_info;
        let bidder = &ctx.accounts.bidder;
        let current_highest_bidder = &ctx.accounts.current_highest_bidder;

        if Clock::get()?.slot > auction_info.end_time {
            return err!(CustomError::AuctionEnded);
        }

        if amount_to_deposit <= auction_info.highest_bid {
            return err!(CustomError::InvalidBidAmount);
        }

        let transfer_instruction = anchor_lang::solana_program::system_instruction::transfer(
            &bidder.key(),
            &auction_info.key(),
            amount_to_deposit,
        );

        anchor_lang::solana_program::program::invoke(
            &transfer_instruction,
            &[bidder.to_account_info(), auction_info.to_account_info()],
        )
        .unwrap();

        // Return founds to the previous bidder if it's not the first attempt (the first bidder is the seller)
        if auction_info.highest_bidder != auction_info.seller {
            **current_highest_bidder
                .to_account_info()
                .try_borrow_mut_lamports()? += auction_info.highest_bid;
            **auction_info.to_account_info().try_borrow_mut_lamports()? -= auction_info.highest_bid;
        }

        auction_info.highest_bid = amount_to_deposit;
        auction_info.highest_bidder = *bidder.key;

        emit!(Bid {
            sender: *bidder.key,
            amount: amount_to_deposit
        });

        Ok(())
    }

    pub fn end(ctx: Context<EndCtx>, auctioned_object: String) -> Result<()> {
        msg!("Auction name: {}", auctioned_object);
        let auction_info = &mut ctx.accounts.auction_info;
        let seller = &ctx.accounts.seller;

        if Clock::get()?.slot <= auction_info.end_time {
            return err!(CustomError::AuctionNotEnded);
        }

        // send the auction_info.object to the highest bidder

        **seller.to_account_info().try_borrow_mut_lamports()? +=
            **auction_info.to_account_info().try_borrow_mut_lamports()?;
        **auction_info.to_account_info().try_borrow_mut_lamports()? = 0;

        emit!(End {
            winner: auction_info.highest_bidder,
            amount: auction_info.highest_bid
        });

        Ok(())
    }
}

#[account]
#[derive(InitSpace)]
pub struct AuctionInfo {
    pub seller: Pubkey,         // 32 bytes
    pub highest_bidder: Pubkey, // 32 bytes
    pub end_time: u64,          // 8 bytes
    pub highest_bid: u64,       // 8 bytes
    #[max_len(30)]
    pub object: String,
}

#[derive(Accounts)]
#[instruction(auctioned_object: String)]
pub struct StartCtx<'info> {
    #[account(mut)]
    pub seller: Signer<'info>,
    #[account(
        init, 
        payer = seller, 
        seeds = [auctioned_object.as_ref()],
        bump,
        space = 8 + AuctionInfo::INIT_SPACE
    )]
    pub auction_info: Account<'info, AuctionInfo>,
    pub system_program: Program<'info, System>,
}

#[derive(Accounts)]
#[instruction(auctioned_object: String)]
pub struct BidCtx<'info> {
    #[account(mut)]
    pub bidder: Signer<'info>,
    #[account(
        mut,
        seeds = [auctioned_object.as_ref()],
        bump,
        constraint = auction_info.highest_bidder == *current_highest_bidder.key
    )]
    pub auction_info: Account<'info, AuctionInfo>,
    #[account(mut)]
    pub current_highest_bidder: SystemAccount<'info>,
    pub system_program: Program<'info, System>,
}

#[derive(Accounts)]
#[instruction(auctioned_object: String)]
pub struct EndCtx<'info> {
    #[account(mut)]
    pub seller: Signer<'info>,
    #[account(
        mut,
        seeds = [auctioned_object.as_ref()],
        bump,
        constraint = auction_info.seller == *seller.key @ CustomError::InvalidSeller
    )]
    pub auction_info: Account<'info, AuctionInfo>,
}

#[error_code]
pub enum CustomError {
    #[msg("The auction is not ended")]
    AuctionNotEnded,

    #[msg("The auction is ended")]
    AuctionEnded,

    #[msg("Invalid bid amount, should be higher than the previous bid")]
    InvalidBidAmount,

    #[msg("Invalid seller for the auction provided")]
    InvalidSeller,
}

#[event]
pub struct Start {}

#[event]
pub struct Bid {
    sender: Pubkey,
    amount: u64,
}

#[event]
pub struct End {
    winner: Pubkey,
    amount: u64,
}
