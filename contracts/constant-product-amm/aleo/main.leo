import token_registry.aleo;

program constant_product_amm.aleo {

    storage t0: field;
    storage t1: field;
    storage r0: u128;
    storage r1: u128;
    storage total_liquidity: u64;
    storage initialized: bool;

    mapping liquidity_balance: address => u64;

    @noupgrade
    constructor() {}

    fn initialize(t0_: field, t1_: field) -> Final{

        return final{
            assert(initialized.unwrap_or(false) == false);
            assert(t0_ != t1_);

            t0 = t0_;
            t1 = t1_;
            initialized = true;
        };
    }
   

    fn deposit(t0_: field, t1_: field, x0_: u128, x1_: u128) -> Final {

        let caller: address = self.signer;
        let f0: Final = token_registry.aleo::transfer_public_as_signer(t0_, self.address, x0_);
        let f1: Final = token_registry.aleo::transfer_public_as_signer(t1_, self.address, x1_);

        return final {
            assert(initialized.unwrap_or(false) != false);
            assert(t0_ == t0.unwrap());
            assert(t1_ == t1.unwrap());
            assert(x0_ > 0u128);
            assert(x1_ > 0u128);

            assert(total_liquidity.unwrap_or(0u64) == 0u64 ? true : (x0_ as u128) * (r1.unwrap_or(0u128) as u128) == (x1_ as u128) * (r0.unwrap_or(0u128) as u128));
        
            let liquidity_minted: u64 = total_liquidity.unwrap_or(0u64) == 0u64 ? (x0_ as u64) : (x0_ * (total_liquidity.unwrap_or(0u64) as u128) / (r0.unwrap_or(0u128) as u128)) as u64;

            assert(liquidity_minted > 0u64);

            r0 = r0.unwrap_or(0u128) + x0_;
            r1 = r1.unwrap_or(0u128) + x1_;
            total_liquidity = total_liquidity.unwrap_or(0u64) + liquidity_minted;
            liquidity_balance.set(caller,liquidity_balance.get_or_use(caller,0u64) + liquidity_minted);

            f0.run();
            f1.run();
        };
    }

    fn redeem(t0_: field, t1_: field, x0_: u128, x1_: u128,x_: u64) -> Final {

        let caller: address = self.signer;
        let f0: Final = token_registry.aleo::transfer_public(t0_,caller, x0_);
        let f1: Final = token_registry.aleo::transfer_public(t1_,caller, x1_);

        return final {
            assert(initialized.unwrap_or(false) != false);
            assert(t0_ == t0.unwrap());
            assert(t1_ == t1.unwrap());
            assert(x0_ > 0u128);
            assert(x1_ > 0u128);
            assert(x_ > 0u64);
            assert(x_ < total_liquidity.unwrap_or(0u64));
            assert(liquidity_balance.get_or_use(caller,0u64) >= x_);
            assert(x0_ == (x_ as u128) * r0.unwrap_or(0u128) / (total_liquidity.unwrap_or(0u64) as u128));
            assert(x1_ == (x_ as u128) * r1.unwrap_or(0u128) / (total_liquidity.unwrap_or(0u64) as u128));

            r0 = r0.unwrap_or(0u128) - x0_;
            r1 = r1.unwrap_or(0u128) - x1_;
            total_liquidity = total_liquidity.unwrap_or(0u64) - x_;
            liquidity_balance.set(caller,liquidity_balance.get_or_use(caller,0u64) - x_);

            f0.run();
            f1.run();
        };
    }

    fn swap(t0_: field, t1_: field,token_in_: field, x0_: u128, x1_: u128,min_amount_out_: u128) -> Final {

        let caller: address = self.signer;
        
        let is_t0_in: bool = token_in_ == t0_;
        let token_out_: field = is_t0_in ? t1_ : t0_;

        let f0: Final = token_registry.aleo::transfer_public_as_signer(token_in_, self.address, x0_);
        let f1: Final = token_registry.aleo::transfer_public(token_out_, caller, x1_);

        return final {
            assert(initialized.unwrap_or(false) != false);
            assert(t0_ == t0.unwrap());
            assert(t1_ == t1.unwrap());
            assert(token_in_ == t0_ || token_in_ == t1_);
            assert(x0_ > 0u128);
            assert(x1_ > 0u128);
            
            let r_in: u128 = token_in_ == t0_ ? r0.unwrap_or(0u128) : r1.unwrap_or(0u128);
            let r_out: u128 = token_in_ == t0_ ? r1.unwrap_or(0u128) : r0.unwrap_or(0u128);
            
            assert(x1_ == r_out * x0_ / (r_in + x0_));

            assert(x1_ >= min_amount_out_);

            r0 = token_in_ == t0_ ? r0.unwrap_or(0u128) + x0_ : r0.unwrap_or(0u128) - x1_;
            r1 = token_in_ == t0_ ? r1.unwrap_or(0u128) - x1_ : r1.unwrap_or(0u128) + x0_;

            f0.run();
            f1.run();
        };
    }
}
