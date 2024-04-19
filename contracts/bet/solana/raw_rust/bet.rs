use borsh::{BorshDeserialize, BorshSerialize};
use solana_program::{
    account_info::{next_account_info, AccountInfo},
    clock::Clock,
    entrypoint,
    entrypoint::ProgramResult,
    msg,
    program::invoke,
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
}

impl OracleBetInfo {
    pub const LEN: usize = 32 + 32 + 32 + 8 + 8;
}

pub enum OracleBetInstruction {
    Join { delay: u64, wager: u64 },
    Win,
    Timeout,
}

impl OracleBetInstruction {
    pub fn from_instruction_data(instruction_data: &[u8]) -> Option<Self> {
        match instruction_data {
            [0, tail @ ..] => Self::get_join_context(tail),
            [1, _tail @ ..] => Some(Self::Win),
            [2, _tail @ ..] => Some(Self::Timeout),
            _ => None,
        }
    }

    fn get_join_context(instruction_data: &[u8]) -> Option<Self> {
        let delay = u64::from_le_bytes(instruction_data[0..8].try_into().unwrap());
        let wager = u64::from_le_bytes(instruction_data[8..16].try_into().unwrap());
        Some(Self::Join { delay, wager })
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
        OracleBetInstruction::Join { delay, wager } => join(program_id, accounts, delay, wager),
        OracleBetInstruction::Win => win(program_id, accounts),
        OracleBetInstruction::Timeout => timeout(program_id, accounts),
    }
}

fn join<'a>(
    program_id: &Pubkey,
    accounts: &'a [AccountInfo<'a>],
    delay: u64,
    wager: u64,
) -> ProgramResult {
    msg!("join");
    let accounts_iter: &mut std::slice::Iter<AccountInfo> = &mut accounts.iter();

    let participant1_account: &AccountInfo = next_account_info(accounts_iter)?;
    let participant2_account: &AccountInfo = next_account_info(accounts_iter)?;
    let oracle_account: &AccountInfo = next_account_info(accounts_iter)?;
    let oracle_bet_pda: &AccountInfo = next_account_info(accounts_iter)?;
    let system_account: &AccountInfo = next_account_info(accounts_iter)?;

    assert!(system_program::check_id(system_account.key));

    if !participant1_account.is_signer {
        return Err(ProgramError::MissingRequiredSignature);
    }

    if !participant2_account.is_signer {
        return Err(ProgramError::MissingRequiredSignature);
    }

    let (expected_pda, pda_bump) = Pubkey::find_program_address(
        &[participant1_account.key.as_ref(), participant2_account.key.as_ref()],
        program_id,
    );

    if expected_pda != *oracle_bet_pda.key {
        msg!("Invalid PDA");
        return Err(ProgramError::InvalidAccountData);
    }

    let rent_lamports = Rent::get()?.minimum_balance(OracleBetInfo::LEN);

    msg!("Creating account {} with rent {}", expected_pda, rent_lamports);
    invoke_signed(
        &system_instruction::create_account(
            participant1_account.key,
            oracle_bet_pda.key,
            rent_lamports,
            OracleBetInfo::LEN as u64,
            program_id,
        ),
        &[
            participant1_account.clone(),
            oracle_bet_pda.clone(),
            system_account.clone(),
        ],
        &[&[
            participant1_account.key.as_ref(),
            participant2_account.key.as_ref(),
            &[pda_bump],
        ]],
    )?;
    msg!("Account created");

    let deadline = Clock::get()?.slot + delay;
    let oracle_bet_info = OracleBetInfo {
        oracle: *oracle_account.key,
        participant1: *participant1_account.key,
        participant2: *participant2_account.key,
        wager,
        deadline,
    };

    oracle_bet_info.serialize(&mut &mut oracle_bet_pda.try_borrow_mut_data()?[..])?;

    invoke(
        &system_instruction::transfer(
            participant1_account.key,
            oracle_bet_pda.key,
            oracle_bet_info.wager,
        ),
        &[
            participant1_account.clone(),
            oracle_bet_pda.clone(),
            system_account.clone(),
        ],
    )?;

    invoke(
        &system_instruction::transfer(
            participant2_account.key,
            oracle_bet_pda.key,
            oracle_bet_info.wager,
        ),
        &[
            participant2_account.clone(),
            oracle_bet_pda.clone(),
            system_account.clone(),
        ],
    )?;

    Ok(())
}

fn win<'a>(program_id: &Pubkey, accounts: &'a [AccountInfo<'a>]) -> ProgramResult {
    msg!("win");
    let accounts_iter: &mut std::slice::Iter<AccountInfo> = &mut accounts.iter();

    let oracle_account: &AccountInfo = next_account_info(accounts_iter)?;
    let winner_account: &AccountInfo = next_account_info(accounts_iter)?;
    let participant1_account: &AccountInfo = next_account_info(accounts_iter)?;
    let participant2_account: &AccountInfo = next_account_info(accounts_iter)?;
    let oracle_bet_pda: &AccountInfo = next_account_info(accounts_iter)?;

    if !oracle_account.is_signer {
        return Err(ProgramError::MissingRequiredSignature);
    }

    let (expected_pda, _pda_bump) = Pubkey::find_program_address(
        &[participant1_account.key.as_ref(), participant2_account.key.as_ref()],
        program_id,
    );

    if expected_pda != *oracle_bet_pda.key {
        msg!("Invalid PDA");
        return Err(ProgramError::InvalidAccountData);
    }

    let oracle_bet_info: OracleBetInfo =
        OracleBetInfo::try_from_slice(*oracle_bet_pda.data.borrow())?;

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

    **winner_account.try_borrow_mut_lamports()? += **oracle_bet_pda.lamports.borrow();
    **oracle_bet_pda.try_borrow_mut_lamports()? = 0;
    Ok(())
}

fn timeout<'a>(program_id: &Pubkey, accounts: &'a [AccountInfo<'a>]) -> ProgramResult {
    msg!("timeout");
    let accounts_iter: &mut std::slice::Iter<AccountInfo> = &mut accounts.iter();

    let actor_account: &AccountInfo = next_account_info(accounts_iter)?;
    let participant1_account: &AccountInfo = next_account_info(accounts_iter)?;
    let participant2_account: &AccountInfo = next_account_info(accounts_iter)?;
    let oracle_bet_pda: &AccountInfo = next_account_info(accounts_iter)?;

    if !actor_account.is_signer {
        return Err(ProgramError::MissingRequiredSignature);
    }

    let (expected_pda, _pda_bump) = Pubkey::find_program_address(
        &[participant1_account.key.as_ref(), participant2_account.key.as_ref()],
        program_id,
    );

    if expected_pda != *oracle_bet_pda.key {
        msg!("Invalid PDA");
        return Err(ProgramError::InvalidAccountData);
    }

    let oracle_bet_info: OracleBetInfo =
        OracleBetInfo::try_from_slice(*oracle_bet_pda.data.borrow())?;

    if Clock::get()?.slot < oracle_bet_info.deadline {
        msg!("The timeout was not reached yet");
        return Err(ProgramError::InvalidInstructionData);
    }

    if participant1_account.key != &oracle_bet_info.participant1
        || participant2_account.key != &oracle_bet_info.participant2
    {
        msg!("The participants are not the participants in the oracle_bet_info");
        return Err(ProgramError::InvalidInstructionData);
    }

    **participant2_account.try_borrow_mut_lamports()? += oracle_bet_info.wager;
    **oracle_bet_pda.try_borrow_mut_lamports()? -= oracle_bet_info.wager;

    **participant1_account.try_borrow_mut_lamports()? += **oracle_bet_pda.lamports.borrow();
    **oracle_bet_pda.try_borrow_mut_lamports()? = 0;
    Ok(())
}
