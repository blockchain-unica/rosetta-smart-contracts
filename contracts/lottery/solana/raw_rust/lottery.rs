use borsh::{BorshDeserialize, BorshSerialize};
use solana_program::{
    account_info::{next_account_info, AccountInfo},
    clock::Clock,
    entrypoint,
    entrypoint::ProgramResult,
    keccak, msg,
    program::invoke,
    program::invoke_signed,
    program_error::ProgramError,
    pubkey::Pubkey,
    rent::Rent,
    system_instruction, system_program,
    sysvar::Sysvar,
};

entrypoint!(process_instruction);

const DEADLINE_EXTENSION: u64 = 10;

#[derive(BorshSerialize, BorshDeserialize, Debug)]
pub struct LotteryInfo {
    pub state: u8, // 0 - Init, 1 - RevealP1, 2 - RevealP2
    pub player1: Pubkey,
    pub player2: Pubkey,
    pub hashlock1: [u8; 32],
    pub secret1_len: u64,
    pub hashlock2: [u8; 32],
    pub secret2_len: u64,
    pub end_reveal: u64,
}

impl LotteryInfo {
    pub const LEN: usize = 1 + 32 + 32 + 32 + 8 + 32 + 8 + 8;

    pub fn initialize(
        player1: Pubkey,
        player2: Pubkey,
        hashlock1: [u8; 32],
        hashlock2: [u8; 32],
        end_reveal: u64,
    ) -> Result<Self, ProgramError> {
        if hashlock1 == hashlock2 {
            msg!("Provided two equal hashlocks");
            return Err(ProgramError::InvalidAccountData);
        }

        if Clock::get()?.slot >= end_reveal {
            msg!("Provided invalid timeout");
            return Err(ProgramError::InvalidAccountData);
        }

        Ok(Self {
            state: 0,
            player1,
            player2,
            hashlock1,
            secret1_len: 0,
            hashlock2,
            secret2_len: 0,
            end_reveal,
        })
    }

    pub fn reveal_p1(&mut self, secret: &String) -> ProgramResult {
        if self.state != 0 {
            msg!("Invalid state");
            return Err(ProgramError::InvalidAccountData);
        }

        if Clock::get()?.slot >= self.end_reveal {
            msg!("Timeout reached");
            return Err(ProgramError::InvalidAccountData);
        }

        let hash = keccak::hash(&<String as Clone>::clone(&secret).into_bytes()).to_bytes();

        if hash != self.hashlock1 {
            msg!("Invalid secret");
            return Err(ProgramError::InvalidAccountData);
        }

        self.secret1_len = secret.len() as u64;
        self.state = 1;
        Ok(())
    }

    pub fn reveal_p2(&mut self, secret: &String) -> ProgramResult {
        if self.state != 1 {
            msg!("Invalid state");
            return Err(ProgramError::InvalidAccountData);
        }
        // the deadline extension is needed to avoid attacks where
        // player1 reveals close to the deadline
        if Clock::get()?.slot >= self.end_reveal + DEADLINE_EXTENSION {
            msg!("Timeout reached");
            return Err(ProgramError::InvalidAccountData);
        }

        let hash = keccak::hash(&<String as Clone>::clone(&secret).into_bytes()).to_bytes();

        if hash != self.hashlock2 {
            msg!("Invalid secret");
            return Err(ProgramError::InvalidAccountData);
        }

        self.secret2_len = secret.len() as u64;
        self.state = 2;
        Ok(())
    }

    pub fn get_winner(&self) -> Result<Pubkey, ProgramError> {
        if self.state != 2 {
            msg!("Invalid state");
            return Err(ProgramError::InvalidAccountData);
        }
        let sum = self.secret1_len + self.secret2_len;
        if sum % 2 == 0 {
            Ok(self.player1)
        } else {
            Ok(self.player2)
        }
    }

    pub fn check_redeem_if_p1_no_reveal(&self) -> ProgramResult {
        if self.state != 0 {
            msg!("Invalid state");
            return Err(ProgramError::InvalidAccountData);
        }

        if Clock::get()?.slot <= self.end_reveal {
            msg!("Timeout not reached");
            return Err(ProgramError::InvalidAccountData);
        }
        Ok(())
    }

    pub fn check_redeem_if_p2_no_reveal(&self) -> ProgramResult {
        if self.state != 1 {
            msg!("Invalid state");
            return Err(ProgramError::InvalidAccountData);
        }

        if Clock::get()?.slot <= self.end_reveal + DEADLINE_EXTENSION {
            msg!("Timeout not reached");
            return Err(ProgramError::InvalidAccountData);
        }
        Ok(())
    }
}

pub enum OracleBetInstruction {
    Join {
        hashlock1: [u8; 32],
        hashlock2: [u8; 32],
        delay: u64,
        amount: u64,
    },
    RevealP1 {
        secret: String,
    },
    RevealP2 {
        secret: String,
    },
    RedeemIfP1NoReveal {},
    RedeemIfP2NoReveal {},
}

impl OracleBetInstruction {
    pub fn from_instruction_data(instruction_data: &[u8]) -> Option<Self> {
        match instruction_data {
            [0, tail @ ..] => Self::get_join_context(tail),
            [1, tail @ ..] => Self::get_reveal_p1_context(tail),
            [2, tail @ ..] => Self::get_reveal_p2_context(tail),
            [3, _tail @ ..] => Some(Self::RedeemIfP1NoReveal {}),
            [4, _tail @ ..] => Some(Self::RedeemIfP2NoReveal {}),
            _ => None,
        }
    }

    fn get_join_context(instruction_data: &[u8]) -> Option<Self> {
        let hashlock1 = instruction_data[0..32].try_into().unwrap();
        let hashlock2 = instruction_data[32..64].try_into().unwrap();
        let delay = u64::from_le_bytes(instruction_data[64..72].try_into().unwrap());
        let amount = u64::from_le_bytes(instruction_data[72..80].try_into().unwrap());
        Some(Self::Join {
            hashlock1,
            hashlock2,
            delay,
            amount,
        })
    }

    fn get_reveal_p1_context(instruction_data: &[u8]) -> Option<Self> {
        let secret =
            String::from_utf8(instruction_data[..instruction_data.len()].to_vec()).unwrap();
        Some(Self::RevealP1 { secret })
    }

    fn get_reveal_p2_context(instruction_data: &[u8]) -> Option<Self> {
        let secret =
            String::from_utf8(instruction_data[..instruction_data.len()].to_vec()).unwrap();
        Some(Self::RevealP2 { secret })
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
        OracleBetInstruction::Join {
            hashlock1,
            hashlock2,
            delay,
            amount,
        } => join(program_id, accounts, hashlock1, hashlock2, delay, amount),
        OracleBetInstruction::RevealP1 { secret } => reveal_p1(program_id, accounts, secret),
        OracleBetInstruction::RevealP2 { secret } => reveal_p2(program_id, accounts, secret),
        OracleBetInstruction::RedeemIfP1NoReveal {} => redeem_if_p1_no_reveal(program_id, accounts),
        OracleBetInstruction::RedeemIfP2NoReveal {} => redeem_if_p2_no_reveal(program_id, accounts),
    }
}

fn join<'a>(
    program_id: &Pubkey,
    accounts: &'a [AccountInfo<'a>],
    hashlock1: [u8; 32],
    hashlock2: [u8; 32],
    delay: u64,
    amount: u64,
) -> ProgramResult {
    msg!("join");
    let accounts_iter: &mut std::slice::Iter<AccountInfo> = &mut accounts.iter();
    let player1_account: &AccountInfo = next_account_info(accounts_iter)?;
    let player2_account: &AccountInfo = next_account_info(accounts_iter)?;
    let lottery_info_account: &AccountInfo = next_account_info(accounts_iter)?;
    let system_account: &AccountInfo = next_account_info(accounts_iter)?;

    assert!(system_program::check_id(system_account.key));

    if !player1_account.is_signer {
        return Err(ProgramError::MissingRequiredSignature);
    }

    if !player2_account.is_signer {
        return Err(ProgramError::MissingRequiredSignature);
    }

    let (expected_pda, pda_bump) = Pubkey::find_program_address(
        &[player1_account.key.as_ref(), player2_account.key.as_ref()],
        program_id,
    );

    if expected_pda != *lottery_info_account.key {
        msg!("Invalid PDA");
        return Err(ProgramError::InvalidAccountData);
    }

    let rent_lamports = Rent::get()?.minimum_balance(LotteryInfo::LEN);

    invoke_signed(
        &system_instruction::create_account(
            player1_account.key,
            lottery_info_account.key,
            rent_lamports,
            LotteryInfo::LEN as u64,
            program_id,
        ),
        &[
            player1_account.clone(),
            lottery_info_account.clone(),
            system_account.clone(),
        ],
        &[&[
            player1_account.key.as_ref(),
            player2_account.key.as_ref(),
            &[pda_bump],
        ]],
    )?;

    let deadline = Clock::get()?.slot + delay;
    let lottery_info = LotteryInfo::initialize(
        *player1_account.key,
        *player2_account.key,
        hashlock1,
        hashlock2,
        deadline,
    )?;

    lottery_info.serialize(&mut &mut lottery_info_account.try_borrow_mut_data()?[..])?;

    invoke(
        &system_instruction::transfer(player1_account.key, lottery_info_account.key, amount),
        &[
            player1_account.clone(),
            lottery_info_account.clone(),
            system_account.clone(),
        ],
    )?;

    invoke(
        &system_instruction::transfer(player2_account.key, lottery_info_account.key, amount),
        &[
            player2_account.clone(),
            lottery_info_account.clone(),
            system_account.clone(),
        ],
    )?;

    Ok(())
}

fn reveal_p1<'a>(
    program_id: &Pubkey,
    accounts: &'a [AccountInfo<'a>],
    secret: String,
) -> ProgramResult {
    msg!("reveal_p1");
    let accounts_iter: &mut std::slice::Iter<AccountInfo> = &mut accounts.iter();
    let player1_account: &AccountInfo = next_account_info(accounts_iter)?;
    let player2_account: &AccountInfo = next_account_info(accounts_iter)?;
    let lottery_info_account: &AccountInfo = next_account_info(accounts_iter)?;

    if !player1_account.is_signer {
        return Err(ProgramError::MissingRequiredSignature);
    }

    let (expected_pda, _pda_bump) = Pubkey::find_program_address(
        &[player1_account.key.as_ref(), player2_account.key.as_ref()],
        program_id,
    );

    if expected_pda != *lottery_info_account.key {
        msg!("Invalid PDA");
        return Err(ProgramError::InvalidAccountData);
    }

    let mut lottery_info: LotteryInfo =
        LotteryInfo::try_from_slice(*lottery_info_account.data.borrow())?;

    lottery_info.reveal_p1(&secret)?;

    lottery_info.serialize(&mut &mut lottery_info_account.try_borrow_mut_data()?[..])?;

    Ok(())
}

fn reveal_p2<'a>(
    program_id: &Pubkey,
    accounts: &'a [AccountInfo<'a>],
    secret: String,
) -> ProgramResult {
    msg!("reveal_p2");
    let accounts_iter: &mut std::slice::Iter<AccountInfo> = &mut accounts.iter();
    let player1_account: &AccountInfo = next_account_info(accounts_iter)?;
    let player2_account: &AccountInfo = next_account_info(accounts_iter)?;
    let lottery_info_account: &AccountInfo = next_account_info(accounts_iter)?;

    if !player2_account.is_signer {
        return Err(ProgramError::MissingRequiredSignature);
    }

    let (expected_pda, _pda_bump) = Pubkey::find_program_address(
        &[player1_account.key.as_ref(), player2_account.key.as_ref()],
        program_id,
    );

    if expected_pda != *lottery_info_account.key {
        msg!("Invalid PDA");
        return Err(ProgramError::InvalidAccountData);
    }

    let mut lottery_info: LotteryInfo =
        LotteryInfo::try_from_slice(*lottery_info_account.data.borrow())?;
    lottery_info.reveal_p2(&secret)?;
    lottery_info.serialize(&mut &mut lottery_info_account.try_borrow_mut_data()?[..])?;

    let winner = lottery_info.get_winner()?;

    if winner == *player1_account.key {
        **player1_account.try_borrow_mut_lamports()? += **lottery_info_account.lamports.borrow();
    } else {
        **player2_account.try_borrow_mut_lamports()? += **lottery_info_account.lamports.borrow();
    }
    **lottery_info_account.try_borrow_mut_lamports()? = 0;

    Ok(())
}

fn redeem_if_p1_no_reveal<'a>(
    program_id: &Pubkey,
    accounts: &'a [AccountInfo<'a>],
) -> ProgramResult {
    msg!("redeem_if_p1_no_reveal");
    let accounts_iter: &mut std::slice::Iter<AccountInfo> = &mut accounts.iter();
    let player1_account: &AccountInfo = next_account_info(accounts_iter)?;
    let player2_account: &AccountInfo = next_account_info(accounts_iter)?;
    let lottery_info_account: &AccountInfo = next_account_info(accounts_iter)?;

    if !player2_account.is_signer {
        return Err(ProgramError::MissingRequiredSignature);
    }

    let (expected_pda, _pda_bump) = Pubkey::find_program_address(
        &[player1_account.key.as_ref(), player2_account.key.as_ref()],
        program_id,
    );

    if expected_pda != *lottery_info_account.key {
        msg!("Invalid PDA");
        return Err(ProgramError::InvalidAccountData);
    }

    let lottery_info: LotteryInfo =
        LotteryInfo::try_from_slice(*lottery_info_account.data.borrow())?;
    lottery_info.check_redeem_if_p1_no_reveal()?;

    **player2_account.try_borrow_mut_lamports()? += **lottery_info_account.lamports.borrow();
    **lottery_info_account.try_borrow_mut_lamports()? = 0;

    Ok(())
}

fn redeem_if_p2_no_reveal<'a>(
    program_id: &Pubkey,
    accounts: &'a [AccountInfo<'a>],
) -> ProgramResult {
    msg!("redeem_if_p2_no_reveal");
    let accounts_iter: &mut std::slice::Iter<AccountInfo> = &mut accounts.iter();
    let player1_account: &AccountInfo = next_account_info(accounts_iter)?;
    let player2_account: &AccountInfo = next_account_info(accounts_iter)?;
    let lottery_info_account: &AccountInfo = next_account_info(accounts_iter)?;

    if !player1_account.is_signer {
        return Err(ProgramError::MissingRequiredSignature);
    }

    let (expected_pda, _pda_bump) = Pubkey::find_program_address(
        &[player1_account.key.as_ref(), player2_account.key.as_ref()],
        program_id,
    );

    if expected_pda != *lottery_info_account.key {
        msg!("Invalid PDA");
        return Err(ProgramError::InvalidAccountData);
    }

    let lottery_info: LotteryInfo =
        LotteryInfo::try_from_slice(*lottery_info_account.data.borrow())?;
    lottery_info.check_redeem_if_p2_no_reveal()?;

    **player1_account.try_borrow_mut_lamports()? += **lottery_info_account.lamports.borrow();
    **lottery_info_account.try_borrow_mut_lamports()? = 0;

    Ok(())
}
