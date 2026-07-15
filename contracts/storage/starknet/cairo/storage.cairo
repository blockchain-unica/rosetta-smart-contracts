#[starknet::interface]
pub trait IStorage<TContractState> {
    fn store_bytes(ref self: TContractState, byte_sequence: ByteArray);
    fn store_string(ref self: TContractState, text_string: ByteArray);
}

#[starknet::contract]
pub mod Storage {
    use starknet::storage::{StoragePointerReadAccess, StoragePointerWriteAccess};
    use super::IStorage;

    #[storage]
    struct Storage {
        byte_sequence: ByteArray,  // mirrors: bytes public byteSequence
        text_string: ByteArray,    // mirrors: string public textString
    }

    #[constructor]
    fn constructor(ref self: ContractState) {}

    #[abi(embed_v0)]
    impl StorageImpl of IStorage<ContractState> {

        fn store_bytes(ref self: ContractState, byte_sequence: ByteArray) {
            self.byte_sequence.write(byte_sequence);
        }

        fn store_string(ref self: ContractState, text_string: ByteArray) {
            self.text_string.write(text_string);
        }
    }
}
