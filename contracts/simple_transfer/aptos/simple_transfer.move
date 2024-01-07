module deploy_address::simple_transfer {
    use aptos_framework::coin::{Self, Coin};
    use aptos_framework::signer;
    
    struct SimpleTransfer<phantom CoinType> has key {
        recipient: address,
        owner: address,
        amount: Coin<CoinType>,
    }

    public fun initialize<CoinType>(owner: &signer, recipient: address) {
        let simple_transfer = SimpleTransfer {
            recipient: recipient,
            owner: signer::address_of(owner),
            amount: coin::zero<CoinType>(),
        };
        move_to(owner, simple_transfer);
    }

    public fun deposit<CoinType>(sender: &signer, deposit_amount: Coin<CoinType>) acquires SimpleTransfer {
        let simple_transfer = borrow_global_mut<SimpleTransfer<CoinType>>(signer::address_of(sender));
        assert!(simple_transfer.owner == signer::address_of(sender), 0);
        coin::merge(&mut simple_transfer.amount, deposit_amount);
    }

    public fun withdraw<CoinType>(sender: &signer, owner: address, amount: u64) acquires SimpleTransfer {
        let simple_transfer = borrow_global_mut<SimpleTransfer<CoinType>>(owner);
        assert!(simple_transfer.owner == owner, 0);
        assert!(coin::value(&simple_transfer.amount) >= amount, 1);
        let withdraw_amount = coin::extract(&mut simple_transfer.amount, amount);
        coin::deposit(signer::address_of(sender), withdraw_amount);
    }
}
