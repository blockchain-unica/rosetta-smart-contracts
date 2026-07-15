import credits.aleo;

program auction.aleo {

    storage seller: address;
    storage deadline: u32;
    storage object: [u8; 64];
    mapping bids: address => u64;
    storage highest_bidder: address;
    storage highest_bid: u64;
    storage starting_bid: u64;

    @noupgrade
    constructor() {}


    fn initialize(starting_bid_: u64,object_: [u8; 64]) -> Final {

        let seller_:address = self.signer;

        return final {
            assert(seller.unwrap_or(aleo1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq3ljyzc) == aleo1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq3ljyzc);
            assert(highest_bid.unwrap_or(0u64) == 0u64);
            assert(starting_bid_ > 0u64);
            seller = seller_;
            starting_bid = starting_bid_;
            highest_bid = 0u64;
            highest_bidder = aleo1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq3ljyzc;
            object = object_;
        };
    }

    fn start(duration_: u32) -> Final {

        let caller_: address = self.signer;

        return final{
            assert(seller.unwrap_or(aleo1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq3ljyzc) != aleo1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq3ljyzc);
            assert(deadline.unwrap_or(0u32) == 0u32); 
            assert(seller.unwrap() == caller_);
            assert(duration_ > 0u32);
            deadline = block.height + duration_;
        };
    }
    
    fn bid(bid_amount_: u64) -> Final {

        let caller_: address = self.signer;

        let f: Final = credits.aleo::transfer_public_as_signer(self.address,bid_amount_);

        return final{
            assert(deadline.unwrap_or(0u32) != 0u32);
            assert(block.height <= deadline.unwrap_or(0u32));
            assert(bids.get_or_use(caller_, 0u64) == 0u64); /* obblighiamo il withdraw */
            assert(bid_amount_ > starting_bid.unwrap_or(0u64));
            assert(bid_amount_ > highest_bid.unwrap_or(0u64));

            if(highest_bidder.unwrap_or(aleo1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq3ljyzc) != aleo1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq3ljyzc){
                bids.set(highest_bidder.unwrap(), highest_bid.unwrap());
            }

            highest_bidder = caller_;
            highest_bid = bid_amount_;

            f.run();
        };
    }

    fn withdraw(bid_amount_: u64) -> Final {
        let caller_: address = self.signer;

        let f: Final = credits.aleo::transfer_public(self.signer,bid_amount_);

        return final{
            assert(caller_ != highest_bidder.unwrap_or(aleo1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq3ljyzc));
            assert(bids.get_or_use(caller_, 0u64) > 0u64);
            assert(bids.get(caller_)  == bid_amount_);
            
            f.run();
            
            bids.remove(caller_);
        };
    }

    fn end(bid_amount_: u64) -> Final {
        let caller_: address = self.signer;

        let f: Final = credits.aleo::transfer_public(self.signer,bid_amount_);

        return final{
            assert(caller_ == seller.unwrap_or(aleo1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq3ljyzc));
            assert(deadline.unwrap_or(0u32) != 0u32);
            assert(block.height > deadline.unwrap());
            assert(bid_amount_ == highest_bid.unwrap_or(0u64));

            f.run();

            deadline = 0u32;
            highest_bid = 0u64;
            highest_bidder = aleo1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq3ljyzc;
        };
    }
}