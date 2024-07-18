module rosetta_smart_contracts::simple_wallet {
    use aptos_framework::coin::{Self, Coin};
    use aptos_framework::signer;
    use aptos_framework::event;
    use std::vector;

    struct Wallet<phantom CoinType> has key {
        owner: address,
        transactions: vector<Transaction<CoinType>>,
        coins: Coin<CoinType>
    }

    struct Transaction<phantom CoinType> has store {
        to: address,
        value: u64,
        data: vector<u8>,
        executed: bool
    }

    #[event]
    struct Deposit has drop, store {
        sender: address,
        amount: u64,
        balance: u64
    }

    #[event]
    struct Withdraw has drop, store {
        sender: address,
        amount: u64,
    }

    #[event]
    struct SubmitTransaction has drop, store {
        owner: address,
        tx_id: u64,
        to: address,
        value: u64,
        data: vector<u8>
    }

    #[event]
    struct ExecuteTransaction has drop, store {
        owner: address,
        tx_id: u64
    }

    public fun initialize<CoinType>(owner: &signer) {
        let wallet = Wallet<CoinType> {
            owner: signer::address_of(owner),
            transactions: vector::empty<Transaction<CoinType>>(),
            coins: coin::zero<CoinType>()
        };
        move_to<Wallet<CoinType>>(owner, wallet);
    }

    public fun deposit<CoinType>(sender: &signer, wallet_owner: address, coins: Coin<CoinType>) acquires Wallet {
        let wallet = borrow_global_mut<Wallet<CoinType>>(wallet_owner);
        let coins_value = coin::value(&coins);
        coin::merge(&mut wallet.coins, coins);
        let deposit_event = Deposit {
            sender: signer::address_of(sender),
            amount: coins_value,
            balance: coin::value(&wallet.coins)
        };
        event::emit(deposit_event);
    }

    public fun create_transaction<CoinType>(owner: &signer, to: address, value: u64, data: vector<u8>): u64 acquires Wallet {
        // TODO events
        let wallet = borrow_global_mut<Wallet<CoinType>>(signer::address_of(owner));
        assert!(signer::address_of(owner) == wallet.owner, 0); // Maybe this assert is useless
        let tx_id = vector::length(&wallet.transactions);
        let transaction = Transaction<CoinType> {
            to: to,
            value: value,
            data: data,
            executed: false
        };
        vector::push_back(&mut wallet.transactions, transaction);
        let submit_transaction_event = SubmitTransaction {
            owner: signer::address_of(owner),
            tx_id: tx_id,
            to: to,
            value: value,
            data: data
        };
        event::emit(submit_transaction_event);
        tx_id
    }

    public fun execute_transaction<CoinType>(owner: &signer, tx_id: u64) acquires Wallet {
        let wallet = borrow_global_mut<Wallet<CoinType>>(signer::address_of(owner));
        assert!(signer::address_of(owner) == wallet.owner, 0); // Maybe this assert is useless
        assert!(tx_id < vector::length(&wallet.transactions), 1);
        assert!(vector::borrow(&wallet.transactions, tx_id).executed == false, 2);

        let transaction = vector::borrow_mut(&mut wallet.transactions, tx_id);
        assert!(coin::value(&wallet.coins) >= transaction.value, 3);
        
        transaction.executed = true;
        let coins = coin::extract(&mut wallet.coins, transaction.value);
        coin::deposit<CoinType>(transaction.to, coins);

        let execute_transaction_event = ExecuteTransaction {
            owner: signer::address_of(owner),
            tx_id: tx_id
        };
        event::emit(execute_transaction_event);
    }

    public fun withdraw<CoinType>(owner: &signer) acquires Wallet {
        let wallet = borrow_global_mut<Wallet<CoinType>>(signer::address_of(owner));
        assert!(signer::address_of(owner) == wallet.owner, 0); // Maybe this assert is useless

        let coins = coin::extract_all(&mut wallet.coins);
        coin::deposit<CoinType>(signer::address_of(owner), coins);

        let withdraw_event = Withdraw {
            sender: signer::address_of(owner),
            amount: coin::value(&wallet.coins)
        };
        event::emit(withdraw_event);
    }
}