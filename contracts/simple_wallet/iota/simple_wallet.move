
module simple_wallet::simple_wallet;

use iota::iota::IOTA;
use iota::balance::{Self, Balance};
use iota::coin::{Self, Coin};
use iota::vec_map::{Self, VecMap};

const EPermissionDenied: u64 = 0;
const EInvalidId: u64 = 1;
const ELowBalance: u64 = 2;

public struct Wallet has key, store {
    id: UID,
    owner: address,
    balance: Balance<IOTA>,
    transactions: VecMap<ID, Transaction>
}

public struct Transaction has copy, drop, store {
    recipient: address,
    value: u64,
    data: vector<u8>
}

fun init(ctx: &mut TxContext){
    let wallet = Wallet {
        id: object::new(ctx),
        owner: ctx.sender(),
        balance: balance::zero<IOTA>(),
        transactions: vec_map::empty<ID, Transaction>()
    };
    transfer::public_transfer(wallet, ctx.sender());
}

// only Wallet's owner can pass as parameter his Wallet reference
public fun deposit(coin: Coin<IOTA>, wallet: &mut Wallet){
    wallet.balance.join(coin::into_balance(coin));
}

public fun createTransaction(recipient: address, value: u64, data: vector<u8>, wallet: &mut Wallet, ctx: &mut TxContext){
    let uid = object::new(ctx);
    let transaction = Transaction {
        recipient: recipient,
        value: value,
        data: data
    };
    wallet.transactions.insert(*uid.as_inner(), transaction);
    object::delete(uid);
}

public fun executeTransaction(id: ID, wallet: &mut Wallet, ctx: &mut TxContext){
    let mut transaction_opt = wallet.transactions.try_get(&id);
    assert!(transaction_opt.is_some(), EInvalidId);
    let transaction = transaction_opt.extract();
    assert!(transaction.value <= wallet.balance.value(), ELowBalance);
    wallet.transactions.remove(&id);
    let coin = coin::take(&mut wallet.balance, transaction.value, ctx);
    transfer::public_transfer(coin, transaction.recipient);
}

public fun withdraw(value: u64, wallet: &mut Wallet, ctx: &mut TxContext){
    assert!(ctx.sender() == wallet.owner, EPermissionDenied);
    assert!(value <= wallet.balance.value(), ELowBalance);

    let coin = coin::take(&mut wallet.balance, value, ctx);
    transfer::public_transfer(coin, wallet.owner);
}

#[test_only]
public fun init_test(ctx: &mut TxContext){
    let wallet = Wallet {
        id: object::new(ctx),
        owner: ctx.sender(),
        balance: balance::zero<IOTA>(),
        transactions: vec_map::empty<ID, Transaction>()
    };
    transfer::public_transfer(wallet, ctx.sender());
}

public fun transactions(self: &mut Wallet): &mut VecMap<ID, Transaction>{
    &mut self.transactions
}
public fun id(transactions: &VecMap<ID, Transaction>, i: u64): ID{
    let keys = transactions.keys();
    keys[i]
}
