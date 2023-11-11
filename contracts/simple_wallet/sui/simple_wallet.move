
module simple_wallet::simple_wallet {
    use sui::tx_context::{Self, TxContext};
    use sui::object::{Self, UID, ID};
    use sui::transfer;
    use sui::coin;

    const ErrorInsufficientFunds: u64 = 0;
    const ErrorWrongWallet: u64 = 1;

    struct Wallet<phantom T> has key {
        id: UID,
        money: coin::Coin<T>,
    }

    struct Transaction<phantom T> has key {
        id: UID,
        to: address,
        value: u64,
        walletId: ID,
    }

    public entry fun create_wallet<T>(ctx: &mut TxContext) {
        let sender = tx_context::sender(ctx);
        let wallet = Wallet {
            id: object::new(ctx),
            money: coin::zero<T>(ctx),
        };
        transfer::transfer(wallet, sender);
    }

    // Wallet is a Sui OWNED object, so it can only be used by the owner
    public entry fun deposit<T>(wallet: &mut Wallet<T>, coin: coin::Coin<T>) {
        coin::join(&mut wallet.money, coin);
    }

    public entry fun withdraw<T>(wallet: &mut Wallet<T>, coin: &mut coin::Coin<T>, ctx: &mut TxContext) {
        let wallet_amount = coin::value(&wallet.money);
        coin::join(coin, coin::split(&mut wallet.money, wallet_amount, ctx));
    }

    public entry fun createTransaction<T>(wallet: &Wallet<T>, to: address, value: u64, ctx: &mut TxContext) {
        let transaction = Transaction<T> {
            id: object::new(ctx),
            to: to,
            value: value,
            walletId: object::uid_to_inner(&wallet.id),
        };
        transfer::transfer(transaction, tx_context::sender(ctx));
    }

    public entry fun executeTransaction<T>(wallet: &mut Wallet<T>, transaction: Transaction<T>, ctx: &mut TxContext) {
        assert!(transaction.value <= coin::value(&wallet.money), ErrorInsufficientFunds);

        let Transaction {
            id: id,
            to: to,
            value: value,
            walletId: walletId,
        } = transaction;
        object::delete(id);

        assert!(walletId == object::uid_to_inner(&wallet.id), ErrorWrongWallet);

        let money_value = coin::split<T>(&mut wallet.money, value, ctx);
        transfer::public_transfer(money_value, to);
    }
}
