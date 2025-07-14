
/// Module: escrow
module escrow::escrow;

use iota::balance::{Self, Balance};
use iota::iota::IOTA;
use iota::coin::{Self, Coin};

const EPermissionDenied: u64 = 0;
const EWrongAmount: u64 = 1;

const IDLE: u8 = 0;
const ACTIVE: u8 = 1;

public struct Escrow has key {
    id: UID,
    buyer: address,
    seller: address,
    amount_required: u64,
    amount: Balance<IOTA>,
    state: u8
}

public fun initialize (buyer: address, amount_required: u64, ctx: &mut TxContext){
    let escrow = Escrow {
        id: object::new(ctx),
        buyer: buyer,
        seller: ctx.sender(),
        amount_required: amount_required,
        amount: balance::zero<IOTA>(),
        state: IDLE 
    };
    transfer::share_object(escrow);
}

public fun deposit(amount: Coin<IOTA>, escrow: &mut Escrow, ctx: &mut TxContext){
    assert!(ctx.sender() == escrow.buyer, EPermissionDenied);
    assert!(escrow.amount_required == amount.value(), EWrongAmount);
    assert!(escrow.state == IDLE, EPermissionDenied);

    let amount = amount.into_balance();
    escrow.amount.join(amount);
    escrow.state = ACTIVE;
}

fun send_balance(recipient: address, escrow: Escrow, ctx: &mut TxContext){
    assert!(escrow.state == ACTIVE, EPermissionDenied);

    let Escrow {id: id, buyer: _, seller: _, amount_required: _, amount: balance, state: _} = escrow;
    let coin = coin::from_balance(balance, ctx);
    transfer::public_transfer(coin, recipient);   
    object::delete(id);
}

public fun pay(escrow: Escrow, ctx: &mut TxContext){
    assert!(escrow.buyer == ctx.sender(), EPermissionDenied);

    send_balance(escrow.seller, escrow, ctx);
}

public fun refund(escrow: Escrow, ctx: &mut TxContext){
    assert!(escrow.seller == ctx.sender(), EPermissionDenied);

    send_balance(escrow.buyer, escrow, ctx);
}
