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
    system_instruction,
    sysvar::Sysvar,
    system_program,
};

entrypoint!(process_instruction);

#[derive(BorshSerialize, BorshDeserialize, Debug)]
struct AuctionState {
    pub auction_name: String,
    pub seller: Pubkey,
    pub highest_bidder: Pubkey,
    pub end_time: u64,
    pub highest_bid: u64,
}

const START_SEED_FOR_AUCTION: &str = "auction";

pub fn process_instruction(
    program_id: &Pubkey,
    accounts: &[AccountInfo],
    instruction_data: &[u8],
) -> ProgramResult {
    if instruction_data.len() == 0 {
        return Err(ProgramError::InvalidInstructionData);
    }
    match instruction_data[0] {
        0 => start(
            program_id,
            accounts,
            &instruction_data[1..instruction_data.len()],
        ),
        1 => bid(
            program_id,
            accounts,
            &instruction_data[1..instruction_data.len()],
        ),
        2 => end(program_id, accounts),
        _ => {
            msg!("Didn't found the entrypoint required");
            Err(ProgramError::InvalidInstructionData)
        }
    }
}

fn start(program_id: &Pubkey, accounts: &[AccountInfo], instruction_data: &[u8]) -> ProgramResult {
    let accounts_iter: &mut std::slice::Iter<AccountInfo> = &mut accounts.iter();
    let seller_account: &AccountInfo = next_account_info(accounts_iter)?;
    let auction_account_pda: &AccountInfo = next_account_info(accounts_iter)?;
    let system_program_account = next_account_info(accounts_iter)?;

    if system_program_account.key != &system_program::id() {
        return Err(ProgramError::InvalidAccountData);
    }

    if !seller_account.is_signer {
        msg!("The seller should be signer");
        return Err(ProgramError::MissingRequiredSignature);
    }

    let mut auction_state = AuctionState::try_from_slice(&instruction_data)?;

    let (auction_pda, auction_bump) = Pubkey::find_program_address(
        &[
            format!("{}{}", START_SEED_FOR_AUCTION, auction_state.auction_name).as_bytes(),
            seller_account.key.as_ref(),
        ],
        program_id,
    );

    if auction_pda != *auction_account_pda.key {
        msg!("Not the sender's auction PDA");
        return Err(ProgramError::InvalidAccountData);
    }

    if auction_state.end_time <= Clock::get()?.slot {
        msg!("The end slot should be in the future");
        return Err(ProgramError::InvalidInstructionData);
    }

    if auction_state.highest_bid <= 0 {
        msg!("The initial bid should be positive");
        return Err(ProgramError::InvalidInstructionData);
    }

    let size = auction_state.try_to_vec()?.len();
    let rent_lamports = Rent::get()?.minimum_balance(size);
    invoke_signed(
        &system_instruction::create_account(
            seller_account.key,
            auction_account_pda.key,
            rent_lamports,
            size.try_into().unwrap(),
            program_id,
        ),
        &[
            seller_account.clone(),
            auction_account_pda.clone(),
            system_program_account.clone(),
        ],
        &[&[
            format!("{}{}", START_SEED_FOR_AUCTION, auction_state.auction_name).as_bytes(),
            seller_account.key.as_ref(),
            &[auction_bump],
        ]],
    )?;

    auction_state.seller = *seller_account.key;

    auction_state.serialize(&mut &mut auction_account_pda.try_borrow_mut_data()?[..])?;

    Ok(())
}

fn bid(program_id: &Pubkey, accounts: &[AccountInfo], instruction_data: &[u8]) -> ProgramResult {
    let accounts_iter: &mut std::slice::Iter<AccountInfo> = &mut accounts.iter();
    let bidder_account: &AccountInfo = next_account_info(accounts_iter)?;
    let current_highest_bidder_account: &AccountInfo = next_account_info(accounts_iter)?;
    let auction_account_pda: &AccountInfo = next_account_info(accounts_iter)?;
    let seller_account: &AccountInfo = next_account_info(accounts_iter)?;
    let system_program_account: &AccountInfo = next_account_info(accounts_iter)?;

    if !bidder_account.is_signer {
        msg!("The bidder should be signer");
        return Err(ProgramError::MissingRequiredSignature);
    }

    if system_program_account.key != &system_program::id() {
        return Err(ProgramError::InvalidAccountData);
    }

    let mut auction_state = AuctionState::try_from_slice(*auction_account_pda.data.borrow())?;

    let (auction_pda, _auction_bump) = Pubkey::find_program_address(
        &[
            format!("{}{}", START_SEED_FOR_AUCTION, auction_state.auction_name).as_bytes(),
            seller_account.key.as_ref(),
        ],
        program_id,
    );

    if auction_pda != *auction_account_pda.key {
        msg!("Not the sender's auction PDA");
        return Err(ProgramError::InvalidAccountData);
    }

    let amount_to_deposit: u64 = instruction_data
        .iter()
        .rev()
        .fold(0, |acc, &x| (acc << 8) + x as u64);

    let (_auction_pda, auction_bump) = Pubkey::find_program_address(
        &[
            format!("{}{}", START_SEED_FOR_AUCTION, auction_state.auction_name).as_bytes(),
            auction_state.seller.as_ref(),
        ],
        program_id,
    );

    if Clock::get()?.slot > auction_state.end_time {
        msg!("The auction is over");
        return Err(ProgramError::InvalidInstructionData);
    }

    if amount_to_deposit <= auction_state.highest_bid {
        msg!("The new amount should be higher than the previous");
        return Err(ProgramError::InvalidInstructionData);
    }

    // Transfer founds from the new bidder to auction_account_pda
    invoke_signed(
        &system_instruction::transfer(
            bidder_account.key,
            auction_account_pda.key,
            amount_to_deposit,
        ),
        &[
            bidder_account.clone(),
            auction_account_pda.clone(),
            system_program_account.clone(),
        ],
        &[&[
            format!("{}{}", START_SEED_FOR_AUCTION, auction_state.auction_name).as_bytes(),
            seller_account.key.as_ref(),
            &[auction_bump],
        ]],
    )?;

    // Return founds to the previous bidder if it's not the seller (there was at least one real bid)
    if auction_state.highest_bidder != auction_state.seller {
        **current_highest_bidder_account.try_borrow_mut_lamports()? += auction_state.highest_bid;
        **auction_account_pda.try_borrow_mut_lamports()? -= auction_state.highest_bid;
    }

    auction_state.highest_bid = amount_to_deposit;
    auction_state.highest_bidder = *bidder_account.key;

    auction_state.serialize(&mut &mut auction_account_pda.try_borrow_mut_data()?[..])?;

    Ok(())
}

fn end(program_id: &Pubkey, accounts: &[AccountInfo]) -> ProgramResult {
    let accounts_iter: &mut std::slice::Iter<AccountInfo> = &mut accounts.iter();
    let seller_account: &AccountInfo = next_account_info(accounts_iter)?;
    let auction_account_pda: &AccountInfo = next_account_info(accounts_iter)?;

    if !seller_account.is_signer {
        msg!("The seller should be signer");
        return Err(ProgramError::MissingRequiredSignature);
    }

    let auction_state = AuctionState::try_from_slice(*auction_account_pda.data.borrow())?;

    let (auction_pda, _auction_bump) = Pubkey::find_program_address(
        &[
            format!("{}{}", START_SEED_FOR_AUCTION, auction_state.auction_name).as_bytes(),
            seller_account.key.as_ref(),
        ],
        program_id,
    );

    if auction_pda != *auction_account_pda.key {
        msg!("Not the sender's auction PDA");
        return Err(ProgramError::InvalidAccountData);
    }

    let auction_state = AuctionState::try_from_slice(*auction_account_pda.data.borrow())?;

    if Clock::get()?.slot <= auction_state.end_time {
        msg!("The auction is not over");
        return Err(ProgramError::InvalidInstructionData);
    }

    **seller_account.try_borrow_mut_lamports()? += **auction_account_pda.try_borrow_lamports()?;
    **auction_account_pda.try_borrow_mut_lamports()? = 0;

    Ok(())
}
