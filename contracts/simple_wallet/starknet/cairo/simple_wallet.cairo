use starknet::{ContractAddress};

#[starknet::interface]
pub trait ISimpleWallet<TContractState> {
    fn deposit(ref self: TContractState, amount: u256);
    fn create_transaction(
        ref self: TContractState,
        to: ContractAddress,
        value: u256,
        data: ByteArray,
    );
    fn execute_transaction(ref self: TContractState, tx_id: u64);
    fn withdraw(ref self: TContractState);
    fn get_owner(self: @TContractState) -> ContractAddress;
    fn get_balance(self: @TContractState) -> u256;
    fn get_transaction_count(self: @TContractState) -> u64;
    fn get_transaction(self: @TContractState, tx_id: u64) -> Transaction;
}

#[derive(Drop, Serde, starknet::Store)]
pub struct Transaction {
    pub to: ContractAddress,
    pub value: u256,
    pub data: ByteArray,
    pub executed: bool,
}

#[starknet::contract]
pub mod SimpleWallet {
    use openzeppelin::token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
    use starknet::{ContractAddress, get_caller_address, get_contract_address};
    use starknet::storage::{
        StoragePointerReadAccess, StoragePointerWriteAccess,
        Vec, VecTrait, MutableVecTrait, 
    };
    use super::{ISimpleWallet, Transaction};
    
    #[storage]
    struct Storage {
        owner: ContractAddress,
        token: ContractAddress,
        transactions: Vec<Transaction>, 
    }

    // ---------------------------------------------------------------------------
    // Errors
    // ---------------------------------------------------------------------------
    mod Errors {
        pub const ONLY_OWNER: felt252         = 'only the owner';
        pub const INVALID_ADDRESS: felt252    = 'invalid address';
        pub const TX_NOT_FOUND: felt252       = 'transaction does not exist';
        pub const ALREADY_EXECUTED: felt252   = 'transaction already executed';
        pub const INSUFFICIENT_FUNDS: felt252 = 'insufficient funds';
        pub const TRANSFER_FAILED: felt252    = 'transfer failed';
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        owner: ContractAddress,
        token: ContractAddress,
    ) {
        assert(
            owner != starknet::contract_address_const::<0>(),
            Errors::INVALID_ADDRESS
        );
        self.owner.write(owner);
        self.token.write(token);
    }

    #[abi(embed_v0)]
    impl SimpleWalletImpl of ISimpleWallet<ContractState> {

        /// Owner must call approve(wallet, amount) on the token first.
        fn deposit(ref self: ContractState, amount: u256) {
            let caller = get_caller_address();
            assert(caller == self.owner.read(), Errors::ONLY_OWNER);

            let token   = IERC20Dispatcher { contract_address: self.token.read() };
            let success = token.transfer_from(caller, get_contract_address(), amount);
            assert(success, Errors::TRANSFER_FAILED);
        }

        /// Owner creates a new transaction entry — does NOT execute it yet.
        fn create_transaction(
            ref self: ContractState,
            to: ContractAddress,
            value: u256,
            data: ByteArray,
        ) {
            assert(get_caller_address() == self.owner.read(), Errors::ONLY_OWNER);

            self.transactions.push(Transaction { to, value, data, executed: false });
        }

        /// Owner executes a previously created transaction by ID.
        fn execute_transaction(ref self: ContractState, tx_id: u64) {
            assert(get_caller_address() == self.owner.read(), Errors::ONLY_OWNER);
            assert(tx_id < self.transactions.len(), Errors::TX_NOT_FOUND);

            let tx = self.transactions.at(tx_id).read();
            assert(!tx.executed, Errors::ALREADY_EXECUTED);

            let token   = IERC20Dispatcher { contract_address: self.token.read() };
            let balance = token.balance_of(get_contract_address());
            assert(tx.value < balance, Errors::INSUFFICIENT_FUNDS);

            self.transactions.at(tx_id).write(
                Transaction { to: tx.to, value: tx.value, data: tx.data, executed: true }
            );

            let success = token.transfer(tx.to, tx.value);
            assert(success, Errors::TRANSFER_FAILED);
        }

        /// Owner withdraws the entire wallet balance.
        fn withdraw(ref self: ContractState) {
            assert(get_caller_address() == self.owner.read(), Errors::ONLY_OWNER);

            let token   = IERC20Dispatcher { contract_address: self.token.read() };
            let balance = token.balance_of(get_contract_address());
            let success = token.transfer(self.owner.read(), balance);
            assert(success, Errors::TRANSFER_FAILED);
        }

        fn get_owner(self: @ContractState) -> ContractAddress { self.owner.read() }

        fn get_balance(self: @ContractState) -> u256 {
            let token = IERC20Dispatcher { contract_address: self.token.read() };
            token.balance_of(get_contract_address())
        }

        // mirrors: transactions.length
        fn get_transaction_count(self: @ContractState) -> u64 {
            self.transactions.len()
        }

        fn get_transaction(self: @ContractState, tx_id: u64) -> Transaction {
            assert(tx_id < self.transactions.len(), Errors::TX_NOT_FOUND);
            self.transactions.at(tx_id).read()
        }
    }
}