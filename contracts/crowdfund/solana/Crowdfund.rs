use borsh::{BorshDeserialize, BorshSerialize};
use solana_program::{
    account_info::{next_account_info, AccountInfo},
    clock::Clock,
    entrypoint,
    entrypoint::ProgramResult,
    msg,
    program_error::ProgramError,
    pubkey::Pubkey,
    rent::Rent,
    sysvar::Sysvar,
};

entrypoint!(process_instruction);

#[derive(BorshSerialize, BorshDeserialize, Debug)]
struct Campaign {
    pub receiver: Pubkey,
    pub end_donate_slot: u64,
    pub goal: u64,
}

#[derive(BorshSerialize, BorshDeserialize, Debug)]
struct DonationInfo {
    pub donor: Pubkey,
    pub reciever_campain: Pubkey,
    pub amount_donated: u64,
}

pub fn process_instruction(
    program_id: &Pubkey,
    accounts: &[AccountInfo],
    instruction_data: &[u8],
) -> ProgramResult {
    if instruction_data.len() == 0 {
        return Err(ProgramError::InvalidInstructionData);
    }
    match instruction_data[0] {
        0 => create_campaign(
            program_id,
            accounts,
            &instruction_data[1..instruction_data.len()],
        ),
        1 => donate(
            program_id,
            accounts,
            &instruction_data[1..instruction_data.len()],
        ),
        2 => withdraw(program_id, accounts),
        3 => reclaim(program_id, accounts),
        _ => {
            msg!("Didn't found the entrypoint required");
            Err(ProgramError::InvalidInstructionData)
        }
    }
}

fn create_campaign(
    program_id: &Pubkey,
    accounts: &[AccountInfo],
    instruction_data: &[u8],
) -> ProgramResult {
    let accounts_iter = &mut accounts.iter();
    let creator_account = next_account_info(accounts_iter)?;
    let campain_account = next_account_info(accounts_iter)?;

    if !creator_account.is_signer {
        msg!("The creator account should be signer");
        return Err(ProgramError::IncorrectProgramId);
    }

    if campain_account.owner != program_id {
        msg!("The campain account isn't owned by program");
        return Err(ProgramError::IncorrectProgramId);
    }

    let campain = Campaign::try_from_slice(&instruction_data)?;

    if campain.receiver != *creator_account.key {
        msg!("The creator of campain should be the receiver");
        return Err(ProgramError::InvalidInstructionData);
    }

    if campain.end_donate_slot <= Clock::get()?.slot {
        msg!("The end donate slot should be in the future");
        return Err(ProgramError::InvalidInstructionData);
    }

    if campain.goal <= 0 {
        msg!("The goal amount should be positive");
        return Err(ProgramError::InvalidInstructionData);
    }

    let rent_exemption = Rent::get()?.minimum_balance(campain_account.data_len());
    if **campain_account.lamports.borrow() < rent_exemption {
        msg!("The state account should be rent exempt");
        return Err(ProgramError::InsufficientFunds);
    }

    campain.serialize(&mut &mut campain_account.try_borrow_mut_data()?[..])?;

    Ok(())
}

fn donate(program_id: &Pubkey, accounts: &[AccountInfo], instruction_data: &[u8]) -> ProgramResult {
    let accounts_iter = &mut accounts.iter();
    let donor_account = next_account_info(accounts_iter)?;
    let campain_account = next_account_info(accounts_iter)?;
    let donation_account = next_account_info(accounts_iter)?;

    if !donor_account.is_signer {
        msg!("The donor account should be signer");
        return Err(ProgramError::IncorrectProgramId);
    }

    if campain_account.owner != program_id {
        msg!("The campain account isn't owned by program");
        return Err(ProgramError::IncorrectProgramId);
    }

    if donation_account.owner != program_id {
        msg!("The donation account isn't owned by program");
        return Err(ProgramError::IncorrectProgramId);
    }

    let campain = Campaign::try_from_slice(*campain_account.data.borrow())?;

    if Clock::get()?.slot > campain.end_donate_slot {
        msg!("The campain is over");
        return Err(ProgramError::InvalidInstructionData);
    }

    let donation_info = DonationInfo::try_from_slice(&instruction_data)?;

    if donation_info.donor != *donor_account.key {
        return Err(ProgramError::InvalidInstructionData);
    }

    if donation_info.reciever_campain != *campain_account.key {
        msg!("The donation should be for the campain that was provided");
        return Err(ProgramError::InvalidInstructionData);
    }

    let rent_exemption_donation_account = Rent::get()?.minimum_balance(donation_account.data_len());
    if **donation_account.lamports.borrow() < rent_exemption_donation_account + donation_info.amount_donated {
        msg!("The donation account should be rent exempt");
        return Err(ProgramError::InsufficientFunds);
    }

    donation_info.serialize(&mut &mut donation_account.try_borrow_mut_data()?[..])?;

    **campain_account.try_borrow_mut_lamports()? += donation_info.amount_donated;
    **donation_account.try_borrow_mut_lamports()? -= donation_info.amount_donated;

    Ok(())
}

fn withdraw(program_id: &Pubkey, accounts: &[AccountInfo]) -> ProgramResult {
    let accounts_iter = &mut accounts.iter();
    let creator_account = next_account_info(accounts_iter)?;
    let campain_account = next_account_info(accounts_iter)?;

    if !creator_account.is_signer {
        msg!("The creator account should be signer");
        return Err(ProgramError::IncorrectProgramId);
    }

    if campain_account.owner != program_id {
        msg!("The campain account isn't owned by program");
        return Err(ProgramError::IncorrectProgramId);
    }

    let campain = Campaign::try_from_slice(*campain_account.data.borrow())?;

    if campain.receiver != *creator_account.key {
        msg!("Only the creator can withdraw");
        return Err(ProgramError::InvalidInstructionData);
    }

    if Clock::get()?.slot < campain.end_donate_slot {
        msg!("The campain is not over yet");
        return Err(ProgramError::InvalidInstructionData);
    }

    let rent_exemption_campain_account = Rent::get()?.minimum_balance(campain_account.data_len());
    if **campain_account.try_borrow_lamports()? < campain.goal + rent_exemption_campain_account {
        msg!("The goal was not reached");
        return Err(ProgramError::InvalidInstructionData);
    }

    let reached_amount = **campain_account.try_borrow_lamports()?;

    **campain_account.try_borrow_mut_lamports()? -= reached_amount;
    **creator_account.try_borrow_mut_lamports()? += reached_amount;

    Ok(())
}

fn reclaim(program_id: &Pubkey, accounts: &[AccountInfo]) -> ProgramResult {
    let accounts_iter = &mut accounts.iter();
    let donor_account = next_account_info(accounts_iter)?;
    let campain_account = next_account_info(accounts_iter)?;
    let donation_account = next_account_info(accounts_iter)?;

    if !donor_account.is_signer {
        msg!("The donor account should be signer");
        return Err(ProgramError::IncorrectProgramId);
    }

    if campain_account.owner != program_id {
        msg!("The campain account isn't owned by program");
        return Err(ProgramError::IncorrectProgramId);
    }

    if donation_account.owner != program_id {
        msg!("The donation account isn't owned by program");
        return Err(ProgramError::IncorrectProgramId);
    }

    let campain = Campaign::try_from_slice(*campain_account.data.borrow())?;

    let donation_info = DonationInfo::try_from_slice(*donation_account.data.borrow())?;

    if donation_info.donor != *donor_account.key {
        msg!("Only the donor can reclaim");
        return Err(ProgramError::InvalidInstructionData);
    }

    if Clock::get()?.slot < campain.end_donate_slot {
        msg!("The campain is not over yet");
        return Err(ProgramError::InvalidInstructionData);
    }

    if donation_info.reciever_campain != *campain_account.key {
        msg!("The donation is not for the provided campain");
        return Err(ProgramError::InvalidInstructionData);
    }

    // Since the campain at this pooint is over we can
    // return the rent founds to the donor (even if the goal was reached).
    // So we are not revering the transaction, even if the goal was reached, 
    // to send back the rent founds of the donation account to the donor.
    **donor_account.try_borrow_mut_lamports()? += **donation_account.try_borrow_lamports()?;
    **donation_account.try_borrow_mut_lamports()? = 0;

    let rent_exemption_campain_account = Rent::get()?.minimum_balance(campain_account.data_len());
    if **campain_account.try_borrow_lamports()? < (campain.goal + rent_exemption_campain_account) { 
        // If the goal was not reached, return the donation to the donor
        **campain_account.try_borrow_mut_lamports()? -= donation_info.amount_donated;
        **donor_account.try_borrow_mut_lamports()? += donation_info.amount_donated;
    }

    Ok(())
}
