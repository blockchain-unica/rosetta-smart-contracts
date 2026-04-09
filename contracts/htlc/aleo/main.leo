import credits.aleo;

program htlc.aleo {

    storage owner: address;
    storage verifier: address;
    storage hash: field;
    storage deadline: u32;
    storage collateral: u64;

    @noupgrade
    async constructor() {}

    async transition initialize(collateral_: u64, delay_: u32, verifier_: address, hash_: field) -> Future {
        let f: Future = credits.aleo/transfer_public_as_signer(self.address,collateral_);
        return finalize_initialize(f,self.signer,delay_,verifier_,hash_,collateral_);
    }

    async function finalize_initialize (f: Future, owner_:address, delay_: u32, verifier_: address, hash_: field, collateral_: u64) {
        assert(owner.unwrap_or(aleo1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq3ljyzc) == aleo1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq3ljyzc);
        assert(verifier.unwrap_or(aleo1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq3ljyzc) == aleo1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq3ljyzc);
        f.await();
        owner = owner_;
        verifier = verifier_;
        hash = hash_;
        deadline = block.height + delay_;
        collateral = collateral_;
    }

    async transition reveal(secret: [u8; 32], collateral_: u64) -> Future {

        let computed_hash: field = Keccak256::hash_to_field_raw(secret);

        let f: Future = credits.aleo/transfer_public(self.signer,collateral_);

        return finalize_reveal(f,self.signer,computed_hash,collateral_);
    }

    async function finalize_reveal (f: Future, owner_:address, computed_hash_: field, collateral_: u64) {
        assert(owner.unwrap_or(aleo1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq3ljyzc) == owner_);
        assert(block.height <= deadline.unwrap());
        assert(collateral.unwrap_or(0) == collateral_);

        assert(computed_hash_ == hash.unwrap());

        f.await();
    }   

    async transition timeout(collateral_: u64, verifier_: address) -> Future {
        
        let f: Future = credits.aleo/transfer_public(verifier_,collateral_);

        return finalize_timeout(f,verifier_,collateral_);
    }

    async function finalize_timeout (f: Future, verifier_:address, collateral_: u64) {
        assert(owner.unwrap_or(aleo1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq3ljyzc) != aleo1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq3ljyzc);
        assert(block.height > deadline.unwrap());
        assert(collateral.unwrap_or(0) == collateral_);
        assert(verifier.unwrap_or(aleo1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq3ljyzc) == verifier_);

        f.await();
    }   


}
