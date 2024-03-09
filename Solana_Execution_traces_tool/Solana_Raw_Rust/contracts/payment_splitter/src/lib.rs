use borsh::{BorshDeserialize, BorshSerialize};
use solana_program::{
    account_info::{next_account_info, AccountInfo},
    entrypoint,
    entrypoint::ProgramResult,
    msg,
    program::invoke_signed,
    program_error::ProgramError,
    pubkey::Pubkey,
    rent::Rent,
    system_instruction,
    sysvar::Sysvar,
};

use std::collections::BTreeMap;

entrypoint!(process_instruction);

const PS_SEED: &str = "PS_SEEDsssssdsssssssdd";

#[derive(BorshSerialize, BorshDeserialize, Debug)]
pub struct PaymentSplitterInfo {
    pub shares_map: BTreeMap<Pubkey, u64>,
    pub released_map: BTreeMap<Pubkey, u64>,
    pub current_lamports: u64,
}

impl PaymentSplitterInfo {
    pub fn check_validity(&mut self) {
        if self.shares_map.len() != self.released_map.len() {
            panic!("PaymentSplitter: shares_map and released_map are not the same size");
        }

        for (key, _value) in &self.shares_map {
            if !self.released_map.contains_key(key) {
                panic!("PaymentSplitter: shares_map and released_map keys are not the same");
            }
        }

        for (_key, value) in &self.shares_map {
            if *value == 0 {
                panic!("PaymentSplitter: share value is 0 for some account");
            }
        }

        for (key, _value) in &self.shares_map {
            self.released_map.insert(*key, 0);
        }
    }

    pub fn get_total_shares(&self) -> u64 {
        let mut total_shares: u64 = 0;
        for (_key, value) in &self.shares_map {
            total_shares += value;
        }
        return total_shares;
    }

    pub fn get_total_released(&self) -> u64 {
        let mut total_shares: u64 = 0;
        for (_key, value) in &self.released_map {
            total_shares += value;
        }
        return total_shares;
    }

    pub fn get_released(&self, account: &Pubkey) -> u64 {
        return self.released_map[account];
    }

    pub fn get_shares(&self, account: &Pubkey) -> u64 {
        return self.shares_map[account];
    }

    pub fn get_releasable_for_account(&self, account: &Pubkey) -> u64 {
        let total_received = self.current_lamports + self.get_total_released();
        let already_released = self.get_released(&account);

        let payment = (total_received * self.shares_map[&account]) / self.get_total_shares()
            - already_released;

        return payment;
    }
}

pub enum PSInstruction {
    Initialize {
        ps_info: PaymentSplitterInfo,
        pda_size: usize,
    },
    Release,
}

impl PSInstruction {
    pub fn from_instruction_data(instruction_data: &[u8]) -> Option<Self> {
        match instruction_data {
            [0, tail @ ..] => Self::get_initialize_context(tail),
            [1, _tail @ ..] => Some(Self::Release),
            _ => None,
        }
    }

    fn get_initialize_context(instruction_data: &[u8]) -> Option<Self> {
        let mut ps_info = PaymentSplitterInfo::try_from_slice(&instruction_data).unwrap();
        ps_info.check_validity();
        let pda_size = instruction_data.len();
        Some(Self::Initialize { ps_info, pda_size })
    }
}

pub fn process_instruction<'a>(
    program_id: &Pubkey,
    accounts: &'a [AccountInfo<'a>],
    instruction_data: &[u8],
) -> ProgramResult {
    let instruction = PSInstruction::from_instruction_data(instruction_data)
        .ok_or(ProgramError::InvalidInstructionData)?;
    match instruction {
        PSInstruction::Initialize { ps_info, pda_size } => {
            initialize(program_id, accounts, ps_info, pda_size)
        }
        PSInstruction::Release => release(program_id, accounts),
    }
}

fn initialize<'a>(
    program_id: &Pubkey,
    accounts: &'a [AccountInfo<'a>],
    ps_info: PaymentSplitterInfo,
    pda_size: usize,
) -> ProgramResult {
    let accounts_iter: &mut std::slice::Iter<AccountInfo> = &mut accounts.iter();
    let initializer_account: &AccountInfo = next_account_info(accounts_iter)?;
    let ps_state_account: &AccountInfo = next_account_info(accounts_iter)?;
    let system_program_account: &AccountInfo = next_account_info(accounts_iter)?;

    if !initializer_account.is_signer {
        return Err(ProgramError::MissingRequiredSignature);
    }

    let _ps_bump = check_pda(program_id, ps_state_account, &[PS_SEED.as_bytes()])?;

    create_pda_account(
        initializer_account,
        ps_state_account,
        system_program_account,
        ps_info.current_lamports,
        program_id,
        &[&[PS_SEED.as_bytes(), &[_ps_bump]]],
        pda_size,
    )?;

    ps_info.serialize(&mut &mut ps_state_account.try_borrow_mut_data()?[..])?;

    Ok(())
}

fn release<'a>(program_id: &Pubkey, accounts: &'a [AccountInfo<'a>]) -> ProgramResult {
    let accounts_iter: &mut std::slice::Iter<AccountInfo> = &mut accounts.iter();
    let payee_account: &AccountInfo = next_account_info(accounts_iter)?;
    let ps_state_account: &AccountInfo = next_account_info(accounts_iter)?;

    if !payee_account.is_signer {
        return Err(ProgramError::MissingRequiredSignature);
    }

    let _ps_bump = check_pda(program_id, ps_state_account, &[PS_SEED.as_bytes()])?;

    let mut ps_info = PaymentSplitterInfo::try_from_slice(*ps_state_account.data.borrow())?;

    let payee_shares = ps_info.get_shares(payee_account.key);
    if payee_shares == 0 {
        msg!("Account has no shares");
        return Err(ProgramError::InvalidAccountData);
    }

    let payment_value: u64 = ps_info.get_releasable_for_account(&payee_account.key);

    if payment_value == 0 {
        msg!("Account is not due payment");
        return Err(ProgramError::InvalidAccountData);
    }

    let payee_released = ps_info.get_released(payee_account.key);
    ps_info
        .released_map
        .insert(*payee_account.key, payee_released + payment_value);

    ps_info.current_lamports -= payment_value;

    **payee_account.try_borrow_mut_lamports()? += payment_value;
    **ps_state_account.try_borrow_mut_lamports()? -= payment_value;

    ps_info.serialize(&mut &mut ps_state_account.try_borrow_mut_data()?[..])?;

    Ok(())
}

pub fn check_pda<'a>(
    program_id: &Pubkey,
    account_to_check: &'a AccountInfo<'a>,
    seeds: &[&[u8]],
) -> Result<u8, ProgramError> {
    let (pub_key, bump_seed) = Pubkey::find_program_address(&seeds, program_id);

    if pub_key != *account_to_check.key {
        msg!("PDA doesn't match with the one provided");
        return Err(ProgramError::InvalidAccountData);
    }

    return Ok(bump_seed);
}

pub fn create_pda_account<'a>(
    payer: &'a AccountInfo<'a>,
    new_account: &'a AccountInfo<'a>,
    system_program_account: &'a AccountInfo<'a>,
    additional_lamports: u64,
    program_id: &Pubkey,
    signers_seeds: &[&[&[u8]]],
    data_len: usize,
) -> ProgramResult {
    if new_account.lamports() != 0 {
        msg!("Trying to create an already existing account");
        return Err(ProgramError::InvalidAccountData);
    }

    let rent = Rent::get()?;

    let instruction = system_instruction::create_account(
        payer.key,
        new_account.key,
        rent.minimum_balance(data_len) + additional_lamports as u64,
        data_len as u64,
        program_id,
    );

    let account_infos = [
        payer.clone(),
        new_account.clone(),
        system_program_account.clone(),
    ];

    invoke_signed(&instruction, &account_infos, signers_seeds)
}
