use anchor_lang::prelude::*;

declare_id!("2nh21WYLmcWLt3TvxzDyTb8rwB8FSn99XAXDEtsNn68x");

#[program]
pub mod payment_splitter {
    use super::*;

    pub fn initialize(
        ctx: Context<InitializeCtx>,
        lamports_to_transfer: u64,
        required_space: u64,
        shares_amounts: Vec<u64>,
    ) -> Result<()> {
        msg!(
            "Initializing PaymentSplitter with {} lamports and the space of {} bytes",
            lamports_to_transfer,
            required_space
        );

        let initializer = &mut ctx.accounts.initializer;
        let ps_info = &mut ctx.accounts.ps_info;

        let transfer_instruction = anchor_lang::solana_program::system_instruction::transfer(
            &initializer.key(),
            &ps_info.key(),
            lamports_to_transfer,
        );
        anchor_lang::solana_program::program::invoke(
            &transfer_instruction,
            &[initializer.to_account_info(), ps_info.to_account_info()],
        )
        .unwrap();

        ps_info.current_lamports = lamports_to_transfer;

        let payees = ctx.remaining_accounts;

        require!(!payees.is_empty(), CustomError::NoPayeesProvided);
        require!(
            payees.len() == shares_amounts.len(),
            CustomError::PayeesSharesLengthMismatch
        );

        ps_info.released_amounts = vec![0; payees.len()];

        for paye in payees.iter() {
            // Check if the payee already has shares
            for already_present_payee in ps_info.payees.iter() {
                if already_present_payee == paye.key {
                    return err!(CustomError::AccountAlreadyHasShares);
                }
            }

            // Add the new payee
            ps_info.payees.push(*paye.key);

            // Add the new payee's share amount
            let payee_index = ps_info.payees.len() - 1;
            let payee_share_amount = shares_amounts[payee_index];
            require!(
                payee_share_amount > 0,
                CustomError::NegativeOrZeroShareAmount
            );
            ps_info.shares_amounts.push(payee_share_amount);

            msg!(
                "Added payee {:?} with share amount {}",
                paye.key,
                payee_share_amount
            );
        }

        Ok(())
    }

    pub fn release(_ctx: Context<ReleaseCtx>) -> Result<()> {
        let payee = &mut _ctx.accounts.payee;
        let initializer = &mut _ctx.accounts.initializer;
        let ps_info = &mut _ctx.accounts.ps_info;

        let payee_index = ps_info
            .payees
            .iter()
            .position(|&r| r == *payee.key)
            .unwrap();
        let payee_share_amount = ps_info.shares_amounts[payee_index];
        require!(payee_share_amount > 0, CustomError::PayeeHasNoShares);

        let payment = ps_info.get_releasable_for_account(payee.key);
        require!(payment > 0, CustomError::PayeeNotDuePayment);

        ps_info.released_amounts[payee_index] += payment;
        ps_info.current_lamports -= payment;

        // Transfer lamports to the payee
        **payee.to_account_info().try_borrow_mut_lamports()? += payment;
        **ps_info.to_account_info().try_borrow_mut_lamports()? -= payment;

        // If all the shares have been released, close the account and return the remaining lamports to the initializer
        let rent_lamports = Rent::get()?.minimum_balance(ps_info.to_account_info().data_len());
        let current_lamports = ps_info.to_account_info().lamports();
        if current_lamports - payment < rent_lamports {
            **initializer.to_account_info().try_borrow_mut_lamports()? +=
                **ps_info.to_account_info().try_borrow_mut_lamports()?;
            **ps_info.to_account_info().try_borrow_mut_lamports()? = 0;
        }

        Ok(())
    }
}

#[account]
pub struct PaymentSplitterInfo {
    pub current_lamports: u64,
    pub payees: Vec<Pubkey>,
    pub shares_amounts: Vec<u64>,
    pub released_amounts: Vec<u64>,
}

impl PaymentSplitterInfo {
    pub fn get_total_shares(&self) -> u64 {
        return self.shares_amounts.iter().sum();
    }

    pub fn get_total_released(&self) -> u64 {
        return self.released_amounts.iter().sum();
    }

    pub fn get_released(&self, account: &Pubkey) -> u64 {
        let payee_index = self.payees.iter().position(|&r| r == *account).unwrap();
        return self.released_amounts[payee_index];
    }

    pub fn get_shares(&self, account: &Pubkey) -> u64 {
        let payee_index = self.payees.iter().position(|&r| r == *account).unwrap();
        return self.shares_amounts[payee_index];
    }

    pub fn get_releasable_for_account(&self, account: &Pubkey) -> u64 {
        let total_received = self.current_lamports + self.get_total_released();
        let already_released = self.get_released(&account);

        let payment = (total_received * self.get_shares(&account)) / self.get_total_shares()
            - already_released;

        return payment;
    }
}

#[derive(Accounts)]
#[instruction(initial_lamports: u64, required_space: u64)]
pub struct InitializeCtx<'info> {
    #[account(mut)]
    pub initializer: Signer<'info>,
    #[account(
        init, 
        payer = initializer, 
        seeds = ["payment_splitter".as_ref(), initializer.key().as_ref()],
        bump,
        space = required_space as usize,
    )]
    pub ps_info: Account<'info, PaymentSplitterInfo>,
    pub system_program: Program<'info, System>,
}

#[derive(Accounts)]
pub struct ReleaseCtx<'info> {
    #[account(mut)]
    pub payee: Signer<'info>,
    #[account(mut)]
    pub initializer: SystemAccount<'info>,
    #[account(
        mut,
        seeds = ["payment_splitter".as_ref(), initializer.key().as_ref()],
        bump,
    )]
    pub ps_info: Account<'info, PaymentSplitterInfo>,
    pub system_program: Program<'info, System>,
}

#[error_code]
pub enum CustomError {
    #[msg("Account is not due payment")]
    AccountNotDuePayment,

    #[msg("No payees provided")]
    NoPayeesProvided,

    #[msg("payees and shares length mismatch")]
    PayeesSharesLengthMismatch,

    #[msg("An account already has shares")]
    AccountAlreadyHasShares,

    #[msg("All the shares amounts have to be greater than 0")]
    NegativeOrZeroShareAmount,

    #[msg("The provided payee has no shares")]
    PayeeHasNoShares,

    #[msg("The provided payee is not due payment")]
    PayeeNotDuePayment,
}
