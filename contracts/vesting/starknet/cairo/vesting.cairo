use starknet::{ContractAddress};

#[starknet::interface]
pub trait IVesting<TContractState> {
    fn release(ref self: TContractState);
    fn releasable(self: @TContractState) -> u256;
    fn vested_amount(self: @TContractState) -> u256;
}

#[starknet::contract]
pub mod Vesting {
    use openzeppelin::token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
    use starknet::{ContractAddress, get_caller_address, get_contract_address, get_block_info};
    use starknet::storage::{StoragePointerReadAccess, StoragePointerWriteAccess};
    use super::IVesting;

    #[storage]
    struct Storage {
        beneficiary: ContractAddress,
        start: u64,       // block number from which vesting begins
        duration: u64,    // duration in blocks
        released: u256,   // total already released to beneficiary
        token: ContractAddress,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        Released: Released,
    }

    #[derive(Drop, starknet::Event)]
    struct Released {
        #[key]
        beneficiary: ContractAddress,
        amount: u256,
    }

   mod Errors {
        pub const ZERO_BENEFICIARY: felt252  = 'beneficiary is zero address';
        pub const ONLY_BENEFICIARY: felt252  = 'only the beneficiary';
        pub const NOTHING_TO_RELEASE: felt252 = 'nothing to release';
        pub const TRANSFER_FAILED: felt252   = 'transfer failed';
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        beneficiary: ContractAddress,
        start: u64,
        duration: u64,
        initial_amount: u256,
        token: ContractAddress,
    ) {
        assert(
            beneficiary != starknet::contract_address_const::<0>(),
            Errors::ZERO_BENEFICIARY
        );

        self.beneficiary.write(beneficiary);
        self.start.write(start);
        self.duration.write(duration);
        self.token.write(token);

        // deposit initial balance at creation — deployer must approve first
        if initial_amount > 0 {
            let token_dispatcher = IERC20Dispatcher { contract_address: token };
            let success = token_dispatcher.transfer_from(
                get_caller_address(),
                get_contract_address(),
                initial_amount
            );
            assert(success, Errors::TRANSFER_FAILED);
        }
    }

    #[abi(embed_v0)]
    impl VestingImpl of IVesting<ContractState> {

        fn release(ref self: ContractState) {
            assert(get_caller_address() == self.beneficiary.read(), Errors::ONLY_BENEFICIARY);

            let amount = Self::releasable(@self);
            assert(amount > 0, Errors::NOTHING_TO_RELEASE);

            // update released BEFORE transfer — CEI pattern
            self.released.write(self.released.read() + amount);

            let token   = IERC20Dispatcher { contract_address: self.token.read() };
            let success = token.transfer(self.beneficiary.read(), amount);
            assert(success, Errors::TRANSFER_FAILED);

            self.emit(Released { beneficiary: self.beneficiary.read(), amount });
        }

        fn releasable(self: @ContractState) -> u256 {
            Self::vested_amount(self) - self.released.read()
        }

        /// uses block_number instead of timestamp — Starknet equivalent
        fn vested_amount(self: @ContractState) -> u256 {
            let token    = IERC20Dispatcher { contract_address: self.token.read() };
            let balance  = token.balance_of(get_contract_address());
            let total    = balance + self.released.read();

            // mirrors: _vestingSchedule(address(this).balance + _released, timestamp)
            let current_block = get_block_info().unbox().block_number;
            let start         = self.start.read();
            let duration      = self.duration.read();

            if current_block < start {
                0
            } else if current_block > start + duration {
                total
            } else {
                let elapsed: u256 = (current_block - start).into();
                (total * elapsed) / duration.into()
            }
        }
    }
}
