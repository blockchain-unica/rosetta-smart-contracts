import credits.aleo;

program escrow.aleo {

    storage seller: address;
    storage buyer: address;
    storage required_amount: u64;
    storage deposit_done: bool;
    storage pay_or_refund_done: bool;

    @noupgrade
    constructor() {}

    fn initialize(buyer_: address, required_amount_: u64) -> Final {
        let caller: address = self.signer;
        return final {
            assert(seller.unwrap_or(aleo1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq3ljyzc) == aleo1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq3ljyzc);
            assert(buyer.unwrap_or(aleo1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq3ljyzc) == aleo1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq3ljyzc);
            seller = caller;
            buyer = buyer_;
            required_amount = required_amount_;
            deposit_done = false;
            pay_or_refund_done = false;
        };
    }

    fn deposit(amount_: u64) -> Final {
        let caller: address = self.signer;
        let f: Final = credits.aleo::transfer_public_as_signer(self.address, amount_);
        return final {
            assert(!deposit_done.unwrap_or(false));
            assert(seller.unwrap_or(aleo1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq3ljyzc) != aleo1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq3ljyzc);
            assert(caller == buyer.unwrap_or(aleo1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq3ljyzc));
            assert(amount_ == required_amount.unwrap_or(0u64));
            f.run();
            deposit_done = true;
        };
    }

    fn pay(seller_: address, amount_: u64) -> Final {
        let caller: address = self.signer;
        let f: Final = credits.aleo::transfer_public(seller_, amount_);
        return final {
            assert(deposit_done.unwrap_or(false));
            assert(!pay_or_refund_done.unwrap_or(false));
            assert(caller == buyer.unwrap_or(aleo1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq3ljyzc));
            assert(seller_ == seller.unwrap_or(aleo1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq3ljyzc));
            assert(amount_ == required_amount.unwrap_or(0u64));
            f.run();
            pay_or_refund_done = true;
        };
    }

    fn refund(buyer_: address, amount_: u64) -> Final {
        let caller: address = self.signer;
        let f: Final = credits.aleo::transfer_public(buyer_, amount_);
        return final {
            assert(deposit_done.unwrap_or(false));
            assert(!pay_or_refund_done.unwrap_or(false));
            assert(caller == seller.unwrap_or(aleo1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq3ljyzc));
            assert(buyer_ == buyer.unwrap_or(aleo1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq3ljyzc));
            assert(amount_ == required_amount.unwrap_or(0u64));
            f.run();
            pay_or_refund_done = true;
        };
    }
}