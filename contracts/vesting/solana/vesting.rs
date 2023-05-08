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
struct VestingInfo {
    pub released: u64,
    pub funder: Pubkey,
    pub beneficiary: Pubkey,
    pub start: u64,
    pub duration: u64,
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
        1 => release(program_id, accounts),
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
    let accounts_iter = &mut accounts.iter();
    let funder_account = next_account_info(accounts_iter)?;
    let beneficiary_account = next_account_info(accounts_iter)?;
    let vesting_account = next_account_info(accounts_iter)?;

    if !funder_account.is_signer {
        msg!("The funder account account should be signer");
        return Err(ProgramError::IncorrectProgramId);
    }

    if vesting_account.owner != program_id {
        msg!("The vesting account should be owned by the program");
        return Err(ProgramError::IncorrectProgramId);
    }

    let rent_exemption = Rent::get()?.minimum_balance(vesting_account.data_len());
    if **vesting_account.lamports.borrow() < rent_exemption {
        msg!("The vesting account should be rent exempt");
        return Err(ProgramError::InsufficientFunds);
    }

    let u8_array: [u8; 16] = instruction_data.try_into().unwrap();
    let start = u64::from_le_bytes(u8_array[0..8].try_into().unwrap());
    let duration = u64::from_le_bytes(u8_array[8..16].try_into().unwrap());

    if start <= Clock::get()?.slot {
        msg!("The start slot should be in the future");
        return Err(ProgramError::InvalidInstructionData);
    }

    if duration <= 0 {
        msg!("The duration should be greater than 0");
        return Err(ProgramError::InvalidInstructionData);
    }

    let vesting_info = VestingInfo {
        released: 0,
        funder: *funder_account.key,
        beneficiary: *beneficiary_account.key,
        start,
        duration,
    };

    vesting_info.serialize(&mut &mut vesting_account.try_borrow_mut_data()?[..])?;

    Ok(())
}

fn release(program_id: &Pubkey, accounts: &[AccountInfo]) -> ProgramResult {
    let accounts_iter = &mut accounts.iter();
    let beneficiary_account = next_account_info(accounts_iter)?;
    let vesting_account = next_account_info(accounts_iter)?;
    let funder_account = next_account_info(accounts_iter)?;

    if !beneficiary_account.is_signer {
        msg!("The funder account account should be signer");
        return Err(ProgramError::IncorrectProgramId);
    }

    if vesting_account.owner != program_id {
        msg!("The vesting account should be owned by the program");
        return Err(ProgramError::IncorrectProgramId);
    }

    let mut vesting_info = VestingInfo::try_from_slice(*vesting_account.data.borrow())?;

    if *beneficiary_account.key != vesting_info.beneficiary {
        msg!("The signer is not the beneficiary");
        return Err(ProgramError::IncorrectProgramId);
    }

    let rent_exemption = Rent::get()?.minimum_balance(vesting_account.data_len());
    let balance = **vesting_account.lamports.borrow() - rent_exemption;

    let amount = releasable(
        vesting_info.released,
        balance,
        vesting_info.start,
        vesting_info.duration,
    )?;
    msg!("amount: {}", amount);

    let rent_exemption = Rent::get()?.minimum_balance(vesting_account.data_len());
    if **vesting_account.lamports.borrow() < rent_exemption + amount {
        msg!("Not enough lamports in the vesting account to release");
        return Err(ProgramError::InsufficientFunds);
    }

    **beneficiary_account.try_borrow_mut_lamports()? += amount;
    **vesting_account.try_borrow_mut_lamports()? -= amount;

    // If all the lamports are withdrawn, close the account and send back the rent fees to the founder
    if **vesting_account.lamports.borrow() <= rent_exemption {
        **funder_account.try_borrow_mut_lamports()? += **vesting_account.lamports.borrow();
        **vesting_account.try_borrow_mut_lamports()? = 0;
    }

    vesting_info.released += amount;
    vesting_info.serialize(&mut &mut vesting_account.try_borrow_mut_data()?[..])?;

    Ok(())
}

fn releasable(released: u64, balance: u64, start: u64, duration: u64) -> Result<u64, ProgramError> {
    let current_slot = Clock::get()?.slot;
    Ok(vested_amount(current_slot, released, balance, start, duration)? - released)
}

fn vested_amount(
    timestamp: u64,
    released: u64,
    balance: u64,
    start: u64,
    duration: u64,
) -> Result<u64, ProgramError> {
    Ok(vesting_schedule(
        balance + released,
        timestamp,
        start,
        duration,
    ))
}

fn vesting_schedule(total_allocation: u64, timestamp: u64, start: u64, duration: u64) -> u64 {
    if timestamp < start {
        return 0;
    } else if timestamp > start + duration {
        return total_allocation;
    } else {
        return (total_allocation * (timestamp - start)) / duration;
    }
}
