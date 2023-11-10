
module simple_transfer::htlc {
    use sui::tx_context::{Self, TxContext};
    use sui::object::{Self, UID};
    use sui::transfer;
    use sui::coin;

    const ErrorPermissionDenied: u64 = 0;

    struct SimpleTransfer<phantom T> has key {
        id: UID,
        owner: address,
        recipient: address,
        money: coin::Coin<T>,
    }

    public entry fun create_simple_transfer<T>(recipient: address, ctx: &mut TxContext) {
        let simple_transfer = SimpleTransfer<T> {
            id: object::new(ctx),
            owner: tx_context::sender(ctx),
            recipient: recipient,
            money: coin::zero<T>(ctx),
        };
        transfer::share_object(simple_transfer);
    }

    public entry fun deposit<T>(simple_transfer: &mut SimpleTransfer<T>, coin: coin::Coin<T>, ctx: &mut TxContext) {
        assert!(simple_transfer.owner == tx_context::sender(ctx), ErrorPermissionDenied);
        coin::join(&mut simple_transfer.money, coin);
    }

    public entry fun withdraw<T>(simple_transfer: &mut SimpleTransfer<T>, coin: &mut coin::Coin<T>, amount: u64, ctx: &mut TxContext) {
        assert!(simple_transfer.recipient == tx_context::sender(ctx), ErrorPermissionDenied);

        // coin::split will panic if the amount is greater than the balance
        let cAmount = coin::split(&mut simple_transfer.money, amount, ctx);
        coin::join(coin, cAmount);
    }
}