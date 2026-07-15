use starknet::{ContractAddress};

#[starknet::interface]
pub trait ICrowdfund<TContractState> {
    fn donate(ref self: TContractState, amount: u256);
    fn withdraw(ref self: TContractState);
    fn reclaim(ref self: TContractState);
}

#[starknet::contract]
pub mod Crowdfund {
    use openzeppelin::token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
    use starknet::{ContractAddress, get_caller_address, get_contract_address, get_block_info};
    use starknet::storage::{
        StoragePointerReadAccess, StoragePointerWriteAccess,
        Map, StorageMapReadAccess, StorageMapWriteAccess,
    };
    use super::ICrowdfund;

    #[storage]
    struct Storage {
        receiver: ContractAddress,
        goal: u256,
        end_block: u64,
        token: ContractAddress,
        donors: Map<ContractAddress, u256>,
    }

    mod Errors {
        pub const DEADLINE_NOT_REACHED: felt252  = 'deadline not reached';
        pub const DEADLINE_PASSED: felt252       = 'deadline has passed';
        pub const GOAL_NOT_REACHED: felt252      = 'goal not reached';
        pub const GOAL_REACHED: felt252          = 'goal was reached';
        pub const NOTHING_TO_RECLAIM: felt252    = 'nothing to reclaim';
        pub const ONLY_RECEIVER: felt252         = 'only the receiver';
        pub const TRANSFER_FAILED: felt252       = 'transfer failed';
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        receiver: ContractAddress,
        end_block: u64,
        goal: u256,
        token: ContractAddress,
    ) {
        self.receiver.write(receiver);
        self.end_block.write(end_block);
        self.goal.write(goal);
        self.token.write(token);
    }

    #[abi(embed_v0)]
    impl CrowdfundImpl of ICrowdfund<ContractState> {

        fn donate(ref self: ContractState, amount: u256) {
            let current_block = get_block_info().unbox().block_number;
            assert(current_block <= self.end_block.read(), Errors::DEADLINE_PASSED);

            let caller  = get_caller_address();
            let token   = IERC20Dispatcher { contract_address: self.token.read() };
            let success = token.transfer_from(caller, get_contract_address(), amount);
            assert(success, Errors::TRANSFER_FAILED);

            let prev = self.donors.read(caller);
            self.donors.write(caller, prev + amount);
        }

        fn withdraw(ref self: ContractState) {
            assert(
                get_caller_address() == self.receiver.read(),
                Errors::ONLY_RECEIVER
            );

            let current_block = get_block_info().unbox().block_number;
            assert(current_block >= self.end_block.read(), Errors::DEADLINE_NOT_REACHED);

            let token   = IERC20Dispatcher { contract_address: self.token.read() };
            let balance = token.balance_of(get_contract_address());
            assert(balance >= self.goal.read(), Errors::GOAL_NOT_REACHED);

            let success = token.transfer(self.receiver.read(), balance);
            assert(success, Errors::TRANSFER_FAILED);
        }

        fn reclaim(ref self: ContractState) {
            let current_block = get_block_info().unbox().block_number;
            assert(current_block >= self.end_block.read(), Errors::DEADLINE_NOT_REACHED);

            let token   = IERC20Dispatcher { contract_address: self.token.read() };
            let balance = token.balance_of(get_contract_address());
            assert(balance < self.goal.read(), Errors::GOAL_REACHED);

            let caller = get_caller_address();
            let amount = self.donors.read(caller);
            assert(amount > 0, Errors::NOTHING_TO_RECLAIM);

            self.donors.write(caller, 0);

            let success = token.transfer(caller, amount);
            assert(success, Errors::TRANSFER_FAILED);

        }
    }
}
