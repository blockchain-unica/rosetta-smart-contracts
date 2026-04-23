import credits.aleo;

program vesting.aleo {
    
    const STEP_SIZE: u32 = 15u32;

    storage beneficiary: address;
    storage start: u32;
    storage duration: u32;
    storage already_released: u64;


    @noupgrade
    constructor() {}


    fn initialize(beneficiary_: address, start_: u32, duration_: u32, initial_balance_: u64) -> Final {

        let f: Final = credits.aleo::transfer_public_as_signer(self.address, initial_balance_);

        return final {
            assert(beneficiary.unwrap_or(aleo1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq3ljyzc) == aleo1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq3ljyzc);
            assert(beneficiary_ != aleo1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq3ljyzc);
            assert(start_ > 0u32);
            assert(duration_ >= STEP_SIZE);
            assert(initial_balance_ > 0u64);
            beneficiary = beneficiary_;
            start = start_;
            duration = duration_;

            f.run();
        };
    }

    fn release(amount_: u64) -> Final {

        let caller_: address = self.signer;

        let f: Final = credits.aleo::transfer_public(caller_, amount_);

        return final {
            assert(beneficiary.unwrap_or(aleo1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq3ljyzc) != aleo1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq3ljyzc);
            assert(caller_ == beneficiary.unwrap());

            let bal: u64 = credits.aleo::account.get_or_use(self.address, 0u64);
            let total_allocation: u64 = bal + already_released.unwrap_or(0u64);

            let elapsed: u32 = block.height.sub_wrapped(start.unwrap());
            let steps_elapsed: u64 = (elapsed / STEP_SIZE) as u64;
            let total_steps: u64 = (duration.unwrap() / STEP_SIZE) as u64;

            let vested: u64 = block.height < start.unwrap() ? 0u64 : (block.height > start.unwrap() + duration.unwrap() ? total_allocation : total_allocation * steps_elapsed / total_steps);

            let releasable: u64 = vested - already_released.unwrap_or(0u64);

            assert(releasable > 0u64);
            assert(amount_ == releasable);

            already_released = already_released.unwrap_or(0u64) + releasable;

            f.run();
        };
    }

    
}