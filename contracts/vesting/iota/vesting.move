
module vesting::vesting;

use iota::balance::{Self, Balance};
use iota::iota::IOTA;
use iota::coin::{Self, Coin};
use iota::clock::Clock;
use 0x1::u64::{max, min};

const EPermissionDenied: u64 = 0;


public struct Vesting has key {
    id: UID,
    owner: address,
    beneficiary: address,
    start: u64,
    end: u64,
    balance: Balance<IOTA>,
    initialized: bool
}

fun init(ctx: &mut TxContext){
    let vesting = Vesting {
        id: object::new(ctx),
        owner: ctx.sender(),
        beneficiary: @0x0,
        start: 0,
        end: 0,
        balance: balance::zero<IOTA>(),
        initialized: false 
    };
    transfer::share_object(vesting);
}

public fun initialize(beneficiary: address, start: u64, duration: u64, amount: Coin<IOTA>, 
    vesting: &mut Vesting, clock: &Clock, ctx: &mut TxContext)
{
    assert!(!vesting.initialized, EPermissionDenied);
    assert!(vesting.owner == ctx.sender(), EPermissionDenied);

    vesting.beneficiary = beneficiary;
    vesting.start = start + clock.timestamp_ms();
    vesting.end = start + duration + clock.timestamp_ms();
    vesting.balance.join(coin::into_balance(amount));
    vesting.initialized = true;
}

public fun release(vesting: &mut Vesting, clock: &Clock, ctx: &mut TxContext){
    assert!(vesting.beneficiary == ctx.sender(), EPermissionDenied);
    assert!(vesting.initialized, EPermissionDenied);

    let clamped_time = max(vesting.start, min(vesting.end, clock.timestamp_ms()));
    let amount = vesting.balance.value() * (clamped_time - vesting.start)/ (vesting.end - vesting.start);
    let coin = coin::take(&mut vesting.balance, amount, ctx);
    transfer::public_transfer(coin, vesting.beneficiary);
}

#[test_only]
public fun init_test(ctx: &mut TxContext){
    let vesting = Vesting {
        id: object::new(ctx),
        owner: ctx.sender(),
        beneficiary: @0x0,
        start: 0,
        end: 0,
        balance: balance::zero<IOTA>(),
        initialized: false 
    };
    transfer::share_object(vesting);
}

public fun value(self: & Vesting): u64 {
    self.balance.value()
} 
