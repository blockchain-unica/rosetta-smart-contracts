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

use pyth_sdk_solana::load_price_feed_from_account_info;
use std::str::FromStr;

// Pyth oracle
// https://www.quicknode.com/guides/solana-development/3rd-party-integrations/pyth-price-feeds
// https://docs.rs/crate/pyth-sdk-solana/latest/source/src/lib.rs

entrypoint!(process_instruction);

#[derive(BorshSerialize, BorshDeserialize, Debug)]
pub struct OracleBetInfo {
    pub owner: Pubkey,  // 32 bytes
    pub player: Pubkey, // 32 bytes
    pub wager: u64,     // 8 bytes
    pub deadline: u64,  // 8 bytes
    pub rate: u64,      // 8 bytes
}

impl OracleBetInfo {
    pub const LEN: usize = 32 + 32 + 8 + 8 + 8;
}

const BTC_USDC_FEED: &str = "HovQMDrbAgAYPCmHVSrezcSmkMtXSSUsLDFANExrZh2J"; // only for the devnet cluster
const BTC_USDC_FEED_OWNER: &str = "gSbePebfvPy7tRqimPoVecS2UsBvYv46ynrzWocc92s"; // only for the devnet cluster
const STALENESS_THRESHOLD: u64 = 60; // staleness threshold in seconds

pub enum OracleBetInstruction {
    Init { delay: u64, wager: u64, rate: u64 },
    Join,
    Win,
    Timeout,
}

impl OracleBetInstruction {
    pub fn from_instruction_data(instruction_data: &[u8]) -> Option<Self> {
        match instruction_data {
            [0, tail @ ..] => Self::get_init_context(tail),
            [1, _tail @ ..] => Some(Self::Join),
            [2, _tail @ ..] => Some(Self::Win),
            [3, _tail @ ..] => Some(Self::Timeout),
            _ => None,
        }
    }

    fn get_init_context(instruction_data: &[u8]) -> Option<Self> {
        let delay = u64::from_le_bytes(instruction_data[0..8].try_into().unwrap());
        let wager = u64::from_le_bytes(instruction_data[8..16].try_into().unwrap());
        let rate = u64::from_le_bytes(instruction_data[16..24].try_into().unwrap());
        Some(Self::Init { delay, wager, rate })
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
        OracleBetInstruction::Init { delay, wager, rate } => {
            init(program_id, accounts, delay, wager, rate)
        }
        OracleBetInstruction::Join => join(program_id, accounts),
        OracleBetInstruction::Win => win(program_id, accounts),
        OracleBetInstruction::Timeout => timeout(program_id, accounts),
    }
}

fn init<'a>(
    program_id: &Pubkey,
    accounts: &'a [AccountInfo<'a>],
    delay: u64,
    wager: u64,
    rate: u64,
) -> ProgramResult {
    msg!("init");
    let accounts_iter: &mut std::slice::Iter<AccountInfo> = &mut accounts.iter();
    let owner_account: &AccountInfo = next_account_info(accounts_iter)?;
    let oracle_bet_pda: &AccountInfo = next_account_info(accounts_iter)?;
    let system_account: &AccountInfo = next_account_info(accounts_iter)?;

    assert!(system_program::check_id(system_account.key));

    if !owner_account.is_signer {
        return Err(ProgramError::MissingRequiredSignature);
    }

    let (expected_pda, pda_bump) =
        Pubkey::find_program_address(&[owner_account.key.as_ref()], program_id);

    if expected_pda != *oracle_bet_pda.key {
        msg!("Invalid PDA");
        return Err(ProgramError::InvalidAccountData);
    }

    let rent_lamports = Rent::get()?.minimum_balance(OracleBetInfo::LEN);

    invoke_signed(
        &system_instruction::create_account(
            owner_account.key,
            oracle_bet_pda.key,
            rent_lamports,
            OracleBetInfo::LEN as u64,
            program_id,
        ),
        &[
            owner_account.clone(),
            oracle_bet_pda.clone(),
            system_account.clone(),
        ],
        &[&[owner_account.key.as_ref(), &[pda_bump]]],
    )?;

    let deadline = Clock::get()?.slot + delay;
    let oracle_bet_info = OracleBetInfo {
        owner: *owner_account.key,
        player: Pubkey::default(),
        wager,
        deadline,
        rate,
    };

    oracle_bet_info.serialize(&mut &mut oracle_bet_pda.try_borrow_mut_data()?[..])?;

    invoke(
        &system_instruction::transfer(owner_account.key, oracle_bet_pda.key, oracle_bet_info.wager),
        &[
            owner_account.clone(),
            oracle_bet_pda.clone(),
            system_account.clone(),
        ],
    )?;

    Ok(())
}

fn join<'a>(program_id: &Pubkey, accounts: &'a [AccountInfo<'a>]) -> ProgramResult {
    msg!("join");
    let accounts_iter: &mut std::slice::Iter<AccountInfo> = &mut accounts.iter();
    let owner_account: &AccountInfo = next_account_info(accounts_iter)?;
    let player_account: &AccountInfo = next_account_info(accounts_iter)?;
    let oracle_bet_pda: &AccountInfo = next_account_info(accounts_iter)?;
    let system_account: &AccountInfo = next_account_info(accounts_iter)?;

    assert!(system_program::check_id(system_account.key));

    if !player_account.is_signer {
        return Err(ProgramError::MissingRequiredSignature);
    }

    let (expected_pda, _pda_bump) =
        Pubkey::find_program_address(&[owner_account.key.as_ref()], program_id);

    if expected_pda != *oracle_bet_pda.key {
        msg!("Invalid PDA");
        return Err(ProgramError::InvalidAccountData);
    }

    let mut oracle_bet_info = OracleBetInfo::try_from_slice(*oracle_bet_pda.data.borrow())?;

    if oracle_bet_info.player != Pubkey::default() {
        msg!("The player is already set");
        return Err(ProgramError::InvalidInstructionData);
    }

    oracle_bet_info.player = *player_account.key;

    oracle_bet_info.serialize(&mut &mut oracle_bet_pda.try_borrow_mut_data()?[..])?;

    invoke(
        &system_instruction::transfer(
            player_account.key,
            oracle_bet_pda.key,
            oracle_bet_info.wager,
        ),
        &[
            player_account.clone(),
            oracle_bet_pda.clone(),
            system_account.clone(),
        ],
    )?;

    Ok(())
}

fn win<'a>(program_id: &Pubkey, accounts: &'a [AccountInfo<'a>]) -> ProgramResult {
    msg!("win");
    let accounts_iter: &mut std::slice::Iter<AccountInfo> = &mut accounts.iter();
    let owner_account: &AccountInfo = next_account_info(accounts_iter)?;
    let player_account: &AccountInfo = next_account_info(accounts_iter)?;
    let price_feed_account: &AccountInfo = next_account_info(accounts_iter)?;
    let oracle_bet_pda: &AccountInfo = next_account_info(accounts_iter)?;

    if !player_account.is_signer {
        return Err(ProgramError::MissingRequiredSignature);
    }

    let (expected_pda, _pda_bump) =
        Pubkey::find_program_address(&[owner_account.key.as_ref()], program_id);

    if expected_pda != *oracle_bet_pda.key {
        msg!("Invalid PDA");
        return Err(ProgramError::InvalidAccountData);
    }

    let oracle_bet_info: OracleBetInfo =
        OracleBetInfo::try_from_slice(*oracle_bet_pda.data.borrow())?;

    if owner_account.key != &oracle_bet_info.owner || player_account.key != &oracle_bet_info.player
    {
        msg!("The participants are not the participants in the oracle_bet_info");
        return Err(ProgramError::InvalidInstructionData);
    }

    if oracle_bet_info.deadline <= Clock::get()?.slot {
        msg!("The deadline has passed");
        return Err(ProgramError::InvalidInstructionData);
    }

    if price_feed_account.key != &Pubkey::from_str(BTC_USDC_FEED).unwrap() {
        msg!("The price_feed_account is not the BTC/USD price feed account");
        return Err(ProgramError::InvalidInstructionData);
    }

    if price_feed_account.owner != &Pubkey::from_str(BTC_USDC_FEED_OWNER).unwrap() {
        msg!("The price_feed_account is not owned by the Pyth oracle program");
        return Err(ProgramError::InvalidInstructionData);
    }

    let price_feed = load_price_feed_from_account_info(&price_feed_account).unwrap();
    let current_timestamp = Clock::get()?.unix_timestamp;
    let current_price = price_feed
        .get_price_no_older_than(current_timestamp, STALENESS_THRESHOLD)
        .unwrap();

    let price = u64::try_from(current_price.price).unwrap()
        / 10u64.pow(u32::try_from(-current_price.expo).unwrap());
    let display_confidence = u64::try_from(current_price.conf).unwrap()
        / 10u64.pow(u32::try_from(-current_price.expo).unwrap());

    msg!("BTC/USD price: ({} +- {})", price, display_confidence);

    if price <= oracle_bet_info.rate {
        msg!("The rate is not higher than the current price");
        return Err(ProgramError::InvalidInstructionData);
    }

    **player_account.try_borrow_mut_lamports()? += **oracle_bet_pda.lamports.borrow();
    **oracle_bet_pda.try_borrow_mut_lamports()? = 0;

    Ok(())
}

fn timeout<'a>(program_id: &Pubkey, accounts: &'a [AccountInfo<'a>]) -> ProgramResult {
    msg!("timeout");
    let accounts_iter: &mut std::slice::Iter<AccountInfo> = &mut accounts.iter();
    let owner_account: &AccountInfo = next_account_info(accounts_iter)?;
    let oracle_bet_pda: &AccountInfo = next_account_info(accounts_iter)?;

    if !owner_account.is_signer {
        return Err(ProgramError::MissingRequiredSignature);
    }

    let (expected_pda, _pda_bump) =
        Pubkey::find_program_address(&[owner_account.key.as_ref()], program_id);

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

    **owner_account.try_borrow_mut_lamports()? += **oracle_bet_pda.lamports.borrow();
    **oracle_bet_pda.try_borrow_mut_lamports()? = 0;
    Ok(())
}
