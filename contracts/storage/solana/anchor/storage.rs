use anchor_lang::prelude::*;

declare_id!("2ZE5N8rTU2S2GUuQGX8ZsBAraByUqD37hYP8pz1hYLLJ");

#[program]
pub mod storage {
    use super::*;

    pub fn initialize(_ctx: Context<InitializeCtx>) -> Result<()> {
        msg!("Initializing storage accounts");
        Ok(())
    }

    pub fn store_string(ctx: Context<StoreStringCtx>, data_to_store: String) -> Result<()> {
        let string_storage_pda = &mut ctx.accounts.string_storage_pda;
        string_storage_pda.my_string = data_to_store;
        Ok(())
    }

    pub fn store_bytes(ctx: Context<StoreBytesCtx>, data_to_store: Vec<u8>) -> Result<()> {
        let bytes_storage_dpa = &mut ctx.accounts.bytes_storage_dpa;
        bytes_storage_dpa.my_bytes = data_to_store;
        Ok(())
    }
}

#[account]
pub struct MemoryStringPDA {
    pub my_string: String,
}

#[account]
pub struct MemoryBytesPDA {
    pub my_bytes: Vec<u8>,
}

#[derive(Accounts)]
pub struct InitializeCtx<'info> {
    #[account(mut)]
    pub user: Signer<'info>,
    pub system_program: Program<'info, System>,
    #[account(
        init_if_needed, 
        payer = user, 
        seeds = [b"storage_string", user.key.as_ref()],
        bump,
        space = 8 + 4 // no additional space needed because we don't store anything yet
    )]
    pub string_storage_pda: Account<'info, MemoryStringPDA>,
    #[account(
        init_if_needed, 
        payer = user, 
        seeds = [b"storage_bytes", user.key.as_ref()],
        bump,
        space = 8 + 4  // no additional space needed because we don't store anything yet
    )]
    pub bytes_storage_dpa: Account<'info, MemoryBytesPDA>,
}

#[derive(Accounts)]
#[instruction(data_to_store: String)]
pub struct StoreStringCtx<'info> {
    #[account(mut)]
    pub user: Signer<'info>,
    pub system_program: Program<'info, System>,
    #[account(
        mut,
        seeds = [b"storage_string", user.key.as_ref()],
        bump,
        realloc = 8 + 4 + data_to_store.len(),
        realloc::payer = user,
        realloc::zero = false,
    )]
    pub string_storage_pda: Account<'info, MemoryStringPDA>,
}

#[derive(Accounts)]
#[instruction(data_to_store: Vec<u8>)]
pub struct StoreBytesCtx<'info> {
    #[account(mut)]
    pub user: Signer<'info>,
    pub system_program: Program<'info, System>,
    #[account(
        mut,
        seeds = [b"storage_bytes", user.key.as_ref()],
        bump,
        realloc = 8 + 4 + data_to_store.len(),
        realloc::payer = user,
        realloc::zero = false,
    )]
    pub bytes_storage_dpa: Account<'info, MemoryBytesPDA>,
}
