use solana_program::{
    account_info::{next_account_info, AccountInfo},
    entrypoint,
    entrypoint::ProgramResult,
    msg,
    program::{invoke, invoke_signed},
    program_error::ProgramError,
    pubkey::Pubkey,
    rent::Rent,
    system_instruction,
    sysvar::Sysvar,
};

entrypoint!(process_instruction);

const SEED_STORAGE_BYTES: &str = "storage_bytes";
const SEED_STORAGE_STRING: &str = "storage_string";

pub fn process_instruction(
    program_id: &Pubkey,
    accounts: &[AccountInfo],
    instruction_data: &[u8],
) -> ProgramResult {
    if instruction_data.len() == 0 {
        return Err(ProgramError::InvalidInstructionData);
    }
    match instruction_data[0] {
        0 => store_bytes(
            program_id,
            accounts,
            &instruction_data[1..instruction_data.len()],
        ),
        1 => {
            let string_to_store = String::from_utf8(instruction_data[1..].to_vec()).unwrap();
            store_string(program_id, accounts, string_to_store)
        }
        _ => {
            msg!("Didn't found the entrypoint required");
            Err(ProgramError::InvalidInstructionData)
        }
    }
}

fn store_bytes(
    program_id: &Pubkey,
    accounts: &[AccountInfo],
    bytes_to_store: &[u8],
) -> ProgramResult {
    let accounts_iter: &mut std::slice::Iter<AccountInfo> = &mut accounts.iter();

    let sender_account: &AccountInfo = next_account_info(accounts_iter)?;
    if !sender_account.is_signer {
        return Err(ProgramError::MissingRequiredSignature);
    }

    let bytes_pda_account: &AccountInfo = next_account_info(accounts_iter)?;

    let (bytes_pda_pub_key, storage_bump) =
        Pubkey::find_program_address(&[SEED_STORAGE_BYTES.as_bytes()], program_id);

    if bytes_pda_pub_key != *bytes_pda_account.key {
        msg!("Not the right PDA");
        return Err(ProgramError::InvalidAccountData);
    }

    let system_program_account = next_account_info(accounts_iter)?;
    if system_program_account.key != &solana_program::system_program::id() {
        return Err(ProgramError::InvalidAccountData);
    }


    if bytes_pda_account.lamports() == 0 {
        let space = bytes_to_store.len();
        let rent = Rent::get()?;
        let rent_lamports = rent.minimum_balance(space);
        invoke_signed(
            &system_instruction::create_account(
                sender_account.key,
                bytes_pda_account.key,
                rent_lamports,
                space as u64,
                program_id,
            ),
            &[
                sender_account.clone(),
                bytes_pda_account.clone(),
                system_program_account.clone(),
            ],
            &[&[SEED_STORAGE_BYTES.as_bytes(), &[storage_bump]]],
        )?;

        bytes_pda_account.data.borrow_mut()[..].copy_from_slice(&bytes_to_store);

        return Ok(());
    }

    // Update the account size
    let new_size = bytes_to_store.len();
    let rent = Rent::get()?;
    let new_minimum_balance = rent.minimum_balance(new_size);

    // Make the account rent exempt if needed
    let lamports_diff = new_minimum_balance.saturating_sub(bytes_pda_account.lamports());
    invoke(
        &system_instruction::transfer(sender_account.key, bytes_pda_account.key, lamports_diff),
        &[
            sender_account.clone(),
            bytes_pda_account.clone(),
            system_program_account.clone(),
        ],
    )?;

    bytes_pda_account.realloc(new_size, false)?;

    // Update the data
    bytes_pda_account.data.borrow_mut()[..].copy_from_slice(&bytes_to_store);

    Ok(())
}

fn store_string(
    program_id: &Pubkey,
    accounts: &[AccountInfo],
    string_to_store: String,
) -> ProgramResult {
    let accounts_iter: &mut std::slice::Iter<AccountInfo> = &mut accounts.iter();

    let sender_account: &AccountInfo = next_account_info(accounts_iter)?;
    if !sender_account.is_signer {
        return Err(ProgramError::MissingRequiredSignature);
    }
    
    let string_pda_account: &AccountInfo = next_account_info(accounts_iter)?;

    let (string_pda_pub_key, storage_bump) =
        Pubkey::find_program_address(&[SEED_STORAGE_STRING.as_bytes()], program_id);

    if string_pda_pub_key != *string_pda_account.key {
        msg!("Not the right PDA");
        return Err(ProgramError::InvalidAccountData);
    }

    let system_program_account = next_account_info(accounts_iter)?;
    if system_program_account.key != &solana_program::system_program::id() {
        return Err(ProgramError::InvalidAccountData);
    }

    if string_pda_account.lamports() == 0 {
        let space = string_to_store.as_bytes().len();
        let rent = Rent::get()?;
        let rent_lamports = rent.minimum_balance(space);
        invoke_signed(
            &system_instruction::create_account(
                sender_account.key,
                string_pda_account.key,
                rent_lamports,
                space as u64,
                program_id,
            ),
            &[
                sender_account.clone(),
                string_pda_account.clone(),
                system_program_account.clone(),
            ],
            &[&[SEED_STORAGE_STRING.as_bytes(), &[storage_bump]]],
        )?;

        string_pda_account.data.borrow_mut()[..].copy_from_slice(&string_to_store.as_bytes());

        return Ok(());
    }

    // Update the account size
    let new_size =  string_to_store.as_bytes().len();
    let rent = Rent::get()?;
    let new_minimum_balance = rent.minimum_balance(new_size);

    // Make the account rent exempt if needed
    let lamports_diff = new_minimum_balance.saturating_sub(string_pda_account.lamports());
    invoke(
        &system_instruction::transfer(sender_account.key, string_pda_account.key, lamports_diff),
        &[
            sender_account.clone(),
            string_pda_account.clone(),
            system_program_account.clone(),
        ],
    )?;

    string_pda_account.realloc(new_size, false)?;

    // Update the data
    string_pda_account.data.borrow_mut()[..].copy_from_slice(&string_to_store.as_bytes());

    Ok(())
}
