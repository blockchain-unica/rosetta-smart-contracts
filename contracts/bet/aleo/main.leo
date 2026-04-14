import credits.aleo;

program bet.aleo {

    storage player1: address;
    storage player2: address;
    storage deadline: u32;
    storage oracle: address;
    storage wager: u64;
    storage redeemer: address;
    storage winner_declared: bool;

    fn initialize(oracle_addr: address, timeout_: u32, bet_amount: u64) -> Final {
        let caller: address = self.signer;
        let f: Final = credits.aleo::transfer_public_as_signer(self.address, bet_amount);
        return final {
            assert(player1.unwrap_or(aleo1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq3ljyzc) == aleo1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq3ljyzc);
            f.run();
            player1 = caller;
            oracle = oracle_addr;
            wager = bet_amount;
            deadline = block.height + timeout_;
        };
    }

    fn join(bet_amount: u64) -> Final {
        let caller: address = self.signer;
        let f: Final = credits.aleo::transfer_public_as_signer(self.address, bet_amount);
        return final {
            assert(player1.unwrap_or(aleo1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq3ljyzc) != aleo1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq3ljyzc);
            assert(player2.unwrap_or(aleo1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq3ljyzc) == aleo1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq3ljyzc);
            assert(bet_amount == wager.unwrap());
            assert(block.height <= deadline.unwrap());
            f.run();
            player2 = caller;
        };
    }

    fn win(public winner: u8, public winner_addr: address, public pot: u64) -> Final {
        let caller: address = self.signer;
        let f: Final = credits.aleo::transfer_public(winner_addr, pot);
        return final {
            assert(caller == oracle.unwrap());
            assert(block.height <= deadline.unwrap());
            assert(player2.unwrap_or(aleo1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq3ljyzc) != aleo1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq3ljyzc);
            assert(pot == wager.unwrap() * 2u64);
            assert(winner <= 1u8);
            let expected: address = winner == 0u8 ? player1.unwrap() : player2.unwrap();
            assert(winner_addr == expected);
            winner_declared = true;
            f.run();
        };
    }

    fn timeout(public bet_amount: u64) -> Final {
        let caller: address = self.signer;
        let f: Final = credits.aleo::transfer_public(caller, bet_amount);
        return final {
            assert(block.height > deadline.unwrap());
            assert(winner_declared.unwrap_or(false) == false);
            assert(player1.unwrap_or(aleo1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq3ljyzc) != aleo1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq3ljyzc);
            assert((caller == player1.unwrap() || caller == player2.unwrap()) && caller != redeemer.unwrap_or(aleo1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq3ljyzc));
            assert(wager.unwrap() == bet_amount);
            redeemer = caller;
            f.run();
        };
    }

    @noupgrade
    constructor() {}
}