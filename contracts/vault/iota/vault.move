
module vault::vault;

use iota::coin::{Self, Coin};
use iota::balance::{Self, Balance};
use iota::clock::Clock;

const EPermissionDenied: u64 = 0;
const ENotInitialized: u64 = 1;
const EWrongState: u64 = 2;
const EWrongTime: u64 = 3;
const ELowBalance:u64 = 4;

const READY: u8 = 1; 
const ONGOING: u8 = 2;

public struct Vault<phantom T> has key {
    id: UID,
    owner: address,
    receiver: address,
    amount: Balance<T>,
    withdrawal_amount: u64,
    recovery_key: vector<u8>,
    wait_time: u64,
    deadline: u64,
    state: u8 
}

// wait_time is in seconds
public fun initialize<T>(recovery_key: vector<u8>, wait_time: u64, ctx: &mut TxContext){
    let vault = Vault<T> {
        id: object::new(ctx),
        owner: ctx.sender(),
        receiver: @0x0,
        amount: balance::zero<T>(),
        withdrawal_amount: 0,
        recovery_key: recovery_key,
        wait_time: wait_time * 1000,
        deadline: 0,
        state: READY
    };
    transfer::share_object(vault);
}

public fun receive<T>(amount: Coin<T>, vault: &mut Vault<T>){

    let amount = coin::into_balance(amount);
    vault.amount.join(amount);
}

public fun withdraw<T>(amount: u64, receiver: address, vault: &mut Vault<T>,clock: &Clock, ctx: &mut TxContext){
    assert!(vault.state == READY, ENotInitialized);
    assert!(ctx.sender() == vault.owner, EPermissionDenied);
    assert!(vault.amount.value() >= amount, ELowBalance);

    vault.receiver = receiver;
    vault.withdrawal_amount = amount;
    vault.deadline = clock.timestamp_ms() + vault.wait_time;
    vault.state = ONGOING;
}

public fun finalize<T>(vault: &mut Vault<T>, clock: &Clock, ctx: &mut TxContext){
    assert!(vault.state == ONGOING, EWrongState);
    assert!(vault.deadline <= clock.timestamp_ms(), EWrongTime);
    assert!(ctx.sender() == vault.owner, EPermissionDenied);

    let coin = coin::take( &mut vault.amount, vault.withdrawal_amount, ctx);
    transfer::public_transfer(coin, vault.receiver);
    vault.state = READY;
}

public fun cancel<T>(recovery_key: vector<u8>, vault: &mut Vault<T>, clock: &Clock, ctx: &mut TxContext){
    assert!(vault.state == ONGOING, EWrongState);
    assert!(vault.deadline > clock.timestamp_ms(), EWrongTime);
    assert!(ctx.sender() == vault.owner, EPermissionDenied);
    assert!(vault.recovery_key == recovery_key, EPermissionDenied);

    vault.state = READY;
}
