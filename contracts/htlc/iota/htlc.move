module htlc::htlc;

use iota::coin::{Self, Coin};
use iota::balance::Balance;
use iota::hash;
use iota::iota::{Self, IOTA};
use iota::clock::{Self, Clock};

const EPermissionDenied: u64 = 0;
const EWrongSecret: u64 = 1;
const ETimeNotFinished: u64 = 2;

public struct Htlc has key {
    id: UID,
    committer: address,
    receiver: address,
    hash: vector<u8>,
    deadline: u64,
    amount: Balance<IOTA>,
}

public fun initialize(
    receiver: address,
    preimage: vector<u8>, 
    timeout: u64, 
    coin: Coin<IOTA>,
    clock: &Clock, 
    ctx: &mut TxContext){
    let htlc = Htlc {
        id: object::new(ctx),
        committer: ctx.sender(),
        receiver: receiver,
        hash: hash::keccak256(&preimage),
        deadline: clock::timestamp_ms(clock) + timeout,
        amount: coin::into_balance(coin),
    };
    transfer::share_object(htlc);
}

public fun reveal(secret: vector<u8>, htlc: Htlc, ctx: &mut TxContext){
    assert!(ctx.sender() == htlc.committer, EPermissionDenied);
    assert!(htlc.hash == hash::keccak256(&secret), EWrongSecret);

    let Htlc {
        id: id,
        committer: committer,
        receiver: _,
        hash: _,
        deadline: _,
        amount: balance,
    } = htlc;
    object::delete(id);
    let coin = coin::from_balance(balance, ctx);
    iota::transfer(coin, committer);
}

public fun timeout(clock: &Clock, htlc: Htlc, ctx: &mut TxContext){
    assert!(clock::timestamp_ms(clock) > htlc.deadline, ETimeNotFinished);
    let Htlc {
        id: id,
        committer: _,
        receiver: receiver,
        hash: _,
        deadline: _,
        amount: balance,
    } = htlc;

    object::delete(id);
    let coin = coin::from_balance(balance, ctx);
    iota::transfer(coin, receiver);

}

#[test_only]

public fun deadline(self: &Htlc): u64{
    self.deadline
}
