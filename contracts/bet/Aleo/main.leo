import credits.aleo;

program bet.aleo {

    storage player1: address;
    storage player2: address;
    storage deadline: u32;
    storage oracle: address;
    storage wager: u64;
    storage redeemer: address;
    storage winner_declared: bool;

    async transition initialize(oracle_addr: address, timeout_: u32, bet_amount: u64) -> Future {
        let f: Future = credits.aleo/transfer_public_as_signer(self.address, bet_amount);
        return finalize_initialize(f, self.signer, oracle_addr, timeout_, bet_amount);
    }

    async function finalize_initialize(f: Future, caller: address, oracle_addr: address, timeout_: u32, bet_amount: u64) {
        assert(player1.unwrap_or(aleo1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq3ljyzc) == aleo1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq3ljyzc);
        f.await();
        player1 = caller;
        oracle = oracle_addr;
        wager = bet_amount;
        deadline = block.height + timeout_;
    }

    async transition join(bet_amount: u64) -> Future {
        let f: Future = credits.aleo/transfer_public_as_signer(self.address, bet_amount);
        return finalize_join(f, self.signer, bet_amount);
    }

    async function finalize_join(f: Future, caller: address, bet_amount: u64) {
        assert(player1.unwrap_or(aleo1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq3ljyzc) != aleo1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq3ljyzc);
        assert(player2.unwrap_or(aleo1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq3ljyzc) == aleo1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq3ljyzc);
        assert(bet_amount == wager.unwrap());
        assert(block.height <= deadline.unwrap());
        f.await();
        player2 = caller;
    }

    async transition win(public winner: u8, public winner_addr: address, public pot: u64) -> Future {
        let f: Future = credits.aleo/transfer_public(winner_addr, pot);
        return finalize_win(f, self.signer, winner, winner_addr, pot);
    }

    async function finalize_win(f: Future, caller: address, winner: u8, winner_addr: address, pot: u64) {
        assert(caller == oracle.unwrap());
        assert(block.height <= deadline.unwrap());
        assert(player2.unwrap_or(aleo1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq3ljyzc) != aleo1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq3ljyzc);
        assert(pot == wager.unwrap() * 2u64);
        assert(winner <= 1u8);
        let expected: address = winner == 0u8 ? player1.unwrap() : player2.unwrap();
        assert(winner_addr == expected);
        winner_declared = true;
        f.await();
    }

    async transition timeout(public bet_amount: u64) -> Future {
        let f: Future = credits.aleo/transfer_public(self.signer, bet_amount);
        return finalize_timeout(f, self.signer, bet_amount);
    }

    async function finalize_timeout(f: Future, caller: address, bet_amount: u64) {
        assert(block.height > deadline.unwrap());
        assert(winner_declared.unwrap_or(false) == false);
        assert(player1.unwrap_or(aleo1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq3ljyzc) != aleo1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq3ljyzc);
        assert((caller == player1.unwrap() || caller == player2.unwrap()) && caller != redeemer.unwrap_or(aleo1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq3ljyzc));
        assert(wager.unwrap() == bet_amount);
        redeemer = caller;
        f.await();
    }

    @noupgrade
    async constructor() {}
}