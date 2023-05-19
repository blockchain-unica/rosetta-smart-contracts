use borsh::{BorshDeserialize, BorshSerialize};
use solana_program::{
    account_info::{next_account_info, AccountInfo},
    entrypoint,
    entrypoint::ProgramResult,
    msg,
    program::{invoke, invoke_signed},
    program_error::ProgramError,
    pubkey::Pubkey,
    rent::Rent,
    sysvar::Sysvar,
};

entrypoint!(process_instruction);

#[derive(BorshSerialize, BorshDeserialize, Debug)]
struct DepositInfo {
    pub sender: Pubkey,
    pub temp_token_account: Pubkey,
    pub reciever_token_account: Pubkey,
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
        0 => deposit(
            program_id,
            accounts,
            &instruction_data[1..instruction_data.len()],
        ),
        1 => withdraw(
            program_id,
            accounts,
            &instruction_data[1..instruction_data.len()],
        ),
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

    // The account that wants to deposit
    let sender: &AccountInfo = next_account_info(accounts_iter)?;
    if !sender.is_signer {
        return Err(ProgramError::MissingRequiredSignature);
    }

    // The sender's temporal token account to deposit from
    let temp_token_account: &AccountInfo = next_account_info(accounts_iter)?;

    // The state account that will store the deposit info
    let state_account: &AccountInfo = next_account_info(accounts_iter)?;
    if state_account.owner.ne(&program_id){
        msg!("The state account isn't owned by program");
        return Err(ProgramError::IllegalOwner);
    }

    // The state account should have enough balance to be rent exempted
    let rent_exemption: u64 = Rent::get()?.minimum_balance(state_account.data_len());
    if **state_account.lamports.borrow() < rent_exemption {
        msg!("The state account should be rent exempted");
        return Err(ProgramError::AccountNotRentExempt);
    }

    // Deserialize from instruction data the amount that the sender wants to deposit
    let amount_to_deposit: u64 = instruction_data
        .iter()
        .rev()
        .fold(0, |acc, &x| (acc << 8) + x as u64);

    // The reciever's token account to deposit to
    let reciever_token_account: &AccountInfo = next_account_info(accounts_iter)?;

    // Now we have all the information we need to build the DepositInfo struct instance
    let deposit_info: DepositInfo = DepositInfo {
        sender: *sender.key,
        temp_token_account: *temp_token_account.key,
        reciever_token_account: *reciever_token_account.key,
        amount: amount_to_deposit,
    };

    // Serialize the DepositInfo struct instance and save it to the state account
    deposit_info.serialize(&mut &mut state_account.try_borrow_mut_data()?[..])?;

    // The PDA account that will own the temp token account
    let (pda, _nonce) = Pubkey::find_program_address(&[b"TokenTransfer"], program_id);

    // Call the Token program to transfer temp account ownership to the PDA
    let token_program: &AccountInfo = next_account_info(accounts_iter)?;
    invoke(
        &spl_token::instruction::set_authority(
            token_program.key,
            temp_token_account.key,
            Some(&pda),
            spl_token::instruction::AuthorityType::AccountOwner,
            sender.key,
            &[&sender.key],
        )?,
        &[
            temp_token_account.clone(),
            sender.clone(),
            token_program.clone(),
        ],
    )?;

    Ok(())
}

fn withdraw(
    program_id: &Pubkey,
    accounts: &[AccountInfo],
    instruction_data: &[u8],
) -> ProgramResult {
    let accounts_iter = &mut accounts.iter();

    // The account that wants to withdraw
    let recipient = next_account_info(accounts_iter)?;
    if !recipient.is_signer {
        return Err(ProgramError::MissingRequiredSignature);
    }

    // The account that deposited tokens to the recipient
    let sender = next_account_info(accounts_iter)?;

    // The recipient's token account
    let recipients_token_account = next_account_info(accounts_iter)?;
    if recipients_token_account.lamports() == 0 {
        msg!("The recipient token account does not exist");
        return Err(ProgramError::InvalidAccountData);
    }

    // The sender's token account
    let temp_token_account = next_account_info(accounts_iter)?;

    // The state account that stores the deposit info
    let state_account = next_account_info(accounts_iter)?;
    let mut deposit_info: DepositInfo = DepositInfo::try_from_slice(*state_account.data.borrow())?;

    let token_program = next_account_info(accounts_iter)?;

    // The PDA account that owns the temp token account
    let pda_account = next_account_info(accounts_iter)?;
    let (pda, nonce) = Pubkey::find_program_address(&[b"TokenTransfer"], program_id);

    // Deserialize the amount that the recipient wants to withdraw
    let amount_to_withdraw: u64 = instruction_data
        .iter()
        .rev()
        .fold(0, |acc, &x| (acc << 8) + x as u64);

    // Calling the token program to transfer tokens to the recipient
    invoke_signed(
        &spl_token::instruction::transfer(
            token_program.key,
            &deposit_info.temp_token_account,
            &deposit_info.reciever_token_account,
            &pda, //owner
            &[&pda],
            amount_to_withdraw * 1000000000,
        )?,
        &[
            temp_token_account.clone(),
            recipients_token_account.clone(),
            pda_account.clone(),
            token_program.clone(),
        ],
        &[&[&b"TokenTransfer"[..], &[nonce]]],
    )?;

    // Updating the deposit info
    deposit_info.amount = deposit_info.amount - amount_to_withdraw;
    deposit_info.serialize(&mut &mut state_account.data.borrow_mut()[..])?;

    if deposit_info.amount <= 0 {
        //Calling the token program to close pda's temp account
        invoke_signed(
            &spl_token::instruction::close_account(
                token_program.key,
                temp_token_account.key,
                sender.key,
                &pda,
                &[&pda],
            )?,
            &[
                temp_token_account.clone(),
                sender.clone(),
                pda_account.clone(),
                token_program.clone(),
            ],
            &[&[&b"TokenTransfer"[..], &[nonce]]],
        )?;

        // Closing the state account and send back the rent lamports to the sender
        **sender.try_borrow_mut_lamports()? = sender
            .lamports()
            .checked_add(state_account.lamports())
            .ok_or(ProgramError::InvalidAccountData)?;
        **state_account.try_borrow_mut_lamports()? = 0;
        *state_account.try_borrow_mut_data()? = &mut [];
    }

    Ok(())
}