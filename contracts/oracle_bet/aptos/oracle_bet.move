module deploy_address::bet_v1 {

    use aptos_framework::coin::{Coin, Self};
    use std::signer::{address_of};
    use std::timestamp;

    struct OracleBet has key {
        player1: address,
        player2: address,
        oracle: address,
        stake: u64,
        deadline: u64,
    }

    struct Bet<phantom CoinType> has key {
        value: Coin<CoinType>
    }

    public fun initBet(bookmaker: &signer, player1: address, player2: address, oracle: address, stake: u64, deadline: u64) {
        let oracleBet = OracleBet {
            player1,
            player2,
            oracle,
            stake,
            deadline
        };

        move_to(bookmaker, oracleBet);
    }

    public fun join<CoinType>(better: &signer, bet: Coin<CoinType>, bookmaker: address) acquires OracleBet {
        let oracleBet = borrow_global_mut<OracleBet>(bookmaker);
        assert!(address_of(better) == oracleBet.player1 || address_of(better) == oracleBet.player2, 0);
        assert!(coin::value<CoinType>(&bet) == oracleBet.stake, 0);
        let bet = Bet { value: bet };

        move_to(better, bet);
    }

    public fun winner<CoinType>(oracle: &signer, winner: address, bookmaker: address) acquires OracleBet, Bet {
        assert!(exists<OracleBet>(bookmaker), 0);
        let OracleBet {
            player1,
            player2,
            oracle: oracle_address,
            stake: _,
            deadline: _
        } = move_from<OracleBet>(bookmaker);
        assert!(address_of(oracle) == oracle_address, 0);
        assert!(winner == player1 || winner == player2, 0);
        let Bet { value: bet1 } = move_from<Bet<CoinType>>(player1);
        let Bet { value: bet2 } = move_from<Bet<CoinType>>(player2);
        coin::merge(&mut bet1,bet2);
        coin::deposit(winner, bet1 );
    }

    public fun timeout<CoinType>(bookmaker: address) acquires OracleBet, Bet {
        let OracleBet {
            player1,
            player2,
            oracle: _,
            stake: _,
            deadline
        } = move_from<OracleBet>(bookmaker);
        assert!(deadline < timestamp::now_seconds(), 0);
        let Bet { value: bet1 } = move_from<Bet<CoinType>>(player1);
        let Bet { value: bet2 } = move_from<Bet<CoinType>>(player2);
        coin::deposit(player1, bet1);
        coin::deposit(player2, bet2);
    }

}