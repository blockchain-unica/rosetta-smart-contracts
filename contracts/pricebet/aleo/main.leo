import credits.aleo;
import oracle_pricebet.aleo;


program pricebet.aleo {
    
    storage owner:address;
    storage pot:u64;
    storage oracle:field;
    storage deadline:u32;
    storage rate:u64;
    storage player:address;

    @noupgrade
    constructor() {}

    fn initialize(pot_:u64,oracle_: field, deadline_:u32,rate_:u64) -> Final {
        let caller_:address = self.signer;

        let f: Final = credits.aleo::transfer_public_as_signer(self.address, pot_);

        return final {
            assert(owner.unwrap_or(aleo1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq3ljyzc) == aleo1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq3ljyzc);
            assert(pot_ > 0u64);
            assert(deadline_ > 0u32);
            assert(rate_ > 0u64);
            owner = caller_;
            pot = pot_;
            oracle = oracle_;
            deadline = block.height + deadline_;
            rate = rate_;

            f.run();
        };
    }

    fn join(pot_:u64) -> Final{
        let caller_:address = self.signer;

        let f: Final = credits.aleo::transfer_public_as_signer(self.address, pot_);

        return final {
            assert(owner.unwrap_or(aleo1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq3ljyzc) != aleo1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq3ljyzc);
            assert(player.unwrap_or(aleo1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq3ljyzc) == aleo1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq3ljyzc);
            assert(pot_ == pot.unwrap());

            player = caller_;
            pot = pot.unwrap() * 2u64;
            f.run();
        };
    }

    fn win(pot_: u64) -> Final{
        let caller_:address = self.signer;

        let f: Final = credits.aleo::transfer_public(caller_,pot_);

        return final {
            assert(owner.unwrap_or(aleo1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq3ljyzc) != aleo1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq3ljyzc);
            assert(player.unwrap_or(aleo1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq3ljyzc) != aleo1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq3ljyzc);
            assert(caller_ == player.unwrap());
            assert(pot_ == pot.unwrap());
            assert(block.height < deadline.unwrap());

            let rate_opt: u64? = oracle_pricebet.aleo::Oracle@(oracle.unwrap())::rate;
            let current_rate: u64 = rate_opt.unwrap_or(0u64);

            assert(current_rate >= rate.unwrap());

            f.run();
        };
    }

    fn timeout(pot_: u64) -> Final{
        let caller_:address = self.signer;

        let f: Final = credits.aleo::transfer_public(caller_,pot_);

        return final {
            assert(owner.unwrap_or(aleo1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq3ljyzc) != aleo1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq3ljyzc);
            assert(caller_ == owner.unwrap());
            assert(pot_ == pot.unwrap());
            assert(block.height >= deadline.unwrap());

            f.run();
        };
    }
}
