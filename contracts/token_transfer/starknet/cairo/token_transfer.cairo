use starknet::ContractAddress;

#[starknet::interface]
pub trait ITokenTransfer<TContractState> {
    fn deposit(ref self: TContractState, amount: u256);
    fn withdraw(ref self: TContractState, amount: u256);
    fn get_balance(self: @TContractState) -> u256;
    fn get_owner(self: @TContractState) -> ContractAddress;
    fn get_recipient(self: @TContractState) -> ContractAddress;
    fn get_token(self: @TContractState) -> ContractAddress;
}

#[starknet::contract]
pub mod TokenTransfer {
    use openzeppelin::token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
    use starknet::{ContractAddress, get_caller_address, get_contract_address};
    use starknet::storage::{StoragePointerReadAccess, StoragePointerWriteAccess};
    use super::ITokenTransfer;

    #[storage]
    struct Storage {
        owner: ContractAddress,
        recipient: ContractAddress,
        token: ContractAddress,
    }

    // ---------------------------------------------------------------------------
    // Events
    // ---------------------------------------------------------------------------
    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        Withdraw: Withdraw,
    }

    #[derive(Drop, starknet::Event)]
    struct Withdraw {
        #[key]
        sender: ContractAddress,
        amount: u256,
    }

    // ---------------------------------------------------------------------------
    // Errors
    // ---------------------------------------------------------------------------
    mod Errors {
        pub const ONLY_OWNER: felt252        = 'only the owner';
        pub const ONLY_RECIPIENT: felt252    = 'only the recipient can withdraw';
        pub const ZERO_BALANCE: felt252      = 'the contract balance is zero';
        pub const DEPOSIT_FAILED: felt252    = 'deposit failed';
        pub const TRANSFER_FAILED: felt252   = 'transfer failed';
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        recipient: ContractAddress,
        token: ContractAddress,
    ) {
        self.owner.write(get_caller_address());
        self.recipient.write(recipient);
        self.token.write(token);
    }

    #[abi(embed_v0)]
    impl TokenTransferImpl of ITokenTransfer<ContractState> {

        /// Owner must call approve(contract_address, amount) on the token first.
        fn deposit(ref self: ContractState, amount: u256) {
            let caller = get_caller_address();
            assert(caller == self.owner.read(), Errors::ONLY_OWNER);

            let token = IERC20Dispatcher { contract_address: self.token.read() };
            let success = token.transfer_from(caller, get_contract_address(), amount);
            assert(success, Errors::DEPOSIT_FAILED);

        }

        /// Recipient withdraws up to `amount` tokens.
        fn withdraw(ref self: ContractState, amount: u256) {
            let caller = get_caller_address();
            assert(caller == self.recipient.read(), Errors::ONLY_RECIPIENT);

            let token = IERC20Dispatcher { contract_address: self.token.read() };
            let balance = token.balance_of(get_contract_address());
            assert(balance > 0, Errors::ZERO_BALANCE);

            let actual_amount = if amount > balance { balance } else { amount };

            let success = token.transfer(self.recipient.read(), actual_amount);
            assert(success, Errors::TRANSFER_FAILED);

            self.emit(Withdraw { sender: caller, amount: actual_amount });
        }
    }
}
