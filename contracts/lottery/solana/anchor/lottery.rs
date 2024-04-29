use anchor_lang::prelude::*;
use borsh::{BorshDeserialize, BorshSerialize};
use anchor_lang::system_program;

declare_id!("6ARjupjjEaESHGUajXBfDbE7L4Ge8KPKuGpFk3XVMhfW");

const DEADLINE_EXTENSION: u64 = 10;

#[program]
pub mod lottery {
    use super::*;

    pub fn join(
        ctx: Context<JoinCtx>,
        hashlock1: [u8; 32],
        hashlock2: [u8; 32],
        delay: u64,
        amount: u64,
    ) -> Result<()> {
        let lottery_info = &mut ctx.accounts.lottery_info;
        let end_reveal = Clock::get()?.slot + delay;
        lottery_info.initialize(
            *ctx.accounts.player1.key,
            *ctx.accounts.player2.key,
            hashlock1,
            hashlock2,
            end_reveal,
        )?;

        let participant1 = ctx.accounts.player1.to_account_info();
        system_program::transfer(
            CpiContext::new(
                ctx.accounts.system_program.to_account_info(),
                system_program::Transfer {
                    from: participant1.clone(),
                    to: lottery_info.to_account_info().clone(),
                },
            ),
            amount,
        )?;

        let participant2 = ctx.accounts.player2.to_account_info();
        system_program::transfer(
            CpiContext::new(
                ctx.accounts.system_program.to_account_info(),
                system_program::Transfer {
                    from: participant2.clone(),
                    to: lottery_info.to_account_info().clone(),
                },
            ),
            amount,
        )?;

        Ok(())
    }

    pub fn reveal_p1(ctx: Context<RevealP1Ctx>, secret: String) -> Result<()> {
        let lottery_info = &mut ctx.accounts.lottery_info;
        lottery_info.reveal_p1(&secret)?;
        Ok(())
    }

    pub fn reveal_p2(ctx: Context<RevealP2Ctx>, secret: String) -> Result<()> {
        let lottery_info = &mut ctx.accounts.lottery_info;
        lottery_info.reveal_p2(&secret)?;

        let winner = lottery_info.get_winner()?;

        if winner == *ctx.accounts.player1.key {
            let player1 = &ctx.accounts.player1;
            **player1.to_account_info().try_borrow_mut_lamports()? +=
                lottery_info.to_account_info().lamports();
        } else {
            let player2 = &ctx.accounts.player2;
            **player2.to_account_info().try_borrow_mut_lamports()? +=
                lottery_info.to_account_info().lamports();
        }
        **lottery_info.to_account_info().try_borrow_mut_lamports()? = 0;
        Ok(())
    }

    pub fn redeem_if_p1_no_reveal(ctx: Context<RedeemIfP1NoRevealCtx>) -> Result<()> {
        let lottery_info = &mut ctx.accounts.lottery_info;
        lottery_info.check_redeem_if_p1_no_reveal()?;
        let player2 = &ctx.accounts.player2;
        **player2.to_account_info().try_borrow_mut_lamports()? +=
            lottery_info.to_account_info().lamports();
        **lottery_info.to_account_info().try_borrow_mut_lamports()? = 0;
        Ok(())
    }

    pub fn redeem_if_p2_no_reveal(ctx: Context<RedeemIfP2NoRevealCtx>) -> Result<()> {
        let lottery_info = &mut ctx.accounts.lottery_info;
        lottery_info.check_redeem_if_p2_no_reveal()?;
        let player1 = &ctx.accounts.player1;
        **player1.to_account_info().try_borrow_mut_lamports()? +=
            lottery_info.to_account_info().lamports();
        **lottery_info.to_account_info().try_borrow_mut_lamports()? = 0;
        Ok(())
    }
}

#[derive(BorshSerialize, BorshDeserialize, Debug, PartialEq, Clone, InitSpace)]
pub enum LotteryState {
    Init = 0,
    RevealP1 = 1,
    RevealP2 = 2,
}

#[account]
#[derive(InitSpace)]
pub struct LotteryInfo {
    pub state: LotteryState,
    pub player1: Pubkey,
    pub player2: Pubkey,
    pub hashlock1: [u8; 32],
    #[max_len(30)]
    pub secret1: String,
    pub hashlock2: [u8; 32],
    #[max_len(30)]
    pub secret2: String,
    pub end_reveal: u64,
}

impl LotteryInfo {
    pub fn initialize(
        &mut self,
        player1: Pubkey,
        player2: Pubkey,
        hashlock1: [u8; 32],
        hashlock2: [u8; 32],
        end_reveal: u64,
    ) -> Result<()> {
        require!(hashlock1 != hashlock2, CustomError::TwoEqualHashes);
        require!(
            Clock::get()?.slot < end_reveal,
            CustomError::InvalidTimeoutProvided
        );
        self.state = LotteryState::Init;
        self.player1 = player1;
        self.player2 = player2;
        self.hashlock1 = hashlock1;
        self.hashlock2 = hashlock2;
        self.end_reveal = end_reveal;
        Ok(())
    }

    pub fn reveal_p1(&mut self, secret: &String) -> Result<()> {
        require!(self.state == LotteryState::Init, CustomError::InvalidState);
        require!(
            Clock::get()?.slot < self.end_reveal,
            CustomError::TimeoutReached
        );
        let hash = anchor_lang::solana_program::keccak::hash(
            &<String as Clone>::clone(&secret).into_bytes(),
        )
        .to_bytes();
        require!(hash == self.hashlock1, CustomError::InvalidSecret);
        self.secret1 = secret.clone();
        self.state = LotteryState::RevealP1;
        Ok(())
    }

    pub fn reveal_p2(&mut self, secret: &String) -> Result<()> {
        require!(
            self.state == LotteryState::RevealP1,
            CustomError::InvalidState
        );
        // the deadline extension is needed to avoid attacks where
        // player1 reveals close to the deadline
        require!(
            Clock::get()?.slot < self.end_reveal + DEADLINE_EXTENSION,
            CustomError::InvalidTimeoutProvided
        );
        let hash = anchor_lang::solana_program::keccak::hash(
            &<String as Clone>::clone(&secret).into_bytes(),
        )
        .to_bytes();
        require!(hash == self.hashlock2, CustomError::InvalidSecret);
        self.secret2 = secret.clone();
        self.state = LotteryState::RevealP2;
        Ok(())
    }

    pub fn get_winner(&self) -> Result<Pubkey> {
        require!(
            self.state == LotteryState::RevealP2,
            CustomError::InvalidState
        );
        let sum = self.secret1.len() + self.secret2.len();
        if sum % 2 == 0 {
            Ok(self.player1)
        } else {
            Ok(self.player2)
        }
    }

    pub fn check_redeem_if_p1_no_reveal(&self) -> Result<()> {
        require!(self.state == LotteryState::Init, CustomError::InvalidState);
        require!(
            Clock::get()?.slot > self.end_reveal,
            CustomError::TimeoutNotReached
        );
        Ok(())
    }

    pub fn check_redeem_if_p2_no_reveal(&self) -> Result<()> {
        require!(
            self.state == LotteryState::RevealP1,
            CustomError::InvalidState
        );
        require!(
            Clock::get()?.slot > self.end_reveal + DEADLINE_EXTENSION,
            CustomError::TimeoutNotReached
        );
        Ok(())
    }
}

#[derive(Accounts)]
pub struct JoinCtx<'info> {
    #[account(mut)]
    pub player1: Signer<'info>,
    #[account(mut)]
    pub player2: Signer<'info>,
    #[account(
        init, 
        payer = player1, 
        seeds = [player1.key().as_ref(), player2.key().as_ref()], 
        bump,
        space = 8 + LotteryInfo::INIT_SPACE
    )]
    pub lottery_info: Account<'info, LotteryInfo>,
    pub system_program: Program<'info, System>,
}

#[derive(Accounts)]
pub struct RevealP1Ctx<'info> {
    #[account(mut)]
    pub player1: Signer<'info>,
    pub player2: SystemAccount<'info>,
    #[account(
        mut,
        seeds = [player1.key().as_ref(), player2.key().as_ref()], 
        bump,
    )]
    pub lottery_info: Account<'info, LotteryInfo>,
}

#[derive(Accounts)]
pub struct RevealP2Ctx<'info> {
    #[account(mut)]
    pub player1: SystemAccount<'info>,
    #[account(mut)]
    pub player2: Signer<'info>,
    #[account(
        mut,
        seeds = [player1.key().as_ref(), player2.key().as_ref()], 
        bump,
    )]
    pub lottery_info: Account<'info, LotteryInfo>,
}

#[derive(Accounts)]
pub struct RedeemIfP1NoRevealCtx<'info> {
    pub player1: SystemAccount<'info>,
    #[account(mut)]
    pub player2: Signer<'info>,
    #[account(
        mut,
        seeds = [player1.key().as_ref(), player2.key().as_ref()], 
        bump,
    )]
    pub lottery_info: Account<'info, LotteryInfo>,
}

#[derive(Accounts)]
pub struct RedeemIfP2NoRevealCtx<'info> {
    #[account(mut)]
    pub player1: Signer<'info>,
    pub player2: SystemAccount<'info>,
    #[account(
        mut,
        seeds = [player1.key().as_ref(), player2.key().as_ref()], 
        bump,
    )]
    pub lottery_info: Account<'info, LotteryInfo>,
}

#[derive(Accounts)]
pub struct WinCtx {}

#[error_code]
pub enum CustomError {
    #[msg("Invalid state")]
    InvalidState,

    #[msg("Invalid timeout provided")]
    InvalidTimeoutProvided,

    #[msg("Timeout reached")]
    TimeoutReached,

    #[msg("Timeout not reached")]
    TimeoutNotReached,

    #[msg("Invalid secret")]
    InvalidSecret,

    #[msg("Two equal hashes")]
    TwoEqualHashes,
}
