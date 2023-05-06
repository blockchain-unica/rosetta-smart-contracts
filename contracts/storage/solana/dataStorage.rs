use borsh::{BorshDeserialize, BorshSerialize};
use solana_program::{
    account_info::{next_account_info, AccountInfo},
    entrypoint,
    entrypoint::ProgramResult,
    msg,
    program_error::ProgramError,
    pubkey::Pubkey,
};

entrypoint!(process_instruction);

#[derive(BorshSerialize, BorshDeserialize, Debug)]
struct StorageInfo {
    pub byte_sequence: [u8; 5],
    pub text_string: String,
}

pub fn process_instruction(
    _program_id: &Pubkey,
    accounts: &[AccountInfo],
    instruction_data: &[u8],
) -> ProgramResult {
    if instruction_data.len() == 0 {
        return Err(ProgramError::InvalidInstructionData);
    }
    match instruction_data[0] {
        0 => initialize(accounts, &instruction_data[1..instruction_data.len()]),
        1 => store_bytes(accounts, &instruction_data[1..instruction_data.len()]),
        2 => store_string(accounts, &instruction_data[1..instruction_data.len()]),
        _ => {
            msg!("Didn't found the entrypoint required");
            Err(ProgramError::InvalidInstructionData)
        }
    }
}

fn initialize(accounts: &[AccountInfo], instruction_data: &[u8]) -> ProgramResult {
    let accounts_iter: &mut std::slice::Iter<AccountInfo> = &mut accounts.iter();

    let state_account: &AccountInfo = next_account_info(accounts_iter)?;

    let storage_info = StorageInfo::try_from_slice(&instruction_data)?;

    storage_info.serialize(&mut &mut state_account.data.borrow_mut()[..])?;
     
    Ok(())
}

fn store_bytes(accounts: &[AccountInfo], instruction_data: &[u8]) -> ProgramResult {
    let accounts_iter: &mut std::slice::Iter<AccountInfo> = &mut accounts.iter();

    let state_account: &AccountInfo = next_account_info(accounts_iter)?;

    let mut storage_info = StorageInfo::try_from_slice(*state_account.data.borrow())?;

    storage_info.byte_sequence = instruction_data[..instruction_data.len()].try_into().unwrap();

    storage_info.serialize(&mut &mut state_account.data.borrow_mut()[..])?;
     
    Ok(())
}

fn store_string(accounts: &[AccountInfo], instruction_data: &[u8]) -> ProgramResult {

    let accounts_iter: &mut std::slice::Iter<AccountInfo> = &mut accounts.iter();

    let state_account: &AccountInfo = next_account_info(accounts_iter)?;

    let mut storage_info = StorageInfo::try_from_slice(*state_account.data.borrow())?;

    storage_info.text_string = String::from_utf8(instruction_data[..instruction_data.len()].to_vec()).unwrap();

    storage_info.serialize(&mut &mut state_account.data.borrow_mut()[..])?;

    Ok(())
}