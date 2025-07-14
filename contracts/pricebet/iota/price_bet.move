module price_bet::price_bet;

use iota::balance::{Self, Balance};
use iota::iota::IOTA;
use iota::clock::Clock;
use iota::coin::{Self, Coin};
use price_bet::oracle::Oracle;

const EPermissionDenied: u64 = 0;
const EWrongState: u64 = 1;
const EWrongAmount:u64 = 2;
const EWrongOracle: u64 = 3;
const EWrongTime: u64 = 4;
const ENotWin: u64 = 5;

const INIT: u8 = 0;
const IDLE: u8 = 1;
const ONGOING: u8 = 2;

public struct PriceBet has key {
    id: UID,
    owner: address,
    player: address,
    oracle: address,
    deadline: u64,
    exchange_rate: u64,
    pot: Balance<IOTA>,
    state: u8
}

public fun destroy(self: PriceBet){
    assert!(self.pot.value() == 0);
    let PriceBet {
        id: id,
        owner: _,
        player: _,
        oracle: _,
        deadline: _,
        exchange_rate: _,
        pot,
        state: _
    } = self;
    object::delete(id);
    pot.destroy_zero();
}

fun init(ctx: &mut TxContext) {
    let price_bet = PriceBet {
        id: object::new(ctx),
        owner: ctx.sender(),
        player: @0x0,
        oracle: @0x0,
        deadline: 0,
        exchange_rate: 0,
        pot: balance::zero(),
        state: INIT
    };
    transfer::share_object(price_bet);
}

//deadline is in minutes
public fun initialize(initial_pot: Coin<IOTA>, oracle: &Oracle, deadline: u64, exchange_rate: u64,price_bet: &mut PriceBet, ctx: &mut TxContext){
    assert!(ctx.sender() == price_bet.owner, EPermissionDenied);
    assert!(price_bet.state == INIT, EWrongState);
    price_bet.pot.join(initial_pot.into_balance());
    price_bet.oracle = oracle.addr();
    price_bet.deadline = deadline * 60000;
    price_bet.exchange_rate = exchange_rate;
    price_bet.state = IDLE;
}

public fun join(coin: Coin<IOTA>, price_bet: &mut PriceBet, clock: &Clock, ctx: &mut TxContext){
    assert!(price_bet.state == IDLE, EWrongState);
    assert!(price_bet.pot.value() == coin.value(), EWrongAmount);
    price_bet.player = ctx.sender();
    price_bet.pot.join(coin.into_balance());
    price_bet.deadline = price_bet.deadline + clock.timestamp_ms();
    price_bet.state = ONGOING;
}

public fun win(oracle: &Oracle, mut price_bet: PriceBet, clock: &Clock, ctx: &mut TxContext){
    assert!(price_bet.state == ONGOING, EWrongState);
    assert!(price_bet.oracle == oracle.addr(), EWrongOracle);
    assert!(price_bet.deadline >= clock.timestamp_ms(), EWrongTime);
    assert!(oracle.exchange_rate() > price_bet.exchange_rate, ENotWin);
    let value = price_bet.pot.value();
    let coin = coin::take(&mut price_bet.pot, value, ctx);
    let recipient = price_bet.player;
    price_bet.destroy();
    transfer::public_transfer(coin, recipient);
}

public fun timeout(mut price_bet: PriceBet, clock: &Clock, ctx: &mut TxContext){
    assert!(price_bet.state == ONGOING, EWrongState);
    assert!(price_bet.deadline < clock.timestamp_ms(), EWrongTime);
    let value = price_bet.pot.value();
    let coin = coin::take(&mut price_bet.pot, value, ctx);
    let recipient = price_bet.owner;
    price_bet.destroy();
    transfer::public_transfer(coin, recipient);
}

#[test_only]
public fun init_test(ctx: &mut TxContext) {
    let price_bet = PriceBet {
        id: object::new(ctx),
        owner: ctx.sender(),
        player: @0x0,
        oracle: @0x0,
        deadline: 0,
        exchange_rate: 0,
        pot: balance::zero(),
        state: INIT
    };
    transfer::share_object(price_bet);
}