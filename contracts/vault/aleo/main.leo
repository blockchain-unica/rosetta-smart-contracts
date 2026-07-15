import credits.aleo;

program vault.aleo {

    storage owner: address;
    storage recovery: address;
    storage wait_time: u32;

    storage receiver: address;
    storage desired_amount: u64;
    storage request_time: u32;

    @noupgrade
    constructor() {}


    fn initialize(recovery_: address, wait_time_: u32) -> Final {

        let caller_: address = self.signer;

        return final {
            assert(owner.unwrap_or(aleo1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq3ljyzc) == aleo1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq3ljyzc);
            assert(recovery_ != aleo1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq3ljyzc);
            assert(wait_time_ > 0u32);
            owner = caller_;
            recovery = recovery_;
            wait_time = wait_time_;
        };
    }

    fn receive(amount_: u64) -> Final {

        let f: Final = credits.aleo::transfer_public_as_signer(self.address,amount_);

        return final{
            
            assert(recovery.unwrap_or(aleo1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq3ljyzc) != aleo1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq3ljyzc);

            f.run();
        };
    }
    
    fn withdraw(receiver_:address, desired_amount_: u64) -> Final {

        let caller_: address = self.signer;

        return final{
            assert(caller_ == owner.unwrap());
            assert(request_time.unwrap_or(0u32) == 0u32);
            assert(receiver_ != aleo1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq3ljyzc);
            
            let bal: u64 = credits.aleo::account.get_or_use(self.address, 0u64);
            assert(desired_amount_ <= bal);

            receiver =  receiver_;
            desired_amount = desired_amount_;
            request_time = block.height;
        };
    }


    fn finalize_withdraw(receiver_:address, amount_: u64) -> Final {

        let caller_: address = self.signer;

        let f: Final = credits.aleo::transfer_public(receiver_,amount_);

        return final{
            assert(caller_ == owner.unwrap_or(aleo1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq3ljyzc));

            assert(request_time.unwrap() != 0u32);

            assert(block.height > request_time.unwrap() + wait_time.unwrap());

            assert(receiver_ == receiver.unwrap_or(aleo1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq3ljyzc));

            assert(amount_ == desired_amount.unwrap());

            f.run();

            request_time = 0u32;

        };
    }

    fn cancel() -> Final {

        let caller_: address = self.signer;

        return final {
            assert(caller_ == recovery.unwrap_or(aleo1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq3ljyzc));

            assert(request_time.unwrap() != 0u32);

            assert(block.height <= request_time.unwrap() + wait_time.unwrap());

            request_time = 0u32;
        };
    }
}