import credits.aleo;

program simple_transfer.aleo {

    storage owner: address;
    storage recipient: address;
    storage balance: u64;

    @noupgrade
    constructor() {}

    fn initialize(recipient_: address) -> Final {
        let caller: address = self.signer;
        return final {
            assert(owner.unwrap_or(aleo1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq3ljyzc) == aleo1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq3ljyzc);
            assert(recipient.unwrap_or(aleo1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq3ljyzc) == aleo1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq3ljyzc);
            owner = caller;
            recipient = recipient_;
            balance = 0u64;
        };
    }

    fn deposit(amount_: u64) -> Final {
        let caller: address = self.signer;
        let f: Final = credits.aleo::transfer_public_as_signer(self.address, amount_);
        return final {
            assert(caller == owner.unwrap_or(aleo1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq3ljyzc));
            f.run();
            balance = balance.unwrap_or(0u64) + amount_;
        };
    }

    fn withdraw(amount_: u64) -> Final {
        let caller: address = self.signer;
        let f: Final = credits.aleo::transfer_public(caller, amount_);
        return final {
            assert(caller == recipient.unwrap_or(aleo1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq3ljyzc));
            assert(amount_ > 0u64);
            assert(balance.unwrap_or(0u64) >= amount_);
            f.run();
            balance = balance.unwrap_or(0u64) - amount_;
        };
    }
}