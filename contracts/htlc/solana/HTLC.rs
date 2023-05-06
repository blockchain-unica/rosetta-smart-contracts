use borsh::{BorshDeserialize, BorshSerialize};
use sha2::{Digest, Sha256};
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

const LAMPORTS_PER_SOL: u64 = 1_000_000_000;

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
        0 => initialize(
            program_id,
            accounts,
            &instruction_data[1..instruction_data.len()],
        ),
        1 => reveal(
            program_id,
            accounts,
            &instruction_data[1..instruction_data.len()],
        ),
        2 => timeout(program_id, accounts),
        _ => {
            msg!("Didn't found the entrypoint required");
            Err(ProgramError::InvalidInstructionData)
        }
    }
}

#[derive(BorshSerialize, BorshDeserialize, Debug)]
struct HTLCInfo {
    pub owner: Pubkey,
    pub verifier: Pubkey,
    pub hashed_secret: [u8; 32],
    pub delay: u64,
    pub reveal_timeout: u64,
}

fn initialize(
    program_id: &Pubkey,
    accounts: &[AccountInfo],
    instruction_data: &[u8],
) -> ProgramResult {
    let accounts_iter: &mut std::slice::Iter<AccountInfo> = &mut accounts.iter();
    let sender: &AccountInfo = next_account_info(accounts_iter)?;
    let writing_account: &AccountInfo = next_account_info(accounts_iter)?;

    if !sender.is_signer {
        msg!("The owner account should be the signer");
        return Err(ProgramError::MissingRequiredSignature);
    }

    if writing_account.owner != program_id {
        msg!("The writing account isn't owned by program");
        return Err(ProgramError::InvalidAccountData);
    }

    let mut htlc_info: HTLCInfo = HTLCInfo::try_from_slice(&instruction_data)?;
    htlc_info.owner = *sender.key;
    htlc_info.reveal_timeout = Clock::get()?.slot + htlc_info.delay;

    let rent_exemption: u64 = Rent::get()?.minimum_balance(writing_account.data_len());
    let cost: u64 = LAMPORTS_PER_SOL / 10; // 0.1 SOL
    if **writing_account.lamports.borrow() < rent_exemption + cost {
        msg!(
            "The balance of writing account is under rent exemption + the cost of the service {}",
            cost / LAMPORTS_PER_SOL
        );
        return Err(ProgramError::InsufficientFunds);
    }

    htlc_info.serialize(&mut &mut writing_account.try_borrow_mut_data()?[..])?;

    Ok(())
}

#[derive(BorshSerialize, BorshDeserialize, Debug)]
struct Secret {
    pub secret_string: String,
}

fn reveal(program_id: &Pubkey, accounts: &[AccountInfo], instruction_data: &[u8]) -> ProgramResult {
    let accounts_iter: &mut std::slice::Iter<AccountInfo> = &mut accounts.iter();
    let sender: &AccountInfo = next_account_info(accounts_iter)?;
    let writing_account: &AccountInfo = next_account_info(accounts_iter)?;

    if !sender.is_signer {
        msg!("The sender account should be signer");
        return Err(ProgramError::MissingRequiredSignature);
    }

    if writing_account.owner != program_id {
        msg!("The writing account isn't owned by the program");
        return Err(ProgramError::InvalidAccountData);
    }

    let htlc_info: HTLCInfo = HTLCInfo::try_from_slice(*writing_account.data.borrow())?;

    if sender.key != &htlc_info.owner {
        msg!("Transaction sender is not the owner of the HTLC");
        return Err(ProgramError::InvalidInstructionData);
    }

    // Verify the secret
    let secret_string =
        String::from_utf8(instruction_data[..instruction_data.len()].to_vec()).unwrap();
    let h: [u8; 32] = hash_data(&secret_string.into_bytes());
    if h != htlc_info.hashed_secret {
        msg!("Invaild secret");
        return Err(ProgramError::InvalidInstructionData);
    }

    **sender.try_borrow_mut_lamports()? += **writing_account.lamports.borrow();
    **writing_account.try_borrow_mut_lamports()? = 0;

    Ok(())
}

fn timeout(program_id: &Pubkey, accounts: &[AccountInfo]) -> ProgramResult {
    let accounts_iter: &mut std::slice::Iter<AccountInfo> = &mut accounts.iter();
    let writing_account: &AccountInfo = next_account_info(accounts_iter)?;
    let sender: &AccountInfo = next_account_info(accounts_iter)?;
    let verifier: &AccountInfo = next_account_info(accounts_iter)?;

    if !sender.is_signer {
        msg!("The sender should be signer");
        return Err(ProgramError::MissingRequiredSignature);
    }

    if writing_account.owner != program_id {
        msg!("The writing account isn't owned by program");
        return Err(ProgramError::InvalidAccountData);
    }

    let htlc_info: HTLCInfo = HTLCInfo::try_from_slice(*writing_account.data.borrow())?;

    if verifier.key != &htlc_info.verifier {
        msg!("The proposed verifier is not the verifier of the HTLC");
        return Err(ProgramError::InvalidAccountData);
    }

    let current_slot: u64 = Clock::get()?.slot;
    if current_slot < htlc_info.reveal_timeout {
        msg!("The reveal timeout is not reached yet");
        return Err(ProgramError::InvalidInstructionData);
    }

    **verifier.try_borrow_mut_lamports()? += **writing_account.lamports.borrow();
    **writing_account.try_borrow_mut_lamports()? = 0;

    Ok(())
}

fn hash_data(data: &[u8]) -> [u8; 32] {
    let mut hasher: Sha256 = Sha256::new();
    hasher.update(data);
    let result = hasher.finalize();
    let mut hash = [0u8; 32];
    hash.copy_from_slice(&result[..]);
    hash
}
