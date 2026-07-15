import credits.aleo;

program htlc.aleo {

    storage owner: address;
    storage verifier: address;
    storage hash: field;
    storage deadline: u32;
    storage collateral: u64;

    @noupgrade
    constructor() {}

    fn initialize(collateral_: u64, delay_: u32, verifier_: address, hash_: field) -> Final {
        let caller: address = self.signer;
        let f: Final = credits.aleo::transfer_public_as_signer(self.address, collateral_);
        return final {
            assert(owner.unwrap_or(aleo1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq3ljyzc) == aleo1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq3ljyzc);
            assert(verifier.unwrap_or(aleo1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq3ljyzc) == aleo1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq3ljyzc);
            f.run();
            owner = caller;
            verifier = verifier_;
            hash = hash_;
            deadline = block.height + delay_;
            collateral = collateral_;
        };
    }

    fn reveal(secret: [u8; 32], collateral_: u64) -> Final {
        let caller: address = self.signer;
        let computed_hash: field = Keccak256::hash_to_field_raw(secret);
        let f: Final = credits.aleo::transfer_public(caller, collateral_);
        return final {
            assert(owner.unwrap_or(aleo1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq3ljyzc) == caller);
            assert(block.height <= deadline.unwrap());
            assert(collateral.unwrap_or(0u64) == collateral_);
            assert(computed_hash == hash.unwrap());
            f.run();
        };
    }

    fn timeout(collateral_: u64, verifier_: address) -> Final {
        let f: Final = credits.aleo::transfer_public(verifier_, collateral_);
        return final {
            assert(owner.unwrap_or(aleo1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq3ljyzc) != aleo1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq3ljyzc);
            assert(block.height > deadline.unwrap());
            assert(collateral.unwrap_or(0u64) == collateral_);
            assert(verifier.unwrap_or(aleo1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq3ljyzc) == verifier_);
            f.run();
        };
    }
}