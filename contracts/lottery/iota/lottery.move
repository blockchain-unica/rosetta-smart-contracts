
module lottery::lottery;

use iota::balance::Balance;
use iota::coin::{Self, Coin};
use iota::clock::Clock;
use iota::hash::keccak256;

const ETimeExpired: u64 = 0;
const EWrongAmount: u64 = 1;
const ETimeNotExpired: u64 = 3;
const EPermissionDenied: u64 = 4;
const EWrongState: u64 = 5;
const EWrongSecret: u64 = 6;

const JOIN1: u8 = 0;
const JOIN2: u8 = 1;
const REVEAL1: u8 = 2;
const REVEAL2: u8 = 3;

public struct Lottery<phantom T> has key {
    id: UID,
    player1: address,
    player2: address,
    hash1: vector<u8>,
    hash2: vector<u8>,
    end_commit: u64,
    end_reveal1: u64,
    end_reveal2: u64,
    balance: Balance<T>,
    state: u8
}

fun destroy<T>(self: Lottery<T>): Balance<T> {
    let Lottery {
        id: id, 
        player1: _,
        player2: _,
        hash1: _,
        hash2: _,
        end_commit: _,
        end_reveal1: _,
        end_reveal2: _,
        balance: balance,
        state: _
    } = self;
    id.delete();
    balance
}

//deadline_commit must be in minutes
public fun join1<T>(deadline_commit: u64, coin: Coin<T>, hash: vector<u8>, clock: &Clock, ctx: &mut TxContext){
    let lottery = Lottery{
        id: object::new(ctx),
        player1: ctx.sender(),
        player2: @0x0,
        hash1: hash,
        hash2: b"",
        end_commit: (deadline_commit * 60000) + clock.timestamp_ms(),
        end_reveal1: 0,
        end_reveal2: 0,
        balance: coin.into_balance(),
        state: JOIN1
    };
    transfer::share_object(lottery);
}

public fun join2<T>(coin: Coin<T>, hash: vector<u8>, clock: &Clock, lottery: &mut Lottery<T>, ctx: &mut TxContext){
    assert!(lottery.state == JOIN1, EWrongState);
    assert!(lottery.end_commit >= clock.timestamp_ms(), ETimeExpired);
    assert!(lottery.balance.value() == coin.value(), EWrongAmount);

    lottery.player2 = ctx.sender();
    lottery.balance.join(coin.into_balance());
    lottery.hash2 = hash;
    lottery.end_reveal1 = 600000 + clock.timestamp_ms();
    lottery.state = JOIN2;
}

public fun redeem_commit<T>(clock: &Clock, lottery: Lottery<T>, ctx: &mut TxContext){
    assert!(lottery.state == JOIN1, EWrongState);
    assert!(lottery.end_commit < clock.timestamp_ms(), ETimeNotExpired);
    assert!(lottery.player1 == ctx.sender(), EPermissionDenied);

    let player1 = lottery.player1;
    let balance = lottery.destroy();
    transfer::public_transfer(coin::from_balance(balance, ctx), player1);

}

public fun reveal1<T>(secret: vector<u8>, clock: &Clock, lottery: &mut Lottery<T>, ctx: &mut TxContext){
    assert!(lottery.state == JOIN2, EWrongState);
    assert!(lottery.player1 == ctx.sender(), EPermissionDenied);
    assert!(lottery.end_reveal1 >= clock.timestamp_ms(), ETimeExpired);
    assert!(keccak256(&secret) == lottery.hash1, EWrongSecret);
    lottery.hash1 = secret;
    lottery.state = REVEAL1;
    lottery.end_reveal2 = 600000 + clock.timestamp_ms();
}

public fun reveal2<T>(secret: vector<u8>, clock: &Clock, lottery: &mut Lottery<T>, ctx: &mut TxContext){
    assert!(lottery.state == REVEAL1, EWrongState);
    assert!(lottery.player2 == ctx.sender(), EPermissionDenied);
    assert!(lottery.end_reveal2 >= clock.timestamp_ms(), ETimeExpired);
    assert!(keccak256(&secret) == lottery.hash2, EWrongSecret);
    lottery.hash2 = secret;
    lottery.state = REVEAL2;
}

public fun redeem<T>(clock: &Clock, lottery: Lottery<T>, ctx: &mut TxContext){
    let time_expired2 = lottery.state == REVEAL1 && ctx.sender() == lottery.player1 && clock.timestamp_ms() > lottery.end_reveal2;
    let time_expired1 = lottery.state == JOIN2 && ctx.sender() == lottery.player2 && clock.timestamp_ms() > lottery.end_reveal1;
    assert!(time_expired2 || time_expired1, ETimeNotExpired);
    let recipient: address;
    if (time_expired2){
        recipient = lottery.player1;
    } else {
        recipient = lottery.player2;
    };
    let balance = lottery.destroy(); 
    transfer::public_transfer( coin::from_balance(balance, ctx), recipient);
}

public fun win<T>(lottery: Lottery<T>, ctx: &mut TxContext){
    assert!(lottery.state == REVEAL2, EWrongState);
    let winner: address;
    if ((lottery.hash1.length() + lottery.hash2.length()) % 2 == 0){
        winner = lottery.player1;
    } else {
        winner = lottery.player2;
    };
    let balance = lottery.destroy();
    transfer::public_transfer(coin::from_balance(balance, ctx), winner);
}