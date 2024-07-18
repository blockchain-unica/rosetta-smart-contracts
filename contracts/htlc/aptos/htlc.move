module rosetta_smart_contracts::htlc {
    use std::vector;
    use aptos_std::aptos_hash;
    use aptos_framework::coin::{Self, Coin};
    use aptos_framework::signer;
    use aptos_framework::timestamp;
    
    struct Htlc<phantom CoinType> has key {
        owner: address,
        verifier: address,
        hash: vector<u8>,
        reveal_timeout: u64, //in seconds
        coin: Coin<CoinType>,
    }

    public fun init<CoinType>(
        owner: &signer,
        verifier: address,
        hash: vector<u8>,
        reveal_timeout: u64,
        coins: Coin<CoinType>
    ) {
        let htlc = Htlc<CoinType> {
            owner: signer::address_of(owner),
            verifier: verifier,
            hash: hash,
            reveal_timeout: reveal_timeout,
            coin: coins,
        };
        move_to(owner, htlc);
    }

    public fun reveal<CoinType>(owner: &signer, secret: vector<u8>) acquires Htlc {
        let htlc = borrow_global_mut<Htlc<CoinType>>(signer::address_of(owner));
        assert!(htlc.owner == signer::address_of(owner), 0);
        let secret_hash = aptos_hash::keccak256(secret);
        assert!(vector::length<u8>(&htlc.hash) == vector::length<u8>(&secret_hash), 1);
        let i = 0;
        while (i <= vector::length<u8>(&htlc.hash)) {
            assert!(vector::borrow<u8>(&htlc.hash, i) == vector::borrow<u8>(&secret_hash, i), 2);
            i = i + 1;
        };
        let coins = coin::extract_all<CoinType>(&mut htlc.coin);
        coin::deposit<CoinType>(signer::address_of(owner), coins);
    }

    public fun timeout<CoinType>(verifier: &signer, owner: address) acquires Htlc {
        let htlc = borrow_global_mut<Htlc<CoinType>>(owner);
        assert!(timestamp::now_seconds() >= htlc.reveal_timeout, 3);
        let coins = coin::extract_all<CoinType>(&mut htlc.coin);
        coin::deposit<CoinType>(signer::address_of(verifier), coins);
    }
}