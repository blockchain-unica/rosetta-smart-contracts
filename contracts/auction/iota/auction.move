
module auction::auction;

use iota::iota::IOTA;
use iota::balance::{Self, Balance};
use iota::coin::{Self, Coin};
use iota::clock::{Self, Clock};

const EPermissionDenied: u64 = 0;
const ETimeFinished: u64 = 1;
const EBidTooMuchLower: u64 = 2;
const ETimeNotFinished: u64 = 3;

const INIT: u8 = 0;
const ACTIVE: u8 = 1;
const ONGOING: u8 = 2;

public struct Auction has key {
    id: UID,
    seller: address,
    bidder: address,
    thing: vector<u8>,
    top_bid: Balance<IOTA>,
    deadline: u64,
    state: u8
}

public fun initialize(
    thing: vector<u8>, 
    starter_bid:Coin<IOTA>,
    deadline:u64, // in minutes
    ctx: &mut TxContext
){
    let auction = Auction {
        id: object::new(ctx),
        seller: ctx.sender(),
        bidder: ctx.sender(),
        thing: thing,
        top_bid: starter_bid.into_balance<IOTA>(),
        deadline: deadline * 60000,
        state: ACTIVE
    };
    transfer::share_object(auction);
}

public fun start(auction: &mut Auction, clock: &Clock, ctx: &mut TxContext){
    assert!(auction.state == ACTIVE, EPermissionDenied);
    assert!(auction.seller == ctx.sender(), EPermissionDenied);
    auction.deadline = auction.deadline + clock::timestamp_ms(clock);
    auction.state = ONGOING;
}

public fun bid(bid: Coin<IOTA>, auction: &mut Auction, clock:&Clock, ctx: &mut TxContext){
    assert!(auction.deadline >= clock.timestamp_ms(), ETimeFinished);
    assert!(bid.value() > auction.top_bid.value(), EBidTooMuchLower);
    assert!(auction.state == ONGOING, EPermissionDenied);

    let bid_value = auction.top_bid.value();
    let low_bid = coin::take<IOTA>(&mut auction.top_bid, bid_value, ctx);
    transfer::public_transfer(low_bid, auction.bidder);

    let top_bid = coin::into_balance(bid);
    auction.top_bid.join(top_bid);
    auction.bidder = ctx.sender();
}

public fun end(auction: Auction,clock: &Clock, ctx: &mut TxContext){
    assert!(auction.seller == ctx.sender(), EPermissionDenied);
    assert!(clock.timestamp_ms()> auction.deadline, ETimeNotFinished);
    assert!(auction.state == ONGOING, EPermissionDenied);
    let Auction {
        id: uid,
        seller: seller,
        bidder: _,
        thing: _,
        top_bid: bid_balance,
        deadline: _,
        state:_ 
    } = auction;
    object::delete(uid);
    let bid_coin = coin::from_balance(bid_balance, ctx);
    transfer::public_transfer(bid_coin, seller);
}

#[test_only]

public fun init_test(ctx: &mut TxContext){
    let auction = Auction {
        id: object::new(ctx),
        seller: ctx.sender(),
        bidder: ctx.sender(),
        thing: b"",
        top_bid: balance::zero<IOTA>(),
        deadline: 0,
        state: INIT
    };
    transfer::share_object(auction);
}
