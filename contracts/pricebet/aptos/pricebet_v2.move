module rosetta_smart_contracts::pricebet_v2 {
    use aptos_framework::coin::{Self, Coin};
    use aptos_framework::aptos_coin::{Self, AptosCoin};
    use aptos_framework::signer;
    use aptos_framework::block;
    use rosetta_smart_contracts::oracle;
     
    struct PriceBet<phantom CoinType> has key {
        deadline_block: u64,
        exchange_rate: u64,
        initial_pot: u64,
        pot: Coin<CoinType>,
        owner: address,
        player: address,
    }

    public fun init<CoinType>(owner: &signer, deadline: u64, initial_pot: u64, exchange_rate: u64) {
        let price_bet = PriceBet<CoinType> {
            deadline_block: deadline,
            exchange_rate: exchange_rate,
            initial_pot: initial_pot,
            pot: coin::withdraw<CoinType>(owner, initial_pot),
            owner: signer::address_of(owner),
            player: @0x0,
        };
        move_to(owner, price_bet);
    }

    public fun join<CoinType>(player: &signer, owner: address, bet: u64) acquires PriceBet {
        let price_bet = borrow_global_mut<PriceBet<CoinType>>(owner);
        assert!(bet == coin::value(&price_bet.pot), 0);
        assert!(price_bet.player == @0x0, 1);
        price_bet.player = signer::address_of(player);
        coin::merge(&mut price_bet.pot, coin::withdraw<CoinType>(player, bet));
    }

    public fun win<CoinType>(player: &signer, owner: address) acquires PriceBet {
        let price_bet = borrow_global_mut<PriceBet<CoinType>>(owner);
        assert!(price_bet.player == signer::address_of(player), 2);
        assert!(price_bet.deadline_block < block::get_current_block_height(), 3);
        let exchange_rate = oracle::get_exchange_rate();
        assert!(exchange_rate >= price_bet.exchange_rate, 4);
        let value = coin::value(&price_bet.pot);
        let win_amount = coin::extract(&mut price_bet.pot, value);
        coin::deposit(signer::address_of(player), win_amount);
    }

    public fun timeout<CoinType>(owner: address) acquires PriceBet {
        let price_bet = borrow_global_mut<PriceBet<CoinType>>(owner);
        assert!(price_bet.deadline_block >= block::get_current_block_height(), 5);
        let value = coin::value(&price_bet.pot);
        let amount = coin::extract(&mut price_bet.pot, value);
        coin::deposit(owner, amount);
    }
}