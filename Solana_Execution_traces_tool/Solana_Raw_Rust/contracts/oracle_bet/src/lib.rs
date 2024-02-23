use borsh::{BorshDeserialize, BorshSerialize};
use solana_program::{
    account_info::{next_account_info, AccountInfo},
    clock::Clock,
    entrypoint,
    entrypoint::ProgramResult,
    msg,
    program::invoke_signed,
    program_error::ProgramError,
    pubkey::Pubkey,
    rent::Rent,
    system_instruction, system_program,
    sysvar::Sysvar,
};

entrypoint!(process_instruction);

#[derive(BorshSerialize, BorshDeserialize, Debug)]
pub struct OracleBetInfo {
    pub oracle: Pubkey,       // 32 bytes
    pub participant1: Pubkey, // 32 bytes
    pub participant2: Pubkey, // 32 bytes
    pub wager: u64,           // 8 bytes
    pub deadline: u64,        // 8 bytes
    pub joined: bool,         // 1 byte
}

impl OracleBetInfo {
    pub const LEN: usize = 32 + 32 + 32 + 8 + 8 + 1;
}

const SEED_FOR_PDA: &str = "oracle_bet";

pub enum OracleBetInstruction {
    Initialize { deadline: u64, wager: u64 },
    Join,
    Win,
    Timeout,
}

impl OracleBetInstruction {
    pub fn from_instruction_data(instruction_data: &[u8]) -> Option<Self> {
        match instruction_data {
            [0, tail @ ..] => Self::get_initialize_context(tail),
            [1, _tail @ ..] => Self::get_join_context(),
            [2, _tail @ ..] => Self::get_win_context(),
            [3, _tail @ ..] => Self::get_timeout_context(),
            _ => None,
        }
    }

    fn get_initialize_context(instruction_data: &[u8]) -> Option<Self> {
        let deadline = u64::from_le_bytes(instruction_data[0..8].try_into().unwrap());
        let wager = u64::from_le_bytes(instruction_data[8..16].try_into().unwrap());
        Some(Self::Initialize { deadline, wager })
    }

    fn get_join_context() -> Option<Self> {
        Some(Self::Join)
    }

    fn get_win_context() -> Option<Self> {
        Some(Self::Win)
    }

    fn get_timeout_context() -> Option<Self> {
        Some(Self::Timeout)
    }
}

pub fn process_instruction<'a>(
    program_id: &Pubkey,
    accounts: &'a [AccountInfo<'a>],
    instruction_data: &[u8],
) -> ProgramResult {
    let instruction = OracleBetInstruction::from_instruction_data(instruction_data)
        .ok_or(ProgramError::InvalidInstructionData)?;

    match instruction {
        OracleBetInstruction::Initialize { deadline, wager } => {
            initialize(program_id, accounts, deadline, wager)
        }
        OracleBetInstruction::Join => join(program_id, accounts),
        OracleBetInstruction::Win => win(program_id, accounts),
        OracleBetInstruction::Timeout => timeout(program_id, accounts),
    }
}

fn initialize<'a>(
    program_id: &Pubkey,
    accounts: &'a [AccountInfo<'a>],
    deadline: u64,
    wager: u64,
) -> ProgramResult {
    msg!("Initialize");
    let accounts_iter: &mut std::slice::Iter<AccountInfo> = &mut accounts.iter();

    let oracle_account: &AccountInfo = next_account_info(accounts_iter)?;
    let participant1_account: &AccountInfo = next_account_info(accounts_iter)?;
    let participant2_account: &AccountInfo = next_account_info(accounts_iter)?;
    let oracle_bet_pda: &AccountInfo = next_account_info(accounts_iter)?;
    let system_account: &AccountInfo = next_account_info(accounts_iter)?;

    if !oracle_account.is_signer {
        return Err(ProgramError::MissingRequiredSignature);
    }

    let current_slot: u64 = Clock::get()?.slot;
    if current_slot >= deadline {
        msg!("The deadline should be in the future");
        return Err(ProgramError::InvalidInstructionData);
    }

    let rent_lamports = Rent::get()?.minimum_balance(OracleBetInfo::LEN);

    let (expected_pda, pda_bump) = Pubkey::find_program_address(
        &[SEED_FOR_PDA.as_bytes(), oracle_account.key.as_ref()],
        program_id,
    );

    if expected_pda != *oracle_bet_pda.key {
        msg!("Invalid PDA");
        return Err(ProgramError::InvalidAccountData);
    }

    invoke_signed(
        &system_instruction::create_account(
            oracle_account.key,
            oracle_bet_pda.key,
            rent_lamports,
            OracleBetInfo::LEN as u64,
            program_id,
        ),
        &[
            oracle_account.clone(),
            oracle_bet_pda.clone(),
            system_account.clone(),
        ],
        &[&[
            SEED_FOR_PDA.as_bytes(),
            oracle_account.key.as_ref(),
            &[pda_bump],
        ]],
    )?;

    let oracle_bet_info = OracleBetInfo {
        oracle: *oracle_account.key,
        participant1: *participant1_account.key,
        participant2: *participant2_account.key,
        wager,
        deadline,
        joined: false,
    };
    oracle_bet_info.serialize(&mut &mut oracle_bet_pda.try_borrow_mut_data()?[..])?;

    Ok(())
}

fn join<'a>(program_id: &Pubkey, accounts: &'a [AccountInfo<'a>]) -> ProgramResult {
    msg!("join");
    let accounts_iter: &mut std::slice::Iter<AccountInfo> = &mut accounts.iter();

    let participant1_account: &AccountInfo = next_account_info(accounts_iter)?;
    let participant2_account: &AccountInfo = next_account_info(accounts_iter)?;
    let oracle_bet_pda: &AccountInfo = next_account_info(accounts_iter)?;
    let system_account: &AccountInfo = next_account_info(accounts_iter)?;

    assert!(system_program::check_id(system_account.key));

    let mut oracle_bet_info: OracleBetInfo =
        OracleBetInfo::try_from_slice(*oracle_bet_pda.data.borrow())?;

    if !participant1_account.is_signer {
        return Err(ProgramError::MissingRequiredSignature);
    }

    if !participant2_account.is_signer {
        return Err(ProgramError::MissingRequiredSignature);
    }

    if oracle_bet_info.participant1 != *participant1_account.key
        || oracle_bet_info.participant2 != *participant2_account.key
    {
        msg!("One or both of the provided actors are not in the oracle_bet_info");
        return Err(ProgramError::InvalidInstructionData);
    }

    if oracle_bet_pda.owner.ne(&program_id) {
        msg!("The oracle_bet_info_account isn't owned by program");
        return Err(ProgramError::IllegalOwner);
    }

    let (expected_pda, pda_bump) = Pubkey::find_program_address(
        &[SEED_FOR_PDA.as_bytes(), oracle_bet_info.oracle.as_ref()],
        program_id,
    );

    if expected_pda != *oracle_bet_pda.key {
        msg!("Invalid PDA");
        return Err(ProgramError::InvalidAccountData);
    }

    let current_slot: u64 = Clock::get()?.slot;
    if current_slot >= oracle_bet_info.deadline {
        msg!("The timeout was already reached");
        return Err(ProgramError::InvalidInstructionData);
    }

    if oracle_bet_info.joined {
        msg!("The bet was already joined");
        return Err(ProgramError::InvalidInstructionData);
    }

    invoke_signed(
        &system_instruction::transfer(
            participant1_account.key,
            oracle_bet_pda.key,
            oracle_bet_info.wager,
        ),
        &[participant1_account.clone(), oracle_bet_pda.clone()],
        &[&[
            SEED_FOR_PDA.as_bytes(),
            oracle_bet_info.oracle.as_ref(),
            &[pda_bump],
        ]],
    )?;

    invoke_signed(
        &system_instruction::transfer(
            participant2_account.key,
            oracle_bet_pda.key,
            oracle_bet_info.wager,
        ),
        &[participant2_account.clone(), oracle_bet_pda.clone()],
        &[&[
            SEED_FOR_PDA.as_bytes(),
            oracle_bet_info.oracle.as_ref(),
            &[pda_bump],
        ]],
    )?;

    oracle_bet_info.joined = true;
    oracle_bet_info.serialize(&mut &mut oracle_bet_pda.try_borrow_mut_data()?[..])?;

    Ok(())
}

fn win<'a>(program_id: &Pubkey, accounts: &'a [AccountInfo<'a>]) -> ProgramResult {
    msg!("win");
    let accounts_iter: &mut std::slice::Iter<AccountInfo> = &mut accounts.iter();

    let oracle_account: &AccountInfo = next_account_info(accounts_iter)?;
    let winner_account: &AccountInfo = next_account_info(accounts_iter)?;
    let oracle_bet_pda: &AccountInfo = next_account_info(accounts_iter)?;

    let oracle_bet_info: OracleBetInfo =
        OracleBetInfo::try_from_slice(*oracle_bet_pda.data.borrow())?;

    if !oracle_bet_info.joined {
        msg!("The bet was not joined yet");
        return Err(ProgramError::InvalidInstructionData);
    }

    if !oracle_account.is_signer {
        return Err(ProgramError::MissingRequiredSignature);
    }

    if oracle_bet_pda.owner.ne(&program_id) {
        msg!("The oracle_bet_info_account isn't owned by program");
        return Err(ProgramError::IllegalOwner);
    }

    let (expected_pda, _pda_bump) = Pubkey::find_program_address(
        &[SEED_FOR_PDA.as_bytes(), oracle_bet_info.oracle.as_ref()],
        program_id,
    );

    if expected_pda != *oracle_bet_pda.key {
        msg!("Invalid PDA");
        return Err(ProgramError::InvalidAccountData);
    }

    if oracle_bet_info.oracle != *oracle_account.key {
        msg!("The oracle isn't in the oracle_bet_info");
        return Err(ProgramError::InvalidInstructionData);
    }

    if oracle_bet_info.participant1 != *winner_account.key
        && oracle_bet_info.participant2 != *winner_account.key
    {
        msg!("The winner isn't in the oracle_bet_info");
        return Err(ProgramError::InvalidInstructionData);
    }

    let amount_to_winner = oracle_bet_info.wager * 2;
    let amount_to_oracle = **oracle_bet_pda.lamports.borrow() - amount_to_winner;

    **winner_account.try_borrow_mut_lamports()? += amount_to_winner;
    **oracle_account.try_borrow_mut_lamports()? += amount_to_oracle;
    **oracle_bet_pda.try_borrow_mut_lamports()? = 0;
    Ok(())
}

fn timeout<'a>(program_id: &Pubkey, accounts: &'a [AccountInfo<'a>]) -> ProgramResult {
    msg!("timeout");
    let accounts_iter: &mut std::slice::Iter<AccountInfo> = &mut accounts.iter();

    let oracle_account: &AccountInfo = next_account_info(accounts_iter)?;
    let participant1_account: &AccountInfo = next_account_info(accounts_iter)?;
    let participant2_account: &AccountInfo = next_account_info(accounts_iter)?;
    let oracle_bet_pda: &AccountInfo = next_account_info(accounts_iter)?;
    
    let oracle_bet_info: OracleBetInfo =
        OracleBetInfo::try_from_slice(*oracle_bet_pda.data.borrow())?;

    if oracle_bet_pda.owner.ne(&program_id) {
        msg!("The oracle_bet_info_account isn't owned by program");
        return Err(ProgramError::IllegalOwner);
    }

    let (expected_pda, _pda_bump) = Pubkey::find_program_address(
        &[SEED_FOR_PDA.as_bytes(), oracle_bet_info.oracle.as_ref()],
        program_id,
    );

    if expected_pda != *oracle_bet_pda.key {
        msg!("Invalid PDA");
        return Err(ProgramError::InvalidAccountData);
    }

    if !oracle_bet_info.joined {
        msg!("The bet was not joined yet");
        return Err(ProgramError::InvalidInstructionData);
    }

    if Clock::get()?.slot < oracle_bet_info.deadline {
        msg!("The timeout was not reached yet");
        return Err(ProgramError::InvalidInstructionData);
    }

    if oracle_account.key != &oracle_bet_info.oracle {
        msg!("The oracle isn't in the oracle_bet_info");
        return Err(ProgramError::InvalidInstructionData);
    }

    **participant1_account.try_borrow_mut_lamports()? += oracle_bet_info.wager;
    **participant2_account.try_borrow_mut_lamports()? += oracle_bet_info.wager;

    let amount_to_oracle = **oracle_bet_pda.lamports.borrow() - oracle_bet_info.wager * 2;
    **oracle_account.try_borrow_mut_lamports()? +=  amount_to_oracle;
    **oracle_bet_pda.try_borrow_mut_lamports()? = 0;
    Ok(())
}