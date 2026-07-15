import token_registry.aleo;

program token_transfer.aleo {

    storage owner: address;
    storage recipient: address;
    storage balance: u128;
    storage token_id: field;

    @noupgrade
    constructor() {}

    fn initialize(recipient_: address, token_id_: field) -> Final {
        let caller: address = self.signer;
        return final {
            assert(owner.unwrap_or(aleo1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq3ljyzc) == aleo1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq3ljyzc);
            assert(recipient.unwrap_or(aleo1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq3ljyzc) == aleo1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq3ljyzc);
            owner = caller;
            recipient = recipient_;
            balance = 0u128;
            token_id = token_id_;
        };
    }

    fn deposit(amount_: u128, token_id_: field) -> Final {
        let caller: address = self.signer;
        let f: Final = token_registry.aleo::transfer_public_as_signer(token_id_, self.address, amount_);
        return final {
            assert(caller == owner.unwrap_or(aleo1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq3ljyzc));
            assert(token_id_ == token_id.unwrap());
            f.run();
            balance = balance.unwrap_or(0u128) + amount_;
        };
    }

    fn withdraw(amount_: u128, token_id_: field) -> Final {
        let caller: address = self.signer;
        let f: Final = token_registry.aleo::transfer_public(token_id_, caller, amount_);
        return final {
            assert(caller == recipient.unwrap_or(aleo1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq3ljyzc));
            assert(amount_ > 0u128);
            assert(token_id_ == token_id.unwrap());
            assert(balance.unwrap_or(0u128) >= amount_);
            f.run();
            balance = balance.unwrap_or(0u128) - amount_;
        };
    }
}