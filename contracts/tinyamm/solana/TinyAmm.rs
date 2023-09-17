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
    system_instruction,
    sysvar::Sysvar,
};

entrypoint!(process_instruction);

#[derive(BorshSerialize, BorshDeserialize, Debug)]
pub struct AmmInfo {
    pub mint0: Pubkey,
    pub mint1: Pubkey,
    pub token_account0: Pubkey,
    pub token_account1: Pubkey,
    pub reserve0: u64,
    pub reserve1: u64,
    pub ever_deposited: bool,
    pub supply: u64,
}

impl AmmInfo {
    pub fn new(
        mint0: Pubkey,
        mint1: Pubkey,
        token_account0: Pubkey,
        token_account1: Pubkey,
    ) -> Self {
        Self {
            mint0,
            mint1,
            token_account0,
            token_account1,
            reserve0: 0,
            reserve1: 0,
            ever_deposited: false,
            supply: 0,
        }
    }

    pub fn check_token_accounts(
        &self,
        pdas_token_account0_public_key: &Pubkey,
        pdas_token_account1_public_key: &Pubkey,
    ) -> Result<(), ProgramError> {
        if pdas_token_account0_public_key.ne(&self.token_account0) {
            msg!("Wrong token account for mint 0");
            return Err(ProgramError::InvalidAccountData);
        }

        if pdas_token_account1_public_key.ne(&self.token_account1) {
            msg!("Wrong token account for mint 1");
            return Err(ProgramError::InvalidAccountData);
        }

        Ok(())
    }

    pub const LEN: usize = 32 + 32 + 32 + 32 + 8 + 8 + 1 + 8;
}

pub enum AmmInstruction {
    Initialize,
    Deposit {
        amount0: u64,
        amount1: u64,
    },
    Redeem {
        amount: u64,
    },
    Swap {
        is_mint0: bool,
        amount_in: u64,
        min_out_amount: u64,
    },
}

impl AmmInstruction {
    pub fn from_instruction_data(instruction_data: &[u8]) -> Option<Self> {
        match instruction_data {
            [0] => Some(Self::Initialize),
            [1, tail @ ..] => Self::get_deposit_context(tail),
            [2, tail @ ..] => Self::get_redeem_context(tail),
            [3, tail @ ..] => Self::get_swap_context(tail),
            _ => None,
        }
    }

    fn get_deposit_context(instruction_data: &[u8]) -> Option<Self> {
        let amount0 = u64::from_le_bytes(instruction_data[0..8].try_into().unwrap());
        let amount1 = u64::from_le_bytes(instruction_data[8..16].try_into().unwrap());
        Some(Self::Deposit { amount0, amount1 })
    }

    fn get_redeem_context(instruction_data: &[u8]) -> Option<Self> {
        let amount = u64::from_le_bytes(instruction_data[0..8].try_into().unwrap());
        Some(Self::Redeem { amount })
    }

    fn get_swap_context(instruction_data: &[u8]) -> Option<Self> {
        let is_mint0 = 0 == u64::from_le_bytes(instruction_data[0..8].try_into().unwrap());
        let amount_in = u64::from_le_bytes(instruction_data[8..16].try_into().unwrap());
        let min_out_amount = u64::from_le_bytes(instruction_data[16..24].try_into().unwrap());
        Some(Self::Swap {
            is_mint0,
            amount_in,
            min_out_amount,
        })
    }
}

const SEED_FOR_AMM: &str = "amm";
const SEED_FOR_MINTED: &str = "minted";
const MINT_DECIMALS: u32 = 9;
const MINTED_ACCOUNT_DATA_LEN: usize = 8;

pub fn process_instruction<'a>(
    program_id: &Pubkey,
    accounts: &'a [AccountInfo<'a>],
    instruction_data: &[u8],
) -> ProgramResult {
    let instruction = AmmInstruction::from_instruction_data(instruction_data)
        .ok_or(ProgramError::InvalidInstructionData)?;

    match instruction {
        AmmInstruction::Initialize => initialize(program_id, accounts),
        AmmInstruction::Deposit { amount0, amount1 } => {
            deposit(program_id, accounts, amount0, amount1)
        }
        AmmInstruction::Redeem { amount } => redeem(program_id, accounts, amount),
        AmmInstruction::Swap {
            is_mint0,
            amount_in,
            min_out_amount,
        } => swap(program_id, accounts, is_mint0, amount_in, min_out_amount),
    }
}

fn initialize<'a>(program_id: &Pubkey, accounts: &'a [AccountInfo<'a>]) -> ProgramResult {
    let accounts_iter: &mut std::slice::Iter<AccountInfo> = &mut accounts.iter();

    let initializer_account: &AccountInfo = next_account_info(accounts_iter)?;
    let amm_account: &AccountInfo = next_account_info(accounts_iter)?;
    let mint0_account: &AccountInfo = next_account_info(accounts_iter)?;
    let mint1_account: &AccountInfo = next_account_info(accounts_iter)?;
    let system_program_account: &AccountInfo = next_account_info(accounts_iter)?;
    let token_program_account: &AccountInfo = next_account_info(accounts_iter)?;
    let token_account_for_mint0: &AccountInfo = next_account_info(accounts_iter)?;
    let token_account_for_mint1: &AccountInfo = next_account_info(accounts_iter)?;

    if !initializer_account.is_signer {
        return Err(ProgramError::MissingRequiredSignature);
    }

    let amm_bump = check_pda(
        program_id,
        amm_account,
        &[
            SEED_FOR_AMM.as_bytes(),
            &mint0_account.key.as_ref(),
            &mint1_account.key.as_ref(),
        ],
    )?;

    create_pda_account(
        initializer_account,
        amm_account,
        system_program_account,
        program_id,
        &[&[
            SEED_FOR_AMM.as_bytes(),
            mint0_account.key.as_ref(),
            mint1_account.key.as_ref(),
            &[amm_bump],
        ]],
        AmmInfo::LEN,
    )?;

    transfer_authority(
        token_program_account,
        initializer_account,
        token_account_for_mint0,
        &amm_account.key,
    )?;

    transfer_authority(
        token_program_account,
        initializer_account,
        token_account_for_mint1,
        &amm_account.key,
    )?;

    let amm_info = AmmInfo::new(
        *mint0_account.key,
        *mint1_account.key,
        *token_account_for_mint0.key,
        *token_account_for_mint1.key,
    );

    amm_info.serialize(&mut &mut amm_account.try_borrow_mut_data()?[..])?;

    Ok(())
}

fn deposit<'a>(
    program_id: &Pubkey,
    accounts: &'a [AccountInfo<'a>],
    amount0: u64,
    amount1: u64,
) -> ProgramResult {
    let accounts_iter: &mut std::slice::Iter<AccountInfo> = &mut accounts.iter();

    let sender_account: &AccountInfo = next_account_info(accounts_iter)?;
    let amm_account: &AccountInfo = next_account_info(accounts_iter)?;
    let pdas_token_account0: &AccountInfo = next_account_info(accounts_iter)?;
    let pdas_token_account1: &AccountInfo = next_account_info(accounts_iter)?;
    let senders_token_account0: &AccountInfo = next_account_info(accounts_iter)?;
    let senders_token_account1: &AccountInfo = next_account_info(accounts_iter)?;
    let token_program_account: &AccountInfo = next_account_info(accounts_iter)?;
    let minted_pda_account: &AccountInfo = next_account_info(accounts_iter)?;
    let system_program_account: &AccountInfo = next_account_info(accounts_iter)?;

    if !sender_account.is_signer {
        return Err(ProgramError::MissingRequiredSignature);
    }

    let mut amm_info: AmmInfo = AmmInfo::try_from_slice(*amm_account.data.borrow())?;

    check_pda(
        program_id,
        amm_account,
        &[
            SEED_FOR_AMM.as_bytes(),
            &amm_info.mint0.as_ref(),
            &amm_info.mint1.as_ref(),
        ],
    )?;

    amm_info.check_token_accounts(pdas_token_account0.key, pdas_token_account1.key)?;

    transfer_tokens_from_user(
        token_program_account,
        sender_account,
        senders_token_account0,
        pdas_token_account0,
        amount0,
    )?;

    transfer_tokens_from_user(
        token_program_account,
        sender_account,
        senders_token_account1,
        pdas_token_account1,
        amount1,
    )?;

    let to_mint = calculate_to_mint(&mut amm_info, amount0, amount1)?;

    amm_info.supply += to_mint;
    amm_info.reserve0 += amount0;
    amm_info.reserve1 += amount1;

    amm_info.serialize(&mut &mut amm_account.try_borrow_mut_data()?[..])?;

    let bump_seed_minted = check_pda(
        program_id,
        minted_pda_account,
        &[SEED_FOR_MINTED.as_bytes(), sender_account.key.as_ref()],
    )?;

    if !account_exists(minted_pda_account) {
        create_pda_account(
            sender_account,
            minted_pda_account,
            system_program_account,
            program_id,
            &[&[
                SEED_FOR_MINTED.as_bytes(),
                sender_account.key.as_ref(),
                &[bump_seed_minted],
            ]],
            MINTED_ACCOUNT_DATA_LEN,
        )?;
    }

    let minted_amount =
        to_mint + u64::from_le_bytes(minted_pda_account.data.borrow()[0..8].try_into().unwrap());
    minted_pda_account
        .try_borrow_mut_data()?
        .copy_from_slice(&minted_amount.to_le_bytes());

    Ok(())
}

fn redeem<'a>(program_id: &Pubkey, accounts: &'a [AccountInfo<'a>], amount: u64) -> ProgramResult {
    let accounts_iter: &mut std::slice::Iter<AccountInfo> = &mut accounts.iter();

    let sender_account: &AccountInfo = next_account_info(accounts_iter)?;
    let amm_account: &AccountInfo = next_account_info(accounts_iter)?;
    let pdas_token_account0: &AccountInfo = next_account_info(accounts_iter)?;
    let pdas_token_account1: &AccountInfo = next_account_info(accounts_iter)?;
    let senders_token_account0: &AccountInfo = next_account_info(accounts_iter)?;
    let senders_token_account1: &AccountInfo = next_account_info(accounts_iter)?;
    let token_program_account: &AccountInfo = next_account_info(accounts_iter)?;
    let minted_pda_account: &AccountInfo = next_account_info(accounts_iter)?;

    if !sender_account.is_signer {
        return Err(ProgramError::MissingRequiredSignature);
    }

    let mut amm_info: AmmInfo = AmmInfo::try_from_slice(*amm_account.data.borrow())?;

    let amm_bump = check_pda(
        program_id,
        amm_account,
        &[
            SEED_FOR_AMM.as_bytes(),
            &amm_info.mint0.as_ref(),
            &amm_info.mint1.as_ref(),
        ],
    )?;

    check_pda(
        program_id,
        minted_pda_account,
        &[SEED_FOR_MINTED.as_bytes(), sender_account.key.as_ref()],
    )?;

    amm_info.check_token_accounts(pdas_token_account0.key, pdas_token_account1.key)?;

    let mut minted_amount =
        u64::from_le_bytes(minted_pda_account.data.borrow()[0..8].try_into().unwrap());

    if amount < minted_amount {
        msg!("The minted amount can not be greater than the provided amount");
        return Err(ProgramError::InvalidAccountData);
    }

    if amount >= amm_info.supply {
        msg!("amount can not be greater or equal to the supply");
        return Err(ProgramError::InvalidAccountData);
    }

    let amount0: u64 = (amount * amm_info.reserve0) / amm_info.supply;
    let amount1: u64 = (amount * amm_info.reserve1) / amm_info.supply;

    let amm_pda_signer_seeds: &[&[&[u8]]] = &[&[
        SEED_FOR_AMM.as_bytes(),
        amm_info.mint0.as_ref(),
        amm_info.mint1.as_ref(),
        &[amm_bump],
    ]];

    transfer_tokens_from_pda(
        token_program_account,
        amm_account,
        pdas_token_account0,
        senders_token_account0,
        &amm_pda_signer_seeds,
        amount0,
    )?;

    transfer_tokens_from_pda(
        token_program_account,
        amm_account,
        pdas_token_account1,
        senders_token_account1,
        &amm_pda_signer_seeds,
        amount1,
    )?;

    amm_info.reserve0 -= amount0;
    amm_info.reserve1 -= amount1;
    amm_info.supply -= amount;

    amm_info.serialize(&mut &mut amm_account.try_borrow_mut_data()?[..])?;

    minted_amount -= amount;

    minted_pda_account
        .try_borrow_mut_data()?
        .copy_from_slice(&minted_amount.to_le_bytes());

    Ok(())
}

fn swap<'a>(
    program_id: &Pubkey,
    accounts: &'a [AccountInfo<'a>],
    is_mint0: bool,
    amount_in: u64,
    min_out_amount: u64,
) -> ProgramResult {
    let accounts_iter: &mut std::slice::Iter<AccountInfo> = &mut accounts.iter();

    let sender_account: &AccountInfo = next_account_info(accounts_iter)?;
    let amm_account: &AccountInfo = next_account_info(accounts_iter)?;
    let pdas_token_account0: &AccountInfo = next_account_info(accounts_iter)?;
    let pdas_token_account1: &AccountInfo = next_account_info(accounts_iter)?;
    let senders_token_account0: &AccountInfo = next_account_info(accounts_iter)?;
    let senders_token_account1: &AccountInfo = next_account_info(accounts_iter)?;
    let token_program_account: &AccountInfo = next_account_info(accounts_iter)?;

    if !sender_account.is_signer {
        return Err(ProgramError::MissingRequiredSignature);
    }

    if amount_in <= 0 {
        msg!("Amount in can not be less or equal to 0");
        return Err(ProgramError::InvalidAccountData);
    }

    let mut amm_info: AmmInfo = AmmInfo::try_from_slice(*amm_account.data.borrow())?;

    let amm_bump = check_pda(
        program_id,
        amm_account,
        &[
            SEED_FOR_AMM.as_bytes(),
            &amm_info.mint0.as_ref(),
            &amm_info.mint1.as_ref(),
        ],
    )?;

    amm_info.check_token_accounts(pdas_token_account0.key, pdas_token_account1.key)?;

    let (reserve_in, reserve_out) = if is_mint0 {
        (amm_info.reserve0, amm_info.reserve1)
    } else {
        (amm_info.reserve1, amm_info.reserve0)
    };

    let (source, destination) = if is_mint0 {
        (senders_token_account0, pdas_token_account0)
    } else {
        (senders_token_account1, pdas_token_account1)
    };

    transfer_tokens_from_user(
        token_program_account,
        sender_account,
        source,
        destination,
        amount_in,
    )?;

    let amount_out = amount_in * reserve_out / (reserve_in + amount_in);

    msg!("Amount out: {}", amount_out);

    if amount_out < min_out_amount {
        msg!("Amount out can not be less than the min out amount");
        return Err(ProgramError::InvalidArgument);
    }

    let (source, destination) = if is_mint0 {
        (pdas_token_account1, senders_token_account1)
    } else {
        (pdas_token_account0, senders_token_account0)
    };

    let amm_pda_signer_seeds: &[&[&[u8]]] = &[&[
        SEED_FOR_AMM.as_bytes(),
        amm_info.mint0.as_ref(),
        amm_info.mint1.as_ref(),
        &[amm_bump],
    ]];

    transfer_tokens_from_pda(
        token_program_account,
        amm_account,
        source,
        destination,
        &amm_pda_signer_seeds,
        amount_out,
    )?;

    if is_mint0 {
        amm_info.reserve0 = amm_info.reserve0 + amount_in;
        amm_info.reserve1 = amm_info.reserve1 - amount_out;
    } else {
        amm_info.reserve0 = amm_info.reserve0 - amount_out;
        amm_info.reserve1 = amm_info.reserve1 + amount_in;
    }

    amm_info.serialize(&mut &mut amm_account.try_borrow_mut_data()?[..])?;

    Ok(())
}

pub fn transfer_authority<'a>(
    token_program: &'a AccountInfo<'a>,
    payer: &'a AccountInfo<'a>,
    token_account: &'a AccountInfo<'a>,
    new_authority: &Pubkey,
) -> ProgramResult {
    let instruction = spl_token::instruction::set_authority(
        token_program.key,
        token_account.key,
        Some(&new_authority),
        spl_token::instruction::AuthorityType::AccountOwner,
        payer.key,
        &[&payer.key],
    )?;

    let account_infos = [payer.clone(), token_account.clone(), token_program.clone()];

    invoke(&instruction, &account_infos)
}

pub fn create_pda_account<'a>(
    payer: &'a AccountInfo<'a>,
    new_account: &'a AccountInfo<'a>,
    system_program_account: &'a AccountInfo<'a>,
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
        rent.minimum_balance(data_len),
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

pub fn transfer_tokens_from_user<'a>(
    token_program: &'a AccountInfo<'a>,
    authority: &'a AccountInfo<'a>,
    source: &'a AccountInfo<'a>,
    destination: &'a AccountInfo<'a>,
    amount: u64,
) -> ProgramResult {
    let instruction = spl_token::instruction::transfer(
        token_program.key,
        source.key,
        destination.key,
        authority.key,
        &[&authority.key],
        amount * 10u64.pow(MINT_DECIMALS),
    )?;

    let account_infos = [
        source.clone(),
        destination.clone(),
        authority.clone(),
        token_program.clone(),
    ];

    invoke(&instruction, &account_infos)
}

pub fn transfer_tokens_from_pda<'a>(
    token_program: &'a AccountInfo<'a>,
    authority: &'a AccountInfo<'a>,
    source: &'a AccountInfo<'a>,
    destination: &'a AccountInfo<'a>,
    signers_seeds: &[&[&[u8]]],
    amount: u64,
) -> ProgramResult {
    let instruction = spl_token::instruction::transfer(
        token_program.key,
        source.key,
        destination.key,
        &authority.key,
        &[&authority.key],
        amount * 10u64.pow(MINT_DECIMALS),
    )?;

    let account_infos = [
        source.clone(),
        destination.clone(),
        authority.clone(),
        token_program.clone(),
    ];

    invoke_signed(&instruction, &account_infos, signers_seeds)
}

pub fn check_pda<'a>(
    program_id: &Pubkey,
    account_to_check: &'a AccountInfo<'a>,
    seeds: &[&[u8]],
) -> Result<u8, ProgramError> {
    let (pub_key, bump_seed) = Pubkey::find_program_address(&seeds, program_id);

    if pub_key != *account_to_check.key {
        msg!("PDA doesen't match with the one provided");
        return Err(ProgramError::InvalidAccountData);
    }

    return Ok(bump_seed);
}

pub fn calculate_to_mint(amm_info: &mut AmmInfo, x0: u64, x1: u64) -> Result<u64, ProgramError> {
    let to_mint: u64;

    if amm_info.ever_deposited {
        if (amm_info.reserve0 * x1) != (amm_info.reserve1 * x0) {
            msg!("Dep precondition");
            return Err(ProgramError::InvalidInstructionData);
        }
        to_mint = (x0 * amm_info.supply) / amm_info.reserve0;
    } else {
        amm_info.ever_deposited = true;
        to_mint = x0;
    }

    if to_mint <= 0 {
        msg!("Dep precondition");
        return Err(ProgramError::InvalidInstructionData);
    }

    return Ok(to_mint);
}

pub fn account_exists(account: &AccountInfo) -> bool {
    account.lamports() != 0
}
