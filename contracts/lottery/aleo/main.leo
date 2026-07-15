import credits.aleo;

program lottery.aleo {

    const STATUS_JOIN0:   u8 = 0u8;
    const STATUS_JOIN1:   u8 = 1u8;
    const STATUS_REVEAL0: u8 = 2u8;
    const STATUS_REVEAL1: u8 = 3u8;
    const STATUS_WIN:     u8 = 4u8;
    const STATUS_END:     u8 = 5u8;

    const STATUS_UNSET:   u8 = 99u8;

    
    storage status: u8;
    storage join_duration: u32;
    storage reveal_duration: u32;
    storage end_commit: u32;
    storage end_reveal: u32;
    storage player0: address;
    storage player1: address;
    storage hash0: field;
    storage hash1: field;
    storage secret0: field;
    storage secret1: field;
    storage bet_amount: u64;

    @noupgrade
    constructor() {}

    fn initialize(join_duration_: u32, reveal_duration_: u32) -> Final {
        return final {
            assert(status.unwrap_or(STATUS_UNSET) == STATUS_UNSET);

            assert(join_duration_ > 0u32);
            assert(reveal_duration_ > 0u32);

            join_duration = join_duration_;
            reveal_duration = reveal_duration_;

            status = STATUS_JOIN0;
        };
    }

    fn join0(hash_: field, bet_amount_: u64) -> Final {

        let caller_: address = self.signer;

        let f: Final = credits.aleo::transfer_public_as_signer(self.address, bet_amount_);
    
        return final{
            assert(status.unwrap_or(STATUS_UNSET) == STATUS_JOIN0);

            assert(bet_amount_ > 0u64);

            player0 = caller_;
            hash0 = hash_;
            bet_amount = bet_amount_;

            end_commit = block.height + join_duration.unwrap();

            status = STATUS_JOIN1;

            f.run();
        };
    }

    fn join1(hash_: field, bet_amount_: u64) -> Final {

        let caller_: address = self.signer;

        let f: Final = credits.aleo::transfer_public_as_signer(self.address, bet_amount_);
    
        return final{
            assert(status.unwrap_or(STATUS_UNSET) == STATUS_JOIN1);
            assert(block.height < end_commit.unwrap());
            assert(bet_amount_ == bet_amount.unwrap());
            assert(hash_ != hash0.unwrap());

            player1 = caller_;
            hash1 = hash_;
            end_reveal = block.height + reveal_duration.unwrap();
            
            status = STATUS_REVEAL0;

            f.run();
        };
    }

    fn redeem0_nojoin1(bet_amount_ : u64) -> Final {
        let caller_: address = self.signer;

        let f: Final = credits.aleo::transfer_public(caller_, bet_amount_);

        return final {
            assert(status.unwrap_or(STATUS_UNSET) == STATUS_JOIN1);
            assert(block.height > end_commit.unwrap());
            assert(caller_ == player0.unwrap());
            assert(bet_amount_ == bet_amount.unwrap());

            status = STATUS_END;

            f.run();
        };
    }

    fn reveal0(secret_: field) -> Final{
        let caller_: address = self.signer;

        return final {
            assert(status.unwrap_or(STATUS_UNSET) == STATUS_REVEAL0);
            assert(block.height < end_reveal.unwrap());
            assert(caller_ == player0.unwrap());
            assert(Poseidon2::hash_to_field(secret_) == hash0.unwrap());

            secret0 = secret_;
            status = STATUS_REVEAL1;
        };
    }

    fn redeem1_noreveal0(amount_: u64) -> Final {
        let caller_: address = self.signer;

        let f: Final = credits.aleo::transfer_public(caller_, amount_);

        return final {
            assert(status.unwrap_or(STATUS_UNSET) == STATUS_REVEAL0);
            assert(block.height > end_reveal.unwrap());
            assert(caller_ == player1.unwrap());
            assert(amount_ == bet_amount.unwrap() * 2u64);

            status = STATUS_END;

            f.run();
        };
    }

    fn reveal1(secret_: field) -> Final{
        let caller_: address = self.signer;

        return final {
            assert(status.unwrap_or(STATUS_UNSET) == STATUS_REVEAL1);
            assert(block.height < end_reveal.unwrap());
            assert(caller_ == player1.unwrap());
            assert(Poseidon2::hash_to_field(secret_) == hash1.unwrap());

            secret1 = secret_;
            status = STATUS_WIN;
        };
    }

    fn redeem0_noreveal1(amount_: u64) -> Final {
        let caller_: address = self.signer;

        let f: Final = credits.aleo::transfer_public(caller_, amount_);

        return final {
            assert(status.unwrap_or(STATUS_UNSET) == STATUS_REVEAL1);
            assert(block.height > end_reveal.unwrap());
            assert(caller_ == player0.unwrap());
            assert(amount_ == bet_amount.unwrap() * 2u64);

            status = STATUS_END;

            f.run();
        };
    }


    fn win(winner_: address, amount_: u64) -> Final {
        let f: Final = credits.aleo::transfer_public(winner_, amount_);

        return final {
            assert(status.unwrap_or(STATUS_UNSET) == STATUS_WIN);
            assert(amount_ == bet_amount.unwrap() * 2u64);

            let s0: field = secret0.unwrap();
            let s1: field = secret1.unwrap();
            let winner: address = Poseidon2::hash_to_u8(s0 + s1) % 2u8 == 0u8 ? player0.unwrap() : player1.unwrap();

            assert(winner_ == winner);

            status = STATUS_END;

            f.run();
        };
    }


    fn compute_hash(secret_: field) -> field {
        return Poseidon2::hash_to_field(secret_);
    }
}   