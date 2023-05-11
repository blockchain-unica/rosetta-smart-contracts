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

entrypoint!(process_instruction);

#[derive(BorshSerialize, BorshDeserialize, Debug)]
struct UserTransaction {
    pub to: Pubkey,
    pub value: u64,
    pub executed: bool,
}

impl UserTransaction {
    pub const LEN: usize = 32 + 8 + 1;
}

const SEED_FOR_WALLET: &str = "wallet";
const SEED_FOR_TRANSACTION: &str = "tx";

pub fn process_instruction(
    program_id: &Pubkey,
    accounts: &[AccountInfo],
    instruction_data: &[u8],
) -> ProgramResult {
    if instruction_data.len() == 0 {
        return Err(ProgramError::InvalidInstructionData);
    }
    match instruction_data[0] {
        0 => deposit(
            program_id,
            accounts,
            &instruction_data[1..instruction_data.len()],
        ),
        1 => create_transaction(
            program_id,
            accounts,
            &instruction_data[1..instruction_data.len()],
        ),
        2 => execute_transaction(
            program_id,
            accounts,
            &instruction_data[1..instruction_data.len()],
        ),
        3 => withdraw(program_id, accounts),
        _ => {
            msg!("Didn't found the entrypoint required");
            Err(ProgramError::InvalidInstructionData)
        }
    }
}

fn deposit(
    program_id: &Pubkey,
    accounts: &[AccountInfo],
    instruction_data: &[u8],
) -> ProgramResult {
    let accounts_iter: &mut std::slice::Iter<AccountInfo> = &mut accounts.iter();
    let owner_account: &AccountInfo = next_account_info(accounts_iter)?;
    let wallet_account: &AccountInfo = next_account_info(accounts_iter)?;
    let system_program_account = next_account_info(accounts_iter)?;

    if !owner_account.is_signer {
        msg!("The owner should be signer");
        return Err(ProgramError::MissingRequiredSignature);
    }

    let (wallet_pda, wallet_bump) = Pubkey::find_program_address(
        &[SEED_FOR_WALLET.as_bytes(), owner_account.key.as_ref()],
        program_id,
    );

    if wallet_pda != *wallet_account.key {
        msg!("Not the sender's pda wallet");
        return Err(ProgramError::InvalidAccountData);
    }

    let amount_to_deposit: u64 = instruction_data
        .iter()
        .rev()
        .fold(0, |acc, &x| (acc << 8) + x as u64);

    if wallet_account.lamports() == 0 {
        let space = 8;
        let rent = Rent::get()?;
        let rent_lamports = rent.minimum_balance(space);
        invoke_signed(
            &system_instruction::create_account(
                owner_account.key,
                wallet_account.key,
                rent_lamports + amount_to_deposit,
                space as u64,
                program_id,
            ),
            &[
                owner_account.clone(),
                wallet_account.clone(),
                system_program_account.clone(),
            ],
            &[&[
                SEED_FOR_WALLET.as_bytes(),
                owner_account.key.as_ref(),
                &[wallet_bump],
            ]],
        )?;
        return Ok(());
    }

    invoke_signed(
        &system_instruction::transfer(owner_account.key, wallet_account.key, amount_to_deposit),
        &[owner_account.clone(), wallet_account.clone()],
        &[&[
            SEED_FOR_WALLET.as_bytes(),
            owner_account.key.as_ref(),
            &[wallet_bump],
        ]],
    )?;

    Ok(())
}

fn create_transaction(
    program_id: &Pubkey,
    accounts: &[AccountInfo],
    instruction_data: &[u8],
) -> ProgramResult {
    let accounts_iter: &mut std::slice::Iter<AccountInfo> = &mut accounts.iter();
    let owner_account: &AccountInfo = next_account_info(accounts_iter)?;
    let wallet_account: &AccountInfo = next_account_info(accounts_iter)?;
    let transaction_account: &AccountInfo = next_account_info(accounts_iter)?;
    let system_program_account = next_account_info(accounts_iter)?;

    if !owner_account.is_signer {
        msg!("The owner should be signer");
        return Err(ProgramError::MissingRequiredSignature);
    }

    let mut num_transactions: u64 = match wallet_account.try_borrow_data()?.get(0..8) {
        Some(data) => u64::from_le_bytes(data.try_into().unwrap()),
        None => {
            msg!("The wallet account is not initialized");
            return Err(ProgramError::InvalidAccountData);
        }
    };

    let (wallet_pda, _wallet_bump) = Pubkey::find_program_address(
        &[SEED_FOR_WALLET.as_bytes(), owner_account.key.as_ref()],
        program_id,
    );

    if wallet_pda != *wallet_account.key {
        msg!("Not the sender's pda wallet");
        return Err(ProgramError::InvalidAccountData);
    }

    let (transaction_pda, transaction_bump) = Pubkey::find_program_address(
        &[
            format!("{}{}", SEED_FOR_TRANSACTION, num_transactions).as_bytes(),
            owner_account.key.as_ref(),
        ],
        program_id,
    );

    if transaction_pda != *transaction_account.key {
        msg!("The provided transaction was not created by the sender");
        return Err(ProgramError::InvalidAccountData);
    }

    // Create the transaction account
    let rent_lamports = Rent::get()?.minimum_balance(UserTransaction::LEN);
    invoke_signed(
        &system_instruction::create_account(
            owner_account.key,
            transaction_account.key,
            rent_lamports,
            UserTransaction::LEN.try_into().unwrap(),
            program_id,
        ),
        &[
            owner_account.clone(),
            transaction_account.clone(),
            system_program_account.clone(),
        ],
        &[&[
            format!("{}{}", SEED_FOR_TRANSACTION, num_transactions).as_bytes(),
            owner_account.key.as_ref(),
            &[transaction_bump],
        ]],
    )?;

    let mut new_transaction = UserTransaction::try_from_slice(&instruction_data)?;

    if new_transaction.value <= 0 {
        msg!("The amount to send should be greater than 0");
        return Err(ProgramError::InvalidInstructionData);
    }

    new_transaction.executed = false;
    new_transaction.serialize(&mut &mut transaction_account.try_borrow_mut_data()?[..])?;

    // Update the number of transactions
    num_transactions += 1;
    wallet_account
        .try_borrow_mut_data()?
        .copy_from_slice(&num_transactions.to_le_bytes());

    Ok(())
}

fn execute_transaction(
    program_id: &Pubkey,
    accounts: &[AccountInfo],
    instruction_data: &[u8],
) -> ProgramResult {
    let accounts_iter: &mut std::slice::Iter<AccountInfo> = &mut accounts.iter();
    let owner_account: &AccountInfo = next_account_info(accounts_iter)?;
    let wallet_account: &AccountInfo = next_account_info(accounts_iter)?;
    let transaction_account: &AccountInfo = next_account_info(accounts_iter)?;
    let receiver_account = next_account_info(accounts_iter)?;

    if !owner_account.is_signer {
        msg!("The owner should be signer");
        return Err(ProgramError::MissingRequiredSignature);
    }

    let (wallet_pda, _wallet_bump) = Pubkey::find_program_address(
        &[SEED_FOR_WALLET.as_bytes(), owner_account.key.as_ref()],
        program_id,
    );

    if wallet_pda != *wallet_account.key {
        msg!("Not the sender's pda wallet");
        return Err(ProgramError::InvalidAccountData);
    }

    let transaction_id: u64 = instruction_data
        .iter()
        .rev()
        .fold(0, |acc, &x| (acc << 8) + x as u64);

    let (transaction_pda, _transaction_bump) = Pubkey::find_program_address(
        &[
            format!("{}{}", SEED_FOR_TRANSACTION, transaction_id).as_bytes(),
            owner_account.key.as_ref(),
        ],
        program_id,
    );

    if transaction_pda != *transaction_account.key {
        msg!("The provided transaction was not created by the sender");
        return Err(ProgramError::InvalidAccountData);
    }

    let mut transaction = UserTransaction::try_from_slice(*transaction_account.data.borrow())?;

    let rent_exemption = Rent::get()?.minimum_balance(wallet_account.data_len());
    if **wallet_account.lamports.borrow() < rent_exemption + transaction.value {
        msg!("Not enough lamports to send");
        return Err(ProgramError::InsufficientFunds);
    }

    **receiver_account.try_borrow_mut_lamports()? += transaction.value;
    **wallet_account.try_borrow_mut_lamports()? -= transaction.value;

    transaction.executed = false;
    transaction.serialize(&mut &mut transaction_account.try_borrow_mut_data()?[..])?;

    /*
    closing the transaction account and send back rent lamports to the owner
    **owner_account.try_borrow_mut_lamports()? += **transaction_account.try_borrow_lamports()?;
    **transaction_account.try_borrow_mut_lamports()? = 0;
    *transaction_account.try_borrow_mut_data()? = &mut [];
    */

    Ok(())
}

fn withdraw(program_id: &Pubkey, accounts: &[AccountInfo]) -> ProgramResult {
    let accounts_iter: &mut std::slice::Iter<AccountInfo> = &mut accounts.iter();
    let owner_account: &AccountInfo = next_account_info(accounts_iter)?;
    let wallet_account: &AccountInfo = next_account_info(accounts_iter)?;

    if !owner_account.is_signer {
        msg!("The owner should be signer");
        return Err(ProgramError::MissingRequiredSignature);
    }

    let (wallet_pda, _wallet_bump) = Pubkey::find_program_address(
        &[SEED_FOR_WALLET.as_bytes(), owner_account.key.as_ref()],
        program_id,
    );

    if wallet_pda != *wallet_account.key {
        msg!("Not the sender's pda wallet");
        return Err(ProgramError::InvalidAccountData);
    }

    **owner_account.try_borrow_mut_lamports()? += **wallet_account.try_borrow_lamports()?;
    **wallet_account.try_borrow_mut_lamports()? = 0;

    Ok(())
}
