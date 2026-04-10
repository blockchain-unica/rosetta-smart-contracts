import credits.aleo;

program escrow.aleo {

    storage seller: address;
    storage buyer: address;
    storage required_amount: u64;
    storage deposit_done: bool;
    storage pay_or_refund_done :bool;
    
   
    @noupgrade
    async constructor() {}

    async transition initialize(buyer_:address, required_amount_: u64) -> Future{
        return finalize_initialize(self.signer,buyer_,required_amount_);
    }

    async function finalize_initialize(seller_: address, buyer_:address,required_amount_: u64){
        assert(seller.unwrap_or(aleo1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq3ljyzc) == aleo1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq3ljyzc);
        assert(buyer.unwrap_or(aleo1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq3ljyzc) == aleo1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq3ljyzc);
        seller = seller_;
        buyer = buyer_;
        required_amount = required_amount_;
        deposit_done = false;
        pay_or_refund_done = false;
    }

    async transition deposit(amount_: u64) -> Future {
        let f: Future = credits.aleo/transfer_public_as_signer(self.address,amount_);
        return finalize_deposit(f,self.signer,amount_);
    }

    async function finalize_deposit(f: Future, buyer_: address, amount_: u64){
        assert(!deposit_done.unwrap_or(false));
        assert(seller.unwrap_or(aleo1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq3ljyzc) != aleo1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq3ljyzc);
        assert(buyer_ == buyer.unwrap_or(aleo1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq3ljyzc));
        assert(amount_ == required_amount.unwrap_or(0u64));
        f.await();
        deposit_done = true;
    }

    async transition pay(seller_: address,amount_: u64) -> Future {
        let f: Future = credits.aleo/transfer_public(seller_,amount_);
        return finalize_pay(f,self.signer,seller_,amount_);
    }

    async function finalize_pay(f: Future, buyer_: address, seller_:address, amount_: u64){
        assert(deposit_done.unwrap_or(false));
        assert(!pay_or_refund_done.unwrap_or(false));
        assert(buyer_ == buyer.unwrap_or(aleo1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq3ljyzc));
        assert(seller_ == seller.unwrap_or(aleo1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq3ljyzc));
        assert(amount_ == required_amount.unwrap_or(0u64));
        f.await();
        pay_or_refund_done = true;
    }

    async transition refund(buyer_: address,amount_: u64) -> Future {
        let f: Future = credits.aleo/transfer_public(buyer_,amount_);
        return finalize_refund(f,self.signer,buyer_,amount_);
    }

    async function finalize_refund(f: Future, seller_: address, buyer_:address, amount_: u64){
        assert(deposit_done.unwrap_or(false));
        assert(!pay_or_refund_done.unwrap_or(false));
        assert(seller_ == seller.unwrap_or(aleo1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq3ljyzc));
        assert(buyer_ == buyer.unwrap_or(aleo1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq3ljyzc));
        assert(amount_ == required_amount.unwrap_or(0u64));
        f.await();
        pay_or_refund_done = true;
    }
}