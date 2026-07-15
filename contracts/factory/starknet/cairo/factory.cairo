use starknet::{ContractAddress};

#[starknet::interface]
pub trait IProduct<TContractState> {
    fn get_tag(self: @TContractState) -> ByteArray;
    fn get_factory(self: @TContractState) -> ContractAddress;
}

#[starknet::contract]
pub mod Product {
    use starknet::{
        ContractAddress, get_caller_address, get_tx_info,
    };
    use starknet::storage::{StoragePointerReadAccess, StoragePointerWriteAccess};
    use super::IProduct;

    #[storage]
    struct Storage {
        tag: ByteArray,               
        owner: ContractAddress,       
        factory: ContractAddress,     
    }

    mod Errors {
        pub const ONLY_OWNER: felt252 = 'only the owner';
    }

    #[constructor]
    fn constructor(ref self: ContractState, tag: ByteArray) {
        let owner = get_tx_info().unbox().account_contract_address;
        let factory = get_caller_address();

        self.owner.write(owner);
        self.factory.write(factory);
        self.tag.write(tag);
    }

    #[abi(embed_v0)]
    impl ProductImpl of IProduct<ContractState> {

        fn get_tag(self: @ContractState) -> ByteArray {
            assert(get_caller_address() == self.owner.read(), Errors::ONLY_OWNER);
            self.tag.read()
        }

        fn get_factory(self: @ContractState) -> ContractAddress {
            self.factory.read()
        }
    }
}

#[starknet::interface]
pub trait IFactory<TContractState> {
    fn create_product(ref self: TContractState, tag: ByteArray) -> ContractAddress;
    fn get_products(self: @TContractState) -> Array<ContractAddress>;
}

#[starknet::contract]
pub mod Factory {
    use starknet::{
        ContractAddress, get_caller_address, ClassHash,
        syscalls::deploy_syscall,
    };
    use starknet::storage::{
        StoragePointerReadAccess, StoragePointerWriteAccess,
        Map,  Vec, StoragePathEntry, VecTrait, MutableVecTrait,
    };
    use super::IFactory;
    use core::poseidon::poseidon_hash_span;


    #[storage]
    struct Storage {
        product_class_hash: ClassHash,
        product_list: Map<ContractAddress, Vec<ContractAddress>>, 
        salt: felt252,
    }

    #[constructor]
    fn constructor(ref self: ContractState, product_class_hash: ClassHash) {
        self.product_class_hash.write(product_class_hash);
    }

    #[abi(embed_v0)]
    impl FactoryImpl of IFactory<ContractState> {

        fn create_product(ref self: ContractState, tag: ByteArray) -> ContractAddress {
            let caller = get_caller_address();

            let mut calldata: Array<felt252> = array![];
            tag.serialize(ref calldata);

            let counter = self.salt.read();
            self.salt.write(counter + 1);
            let salt = poseidon_hash_span(array![caller.into(), counter].span());


            let (product_addr, _) = deploy_syscall(
                self.product_class_hash.read(),
                salt,
                calldata.span(),
                false,
            ).unwrap();


            self.product_list.entry(caller).push(product_addr);
            product_addr
        }

        fn get_products(self: @ContractState) -> Array<ContractAddress> {
            let caller = get_caller_address();
            let vec    = self.product_list.entry(caller);
            let mut result: Array<ContractAddress> = array![];
            let mut i: u64 = 0;
            loop {
                if i >= vec.len() { break; }
                result.append(vec.at(i).read());
                i += 1;
            };
            result
        }
    }
}
