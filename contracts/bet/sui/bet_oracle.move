
module bet_oracle::bet_oracle {
    use sui::tx_context::{Self, TxContext};
    use sui::object::{Self, UID};
    use sui::transfer;
    use sui::coin;
    use sui::clock::{Clock, timestamp_ms};
    use std::vector;

    const ErrorInvalidValue: u64 = 0;
    const ErrorInvalidChoice: u64 = 1;
    const ErrorBadTiming: u64 = 2;
    const ErrorChoiceAlreadySelected: u64 = 3;

    struct Bet<phantom T> has key {
        id: UID,
        oracle: address,
        end_timestamp_ms: u64,
        wager: u64,
        money: coin::Coin<T>,
        bettors: vector<address>,
    }

    public entry fun create_bet<T>(clock: &Clock, wager: u64, durationMs: u64, ctx: &mut TxContext) {
        let bettors = vector::empty<address>();
        vector::push_back(&mut bettors, @0x0);
        vector::push_back(&mut bettors, @0x0);

        let bet = Bet<T> {
            id: object::new(ctx),
            oracle: tx_context::sender(ctx),
            end_timestamp_ms: timestamp_ms(clock) + durationMs,
            wager: wager,
            money: coin::zero<T>(ctx),
            bettors: bettors,
        };
        transfer::share_object(bet);
    }

    // choice: 1 or 2
    public entry fun bet<T>(bet: &mut Bet<T>, choice: u64, coin: coin::Coin<T>, clock: &Clock, ctx: &mut TxContext) {
        assert!(coin::value(&coin) == bet.wager, ErrorInvalidValue);
        assert!(choice >= 1 && choice <= 2, ErrorInvalidChoice);
        assert!(timestamp_ms(clock) < bet.end_timestamp_ms, ErrorBadTiming);
        let choice_idx = choice - 1;
        let bettor_for_choice = vector::borrow(&mut bet.bettors, choice_idx);
        assert!(*bettor_for_choice != @0x0, ErrorChoiceAlreadySelected);

        let vec_last_idx = vector::length(&bet.bettors) - 1;
        vector::swap(&mut bet.bettors, choice_idx, vec_last_idx);
        vector::pop_back(&mut bet.bettors);
        vector::push_back(&mut bet.bettors, tx_context::sender(ctx));
        vector::swap(&mut bet.bettors, choice_idx, vec_last_idx);

        coin::join(&mut bet.money, coin);
    }

    // result: 1 or 2
    public entry fun oracleSetResult<T>(bet: &mut Bet<T>, result: u64, clock: &Clock, ctx: &mut TxContext) {
        assert!(timestamp_ms(clock) >= bet.end_timestamp_ms, ErrorBadTiming);
        assert!(result >= 1 && result <= 2, ErrorInvalidChoice);

        let winner = *vector::borrow(&bet.bettors, result - 1);
        let win_amount = coin::value(&bet.money);
        let all_money = coin::split(&mut bet.money, win_amount, ctx);
        transfer::public_transfer(all_money, winner);
    }
}