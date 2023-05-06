use borsh::{BorshDeserialize, BorshSerialize};
use solana_program::{
    account_info::{next_account_info, AccountInfo},
    entrypoint,
    entrypoint::ProgramResult,
    msg,
    program_error::ProgramError,
    pubkey::Pubkey,
    rent::Rent,
    sysvar::Sysvar,
};

entrypoint!(process_instruction);

pub fn process_instruction(
    program_id: &Pubkey,
    accounts: &[AccountInfo],
    instruction_data: &[u8],
) -> ProgramResult {
    if instruction_data.len() == 0 {
        return Err(ProgramError::InvalidInstructionData);
    }
    match instruction_data[0] {
        0 => deposit(
            program_id,
            accounts,
            &instruction_data[1..instruction_data.len()],
        ),
        1 => withdraw(
            program_id,
            accounts,
            &instruction_data[1..instruction_data.len()],
        ),
        _ => {
            msg!("Didn't found the entrypoint required");
            Err(ProgramError::InvalidInstructionData)
        }
    }
}

#[derive(BorshSerialize, BorshDeserialize, Debug)]
struct DonationDetails {
    pub sender: Pubkey,
    pub recipient: Pubkey,
    pub amount: u64,
}

fn deposit(
    program_id: &Pubkey,
    accounts: &[AccountInfo],
    instruction_data: &[u8],
) -> ProgramResult {
    let accounts_iter: &mut std::slice::Iter<AccountInfo> = &mut accounts.iter();
    let writing_account: &AccountInfo = next_account_info(accounts_iter)?;
    let sender: &AccountInfo = next_account_info(accounts_iter)?;

    if writing_account.owner != program_id {
        msg!("The writing account isn't owned by the program");
        return Err(ProgramError::InvalidAccountData);
    }

    if !sender.is_signer {
        msg!("The sender should be signer");
        return Err(ProgramError::MissingRequiredSignature);
    }

    let mut donation: DonationDetails = DonationDetails::try_from_slice(&instruction_data)?;

    if donation.sender != *sender.key {
        msg!("Invaild instruction data");
        return Err(ProgramError::InvalidInstructionData);
    }

    let rent_exemption: u64 = Rent::get()?.minimum_balance(writing_account.data_len());
    if **writing_account.lamports.borrow() < rent_exemption {
        msg!("The writing account should be rent exempted");
        return Err(ProgramError::InsufficientFunds);
    }

    donation.amount = **writing_account.lamports.borrow();
    donation.serialize(&mut &mut writing_account.try_borrow_mut_data()?[..])?;

    Ok(())
}

#[derive(BorshSerialize, BorshDeserialize, Debug)]
struct WithdrawRequest {
    pub amount: u64,
}

fn withdraw(
    program_id: &Pubkey,
    accounts: &[AccountInfo],
    instruction_data: &[u8],
) -> ProgramResult {
    let accounts_iter: &mut std::slice::Iter<AccountInfo> = &mut accounts.iter();
    let sender: &AccountInfo = next_account_info(accounts_iter)?;
    let recipient: &AccountInfo = next_account_info(accounts_iter)?;
    let writing_account: &AccountInfo = next_account_info(accounts_iter)?;

    if writing_account.owner != program_id {
        msg!("The writing account isn't owned by the program");
        return Err(ProgramError::IncorrectProgramId);
    }
    if !recipient.is_signer {
        msg!("The recipient account should be the signer");
        return Err(ProgramError::MissingRequiredSignature);
    }
    let mut donation: DonationDetails =
        DonationDetails::try_from_slice(*writing_account.data.borrow())?;

    if donation.recipient != *recipient.key {
        msg!("Only the recipient can withdraw");
        return Err(ProgramError::InvalidAccountData);
    }

    let withdraw_request: WithdrawRequest = WithdrawRequest::try_from_slice(&instruction_data)?;

    let rent_exemption = Rent::get()?.minimum_balance(writing_account.data_len());
    if **writing_account.lamports.borrow() - rent_exemption < withdraw_request.amount {
        msg!("Insufficent balance in the writing account for withdraw");
        return Err(ProgramError::InsufficientFunds);
    }

    **writing_account.try_borrow_mut_lamports()? -= withdraw_request.amount;
    **recipient.try_borrow_mut_lamports()? += withdraw_request.amount;

    if **writing_account.lamports.borrow() <= rent_exemption {
        // Return rent founds to the sender of the deposit
        let amount_to_return: u64 = **writing_account.lamports.borrow();
        **sender.try_borrow_mut_lamports()? += amount_to_return;
        **writing_account.try_borrow_mut_lamports()? -= amount_to_return;
    } else {
        donation.amount -= withdraw_request.amount;
        donation.serialize(&mut &mut writing_account.data.borrow_mut()[..])?;
    }

    Ok(())
}
