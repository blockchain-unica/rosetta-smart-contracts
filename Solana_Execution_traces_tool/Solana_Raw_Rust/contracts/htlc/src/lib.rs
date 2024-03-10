use borsh::{BorshDeserialize, BorshSerialize};
use solana_program::{
    account_info::{next_account_info, AccountInfo},
    clock::Clock,
    entrypoint,
    entrypoint::ProgramResult,
    keccak, 
    msg,
    program_error::ProgramError,
    pubkey::Pubkey,
    rent::Rent,
    sysvar::Sysvar,
    program::invoke_signed,
    system_instruction,
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
    pub reveal_timeout: u64,
}

fn initialize(
    program_id: &Pubkey,
    accounts: &[AccountInfo],
    instruction_data: &[u8],
) -> ProgramResult {
    let accounts_iter: &mut std::slice::Iter<AccountInfo> = &mut accounts.iter();
    let owner: &AccountInfo = next_account_info(accounts_iter)?;
    let verifier: &AccountInfo = next_account_info(accounts_iter)?;
    let htlc_info_account_pda: &AccountInfo = next_account_info(accounts_iter)?;
    let system_program_account = next_account_info(accounts_iter)?;

    if system_program_account.key != &solana_program::system_program::id() {
        msg!("The system program account should be the system program");
        return Err(ProgramError::InvalidAccountData);
    }

    if !owner.is_signer {
        msg!("The owner account should be the signer");
        return Err(ProgramError::MissingRequiredSignature);
    }

    let (expected_pda, bump) = Pubkey::find_program_address(
        &[
            owner.key.as_ref(),
            verifier.key.as_ref()
        ],
        program_id,
    );

    if expected_pda != *htlc_info_account_pda.key {
        msg!("Not the right PDA");
        return Err(ProgramError::InvalidAccountData);
    }

    let mut htlc_info: HTLCInfo = HTLCInfo::try_from_slice(&instruction_data)?;
    let size = htlc_info.try_to_vec()?.len();
    let rent_lamports = Rent::get()?.minimum_balance(size);

    invoke_signed(
        &system_instruction::create_account(
            owner.key,
            htlc_info_account_pda.key,
            rent_lamports,
            size.try_into().unwrap(),
            program_id,
        ),
        &[
            owner.clone(),
            htlc_info_account_pda.clone(),
            system_program_account.clone(),
        ],
        &[&[
            owner.key.as_ref(),
            verifier.key.as_ref(),
            &[bump],
        ]],
    )?;

    htlc_info.owner = *owner.key;
    htlc_info.verifier = *verifier.key;

    if htlc_info.reveal_timeout <= Clock::get()?.slot {
        msg!("The reveal timeout should be in the future");
        return Err(ProgramError::InvalidInstructionData);
    }

    let cost: u64 = LAMPORTS_PER_SOL / 10; // 0.1 SOL

    invoke_signed(
        &system_instruction::transfer(
            owner.key,
            htlc_info_account_pda.key,
            cost,
        ),
        &[
            owner.clone(),
            htlc_info_account_pda.clone(),
            system_program_account.clone(),
        ],
        &[&[
            owner.key.as_ref(),
            verifier.key.as_ref(),
            &[bump],
        ]],
    )?;

    htlc_info.serialize(&mut &mut htlc_info_account_pda.try_borrow_mut_data()?[..])?;

    Ok(())
}

fn reveal(program_id: &Pubkey, accounts: &[AccountInfo], instruction_data: &[u8]) -> ProgramResult {
    let accounts_iter: &mut std::slice::Iter<AccountInfo> = &mut accounts.iter();
    let owner: &AccountInfo = next_account_info(accounts_iter)?;
    let htlc_info_account_pda: &AccountInfo = next_account_info(accounts_iter)?;
    let verifier: &AccountInfo = next_account_info(accounts_iter)?;

    if !owner.is_signer {
        msg!("The owner account should be signer");
        return Err(ProgramError::MissingRequiredSignature);
    }

    if htlc_info_account_pda.owner.ne(&program_id) {
        msg!("The writing account isn't owned by the program");
        return Err(ProgramError::IllegalOwner);
    }

    let (expected_pda, _bump) = Pubkey::find_program_address(
        &[
            owner.key.as_ref(),
            verifier.key.as_ref()
        ],
        program_id,
    );

    if expected_pda != *htlc_info_account_pda.key {
        msg!("Not the right PDA");
        return Err(ProgramError::InvalidAccountData);
    }

    let htlc_info: HTLCInfo = HTLCInfo::try_from_slice(*htlc_info_account_pda.data.borrow())?;

    if owner.key != &htlc_info.owner {
        return Err(ProgramError::IllegalOwner);
    }

    if verifier.key != &htlc_info.verifier {
        return Err(ProgramError::InvalidAccountData);
    }

    let secret_string =
        String::from_utf8(instruction_data[..instruction_data.len()].to_vec()).unwrap();
    let h: [u8; 32] = keccak::hash(&secret_string.into_bytes()).to_bytes();
    if h != htlc_info.hashed_secret {
        msg!("Invalid secret");
        return Err(ProgramError::InvalidInstructionData);
    }

    **owner.try_borrow_mut_lamports()? += **htlc_info_account_pda.lamports.borrow();
    **htlc_info_account_pda.try_borrow_mut_lamports()? = 0;

    Ok(())
}

fn timeout(program_id: &Pubkey, accounts: &[AccountInfo]) -> ProgramResult {
    let accounts_iter: &mut std::slice::Iter<AccountInfo> = &mut accounts.iter();
    let htlc_info_account_pda: &AccountInfo = next_account_info(accounts_iter)?;
    let owner: &AccountInfo = next_account_info(accounts_iter)?;
    let verifier: &AccountInfo = next_account_info(accounts_iter)?;

    if !owner.is_signer {
        msg!("The owner should be signer");
        return Err(ProgramError::MissingRequiredSignature);
    }

    let (expected_pda, _bump) = Pubkey::find_program_address(
        &[
            owner.key.as_ref(),
            verifier.key.as_ref()
        ],
        program_id,
    );

    if expected_pda != *htlc_info_account_pda.key {
        msg!("Not the right PDA");
        return Err(ProgramError::InvalidAccountData);
    }

    if htlc_info_account_pda.owner.ne(&program_id) {
        msg!("The writing account isn't owned by program");
        return Err(ProgramError::IllegalOwner);
    }

    let htlc_info: HTLCInfo = HTLCInfo::try_from_slice(*htlc_info_account_pda.data.borrow())?;

    if verifier.key != &htlc_info.verifier {
        msg!("The proposed verifier is not the verifier of the HTLC");
        return Err(ProgramError::InvalidAccountData);
    }

    if owner.key != &htlc_info.owner {
        msg!("The owner is not the owner of the HTLC");
        return Err(ProgramError::IllegalOwner);
    }

    if verifier.key != &htlc_info.verifier {
        msg!("The verifier is not the verifier of the HTLC");
        return Err(ProgramError::InvalidAccountData);
    }

    let current_slot: u64 = Clock::get()?.slot;
    if current_slot < htlc_info.reveal_timeout {
        msg!("The reveal timeout is not reached yet");
        return Err(ProgramError::InvalidInstructionData);
    }

    **verifier.try_borrow_mut_lamports()? += **htlc_info_account_pda.lamports.borrow();
    **htlc_info_account_pda.try_borrow_mut_lamports()? = 0;

    Ok(())
}