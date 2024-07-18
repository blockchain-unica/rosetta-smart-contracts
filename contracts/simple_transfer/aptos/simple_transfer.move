module rosetta_smart_contracts::simple_transfer {
    use aptos_framework::coin::{Self, Coin};
    use aptos_framework::aptos_coin::{Self, AptosCoin};
    use aptos_framework::signer;
     
    struct SimpleTransfer has key {
        recipient: address,
        owner: address,
        amount: Coin<AptosCoin>,
    }

    public fun init(owner: &signer, recipient: address) {
        let simple_transfer = SimpleTransfer {
            recipient: recipient,
            owner: signer::address_of(owner),
            amount: coin::zero<AptosCoin>(),
        };
        move_to(owner, simple_transfer);
    }

    public fun deposit(sender: &signer, deposit_amount: Coin<AptosCoin>) acquires SimpleTransfer {
        let simple_transfer = borrow_global_mut<SimpleTransfer>(signer::address_of(sender));
        assert!(simple_transfer.owner == signer::address_of(sender), 0);
        coin::merge(&mut simple_transfer.amount, deposit_amount);
    }

    public fun withdraw(sender: &signer, owner: address, amount: u64) acquires SimpleTransfer {
        let simple_transfer = borrow_global_mut<SimpleTransfer>(owner);
        assert!(simple_transfer.owner == owner, 0);
        assert!(coin::value(&simple_transfer.amount) >= amount, 1);
        let withdraw_amount = coin::extract(&mut simple_transfer.amount, amount);
        coin::deposit(signer::address_of(sender), withdraw_amount);
    }
}
