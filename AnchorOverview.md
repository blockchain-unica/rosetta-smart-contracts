# Anchor overview

We provide a brief overview of the [Anchor](https://www.anchor-lang.com) framework (version 0.28.0) to simplify the understanding the implementation of Anchor-based use case for the Solana blockchain.


⚠️ A deeper dive into Anchor is advised by reading the [Anchor documentation](https://www.anchor-lang.com). Additionally, understanding concepts such as 
- [Solana stateless account model](https://solanacookbook.com/core-concepts/accounts.html#facts)
- [Rent exemption](https://solanacookbook.com/core-concepts/accounts.html#rent)
- [Program Derived Addresses (PDA)](https://solanacookbook.com/core-concepts/pdas.html#facts)

is recommended for a complete understanding.

## Overview by Example

We provide an overview of the Anchor framework through the implementation of the [Simple Transfer](contracts/simple_transfer) use case. This use case allows a `donor` to deposit native cryptocurrency, and a `receiver` to withdraw arbitrary fractions of the contract balance. We'll omit some implementation details, such as crate imports and error definitions, for brevity.

### Main Logic

Let's start by crafting the main logic of the contract. We have two actions: `deposit` and `withdraw`, each with its own context of associated accounts and parameters. We also define the account structure `BalanceHolderPDA`, which holds the donated balance and associated actors.


```rust
pub mod simple_transfer {

    pub fn deposit(ctx: Context<DepositCtx>, amount_to_deposit: u64) -> Result<()> {
        // Deposit logic
    }

    pub fn withdraw(ctx: Context<WithdrawCtx>, amount_to_withdraw: u64) -> Result<()> {
        // Withdraw logic
    }
}

#[derive(Accounts)]
pub struct DepositCtx<'info> {
    // Deposit accounts
}

#[derive(Accounts)]
pub struct WithdrawCtx<'info> {
    // Withdraw accounts
}

#[account]
#[derive(InitSpace)] // To automatically derive the space required for the account
pub struct BalanceHolderPDA {
    pub sender: Pubkey,
    pub recipient: Pubkey,
    pub amount: u64
}
```

### Deposit Accounts Context
Once we've defined the main logic, let's implement the DepositCtx context.

The first two accounts are the `sender` and `recipient` accounts. The sender is required to sign the transaction (`Signer` type). 

The third account is the `balance_holder_pda`, a [PDA](https://solanacookbook.com/core-concepts/pdas.html#facts) account that will hold the deposited balance. The account is initialized with the `init` attribute with `sender` as the payer. The address of this account is derived through seeds in a way to establish a mapping between the the couple (`sender`, `recipient`) and their storage account. The space is calculated using the `BalanceHolderPDA::INIT_SPACE` constant to cover the [Rent exemption](https://solanacookbook.com/core-concepts/accounts.html#rent).

The last account is the `system_program` account, required to transfer in instructions containing account initialization.

```rust
#[derive(Accounts)]
pub struct DepositCtx<'info> {
    #[account(mut)]
    pub sender: Signer<'info>,
    pub recipient: SystemAccount<'info>,
    #[account(
        init, 
        payer = sender, 
        seeds = [recipient.key().as_ref(), sender.key().as_ref()],
        bump,
        space = 8 + BalanceHolderPDA::INIT_SPACE
    )]
    pub balance_holder_pda: Account<'info, BalanceHolderPDA>,
    pub system_program: Program<'info, System>,
}
```

### Deposit Logic

The deposit logic requires the amount to deposit to be greater than zero. Then, a transfer instruction is crafted to transfer the amount from the sender to the balance holder PDA. Finally, the balance holder PDA account data is set.

```rust
pub fn deposit(ctx: Context<DepositCtx>, amount_to_deposit: u64) -> Result<()> {
    require!(amount_to_deposit > 0, CustomError::InvalidAmount);

    let transfer_instruction = anchor_lang::solana_program::system_instruction::transfer(
        &ctx.accounts.sender.key(),
        &ctx.accounts.balance_holder_pda.key(),
        amount_to_deposit,
    );

    // Transferring amount_to_deposit lamports from the sender to the balance holder PDA
    anchor_lang::solana_program::program::invoke(
        &transfer_instruction,
        &[
            ctx.accounts.sender.to_account_info(),
            ctx.accounts.balance_holder_pda.to_account_info(),
        ],
    )
    .unwrap();

    // Setting the balance holder PDA account data
    let balance_holder_pda = &mut ctx.accounts.balance_holder_pda;
    balance_holder_pda.sender = *ctx.accounts.sender.key;
    balance_holder_pda.recipient = ctx.accounts.recipient.key();
    balance_holder_pda.amount = amount_to_deposit;

    Ok(())
}
```

### Withdraw accounts context

The `WithdrawCtx` context is similar to the `DepositCtx` context. The only difference is that the `recipient` account is a `Signer` type, as the recipient is the one who can withdraw the balance.

```rust
#[derive(Accounts)]
pub struct WithdrawCtx<'info> {
    #[account(mut)]
    pub recipient: Signer<'info>,
    #[account(mut)]
    pub sender: SystemAccount<'info>,
    #[account(
        mut, 
        seeds = [recipient.key().as_ref(), sender.key().as_ref()],
        bump,
    )]
    pub balance_holder_pda: Account<'info, BalanceHolderPDA>,
    pub rent: Sysvar<'info, Rent>,
}
```

### Withdraw logic

In the withdraw logic, we require the amount to withdraw to be greater than zero. We then decrement the assets stored in the balance holder PDA account and increment the recipient account. If all the donated assets have been withdrawn, we close the balance holder PDA account by transferring the remaining balance, designated for rent exemption to the account initializer, the `sender`.

```rust
 pub fn withdraw(ctx: Context<WithdrawCtx>, amount_to_withdraw: u64) -> Result<()> {
        require!(amount_to_withdraw > 0, CustomError::InvalidAmount);

        let from = ctx.accounts.balance_holder_pda.to_account_info();
        let to = ctx.accounts.recipient.to_account_info();

        **from.try_borrow_mut_lamports()? -= amount_to_withdraw;
        **to.try_borrow_mut_lamports()? += amount_to_withdraw;

        ctx.accounts.balance_holder_pda.amount -= amount_to_withdraw;

        let remain_lamports = **from.try_borrow_mut_lamports()?;
        if ctx.accounts.balance_holder_pda.amount == 0 {
            // All the lamports have been withdrawn, closing the lamports holder account account
            **from.try_borrow_mut_lamports()? = 0;
            **ctx
                .accounts
                .sender
                .to_account_info()
                .try_borrow_mut_lamports()? += remain_lamports;
        }

        Ok(())
    }
```