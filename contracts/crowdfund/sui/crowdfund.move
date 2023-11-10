
module crowdfund::crowdfund {
    use sui::tx_context::{Self, TxContext};
    use sui::object::{Self, UID, ID};
    use sui::transfer;
    use sui::coin;
    use sui::clock::{Clock, timestamp_ms};

    const ErrorBadTiming: u64 = 0;
    const ErrorGoalReached: u64 = 1;
    const ErrorGoalNotReached: u64 = 2;
    const ErrorInvalidReceipt: u64 = 3;

    struct Crowdfund<phantom T> has key {
        id: UID,
        endDonate: u64,         // After this timestamp, no more donations are accepted
        goal: u64,              // Amount of Coins to be raised
        receiver: address,      // This address will receive the money
        money: coin::Coin<T>,
    }

    struct Receipt<phantom T> has key {
        id: UID,
        crowdfundId: ID,
        amount: u64,
    }

    public entry fun create_crowdfund<T>(goal: u64, receiver: address, endDonate: u64, ctx: &mut TxContext) {
        let crowdfund = Crowdfund<T> {
            id: object::new(ctx),
            endDonate: endDonate,
            goal: goal,
            receiver: receiver,
            money: coin::zero<T>(ctx),
        };
        transfer::share_object(crowdfund);
    }

    public entry fun donate<T>(crowdfund: &mut Crowdfund<T>, money: coin::Coin<T>, clock: &Clock, ctx: &mut TxContext) {
        assert!(timestamp_ms(clock) <= crowdfund.endDonate, ErrorBadTiming);

        let receipt = Receipt<T> {
            id: object::new(ctx),
            crowdfundId: object::id(crowdfund),
            amount: coin::value(&money),
        };
        coin::join(&mut crowdfund.money, money);
        transfer::transfer(receipt, tx_context::sender(ctx));
    }

    public entry fun withdraw<T>(crowdfund: &mut Crowdfund<T>, clock: &Clock, ctx: &mut TxContext) {
        assert!(timestamp_ms(clock) > crowdfund.endDonate, ErrorBadTiming);
        assert!(coin::value(&crowdfund.money) >= crowdfund.goal, ErrorGoalNotReached);

        let total = coin::value(&crowdfund.money);
        let money = coin::split(&mut crowdfund.money, total, ctx);
        transfer::public_transfer(money, crowdfund.receiver);
    }

    public entry fun reclaim<T>(crowdfund: &mut Crowdfund<T>, receipt: Receipt<T>, clock: &Clock, ctx: &mut TxContext) {
        assert!(timestamp_ms(clock) > crowdfund.endDonate, ErrorBadTiming);
        assert!(coin::value(&crowdfund.money) < crowdfund.goal, ErrorGoalReached);
        assert!(object::id(crowdfund) == receipt.crowdfundId, ErrorInvalidReceipt);

        let Receipt<T> {
            id,
            crowdfundId: _,
            amount,
        } = receipt;
        object::delete(id);
        let money = coin::split(&mut crowdfund.money, amount, ctx);
        transfer::public_transfer(money, tx_context::sender(ctx));
    }
}