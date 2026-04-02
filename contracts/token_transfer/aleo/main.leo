
import token_registry.aleo;

program token_transfer.aleo {

    storage owner: address;
    storage recipient: address;
    storage balance: u128;
    storage token_id: field;
    
   
    @noupgrade
    async constructor() {}

    async transition initialize(recipient_:address, token_id_: field) -> Future{
        return finalize_initialize(self.signer,recipient_,token_id_);
    }

    async function finalize_initialize(owner_: address, recipient_:address, token_id_: field){
        assert(owner.unwrap_or(aleo1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq3ljyzc) == aleo1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq3ljyzc);
        assert(recipient.unwrap_or(aleo1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq3ljyzc) == aleo1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq3ljyzc);
        owner = owner_;
        recipient = recipient_;
        balance = 0u128;
        token_id = token_id_;
    }

    async transition deposit(amount_: u128, token_id_: field) -> Future {
        let f: Future = token_registry.aleo/transfer_public_as_signer(token_id_,self.address,amount_);
        return finalize_deposit(f,self.signer,amount_,token_id_);
    }

    async function finalize_deposit(f: Future, owner_: address, amount_: u128, token_id_: field){
        assert(owner_ == owner.unwrap_or(aleo1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq3ljyzc));
        assert(token_id_ == token_id.unwrap());
        f.await();
        balance = balance.unwrap_or(0u128) + amount_;
    }

    async transition withdraw(amount_: u128, token_id_: field) -> Future {
        let f: Future = token_registry.aleo/transfer_public(token_id_,self.signer,amount_);
        return finalize_withdraw(f,self.signer,amount_,token_id_);
    }

    async function finalize_withdraw(f: Future, recipient_: address, amount_: u128, token_id_: field){
        assert(recipient_ == recipient.unwrap_or(aleo1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq3ljyzc));
        assert(amount_ > 0u128);
        assert(token_id_ == token_id.unwrap());
        assert(balance.unwrap_or(0u128) >= amount_);
        f.await();
        balance = balance.unwrap_or(0u128) - amount_;
    }
}
