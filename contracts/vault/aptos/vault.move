module deploy_address::vault {
    use aptos_framework::coin::{Self, Coin};
    use aptos_framework::signer;
    use aptos_framework::timestamp;
    
    struct Vault<phantom CoinType> has key {
        owner: address,
        recovery: address,
        wait_time: u64, //in seconds
        coins: coin::Coin<CoinType>,
        state: u8,
        request_timestamp: u64, // in seconds
        amount: u64,
        receiver: address,
    }

    public fun initialize<CoinType>(owner: &signer, recovery: address, wait_time: u64) {
        let vault = Vault {
            owner: signer::address_of(owner),
            recovery: recovery,
            wait_time: wait_time,
            coins: coin::zero<CoinType>(),
            state: 0,
            request_timestamp: 0,
            amount: 0,
            receiver: @0x0,
        };
        move_to(owner, vault);
    }

    public fun deposit<CoinType>(owner: address, deposit_amount: Coin<CoinType>) acquires Vault {
        let vault = borrow_global_mut<Vault<CoinType>>(owner);
        coin::merge(&mut vault.coins, deposit_amount);
    }

    public fun withdraw<CoinType>(owner: &signer, amount: u64, receiver: address) acquires Vault {
        let vault = borrow_global_mut<Vault<CoinType>>(signer::address_of(owner));
        assert!(vault.owner == signer::address_of(owner), 0);
        assert!(coin::value(&vault.coins) >= amount, 1);
        assert!(vault.state == 0, 2);

        vault.request_timestamp = timestamp::now_seconds();
        vault.amount = amount;
        vault.state = 1;
        vault.receiver = receiver;
    }

    public fun finalize<CoinType>(owner: &signer) acquires Vault {
        let vault = borrow_global_mut<Vault<CoinType>>(signer::address_of(owner));
        assert!(vault.owner == signer::address_of(owner), 0);
        assert!(vault.state == 1, 1);
        assert!(timestamp::now_seconds() >= vault.request_timestamp + vault.wait_time, 2);

        vault.state = 0;
        coin::deposit<CoinType>(vault.receiver, coin::extract(&mut vault.coins, vault.amount));
    }

    public fun cancel<CoinType>(recovery: &signer, owner:address) acquires Vault {
        let vault = borrow_global_mut<Vault<CoinType>>(owner);
        assert!(vault.owner == owner, 0);
        assert!(vault.recovery == signer::address_of(recovery), 1);
        assert!(vault.state == 1, 2);

        vault.state = 0;
    }
}
