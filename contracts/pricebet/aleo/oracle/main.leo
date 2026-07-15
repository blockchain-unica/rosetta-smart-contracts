interface Oracle {
    storage rate: u64;
}

program oracle_pricebet.aleo : Oracle {
    
    storage rate: u64;

    @noupgrade
    constructor() {}

    fn initialize(initial_rate_: u64) -> Final {
        return final {
            rate = initial_rate_;
        };
    }
}