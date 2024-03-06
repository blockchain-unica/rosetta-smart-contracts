module smart_contracts_comparison::escrow {

    use aptos_framework::signer;
    use aptos_framework::coin::{Self, Coin};

    struct Escrow<phantom CoinType> has key {
        state: u64,
        buyer: address,
        seller: address,
        amount: u64,
        coins: Coin<CoinType>,
    }

    public fun init<CoinType>(seller: &signer, buyer: address, amount: u64) {
        let escrow = Escrow {
            state: 0,
            buyer,
            seller: signer::address_of(seller),
            amount,
            coins: coin::zero<CoinType>(),
        };
        move_to(seller, escrow);
    }

    public fun deposit<CoinType>(buyer: &signer, seller: address, coins: Coin<CoinType>) acquires Escrow {
        let escrow = borrow_global_mut<Escrow<CoinType>>(seller);
        assert!(signer::address_of(buyer) == escrow.buyer, 0);
        assert!(escrow.state == 0, 1);
        assert!(coin::value(&coins) == escrow.amount, 2);
        coin::merge(&mut escrow.coins, coins);
        escrow.state = 1;
    }

    public fun pay<CoinType>(buyer: &signer, seller: address) acquires Escrow {
        let escrow = borrow_global_mut<Escrow<CoinType>>(seller);
        assert!(signer::address_of(buyer) == escrow.buyer, 3);
        assert!(escrow.state == 1, 4);
        let coins = coin::extract(&mut escrow.coins, escrow.amount);
        coin::deposit(seller, coins);
        escrow.state = 2;
    }

    public fun refund<CoinType>(seller: &signer) acquires Escrow{
        let escrow = borrow_global_mut<Escrow<CoinType>>(signer::address_of(seller));
        assert!(signer::address_of(seller) == escrow.seller, 5);
        assert!(escrow.state == 1, 6);
        let coins = coin::extract(&mut escrow.coins, escrow.amount);
        coin::deposit(escrow.buyer, coins);
        escrow.state = 2;
    }
}