module rosetta_smart_contracts::bet {
    
    use aptos_framework::coin::{Coin, Self};
    use std::signer::{address_of};
    use std::timestamp;

    struct Oracle<phantom CoinType> has key {
        player1: address,
        player2: address,
        oracle: address,
        stake: u64,
        deadline: u64,
    }

    struct Bet<phantom CoinType> has key {
        value: Coin<CoinType>
    }

    public fun init<CoinType>(bookmaker: &signer, player1: address, player2: address, oracle: address, stake: u64, deadline: u64) {
        let bet = Oracle<CoinType> {
            player1,
            player2,
            oracle,
            stake,
            deadline
        };
        move_to(bookmaker, bet);
    }

    public fun join<CoinType>(partecipant: &signer, bet: Coin<CoinType>, bookmaker: address) acquires Oracle {
        let oracle = borrow_global_mut<Oracle<CoinType>>(bookmaker);
        assert!(address_of(partecipant) == oracle.player1 || address_of(partecipant) == oracle.player2, 0);
        assert!(coin::value<CoinType>(&bet) == oracle.stake, 0);
        let bet = Bet { value: bet };
        move_to(partecipant, bet);
    }

    public fun win<CoinType>(oracle: &signer, winner: address, bookmaker: address) acquires Oracle, Bet {
        assert!(exists<Oracle<CoinType>>(bookmaker), 0);
        let Oracle {
            player1,
            player2,
            oracle: oracle_address,
            stake: _,
            deadline: _
        } = move_from<Oracle<CoinType>>(bookmaker);
        assert!(address_of(oracle) == oracle_address, 0);
        assert!(winner == player1 || winner == player2, 0);
        let Bet { value: bet1 } = move_from<Bet<CoinType>>(player1);
        let Bet { value: bet2 } = move_from<Bet<CoinType>>(player2);
        coin::merge(&mut bet1, bet2);
        coin::deposit(winner, bet1);
    }

    public fun timeout<CoinType>(bookmaker: address) acquires Oracle, Bet {
        let Oracle {
            player1,
            player2,
            oracle: _,
            stake: _,
            deadline
        } = move_from<Oracle<CoinType>>(bookmaker);
        assert!(deadline < timestamp::now_seconds(), 0);
        let Bet { value: bet1 } = move_from<Bet<CoinType>>(player1);
        let Bet { value: bet2 } = move_from<Bet<CoinType>>(player2);
        coin::deposit(player1, bet1);
        coin::deposit(player2, bet2);
    }

}