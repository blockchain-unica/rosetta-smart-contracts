use borsh::{BorshDeserialize, BorshSerialize};
use solana_program::{
    account_info::{next_account_info, AccountInfo},
    entrypoint,
    entrypoint::ProgramResult,
    msg,
    program::{invoke, invoke_signed},
    program_error::ProgramError,
    pubkey::Pubkey,
};

entrypoint!(process_instruction);

#[derive(BorshSerialize, BorshDeserialize, Debug)]
struct WithdrawRequest {
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
        0 => deposit(program_id, accounts),
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

fn deposit(program_id: &Pubkey, accounts: &[AccountInfo]) -> ProgramResult {
    let account_info_iter: &mut std::slice::Iter<AccountInfo> = &mut accounts.iter();

    let sender: &AccountInfo = next_account_info(account_info_iter)?;
    if !sender.is_signer {
        return Err(ProgramError::MissingRequiredSignature);
    }

    let temp_token_account: &AccountInfo = next_account_info(account_info_iter)?;

    let (pda, _nonce) = Pubkey::find_program_address(&[b"SimpleTransfer"], program_id);

    let token_program: &AccountInfo = next_account_info(account_info_iter)?;
    let change_owner_instruction = spl_token::instruction::set_authority(
        token_program.key,
        temp_token_account.key,
        Some(&pda),
        spl_token::instruction::AuthorityType::AccountOwner,
        sender.key,
        &[&sender.key],
    )?;

    invoke(
        &change_owner_instruction,
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
    let withdraw_request: WithdrawRequest = WithdrawRequest::try_from_slice(&instruction_data)
        .expect("Instruction data serialization didn't worked");

    let account_info_iter = &mut accounts.iter();

    let recipient = next_account_info(account_info_iter)?;

    if !recipient.is_signer {
        return Err(ProgramError::MissingRequiredSignature);
    }

    let recipients_token_account = next_account_info(account_info_iter)?;

    let temp_token_account = next_account_info(account_info_iter)?;
    let (pda, nonce) = Pubkey::find_program_address(&[b"SimpleTransfer"], program_id);

    let token_program = next_account_info(account_info_iter)?;

    let pda_account = next_account_info(account_info_iter)?;

    let transfer_instruction = spl_token::instruction::transfer(
        token_program.key,
        temp_token_account.key,
        recipients_token_account.key,
        &pda,
        &[&pda],
        withdraw_request.amount * 100000000,
    )?;

    invoke_signed(
        &transfer_instruction,
        &[
            temp_token_account.clone(),
            recipients_token_account.clone(),
            pda_account.clone(),
            token_program.clone(),
        ],
        &[&[&b"SimpleTransfer"[..], &[nonce]]],
    )?;

    Ok(())
}
