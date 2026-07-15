
#[starknet::interface]
pub trait IAnonymousData<TContractState> {
    fn get_id(self: @TContractState, nonce: u256) -> u256;
    fn store_data(ref self: TContractState, data: ByteArray, id: u256);
    fn get_my_data(self: @TContractState, nonce: u256) -> ByteArray;
}

#[starknet::contract]
pub mod AnonymousData {
    use starknet::{get_caller_address};
    use starknet::storage::{
        Map, StorageMapReadAccess, StorageMapWriteAccess,
    };
    use core::keccak::keccak_u256s_be_inputs;
    use super::IAnonymousData;

    #[storage]
    struct Storage {
        stored_data: Map<u256, ByteArray>,  // mirrors: mapping(bytes32 => bytes) storedData
    }

    mod Errors {
        pub const ALREADY_STORED: felt252 = 'data already stored for id';
    }

    #[constructor]
    fn constructor(ref self: ContractState) {}

    #[abi(embed_v0)]
    impl AnonymousDataImpl of IAnonymousData<ContractState> {

        /// Returns keccak256(abi.encode(msg.sender, nonce))
        fn get_id(self: @ContractState, nonce: u256) -> u256 {
            let caller: felt252 = get_caller_address().into();
            let caller_u256: u256 = caller.into();

            keccak_u256s_be_inputs(array![caller_u256, nonce].span())
        }

        fn store_data(ref self: ContractState, data: ByteArray, id: u256) {
            // guard to prevent overwriting
            // as the spec says "if data is not already associated"
            let existing = self.stored_data.read(id);
            assert(existing.len() == 0, Errors::ALREADY_STORED);

            self.stored_data.write(id, data);
        }

        fn get_my_data(self: @ContractState, nonce: u256) -> ByteArray {
            let caller: felt252 = get_caller_address().into();
            let caller_u256: u256 = caller.into();

            let id = keccak_u256s_be_inputs(array![caller_u256, nonce].span());

            self.stored_data.read(id)
        }
    }
}