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

#[derive(BorshSerialize, BorshDeserialize, Debug, PartialEq)]
enum State {
    Idle = 0,
    Req = 1,
}

#[derive(BorshSerialize, BorshDeserialize, Debug)]
struct VaultInfo {
    pub owner: Pubkey,
    pub recovery: Pubkey,
    pub receiver: Pubkey,
    pub wait_time: u64,
    pub request_time: u64,
    pub amount: u64,
    pub state: State,
}

#[derive(BorshSerialize, BorshDeserialize, Debug)]
struct PassedAmount {
    pub amount: u64,
}

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
        1 => withdraw(
            program_id,
            accounts,
            &instruction_data[1..instruction_data.len()],
        ),
        2 => finalize(program_id, accounts),
        3 => cancel(program_id, accounts),
        _ => {
            msg!("Didn't found the entrypoint required");
            Err(ProgramError::InvalidInstructionData)
        }
    }
}

fn initialize(
    program_id: &Pubkey,
    accounts: &[AccountInfo],
    instruction_data: &[u8],
) -> ProgramResult {
    let accounts_iter: &mut std::slice::Iter<AccountInfo> = &mut accounts.iter();

    let owner_account: &AccountInfo = next_account_info(accounts_iter)?;
    let state_account: &AccountInfo = next_account_info(accounts_iter)?;
    let recovery_account: &AccountInfo = next_account_info(accounts_iter)?;

    if !owner_account.is_signer {
        msg!("The owner should be signer");
        return Err(ProgramError::MissingRequiredSignature);
    }

    if state_account.owner != program_id {
        msg!("The state account isn't owned by program");
        return Err(ProgramError::IllegalOwner);
    }

    let rent_exemption: u64 = Rent::get()?.minimum_balance(state_account.data_len());
    if **state_account.lamports.borrow() < rent_exemption {
        msg!("State account should be rent-exempt");
        return Err(ProgramError::AccountNotRentExempt);
    }

    let wait_time: u64 = instruction_data
        .iter()
        .rev()
        .fold(0, |acc, &x| (acc << 8) + x as u64);

    let vault_info = VaultInfo {
        owner: *owner_account.key,
        recovery: *recovery_account.key,
        receiver: Pubkey::default(), // temporal
        wait_time,
        request_time: 0,
        amount: 0, // at the beginning the withdraw amount is not setted
        state: State::Idle,
    };

    vault_info.serialize(&mut &mut state_account.try_borrow_mut_data()?[..])?;

    Ok(())
}

fn withdraw(
    program_id: &Pubkey,
    accounts: &[AccountInfo],
    instruction_data: &[u8],
) -> ProgramResult {
    let accounts_iter: &mut std::slice::Iter<AccountInfo> = &mut accounts.iter();

    let owner_account: &AccountInfo = next_account_info(accounts_iter)?;
    let state_account: &AccountInfo = next_account_info(accounts_iter)?;
    let receiver_account: &AccountInfo = next_account_info(accounts_iter)?;

    let withdraw_amount: u64 = instruction_data
        .iter()
        .rev()
        .fold(0, |acc, &x| (acc << 8) + x as u64);

    let mut vault_info: VaultInfo = VaultInfo::try_from_slice(*state_account.data.borrow())?;

    if !owner_account.is_signer {
        msg!("The sender should be signer");
        return Err(ProgramError::MissingRequiredSignature);
    }

    let rent_exemption = Rent::get()?.minimum_balance(state_account.data_len());
    if **state_account.lamports.borrow() - rent_exemption < withdraw_amount {
        msg!("Insufficient balance in the state account to withdraw the defined amount");
        return Err(ProgramError::AccountNotRentExempt);
    }

    if state_account.owner.ne(&program_id){
        msg!("The state account isn't owned by program");
        return Err(ProgramError::IllegalOwner);
    }

    if vault_info.state != State::Idle {
        msg!("The vault isn't in Idle state");
        return Err(ProgramError::InvalidInstructionData);
    }

    if *owner_account.key != vault_info.owner {
        msg!("Only the owner can withdraw the funds");
        return Err(ProgramError::IllegalOwner);
    }

    vault_info.receiver = *receiver_account.key;
    vault_info.request_time = Clock::get()?.slot;
    vault_info.amount = withdraw_amount;
    vault_info.state = State::Req;

    vault_info.serialize(&mut &mut state_account.try_borrow_mut_data()?[..])?;

    Ok(())
}

fn finalize(program_id: &Pubkey, accounts: &[AccountInfo]) -> ProgramResult {
    let accounts_iter: &mut std::slice::Iter<AccountInfo> = &mut accounts.iter();

    let owner_account: &AccountInfo = next_account_info(accounts_iter)?;
    let state_account: &AccountInfo = next_account_info(accounts_iter)?;
    let receiver_account: &AccountInfo = next_account_info(accounts_iter)?;

    if state_account.owner != program_id {
        msg!("The state account isn't owned by program");
        return Err(ProgramError::InvalidAccountData);
    }

    let mut vault_info: VaultInfo = VaultInfo::try_from_slice(*state_account.data.borrow())?;

    if !owner_account.is_signer {
        msg!("The owner account should be signer");
        return Err(ProgramError::MissingRequiredSignature);
    }

    if vault_info.state != State::Req {
        msg!("The vault isn't in Req state");
        return Err(ProgramError::InvalidInstructionData);
    }

    let rent_exemption = Rent::get()?.minimum_balance(state_account.data_len());
    if **state_account.lamports.borrow() - rent_exemption < vault_info.amount {
        msg!("Insufficient balance in the state account to withdraw the defined amount");
        return Err(ProgramError::InsufficientFunds);
    }

    if *owner_account.key != vault_info.owner {
        msg!("Only the owner can withdraw the funds");
        return Err(ProgramError::MissingRequiredSignature);
    }

    if Clock::get()?.slot < vault_info.request_time + vault_info.wait_time {
        msg!("The wait time hasn't passed yet");
        return Err(ProgramError::MissingRequiredSignature);
    }

    vault_info.state = State::Idle;
    vault_info.serialize(&mut &mut state_account.try_borrow_mut_data()?[..])?;

    **state_account.try_borrow_mut_lamports()? -= vault_info.amount;
    **receiver_account.try_borrow_mut_lamports()? += vault_info.amount;

    Ok(())
}

fn cancel(program_id: &Pubkey, accounts: &[AccountInfo]) -> ProgramResult {
    let accounts_iter: &mut std::slice::Iter<AccountInfo> = &mut accounts.iter();

    let recovery_account: &AccountInfo = next_account_info(accounts_iter)?;
    let state_account: &AccountInfo = next_account_info(accounts_iter)?;

    if !recovery_account.is_signer {
        msg!("The recovery account should be signer");
        return Err(ProgramError::MissingRequiredSignature);
    }

    if state_account.owner != program_id {
        msg!("The state account isn't owned by program");
        return Err(ProgramError::InvalidAccountData);
    }

    let mut vault_info: VaultInfo = VaultInfo::try_from_slice(*state_account.data.borrow())?;

    if vault_info.state != State::Req {
        msg!("The vault isn't in Req state");
        return Err(ProgramError::InvalidInstructionData);
    }

    if *recovery_account.key != vault_info.recovery {
        msg!("Only the recovery account can cancel");
        return Err(ProgramError::InvalidAccountData);
    }

    vault_info.state = State::Idle;

    vault_info.serialize(&mut &mut state_account.try_borrow_mut_data()?[..])?;

    Ok(())
}
