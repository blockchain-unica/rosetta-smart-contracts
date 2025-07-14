module crowdfund::crowdfund;

use iota::iota::{Self, IOTA};
use iota::clock::Clock;
use iota::vec_map::{Self, VecMap};
use iota::coin::{Self, Coin};

const EPermissionDenied: u64 = 0;
const ETimeFinished: u64 = 1;
const ETimeNotFinished: u64 = 2;
const EGoalNotAchived: u64 = 3;
const EGoalAchived: u64 = 4;
const ENotDonor: u64 = 5;

public struct Crowdfund has key {
    id: UID,
    admin: address,
    recipient: address,
    donors: VecMap<address, Coin<IOTA>>,
    goal: u64, // of IOTA coin
    amount: u64, // of IOTA coin
    deadline: u64, // in ms
}

public fun destroy(self: Crowdfund){
    let Crowdfund {
        id: id,
        admin: _,
        recipient: _,
        donors: donors,
        goal: _,
        amount: _,
        deadline: _,
    } = self;
    object::delete(id);
    donors.destroy_empty();
}

//deadline field must be in hours
public fun initialize(recipient: address, goal: u64, deadline: u64, clock: &Clock, ctx: &mut TxContext){
    let donors = vec_map::empty<address, Coin<IOTA>>();
    let deadline= deadline * 3600000; 
    let crowdfund = Crowdfund {
        id: object::new(ctx),
        admin: ctx.sender(),
        recipient: recipient,
        donors: donors,
        goal: goal,
        amount: 0,
        deadline: clock.timestamp_ms() + deadline,
    };
    transfer::share_object(crowdfund);
}

public fun donate(donation: Coin<IOTA>, crowdfund: &mut Crowdfund, clock: &Clock, ctx: &mut TxContext){
    assert!(clock.timestamp_ms() <= crowdfund.deadline, ETimeFinished);

    crowdfund.amount = crowdfund.amount + donation.value();
    if (crowdfund.donors.contains(&ctx.sender())){
        let donation_just_sended = crowdfund.donors.get_mut(&ctx.sender());
        donation_just_sended.join(donation);
    } else {
        crowdfund.donors.insert(ctx.sender(), donation);
    };
}

public fun withdraw(mut crowdfund: Crowdfund, clock: &Clock, ctx: &mut TxContext){
    assert!(crowdfund.recipient == ctx.sender(), EPermissionDenied);
    assert!(clock.timestamp_ms() >= crowdfund.deadline, ETimeNotFinished);
    assert!(crowdfund.amount >= crowdfund.goal, EGoalNotAchived);

    let mut donations = coin::zero<IOTA>(ctx);
    while (!crowdfund.donors.is_empty()) {
        let (_, donation) = crowdfund.donors.pop();
        donations.join(donation);
    };
    iota::transfer(donations, crowdfund.recipient);
    crowdfund.destroy();
}


public fun reclaim(mut crowdfund: Crowdfund, clock: &Clock, ctx: &mut TxContext){
    assert!(clock.timestamp_ms() >= crowdfund.deadline, ETimeNotFinished);
    assert!(crowdfund.amount < crowdfund.goal, EGoalAchived);
    assert!(crowdfund.donors.contains(&ctx.sender()), ENotDonor);

    let (donor, donation) = crowdfund.donors.remove(&ctx.sender());
    iota::transfer(donation, donor);
    if (crowdfund.donors.is_empty()){
        crowdfund.destroy();
    } else {
        transfer::share_object(crowdfund);
    }
}


