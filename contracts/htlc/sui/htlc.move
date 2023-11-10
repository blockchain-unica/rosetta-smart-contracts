
module htlc::htlc {
    use sui::tx_context::{Self, TxContext};
    use sui::object::{Self, UID};
    use sui::transfer;
    use sui::coin;
    use sui::clock::{Clock, timestamp_ms};
    use sui::hash;
    use std::option::{Self, Option};

    const ErrorPermissionDenied: u64 = 0;
    const ErrorWrongSecret: u64 = 1;
    const ErrorBadTiming: u64 = 2;

    struct Htlc<phantom T> has key {
        id: UID,
        owner: address,
        verifier: address,
        hash: vector<u8>,
        revealTimestamp: u64,
        money: Option<coin::Coin<T>>,
    }

                                            // string (there is no string type in Move)
    public entry fun create_htlc<T>(coin: coin::Coin<T>, verifier: address, hash: vector<u8>, delayMs: u64, clock: &Clock, ctx: &mut TxContext) {
        let htlc = Htlc<T> {
            id: object::new(ctx),
            owner: tx_context::sender(ctx),
            verifier: verifier,
            hash: hash,
            revealTimestamp: timestamp_ms(clock) + delayMs,
            money: option::some(coin),
        };
        transfer::share_object(htlc);
    }

    public entry fun reveal<T>(htlc: &mut Htlc<T>, secret: vector<u8>, ctx: &mut TxContext) {
        assert!(htlc.owner == tx_context::sender(ctx), ErrorPermissionDenied);
        assert!(hash::keccak256(&secret) == htlc.hash, ErrorWrongSecret);

        let coin = option::extract(&mut htlc.money);
        transfer::public_transfer(coin, htlc.owner);
    }

    public entry fun timeout<T>(htlc: &mut Htlc<T>, clock: &Clock) {
        assert!(timestamp_ms(clock) > htlc.revealTimestamp, ErrorBadTiming);

        let coin = option::extract(&mut htlc.money);
        transfer::public_transfer(coin, htlc.verifier);
    }

}