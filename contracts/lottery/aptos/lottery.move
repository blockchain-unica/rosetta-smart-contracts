module rosetta_smart_contracts::lottery {
    use aptos_framework::coin::{Self, Coin};
    use aptos_framework::aptos_coin::{Self, AptosCoin};
    use aptos_framework::signer;
    use aptos_framework::block;
    use aptos_std::aptos_hash;
    use std::vector;
    use std::string::{Self, String};

    // Lottery status codes
    const JOIN0: u64 = 0;
    const JOIN1: u64 = 1;
    const COMMIT0: u64 = 2;
    const COMMIT1: u64 = 3;
    const REVEAL0: u64 = 4;
    const REVEAL1: u64 = 5;
    const WIN: u64 = 6;
    const END: u64 = 7;

    struct Lottery<phantom CoinType> has key {
        owner: address,
        player_0: address,
        player_1: address,
        winner: address,
        hash_0: vector<u8>,
        hash_1: vector<u8>,
        secret_0: vector<u8>,
        secret_1: vector<u8>,
        bet_amount: u64,
        status: u64,
        end_join: u64,
        end_reveal: u64,
        pot: Coin<CoinType>,
    }

    fun init_module<CoinType>(owner: &signer) {
        let lottery = Lottery<CoinType> {
            owner: signer::address_of(owner),
            player_0: @0x0,
            player_1: @0x0,
            winner: @0x0,
            hash_0: vector[],
            hash_1: vector[],
            secret_0: vector[],
            secret_1: vector[],
            bet_amount: 0,
            status: JOIN0,
            end_join: block::get_current_block_height() + 1000,
            end_reveal: block::get_current_block_height() + 2000,
            pot: coin::zero<CoinType>()
        };
        move_to(owner, lottery);
    }

    public fun join_0<CoinType>(player_0: &signer, owner: address, hash: vector<u8>, coins: Coin<CoinType>) acquires Lottery {
        let lottery = borrow_global_mut<Lottery<CoinType>>(owner);
        assert!(lottery.status == JOIN0, 0);
        assert!(coin::value(&coins) > 10, 1);

        lottery.player_0 = signer::address_of(player_0);
        lottery.hash_0 = hash;
        lottery.status = JOIN1;
        lottery.bet_amount = coin::value(&coins);
        coin::merge(&mut lottery.pot, coins);
    }

    public fun join_1<CoinType>(player_1: &signer, owner: address, hash: vector<u8>, coins: Coin<CoinType>) acquires Lottery {
        let lottery = borrow_global_mut<Lottery<CoinType>>(owner);
        assert!(lottery.status == JOIN1, 2);
        assert!(&lottery.hash_0 != &hash, 3);
        assert!(coin::value(&coins) == lottery.bet_amount, 4);

        lottery.player_1 = signer::address_of(player_1);
        lottery.hash_1 = hash;
        lottery.status = REVEAL0;
        coin::merge(&mut lottery.pot, coins);
    }

    public fun redeem_0_no_join_1(owner: address) acquires Lottery {
        let lottery = borrow_global_mut<Lottery<AptosCoin>>(owner);
        assert!(lottery.status == JOIN1, 5);
        assert!(block::get_current_block_height() > lottery.end_join, 6);
        let value = coin::value(&lottery.pot);
        let pot = coin::extract(&mut lottery.pot, value);
        coin::deposit(lottery.player_0, pot);
        lottery.status = END;
    }

    public fun reveal_0(player0: &signer, secret: vector<u8>, owner: address) acquires Lottery {
        let lottery = borrow_global_mut<Lottery<AptosCoin>>(owner);
        assert!(lottery.status == REVEAL0, 7);
        assert!(signer::address_of(player0) == lottery.player_0, 8);
        let secret_hash = aptos_hash::keccak256(copy secret);
        assert!(vector::length<u8>(&lottery.hash_1) == vector::length<u8>(&secret_hash), 9);
        let i = 0;
        while (i <= vector::length<u8>(&lottery.hash_1)) {
            assert!(vector::borrow<u8>(&lottery.hash_1, i) == vector::borrow<u8>(&secret_hash, i), 10);
            i = i + 1;
        };
        lottery.secret_0 = secret;
        lottery.status = REVEAL1;
    }

    public fun redeem_1_no_reveal_0(owner: address) acquires Lottery {
        let lottery = borrow_global_mut<Lottery<AptosCoin>>(owner);
        assert!(lottery.status == REVEAL0, 11);
        assert!(block::get_current_block_height() > lottery.end_reveal, 12);
        let value = coin::value(&lottery.pot);
        let pot = coin::extract(&mut lottery.pot, value);
        coin::deposit(lottery.player_1, pot);
        lottery.status = END;
    }

    public fun reveal_1(player1: &signer, secret: vector<u8>, owner: address) acquires Lottery {
        let lottery = borrow_global_mut<Lottery<AptosCoin>>(owner);
        assert!(lottery.status == REVEAL1, 13);
        assert!(signer::address_of(player1) == lottery.player_1, 14);
        let secret_hash = aptos_hash::keccak256(copy secret);
        assert!(vector::length<u8>(&lottery.hash_0) == vector::length<u8>(&secret_hash), 15);
        let i = 0;
        while (i <= vector::length<u8>(&lottery.hash_0)) {
            assert!(vector::borrow<u8>(&lottery.hash_0, i) == vector::borrow<u8>(&secret_hash, i), 16);
            i = i + 1;
        };
        lottery.secret_1 = secret;
        lottery.status = WIN;
    }

    public fun win(owner: address) acquires Lottery {
        let lottery = borrow_global_mut<Lottery<AptosCoin>>(owner);
        assert!(lottery.status == WIN, 17);
        let l_0 = vector::length<u8>(&lottery.secret_0);
        let l_1 = vector::length<u8>(&lottery.secret_1);
        if ( (l_0 + l_1) % 2 == 0 ) {
            lottery.winner = lottery.player_0;
        } else {
            lottery.winner = lottery.player_1;
        };

        let value = coin::value(&lottery.pot); 
        let pot = coin::extract(&mut lottery.pot, value);
        coin::deposit(lottery.winner, pot);
        lottery.status = END;
    }
}

