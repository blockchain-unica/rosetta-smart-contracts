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
    let accounts_iter = &mut accounts.iter();
    let writing_account = next_account_info(accounts_iter)?;
    let donator_program_account = next_account_info(accounts_iter)?;
    let donator = next_account_info(accounts_iter)?;

    if writing_account.owner != program_id {
        msg!("writing_account isn't owned by program");
        return Err(ProgramError::InvalidAccountData);
    }
    if donator_program_account.owner != program_id {
        msg!("donator_program_account isn't owned by program");
        return Err(ProgramError::IncorrectProgramId);
    }
    if !donator.is_signer {
        msg!("donator should be signer");
        return Err(ProgramError::MissingRequiredSignature);
    }

    let mut donation = DonationDetails::try_from_slice(&instruction_data)
        .expect("Instruction data serialization didn't worked");

    if donation.sender != *donator.key {
        msg!("Invaild instruction data");
        return Err(ProgramError::InvalidInstructionData);
    }

    let rent_exemption = Rent::get()?.minimum_balance(writing_account.data_len());
    if **writing_account.lamports.borrow() < rent_exemption {
        msg!("The balance of writing_account should be more than rent_exemption");
        return Err(ProgramError::InsufficientFunds);
    }

    donation.amount = **donator_program_account.lamports.borrow();
    **writing_account.try_borrow_mut_lamports()? += **donator_program_account.lamports.borrow();
    **donator_program_account.try_borrow_mut_lamports()? = 0;
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
    let accounts_iter = &mut accounts.iter();
    let writing_account = next_account_info(accounts_iter)?;
    let recipient = next_account_info(accounts_iter)?;

    if writing_account.owner != program_id {
        msg!("writing_account isn't owned by program");
        return Err(ProgramError::IncorrectProgramId);
    }
    if !recipient.is_signer {
        msg!("recipient should be signer");
        return Err(ProgramError::MissingRequiredSignature);
    }
    let mut donation = DonationDetails::try_from_slice(*writing_account.data.borrow())
        .expect("Error deserialaizing data");

    if donation.recipient != *recipient.key {
        msg!("Only the recipient can withdraw");
        return Err(ProgramError::InvalidAccountData);
    }

    let withdraw_request = WithdrawRequest::try_from_slice(&instruction_data)
        .expect("Instruction data serialization didn't worked");

    let rent_exemption = Rent::get()?.minimum_balance(writing_account.data_len());
    if **writing_account.lamports.borrow() - rent_exemption < donation.amount {
        msg!("Insufficent balance");
        return Err(ProgramError::InsufficientFunds);
    }

    **writing_account.try_borrow_mut_lamports()? -= withdraw_request.amount;
    **recipient.try_borrow_mut_lamports()? += withdraw_request.amount;

    donation.amount -= withdraw_request.amount;
    donation.serialize(&mut &mut writing_account.data.borrow_mut()[..])?;

    Ok(())
}
