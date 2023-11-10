
module vault::htlc {
    use sui::tx_context::{Self, TxContext};
    use sui::object::{Self, UID};
    use sui::transfer;
    use sui::coin;
    use sui::clock::{Clock, timestamp_ms};

    const StateIdle : u8 = 0;
    const StateRequest : u8 = 1;

    const ErrorUnauthorized : u64 = 0;
    const ErrorInsufficientFunds : u64 = 1;
    const ErrorInvalidState : u64 = 2;
    const ErrorBadTiming : u64 = 3;

    struct Vault<phantom T> has key {
        id: UID,
        owner: address,
        recovery: address,
        waitTimeMs: u64,
        money: coin::Coin<T>,
        state: u8,
        requestTimestamp: u64,
        requestAmount: u64,
    }

    public entry fun create_vault<T>(recovery: address, waitTimeMs: u64, ctx: &mut TxContext) {
        let vault = Vault<T> {
            id: object::new(ctx),
            owner: tx_context::sender(ctx),
            recovery: recovery,
            waitTimeMs: waitTimeMs,
            money: coin::zero(ctx),
            state: StateIdle,
            requestTimestamp: 0,
            requestAmount: 0,
        };
        transfer::share_object(vault);
    }

    public entry fun withdraw<T>(vault: &mut Vault<T>, amount: u64, clock: &Clock, ctx: &mut TxContext) {
        assert!(vault.owner == tx_context::sender(ctx), ErrorUnauthorized);
        assert!(vault.state == StateIdle, ErrorInvalidState);
        assert!(coin::value(&vault.money) >= amount, ErrorInsufficientFunds);

        vault.requestTimestamp = timestamp_ms(clock);
        vault.requestAmount = amount;
    }

    public entry fun finalize<T>(vault: &mut Vault<T>, coin: &mut coin::Coin<T>, clock: &Clock, ctx: &mut TxContext) {
        assert!(vault.owner == tx_context::sender(ctx), ErrorUnauthorized);
        assert!(vault.state == StateRequest, ErrorInvalidState);
        assert!(timestamp_ms(clock) >= vault.requestTimestamp + vault.waitTimeMs, ErrorBadTiming);

        coin::join(coin, coin::split(&mut vault.money, vault.requestAmount, ctx));
        vault.state = StateIdle;
    }

    public entry fun cancel<T>(vault: &mut Vault<T>, ctx: &mut TxContext) {
        assert!(vault.recovery == tx_context::sender(ctx), ErrorUnauthorized);
        assert!(vault.state == StateRequest, ErrorInvalidState);

        vault.state = StateIdle;
    }
}