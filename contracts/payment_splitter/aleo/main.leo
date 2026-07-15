import credits.aleo;

program payment_splitter.aleo {

    const MAX_PAYEES: u32 = 10u32;

    mapping shares: address => u64;
    mapping released: address => u64;

    storage total_shares: u64;
    storage total_released: u64;
    storage initialized: bool;

    @noupgrade
    constructor() {}

    fn initialize(payees_: [address; 10], shares_: [u64; 10], count_: u32) -> Final {
        return final {
            assert(initialized.unwrap_or(false) == false);
            assert(count_ > 0u32);
            assert(count_ <= MAX_PAYEES);

            let running_total: u64 = 0u64;

            for i: u32 in 0u32..10u32 {
                
                running_total += i < count_ ? shares_[i] : 0u64;

                if i < count_ {
                    assert(payees_[i] != aleo1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq3ljyzc);
                    assert(shares_[i] > 0u64);
                    assert(Mapping::contains(shares, payees_[i]) == false);
                    Mapping::set(shares, payees_[i], shares_[i]);
                }
            }

            total_shares = running_total;
            total_released = 0u64;
            initialized = true;
        };
    }

    fn receive(amount_: u64) -> Final {
        let f: Final = credits.aleo::transfer_public_as_signer(self.address, amount_);

        return final {
            assert(initialized.unwrap_or(false) == true);
            assert(amount_ > 0u64);

            f.run();
        };
    }

    fn release(account_: address, amount_: u64) -> Final {
        let f: Final = credits.aleo::transfer_public(account_, amount_);

        return final {
            assert(initialized.unwrap_or(false) == true);

            assert(Mapping::contains(shares, account_) == true);

            let bal: u64 = credits.aleo::account.get_or_use(self.address, 0u64);
            let total_rel: u64 = total_released.unwrap_or(0u64);
            let total_received: u64 = bal + total_rel;

            let account_shares: u64 = Mapping::get(shares, account_);
            let account_released: u64 = Mapping::get_or_use(released, account_, 0u64);

            let earned: u64 = total_received * account_shares / total_shares.unwrap();
            let releasable: u64 = earned - account_released;

            assert(amount_ > 0u64);
            assert(amount_ == releasable);

            total_released = total_rel + amount_;
            Mapping::set(released, account_, account_released + amount_);

            f.run();
        };
    }
}