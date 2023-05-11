use borsh::{BorshDeserialize, BorshSerialize};
use solana_program::{
    account_info::{next_account_info, AccountInfo},
    entrypoint,
    entrypoint::ProgramResult,
    msg,
    program_error::ProgramError,
    pubkey::Pubkey,
    rent::Rent,
    sysvar::Sysvar,
};

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
        1 => deposit(program_id, accounts),
        2 => pay(program_id, accounts),
        3 => refund(program_id, accounts),
        _ => {
            msg!("Didn't found the entrypoint required");
            Err(ProgramError::InvalidInstructionData)
        }
    }
}

#[derive(BorshSerialize, BorshDeserialize, Debug, PartialEq)]
enum State {
    WaitDeposit = 0,
    WaitRecipient = 1,
    Closed = 2,
}

#[derive(BorshSerialize, BorshDeserialize, Debug)]
struct EscowInfo {
    pub seller: Pubkey,
    pub buyer: Pubkey,
    pub amount: u64,
    pub state: State,
}

fn initialize(
    program_id: &Pubkey,
    accounts: &[AccountInfo],
    instruction_data: &[u8],
) -> ProgramResult {
    let accounts_iter: &mut std::slice::Iter<AccountInfo> = &mut accounts.iter();
    let seller: &AccountInfo = next_account_info(accounts_iter)?;
    let buyer: &AccountInfo = next_account_info(accounts_iter)?;
    let state_account: &AccountInfo = next_account_info(accounts_iter)?;

    if !seller.is_signer {
        msg!("The seller account should be the signer");
        return Err(ProgramError::MissingRequiredSignature);
    }

    if state_account.owner.ne(&program_id){
        msg!("The state account isn't owned by program");
        return Err(ProgramError::IllegalOwner);
    }

    let rent_exemption: u64 = Rent::get()?.minimum_balance(state_account.data_len());
    if **state_account.try_borrow_lamports()? < rent_exemption {
        msg!("The state account should be rent exempted");
        return Err(ProgramError::AccountNotRentExempt);
    }

    let amount: u64 = instruction_data
        .iter()
        .rev()
        .fold(0, |acc, &x| (acc << 8) + x as u64);

    if amount <= 0 {
        msg!("The amount should be positive");
        return Err(ProgramError::InvalidInstructionData);
    }

    let escow_info = EscowInfo {
        seller: *seller.key,
        buyer: *buyer.key,
        amount,
        state: State::WaitDeposit,
    };

    escow_info.serialize(&mut &mut state_account.try_borrow_mut_data()?[..])?;

    Ok(())
}

fn deposit(program_id: &Pubkey, accounts: &[AccountInfo]) -> ProgramResult {
    let accounts_iter: &mut std::slice::Iter<AccountInfo> = &mut accounts.iter();
    let buyer_account: &AccountInfo = next_account_info(accounts_iter)?;
    let state_account: &AccountInfo = next_account_info(accounts_iter)?;

    if !buyer_account.is_signer {
        msg!("The buyer account should be the signer");
        return Err(ProgramError::MissingRequiredSignature);
    }

    if state_account.owner.ne(&program_id){
        msg!("The state account isn't owned by program");
        return Err(ProgramError::IllegalOwner);
    }

    let mut escow_info = EscowInfo::try_from_slice(*state_account.data.borrow())?;

    if escow_info.buyer != *buyer_account.key {
        msg!("Only the buyer can deposit");
        return Err(ProgramError::InvalidAccountData);
    }

    let rent_exemption: u64 = Rent::get()?.minimum_balance(state_account.data_len());
    if **state_account.try_borrow_lamports()? < escow_info.amount + rent_exemption {
        msg!("Not enough lamports in the state account");
        return Err(ProgramError::InsufficientFunds);
    }

    if escow_info.state != State::WaitDeposit {
        msg!("The escow isn't in the state of waiting a deposit");
        return Err(ProgramError::InvalidInstructionData);
    }

    escow_info.state = State::WaitRecipient;
    escow_info.serialize(&mut &mut state_account.try_borrow_mut_data()?[..])?;

    Ok(())
}

fn pay(program_id: &Pubkey, accounts: &[AccountInfo]) -> ProgramResult {
    let accounts_iter: &mut std::slice::Iter<AccountInfo> = &mut accounts.iter();
    let buyer_account: &AccountInfo = next_account_info(accounts_iter)?;
    let seller_account: &AccountInfo = next_account_info(accounts_iter)?;
    let state_account: &AccountInfo = next_account_info(accounts_iter)?;

    if !buyer_account.is_signer {
        msg!("The buyer account should be the signer");
        return Err(ProgramError::MissingRequiredSignature);
    }

    if state_account.owner.ne(&program_id){
        msg!("The state account isn't owned by program");
        return Err(ProgramError::IllegalOwner);
    }

    let mut escow_info = EscowInfo::try_from_slice(*state_account.data.borrow())?;

    if escow_info.buyer != *buyer_account.key {
        msg!("Only the buyer can pay");
        return Err(ProgramError::InvalidAccountData);
    }

    if escow_info.state != State::WaitRecipient {
        msg!("The escow isn't in the state of waiting the recipient");
        return Err(ProgramError::InvalidInstructionData);
    }

    **seller_account.try_borrow_mut_lamports()? += **state_account.try_borrow_lamports()?;
    **state_account.try_borrow_mut_lamports()? = 0;

    escow_info.state = State::Closed;
    escow_info.serialize(&mut &mut state_account.try_borrow_mut_data()?[..])?;

    Ok(())
}

fn refund(program_id: &Pubkey, accounts: &[AccountInfo]) -> ProgramResult {
    let accounts_iter: &mut std::slice::Iter<AccountInfo> = &mut accounts.iter();
    let seller_account: &AccountInfo = next_account_info(accounts_iter)?;
    let buyer_account: &AccountInfo = next_account_info(accounts_iter)?;
    let state_account: &AccountInfo = next_account_info(accounts_iter)?;

    if !seller_account.is_signer {
        msg!("The seller account should be the signer");
        return Err(ProgramError::MissingRequiredSignature);
    }

    if state_account.owner.ne(&program_id){
        msg!("The state account isn't owned by program");
        return Err(ProgramError::IllegalOwner);
    }

    let mut escow_info = EscowInfo::try_from_slice(*state_account.data.borrow())?;

    if escow_info.seller != *seller_account.key {
        msg!("Only the seller can refund");
        return Err(ProgramError::InvalidAccountData);
    }

    if escow_info.state != State::WaitRecipient {
        msg!("The escow isn't in the state of waiting the recipient");
        return Err(ProgramError::InvalidInstructionData);
    }

    **buyer_account.try_borrow_mut_lamports()? += escow_info.amount;
    **state_account.try_borrow_mut_lamports()? -= escow_info.amount;

    // Return the rent founds to the seller
    **seller_account.try_borrow_mut_lamports()? += **state_account.try_borrow_lamports()?;
    **state_account.try_borrow_mut_lamports()? = 0;

    escow_info.state = State::Closed;
    escow_info.serialize(&mut &mut state_account.try_borrow_mut_data()?[..])?;

    Ok(())
}
