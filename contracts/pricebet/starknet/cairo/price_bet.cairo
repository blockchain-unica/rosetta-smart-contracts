use starknet::{ContractAddress};

#[starknet::interface]
pub trait IPriceBet<TContractState> {
    fn join(ref self: TContractState, amount: u256);
    fn win(ref self: TContractState);
    fn timeout(ref self: TContractState);
}

#[starknet::contract]
pub mod PriceBet {
    use openzeppelin::token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
    use starknet::{ContractAddress, get_caller_address, get_contract_address, get_block_info};
    use starknet::storage::{StoragePointerReadAccess, StoragePointerWriteAccess};
    use super::IPriceBet;

    // oracle interface — mirrors: Oracle TheOracle = Oracle(oracle)
    use price_bet::oracle::IOracleDispatcher;
    use price_bet::oracle::IOracleDispatcherTrait;

    #[storage]
    struct Storage {
        owner: ContractAddress,
        player: ContractAddress,       // zero address means no player yet
        oracle: ContractAddress,
        token: ContractAddress,
        initial_pot: u256,
        deadline_block: u64,
        exchange_rate: u256,
    }

    mod Errors {
        pub const WRONG_AMOUNT: felt252      = 'amount must equal initial pot';
        pub const ALREADY_JOINED: felt252    = 'player already joined';
        pub const NO_PLAYER: felt252         = 'no player has joined';
        pub const ONLY_PLAYER: felt252       = 'only the player can win';
        pub const DEADLINE_EXPIRED: felt252  = 'deadline expired';
        pub const DEADLINE_NOT_EXPIRED: felt252 = 'deadline not expired';
        pub const YOU_LOST: felt252          = 'you lost the bet';
        pub const TRANSFER_FAILED: felt252   = 'transfer failed';
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        oracle: ContractAddress,
        deadline: u64,
        exchange_rate: u256,
        initial_pot: u256,
        token: ContractAddress,
    ) {
        let owner         = get_caller_address();
        let current_block = get_block_info().unbox().block_number;

        self.owner.write(owner);
        self.oracle.write(oracle);
        self.token.write(token);
        self.initial_pot.write(initial_pot);
        self.deadline_block.write(current_block + deadline);
        self.exchange_rate.write(exchange_rate);

        let token_dispatcher = IERC20Dispatcher { contract_address: token };
        let success = token_dispatcher.transfer_from(owner, get_contract_address(), initial_pot);
        assert(success, Errors::TRANSFER_FAILED);
    }

    #[abi(embed_v0)]
    impl PriceBetImpl of IPriceBet<ContractState> {

        /// Player joins by depositing exactly initial_pot tokens.
        fn join(ref self: ContractState, amount: u256) {
            let caller = get_caller_address();

            assert(
                self.player.read() == starknet::contract_address_const::<0>(),
                Errors::ALREADY_JOINED
            );

            assert(amount == self.initial_pot.read(), Errors::WRONG_AMOUNT);
            let token  = IERC20Dispatcher { contract_address: self.token.read() };

            // player must approve(contract, initial_pot) before calling join
            let success = token.transfer_from(caller, get_contract_address(), amount);
            assert(success, Errors::TRANSFER_FAILED);

            self.player.write(caller);
        }

        /// Player wins if oracle rate >= bet rate before deadline.
        fn win(ref self: ContractState) {
            let oracle_rate = IOracleDispatcher { contract_address: self.oracle.read() }
                .get_exchange_rate();

            let caller        = get_caller_address();
            let current_block = get_block_info().unbox().block_number;

            assert(current_block < self.deadline_block.read(), Errors::DEADLINE_EXPIRED);
            assert(caller == self.player.read(), Errors::ONLY_PLAYER);

            
            assert(oracle_rate >= self.exchange_rate.read(), Errors::YOU_LOST);

            let token   = IERC20Dispatcher { contract_address: self.token.read() };
            let balance = token.balance_of(get_contract_address());
            let success = token.transfer(self.player.read(), balance);
            assert(success, Errors::TRANSFER_FAILED);

        }

        /// After deadline, owner redeems the whole pot.
        fn timeout(ref self: ContractState) {
            let current_block = get_block_info().unbox().block_number;
            assert(current_block >= self.deadline_block.read(), Errors::DEADLINE_NOT_EXPIRED);

            let token   = IERC20Dispatcher { contract_address: self.token.read() };
            let balance = token.balance_of(get_contract_address());
            let success = token.transfer(self.owner.read(), balance);
            assert(success, Errors::TRANSFER_FAILED);

        }
    }
}