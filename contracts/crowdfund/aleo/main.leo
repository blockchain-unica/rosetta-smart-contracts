import credits.aleo;

program crowdfund.aleo {

    storage recipient: address;
    storage deadline: u32;
    storage goal: u64;
    mapping donors: address => u64;

    @noupgrade
    constructor() {}


    fn initialize( recipient_: address, deadline_: u32, goal_: u64) -> Final {

        return final {
            assert(recipient.unwrap_or(aleo1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq3ljyzc) == aleo1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq3ljyzc);
            assert(goal_ > 0u64);
            recipient = recipient_;
            deadline = deadline_;
            goal = goal_;
        };
    }

    fn donate(amount_: u64) -> Final {

        let caller_: address = self.signer;

        let f: Final = credits.aleo::transfer_public_as_signer(self.address,amount_);

        return final{
           assert(block.height <= deadline.unwrap_or(0u32));

           f.run();

           donors.set(caller_,amount_ + donors.get_or_use(caller_,0u64));
        };
    }
    
    fn withdraw(amount_: u64) -> Final {

        let caller_: address = self.signer;

        let f: Final = credits.aleo::transfer_public(caller_,amount_);

        return final{
            assert(block.height > deadline.unwrap_or(0u32));

            assert(caller_ == recipient.unwrap_or(aleo1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq3ljyzc));

            let bal: u64 = credits.aleo::account.get_or_use(self.address, 0u64);

            assert(bal >= goal.unwrap());

            assert(amount_ == bal);

            f.run();
        };
    }


    fn reclaim(amount_: u64) -> Final {

        let caller_: address = self.signer;

        let f: Final = credits.aleo::transfer_public(caller_,amount_);

        return final{
            assert(block.height > deadline.unwrap_or(0u32));

            let bal: u64 = credits.aleo::account.get_or_use(self.address, 0u64);

            assert(bal < goal.unwrap());

            let donation: u64 = donors.get_or_use(caller_,0u64) ;

            assert(donation > 0u64);

            assert(amount_ == donation);

            f.run();

            donors.set(caller_,0u64);
        };
    }
}