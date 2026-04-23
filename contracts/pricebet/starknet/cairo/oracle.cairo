#[starknet::interface]
pub trait IOracle<TContractState> {
    fn get_exchange_rate(self: @TContractState) -> u256;
}

#[starknet::contract]
pub mod Oracle {
    use starknet::storage::{StoragePointerReadAccess, StoragePointerWriteAccess};
    use super::IOracle;
    
    #[storage]
    struct Storage {
        exchange_rate: u256,
    }

    #[constructor]
    fn constructor(ref self: ContractState, initial_rate: u256) {
        self.exchange_rate.write(initial_rate);
    }

    #[abi(embed_v0)]
    impl OracleImpl of IOracle<ContractState> {
        fn get_exchange_rate(self: @ContractState) -> u256 {
            self.exchange_rate.read()
        }
    }
}