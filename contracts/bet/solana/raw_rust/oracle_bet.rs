use borsh::{BorshDeserialize, BorshSerialize};
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

entrypoint!(process_instruction);

#[derive(BorshSerialize, BorshDeserialize, Debug)]
pub struct OracleBetInfo {
    pub oracle: Pubkey,
    pub participant1: Pubkey,
    pub participant1_has_deposited: bool,
    pub participant2: Pubkey,
    pub participant2_has_deposited: bool,
    pub wager: u64,
    pub deadline: u64,
    pub winner_was_chosen: bool,
}

impl OracleBetInfo {
    pub fn new(
        oracle: Pubkey,
        participant1: Pubkey,
        participant2: Pubkey,
        deadline: u64,
        wager: u64,
    ) -> Self {
        return Self {
            oracle,
            participant1,
            participant1_has_deposited: false,
            participant2,
            participant2_has_deposited: false,
            wager,
            deadline,
            winner_was_chosen: false,
        };
    }

    pub fn participants_have_deposited(&self) -> bool {
        self.participant1_has_deposited && self.participant2_has_deposited
    }

    pub fn only_ne_has_deposited(&self) -> bool {
        self.participant1_has_deposited ^ self.participant2_has_deposited
    }
}

pub enum OracleBetInstruction {
    Initialize { deadline: u64, wager: u64 },
    Bet,
    OracleSetResult
}

impl OracleBetInstruction {
    pub fn from_instruction_data(instruction_data: &[u8]) -> Option<Self> {
        match instruction_data {
            [0, tail @ ..] => Self::get_initialize_context(tail),
            [1, _tail @ ..] => Self::get_bet_context(),
            [2, _tail @ ..] => Self::get_oracle_set_result_context(),
            _ => None,
        }
    }

    fn get_initialize_context(instruction_data: &[u8]) -> Option<Self> {
        let deadline = u64::from_le_bytes(instruction_data[0..8].try_into().unwrap());
        let wager = u64::from_le_bytes(instruction_data[8..16].try_into().unwrap());
        Some(Self::Initialize { deadline, wager })
    }

    fn get_bet_context() -> Option<Self> {
        Some(Self::Bet)
    }

    fn get_oracle_set_result_context() -> Option<Self> {
        Some(Self::OracleSetResult)
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
        OracleBetInstruction::Bet => bet(program_id, accounts),
        OracleBetInstruction::OracleSetResult => oracle_set_result(program_id, accounts),
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
    let oracle_bet_info_account: &AccountInfo = next_account_info(accounts_iter)?;

    if !oracle_account.is_signer {
        return Err(ProgramError::MissingRequiredSignature);
    }

    if oracle_bet_info_account.owner.ne(&program_id) {
        msg!("The oracle_bet_info_account isn't owned by program");
        return Err(ProgramError::IllegalOwner);
    }

    let rent_exemption: u64 = Rent::get()?.minimum_balance(oracle_bet_info_account.data_len());
    if **oracle_bet_info_account.lamports.borrow() < rent_exemption {
        msg!("The oracle_bet_info_account should be rent exempted");
        return Err(ProgramError::AccountNotRentExempt);
    }

    let current_slot: u64 = Clock::get()?.slot;
    if current_slot >= deadline {
        msg!("The deadline should be in the future");
        return Err(ProgramError::InvalidInstructionData);
    }

    let oracle_bet_info = OracleBetInfo{
        oracle: *oracle_account.key,
        participant1: *participant1_account.key,
        participant1_has_deposited: false,
        participant2: *participant2_account.key,
        participant2_has_deposited: false,
        wager,
        deadline,
        winner_was_chosen: false,
    };

    oracle_bet_info.serialize(&mut &mut oracle_bet_info_account.try_borrow_mut_data()?[..])?;

    Ok(())
}

fn bet<'a>(program_id: &Pubkey, accounts: &'a [AccountInfo<'a>]) -> ProgramResult {
    msg!("Bet");
    let accounts_iter: &mut std::slice::Iter<AccountInfo> = &mut accounts.iter();

    let participant_account: &AccountInfo = next_account_info(accounts_iter)?;
    let oracle_bet_info_account: &AccountInfo = next_account_info(accounts_iter)?;

    if !participant_account.is_signer {
        return Err(ProgramError::MissingRequiredSignature);
    }

    if oracle_bet_info_account.owner.ne(&program_id) {
        msg!("The oracle_bet_info_account isn't owned by program");
        return Err(ProgramError::IllegalOwner);
    }

    let mut oracle_bet_info: OracleBetInfo =
        OracleBetInfo::try_from_slice(*oracle_bet_info_account.data.borrow())?;

    if oracle_bet_info.participants_have_deposited() {
        msg!("The participants have already deposited");
        return Err(ProgramError::IllegalOwner);
    }

    let current_slot: u64 = Clock::get()?.slot;
    if current_slot >= oracle_bet_info.deadline {
        msg!("The timeout was already reached");
        return Err(ProgramError::InvalidInstructionData);
    }

    if oracle_bet_info.winner_was_chosen {
        msg!("The winner was already chosen");
        return Err(ProgramError::InvalidInstructionData);
    }

    if oracle_bet_info.participant1 == *participant_account.key {
        oracle_bet_info.participant1_has_deposited = true;
    } else if oracle_bet_info.participant2 == *participant_account.key {
        oracle_bet_info.participant2_has_deposited = true;
    } else {
        msg!("The participant isn't in the oracle_bet_info");
        return Err(ProgramError::InvalidInstructionData);
    }

    let rent_exemption: u64 = Rent::get()?.minimum_balance(oracle_bet_info_account.data_len());

    let minimum_amount: u64 = if oracle_bet_info.only_ne_has_deposited() {
        oracle_bet_info.wager * 2
    } else {
        oracle_bet_info.wager
    };

    if **participant_account.lamports.borrow() - rent_exemption < minimum_amount {
        msg!("Insufficent sended amount");
        return Err(ProgramError::InvalidInstructionData);
    }

    oracle_bet_info.serialize(&mut &mut oracle_bet_info_account.try_borrow_mut_data()?[..])?;
    Ok(())
}


fn oracle_set_result<'a>(program_id: &Pubkey, accounts: &'a [AccountInfo<'a>]) -> ProgramResult {
    msg!("oracle_set_result");
    let accounts_iter: &mut std::slice::Iter<AccountInfo> = &mut accounts.iter();

    let oracle_account: &AccountInfo = next_account_info(accounts_iter)?;
    let winner_account: &AccountInfo = next_account_info(accounts_iter)?;
    let oracle_bet_info_account: &AccountInfo = next_account_info(accounts_iter)?;

    if !oracle_account.is_signer {
        return Err(ProgramError::MissingRequiredSignature);
    }

    if oracle_bet_info_account.owner.ne(&program_id) {
        msg!("The oracle_bet_info_account isn't owned by program");
        return Err(ProgramError::IllegalOwner);
    }

    let mut oracle_bet_info: OracleBetInfo =
        OracleBetInfo::try_from_slice(*oracle_bet_info_account.data.borrow())?;


    if oracle_bet_info.oracle != *oracle_account.key {
        msg!("The oracle isn't in the oracle_bet_info");
        return Err(ProgramError::InvalidInstructionData);
    }

    if oracle_bet_info.winner_was_chosen {
        msg!("The winner was already chosen");
        return Err(ProgramError::InvalidInstructionData);
    }

    oracle_bet_info.winner_was_chosen = true;

    if oracle_bet_info.participant1 == *winner_account.key || oracle_bet_info.participant2 == *winner_account.key {
        oracle_bet_info.winner_was_chosen = true;
    } else {
        msg!("The winner isn't in the oracle_bet_info");
        return Err(ProgramError::InvalidInstructionData);
    }

    if !oracle_bet_info.participants_have_deposited() {
        msg!("The participants have not deposited");
        return Err(ProgramError::IllegalOwner);
    }

    let current_slot: u64 = Clock::get()?.slot;
    if current_slot < oracle_bet_info.deadline {
        msg!("The timeout was not reached yet");
        return Err(ProgramError::InvalidInstructionData);
    }

    let amount_to_winner = oracle_bet_info.wager * 2;
    let amount_to_oracle = **oracle_bet_info_account.lamports.borrow() - amount_to_winner;

    **winner_account.try_borrow_mut_lamports()? += amount_to_winner;
    **oracle_account.try_borrow_mut_lamports()? += amount_to_oracle;
    **oracle_bet_info_account.try_borrow_mut_lamports()?  = 0;
    
    Ok(())
}
