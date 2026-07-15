use starknet::{ContractAddress};

#[starknet::interface]
pub trait IAMM<TContractState> {
    fn deposit(ref self: TContractState, x0: u256, x1: u256);
    fn redeem(ref self: TContractState, x: u256);
    fn swap(ref self: TContractState, t: ContractAddress, x_in: u256, x_out_min: u256);
}

#[starknet::contract]
pub mod AMM {
    use openzeppelin::token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
    use starknet::{ContractAddress, get_caller_address, get_contract_address};
    use starknet::storage::{
        StoragePointerReadAccess, StoragePointerWriteAccess,
        Map, StorageMapReadAccess, StorageMapWriteAccess,
    };
    use super::IAMM;

    #[storage]
    struct Storage {
        t0: ContractAddress,                   // mirrors: IERC20 public immutable t0
        t1: ContractAddress,                   // mirrors: IERC20 public immutable t1
        r0: u256,                              // mirrors: uint public r0
        r1: u256,                              // mirrors: uint public r1
        ever_deposited: bool,                  // mirrors: bool ever_deposited
        supply: u256,                          // mirrors: uint public supply
        minted: Map<ContractAddress, u256>,    // mirrors: mapping(address => uint) public minted
    }

    // ---------------------------------------------------------------------------
    // Errors
    // ---------------------------------------------------------------------------
    mod Errors {
        pub const ZERO_AMOUNT: felt252        = 'amounts must be positive';
        pub const WRONG_RATIO: felt252        = 'must maintain exchange rate';
        pub const ZERO_MINT: felt252          = 'nothing to mint';
        pub const INSUFFICIENT_MINTED: felt252 = 'insufficient liquidity tokens';
        pub const INVALID_TOKEN: felt252      = 'invalid token address';
        pub const SLIPPAGE: felt252           = 'output below minimum';
        pub const TRANSFER_FAILED: felt252    = 'transfer failed';
        pub const BALANCE_MISMATCH: felt252   = 'balance mismatch';
        pub const ZERO_X: felt252             = 'x must be positive';
        pub const SUPPLY_EXCEEDED: felt252    = 'x must be less than supply';
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        t0: ContractAddress,
        t1: ContractAddress,
    ) {
        self.t0.write(t0);
        self.t1.write(t1);
    }

    #[abi(embed_v0)]
    impl AMMImpl of IAMM<ContractState> {

        /// Deposit x0 of t0 and x1 of t1 into the pool.
        /// Mints liquidity tokens proportional to the deposit.
        fn deposit(ref self: ContractState, x0: u256, x1: u256) {
            assert(x0 > 0 && x1 > 0, Errors::ZERO_AMOUNT);

            let caller     = get_caller_address();
            let this       = get_contract_address();
            let t0         = IERC20Dispatcher { contract_address: self.t0.read() };
            let t1         = IERC20Dispatcher { contract_address: self.t1.read() };

            // pull tokens from sender
            let s0 = t0.transfer_from(caller, this, x0);
            assert(s0, Errors::TRANSFER_FAILED);
            let s1 = t1.transfer_from(caller, this, x1);
            assert(s1, Errors::TRANSFER_FAILED);

            let to_mint: u256 = if self.ever_deposited.read() {
                let r0 = self.r0.read();
                let r1 = self.r1.read();
                assert(r0 * x1 == r1 * x0, Errors::WRONG_RATIO);
                (x0 * self.supply.read()) / r0
            } else {
                self.ever_deposited.write(true);
                x0
            };

            assert(to_mint > 0, Errors::ZERO_MINT);

            self.minted.write(caller, self.minted.read(caller) + to_mint);
            self.supply.write(self.supply.read() + to_mint);
            self.r0.write(self.r0.read() + x0);
            self.r1.write(self.r1.read() + x1);

            assert(t0.balance_of(this) == self.r0.read(), Errors::BALANCE_MISMATCH);
            assert(t1.balance_of(this) == self.r1.read(), Errors::BALANCE_MISMATCH);
        }

        /// Redeem x liquidity tokens for proportional amounts of t0 and t1.
        fn redeem(ref self: ContractState, x: u256) {
            let caller = get_caller_address();
            assert(self.minted.read(caller) >= x, Errors::INSUFFICIENT_MINTED);

            assert(x > 0, Errors::ZERO_X);
            assert(x < self.supply.read(), Errors::SUPPLY_EXCEEDED);
            
            let supply = self.supply.read();
            let r0     = self.r0.read();
            let r1     = self.r1.read();

            // mirrors: uint x0 = (x * r0) / supply
            let x0 = (x * r0) / supply;
            let x1 = (x * r1) / supply;

            let this = get_contract_address();
            let t0   = IERC20Dispatcher { contract_address: self.t0.read() };
            let t1   = IERC20Dispatcher { contract_address: self.t1.read() };

            // in Cairo we use transfer (contract is the sender)
            let s0 = t0.transfer(caller, x0);
            assert(s0, Errors::TRANSFER_FAILED);
            let s1 = t1.transfer(caller, x1);
            assert(s1, Errors::TRANSFER_FAILED);

            self.r0.write(r0 - x0);
            self.r1.write(r1 - x1);
            self.supply.write(supply - x);
            self.minted.write(caller, self.minted.read(caller) - x);

            assert(t0.balance_of(this) == self.r0.read(), Errors::BALANCE_MISMATCH);
            assert(t1.balance_of(this) == self.r1.read(), Errors::BALANCE_MISMATCH);
        }

        /// Swap x_in of token t for the other token, receiving at least x_out_min.
        fn swap(ref self: ContractState, t: ContractAddress, x_in: u256, x_out_min: u256) {
            let t0_addr = self.t0.read();
            let t1_addr = self.t1.read();

            assert(t == t0_addr || t == t1_addr, Errors::INVALID_TOKEN);
            assert(x_in > 0, Errors::ZERO_AMOUNT);

            let caller   = get_caller_address();
            let this     = get_contract_address();
            let is_t0    = t == t0_addr;

            let (t_in_addr, t_out_addr, r_in, r_out) = if is_t0 {
                (t0_addr, t1_addr, self.r0.read(), self.r1.read())
            } else {
                (t1_addr, t0_addr, self.r1.read(), self.r0.read())
            };

            let t_in  = IERC20Dispatcher { contract_address: t_in_addr };
            let t_out = IERC20Dispatcher { contract_address: t_out_addr };

            // pull input tokens
            let s_in = t_in.transfer_from(caller, this, x_in);
            assert(s_in, Errors::TRANSFER_FAILED);

            // mirrors: uint x_out = x_in * r_out / (r_in + x_in)
            let x_out = x_in * r_out / (r_in + x_in);

            assert(x_out >= x_out_min, Errors::SLIPPAGE);

            // push output tokens
            let s_out = t_out.transfer(caller, x_out);
            assert(s_out, Errors::TRANSFER_FAILED);

            if is_t0 {
                self.r0.write(self.r0.read() + x_in);
                self.r1.write(self.r1.read() - x_out);
            } else {
                self.r0.write(self.r0.read() - x_out);
                self.r1.write(self.r1.read() + x_in);
            }

            let t0 = IERC20Dispatcher { contract_address: t0_addr };
            let t1 = IERC20Dispatcher { contract_address: t1_addr };
            assert(t0.balance_of(this) == self.r0.read(), Errors::BALANCE_MISMATCH);
            assert(t1.balance_of(this) == self.r1.read(), Errors::BALANCE_MISMATCH);
        }
    }
}