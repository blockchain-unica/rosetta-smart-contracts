module payment_splitter::payment_splitter; 

use iota::vec_map::{Self, VecMap};
use iota::balance::{Self, Balance};
use iota::coin::{Self, Coin};

const EWrongSharesDistribution: u64 = 0;
const EPermissionDenied: u64 = 1;
const EBalanceEmpty: u64 = 2;

public struct Owner has key {
    id: UID,
    addr: address
}

public struct ShareHolder<phantom T> has store {
    shares: u64,
    balance: Balance<T>
}

public struct PaymentSplitter<phantom T> has key {
    id: UID,
    shareholders: VecMap<address, ShareHolder<T>>,
    shares_tot: u64,
    balance: Balance<T>
}

fun init(ctx: &mut TxContext) {
    let owner = Owner {
        id: object::new(ctx),
        addr: ctx.sender()
    };
    transfer::share_object(owner);
}

public fun initialize<T>(shareolders: vector<address>, shares: vector<u64>, owner: Owner, ctx: &mut TxContext){
    assert!(ctx.sender() == owner.addr, EPermissionDenied);
    assert!(shareolders.length() == shares.length(), EWrongSharesDistribution);

    let Owner {id: id, addr: _} = owner;
    let mut shares_tot = 0;
    let mut vecmap_shareholders = vec_map::empty<address, ShareHolder<T>>();
    let mut i = 0;
    while (i < shares.length()){
        shares_tot = shares_tot + shares[i];
        let shareolder = ShareHolder {shares: shares[i], balance: balance::zero<T>()};
        vecmap_shareholders.insert(shareolders[i], shareolder);
        i = i + 1;
    };
    let payment_splitter = PaymentSplitter {
        id: object::new(ctx),
        shareholders: vecmap_shareholders,
        shares_tot,
        balance: balance::zero<T>()
    };
    id.delete();
    transfer::share_object(payment_splitter);
}

public fun receive<T>(coin: Coin<T>, payment_splitter: &mut PaymentSplitter<T>){
    let balance = coin.into_balance();
    payment_splitter.balance.join(balance);
}

public fun release<T>(payment_splitter: &mut PaymentSplitter<T>){
    assert!(payment_splitter.balance.value() > 0, EBalanceEmpty);
    let balance = &mut payment_splitter.balance;
    let balance_amount_per_share = balance.value() / payment_splitter.shares_tot;
    let mut i = 0;
    let keys = payment_splitter.shareholders.keys();
    while(i < keys.length()){
        let shareholder = payment_splitter.shareholders.get_mut(&keys[i]);
        let balance_i = balance.split(balance_amount_per_share * shareholder.shares);
        shareholder.balance.join(balance_i);
        i = i + 1;
    };
}

public fun take_amount<T>(payment_splitter: &mut PaymentSplitter<T>, ctx: &mut TxContext){
    let sharesholder = payment_splitter.shareholders.get_mut(&ctx.sender());
    let value = sharesholder.balance.value();
    let coin = coin::take<T>(&mut sharesholder.balance, value, ctx);
    transfer::public_transfer(coin, ctx.sender());
}

#[test_only]
public fun init_test(ctx: &mut TxContext) {
    let owner = Owner {
        id: object::new(ctx),
        addr: ctx.sender()
    };
    transfer::share_object(owner);
}

public fun balance<T>(self: &PaymentSplitter<T>): &Balance<T>{
    &self.balance
  }
