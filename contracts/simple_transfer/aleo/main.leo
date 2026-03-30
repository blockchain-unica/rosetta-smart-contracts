
import credits.aleo;

program simple_transfer.aleo {

    storage owner: address;
    storage recipient: address;
    storage balance: u64;
    
   
    @noupgrade
    async constructor() {}

    async transition initialize(recipient_:address) -> Future{
        return finalize_initialize(self.signer,recipient_);
    }

    async function finalize_initialize(owner_: address, recipient_:address){
        assert(owner.unwrap_or(aleo1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq3ljyzc) == aleo1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq3ljyzc);
        assert(recipient.unwrap_or(aleo1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq3ljyzc) == aleo1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq3ljyzc);
        owner = owner_;
        recipient = recipient_;
        balance = 0u64;
    }

    async transition deposit(amount_: u64) -> Future {
        let f: Future = credits.aleo/transfer_public_as_signer(self.address,amount_);
        return finalize_deposit(f,self.signer,amount_);
    }

    async function finalize_deposit(f: Future, owner_: address, amount_: u64){
        assert(owner_ == owner.unwrap_or(aleo1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq3ljyzc));
        f.await();
        balance = balance.unwrap_or(0) + amount_;
    }

    async transition withdraw(amount_: u64) -> Future {
        let f: Future = credits.aleo/transfer_public(self.signer,amount_);
        return finalize_withdraw(f,self.signer,amount_);
    }

    async function finalize_withdraw(f: Future, recipient_: address, amount_: u64){
        assert(recipient_ == recipient.unwrap_or(aleo1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq3ljyzc));
        assert(amount_ > 0);
        assert(balance.unwrap_or(0) >= amount_);
        f.await();
        balance = balance.unwrap_or(0) - amount_;
    }
}
