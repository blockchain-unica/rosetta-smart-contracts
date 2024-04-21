use borsh::{BorshDeserialize, BorshSerialize};
use solana_program::{
    account_info::{next_account_info, AccountInfo},
    entrypoint,
    entrypoint::ProgramResult,
    msg,
    program::{invoke, invoke_signed},
    program_error::ProgramError,
    pubkey::Pubkey,
    rent::Rent,
    system_instruction, system_program,
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

impl DonationDetails {
    pub const LEN: usize = 32 + 32 + 8;
}

fn deposit(
    program_id: &Pubkey,
    accounts: &[AccountInfo],
    instruction_data: &[u8],
) -> ProgramResult {
    let accounts_iter: &mut std::slice::Iter<AccountInfo> = &mut accounts.iter();
    let sender: &AccountInfo = next_account_info(accounts_iter)?;
    let recipient: &AccountInfo = next_account_info(accounts_iter)?;
    let balance_holder_pda_account: &AccountInfo = next_account_info(accounts_iter)?;
    let system_account: &AccountInfo = next_account_info(accounts_iter)?;

    assert!(system_program::check_id(system_account.key));

    let (expected_pda, pda_bump) =
        Pubkey::find_program_address(&[sender.key.as_ref(), recipient.key.as_ref()], program_id);

    if expected_pda != *balance_holder_pda_account.key {
        msg!("Invalid PDA");
        return Err(ProgramError::InvalidAccountData);
    }

    let rent_lamports = Rent::get()?.minimum_balance(DonationDetails::LEN);

    invoke_signed(
        &system_instruction::create_account(
            sender.key,
            balance_holder_pda_account.key,
            rent_lamports,
            DonationDetails::LEN as u64,
            program_id,
        ),
        &[
            sender.clone(),
            balance_holder_pda_account.clone(),
            system_account.clone(),
        ],
        &[&[sender.key.as_ref(), recipient.key.as_ref(), &[pda_bump]]],
    )?;

    let amount = instruction_data
        .iter()
        .rev()
        .fold(0, |acc, &x| (acc << 8) + x as u64);

    invoke(
        &system_instruction::transfer(sender.key, balance_holder_pda_account.key, amount),
        &[
            sender.clone(),
            balance_holder_pda_account.clone(),
            system_account.clone(),
        ],
    )?;

    if !sender.is_signer {
        msg!("The sender should be signer");
        return Err(ProgramError::MissingRequiredSignature);
    }

    let donation = DonationDetails {
        sender: *sender.key,
        recipient: *recipient.key,
        amount,
    };

    if donation.sender != *sender.key {
        return Err(ProgramError::InvalidInstructionData);
    }

    donation.serialize(&mut &mut balance_holder_pda_account.try_borrow_mut_data()?[..])?;

    Ok(())
}

fn withdraw(
    program_id: &Pubkey,
    accounts: &[AccountInfo],
    instruction_data: &[u8],
) -> ProgramResult {
    let accounts_iter: &mut std::slice::Iter<AccountInfo> = &mut accounts.iter();
    let sender: &AccountInfo = next_account_info(accounts_iter)?;
    let recipient: &AccountInfo = next_account_info(accounts_iter)?;
    let balance_holder_pda_account: &AccountInfo = next_account_info(accounts_iter)?;

    if !recipient.is_signer {
        msg!("The recipient account should be the signer");
        return Err(ProgramError::MissingRequiredSignature);
    }

    let (expected_pda, _pda_bump) =
        Pubkey::find_program_address(&[sender.key.as_ref(), recipient.key.as_ref()], program_id);

    if expected_pda != *balance_holder_pda_account.key {
        msg!("Invalid PDA");
        return Err(ProgramError::InvalidAccountData);
    }

    let mut donation: DonationDetails =
        DonationDetails::try_from_slice(*balance_holder_pda_account.data.borrow())?;

    if donation.recipient != *recipient.key {
        msg!("Only the recipient can withdraw");
        return Err(ProgramError::InvalidAccountData);
    }

    let withdraw_amount: u64 = instruction_data
        .iter()
        .rev()
        .fold(0, |acc, &x| (acc << 8) + x as u64);

    let rent_exemption = Rent::get()?.minimum_balance(balance_holder_pda_account.data_len());
    if **balance_holder_pda_account.lamports.borrow() - rent_exemption < withdraw_amount {
        msg!("Insufficient balance in the writing account for withdraw");
        return Err(ProgramError::InsufficientFunds);
    }

    **balance_holder_pda_account.try_borrow_mut_lamports()? -= withdraw_amount;
    **recipient.try_borrow_mut_lamports()? += withdraw_amount;

    if **balance_holder_pda_account.lamports.borrow() <= rent_exemption {
        let amount_to_return: u64 = **balance_holder_pda_account.lamports.borrow();
        **sender.try_borrow_mut_lamports()? += amount_to_return;
        **balance_holder_pda_account.try_borrow_mut_lamports()? -= amount_to_return;
    } else {
        donation.amount -= withdraw_amount;
        donation.serialize(&mut &mut balance_holder_pda_account.data.borrow_mut()[..])?;
    }

    Ok(())
}
