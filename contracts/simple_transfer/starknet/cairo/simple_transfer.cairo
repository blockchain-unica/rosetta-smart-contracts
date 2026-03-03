use starknet::ContractAddress;

// Interface required so the test file can call functions via dispatcher
#[starknet::interface]
pub trait ISimpleTransfer<TContractState> {
    fn deposit(ref self: TContractState, amount: u256);
    fn withdraw(ref self: TContractState, amount: u256);
    fn get_balance(self: @TContractState) -> u256;
    fn get_owner(self: @TContractState) -> ContractAddress;
    fn get_recipient(self: @TContractState) -> ContractAddress;
    fn get_token(self: @TContractState) -> ContractAddress;
}


#[starknet::contract]
pub mod SimpleTransfer {
    use openzeppelin::token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
    use starknet::{ContractAddress, get_caller_address, get_contract_address};
    use starknet::storage::{StoragePointerReadAccess, StoragePointerWriteAccess};
    use super::ISimpleTransfer;

    #[storage]
    struct Storage {
        owner: ContractAddress,
        recipient: ContractAddress,
        token: ContractAddress, // e.g. Starknet ETH token address
    }

    // ---------------------------------------------------------------------------
    // Errors
    // ---------------------------------------------------------------------------
    mod Errors {
        pub const ONLY_OWNER: felt252       = 'only the owner can deposit';
        pub const ONLY_RECIPIENT: felt252   = 'only the recipient can withdraw';
        pub const INSUFFICIENT_BALANCE: felt252 = 'balance less than amount';
        pub const TRANSFER_FAILED: felt252  = 'transfer failed';
    }

    // ---------------------------------------------------------------------------
    // Constructor
    // ---------------------------------------------------------------------------
    #[constructor]
    fn constructor(ref self: ContractState, recipient: ContractAddress, token: ContractAddress,) {
        self.recipient.write(recipient);
        self.owner.write(get_caller_address());
        self.token.write(token);
    }

    

    #[abi(embed_v0)]
    impl SimpleTransferImpl of ISimpleTransfer<ContractState> {
        fn deposit(ref self: ContractState, amount: u256) {
            let caller = get_caller_address();
            assert(caller == self.owner.read(), Errors::ONLY_OWNER);
            let token = IERC20Dispatcher { contract_address: self.token.read() };
            let success = token.transfer_from(caller, get_contract_address(), amount);
            assert(success, Errors::TRANSFER_FAILED);
        }

        fn withdraw(ref self: ContractState, amount: u256) {
            let caller = get_caller_address();
            assert(caller == self.recipient.read(), Errors::ONLY_RECIPIENT);
            let token = IERC20Dispatcher { contract_address: self.token.read() };
            let balance = token.balance_of(get_contract_address());
            assert(amount <= balance, Errors::INSUFFICIENT_BALANCE);
            let success = token.transfer(self.recipient.read(), amount);
            assert(success, Errors::TRANSFER_FAILED);
        }

        fn get_balance(self: @ContractState) -> u256 {
            let token = IERC20Dispatcher { contract_address: self.token.read() };
            token.balance_of(get_contract_address())
        }

        fn get_owner(self: @ContractState) -> ContractAddress { self.owner.read() }
        fn get_recipient(self: @ContractState) -> ContractAddress { self.recipient.read() }
        fn get_token(self: @ContractState) -> ContractAddress { self.token.read() }
    }
}
