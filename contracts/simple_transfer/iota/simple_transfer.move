module simple_transfer::simple_transfer;

use iota::coin::{Self, Coin};
use iota::iota::{Self, IOTA};
use iota::balance::{Self, Balance};

const EPermissionsDenied: u64 = 0;
const EBiggerThanBalance: u64 = 1;

public struct Wallet has key {
    id: UID,
    balance: Balance<IOTA>,
    owner: address,
    receiver: address,
} 

public fun initialize(receiver: address, ctx: &mut TxContext){
    let wallet = Wallet {
        id: object::new(ctx),
        balance: balance::zero<IOTA>(),
        owner: ctx.sender(),
        receiver: receiver,
    };
    transfer::share_object(wallet);
}

public fun deposit(amount: Coin<IOTA>,wallet:&mut Wallet, ctx: &mut TxContext){
    assert!(ctx.sender() == wallet.owner, EPermissionsDenied);
    
    let balance_to_deposite = amount.into_balance<IOTA>();
    wallet.balance.join(balance_to_deposite);
}

public fun withdraw(amount: u64, wallet: &mut Wallet, ctx: &mut TxContext){
    assert!(ctx.sender() == wallet.receiver, EPermissionsDenied);
    assert!(amount <= wallet.balance.value(), EBiggerThanBalance);

    let coin = coin::take<IOTA>(&mut wallet.balance, amount, ctx);
    iota::transfer(coin, ctx.sender());
}

#[test_only]
public fun wallet_amount(wallet: &Wallet): u64 {
    wallet.balance.value()
}

entry fun initialize_test(ctx: &mut TxContext){
    let wallet = Wallet {
        id: object::new(ctx),
        balance: balance::zero<IOTA>(),
        owner: ctx.sender(),
        receiver: @0xFACE,
    };
    transfer::share_object(wallet);
}
