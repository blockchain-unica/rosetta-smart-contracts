use starknet::ContractAddress;
use core::byte_array::ByteArray;

#[starknet::interface]
pub trait IHTLC<TContractState> {
    fn reveal(ref self: TContractState, secret: ByteArray);
    fn timeout(ref self: TContractState);
}

#[starknet::contract]
pub mod HTLC {
    use openzeppelin::token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
    use starknet::{ContractAddress, get_caller_address, get_contract_address, get_block_info};
    use starknet::storage::{StoragePointerReadAccess, StoragePointerWriteAccess};
    use core::byte_array::ByteArray;
    use core::keccak::compute_keccak_byte_array;
    use super::IHTLC;

    #[storage]
    struct Storage {
        owner: ContractAddress,       // committer
        receiver: ContractAddress,    // gets funds if timeout
        token: ContractAddress,       // ERC20 collateral token
        hash: u256,                // Poseidon hash of the secret
        reveal_timeout: u64,          // block number deadline
    }

    // ---------------------------------------------------------------------------
    // Errors
    // ---------------------------------------------------------------------------
    mod Errors {
        pub const ONLY_OWNER: felt252         = 'only the owner can reveal';
        pub const INVALID_SECRET: felt252     = 'invalid secret';
        pub const DEADLINE_NOT_REACHED: felt252 = 'deadline not reached yet';
        pub const TRANSFER_FAILED: felt252    = 'transfer failed';
        pub const BELOW_MIN_DEPOSIT: felt252  = 'deposit below minimum';
    }

    // Minimum collateral required 
    const MIN_DEPOSIT: u256 = 1_000_000_000_000_000_000_u256; // 1 token (18 decimals)

    #[constructor]
    fn constructor(
        ref self: ContractState,
        receiver: ContractAddress,
        hash: u256,
        delay: u64,
        amount: u256,
        token: ContractAddress,
    ) {
        assert(amount >= MIN_DEPOSIT, Errors::BELOW_MIN_DEPOSIT);

        let owner = get_caller_address();
        let current_block = get_block_info().unbox().block_number;

        self.owner.write(owner);
        self.receiver.write(receiver);
        self.token.write(token);
        self.hash.write(hash);
        self.reveal_timeout.write(current_block + delay);

        // Lock collateral immediately at deploy time
        let token_dispatcher = IERC20Dispatcher { contract_address: token };
        let success = token_dispatcher.transfer_from(owner, get_contract_address(), amount);
        assert(success, Errors::TRANSFER_FAILED);
    }

    #[abi(embed_v0)]
    impl HTLCImpl of IHTLC<ContractState> {

        fn reveal(ref self: ContractState, secret: ByteArray) {
            let caller = get_caller_address();
            assert(caller == self.owner.read(), Errors::ONLY_OWNER);

            // keccak256 over the provided bytes
            let computed: u256 = compute_keccak_byte_array(@secret);
            assert(computed == self.hash.read(), Errors::INVALID_SECRET);

            let token = IERC20Dispatcher { contract_address: self.token.read() };
            let balance = token.balance_of(get_contract_address());

            let success = token.transfer(self.owner.read(), balance);
            assert(success, Errors::TRANSFER_FAILED);
        }

        /// Anyone can call timeout after the deadline.
        /// Transfers the full balance to the receiver.
        fn timeout(ref self: ContractState) {
            let current_block = get_block_info().unbox().block_number;
            assert(current_block > self.reveal_timeout.read(), Errors::DEADLINE_NOT_REACHED);

            let token = IERC20Dispatcher { contract_address: self.token.read() };
            let balance = token.balance_of(get_contract_address());

            let success = token.transfer(self.receiver.read(), balance);
            assert(success, Errors::TRANSFER_FAILED);
        }
    }
}
