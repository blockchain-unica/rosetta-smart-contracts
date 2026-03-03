use starknet::ContractAddress;

#[starknet::interface]
pub trait IEscrow<TContractState> {
    fn deposit(ref self: TContractState);
    fn pay(ref self: TContractState);
    fn refund(ref self: TContractState);
    fn get_state(self: @TContractState) -> u8;
    fn get_buyer(self: @TContractState) -> ContractAddress;
    fn get_seller(self: @TContractState) -> ContractAddress;
    fn get_amount(self: @TContractState) -> u256;
    fn get_token(self: @TContractState) -> ContractAddress;
}

#[starknet::contract]
pub mod Escrow {
    use openzeppelin::token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
    use starknet::{ContractAddress, get_caller_address, get_contract_address};
    use starknet::storage::{StoragePointerReadAccess, StoragePointerWriteAccess};
    use super::IEscrow;

    // ---------------------------------------------------------------------------
    // State machine — mirrors Solidity enum States
    // ---------------------------------------------------------------------------
    const WAIT_DEPOSIT: u8 = 0;
    const WAIT_RECIPIENT: u8 = 1;
    const CLOSED: u8 = 2;

    // ---------------------------------------------------------------------------
    // Storage
    // ---------------------------------------------------------------------------
    #[storage]
    struct Storage {
        buyer: ContractAddress,
        seller: ContractAddress,
        token: ContractAddress,
        amount: u256,
        state: u8,
    }

    // ---------------------------------------------------------------------------
    // Errors
    // ---------------------------------------------------------------------------
    mod Errors {
        pub const ONLY_BUYER: felt252          = 'only the buyer';
        pub const ONLY_SELLER: felt252         = 'only the seller';
        pub const INVALID_STATE: felt252       = 'invalid state';
        pub const INVALID_AMOUNT: felt252      = 'invalid amount';
        pub const ZERO_ADDRESS: felt252        = 'zero address not allowed';
        pub const SELLER_IS_CREATOR: felt252   = 'creator must be the seller';
        pub const TRANSFER_FAILED: felt252     = 'transfer failed';
    }

    // ---------------------------------------------------------------------------
    // Constructor — seller deploys and sets buyer + required amount
    // ---------------------------------------------------------------------------
    #[constructor]
    fn constructor(
        ref self: ContractState,
        amount: u256,
        buyer: ContractAddress,
        seller: ContractAddress,
        token: ContractAddress,
    ) {
        assert(
            buyer != starknet::contract_address_const::<0>()
            && seller != starknet::contract_address_const::<0>(),
            Errors::ZERO_ADDRESS
        );
        assert(get_caller_address() == seller, Errors::SELLER_IS_CREATOR);

        self.amount.write(amount);
        self.buyer.write(buyer);
        self.seller.write(seller);
        self.token.write(token);
        self.state.write(WAIT_DEPOSIT);
    }

    // ---------------------------------------------------------------------------
    // Implementation
    // ---------------------------------------------------------------------------
    #[abi(embed_v0)]
    impl EscrowImpl of IEscrow<ContractState> {

        fn deposit(ref self: ContractState) {
            let caller = get_caller_address();
            assert(caller == self.buyer.read(), Errors::ONLY_BUYER);
            assert(self.state.read() == WAIT_DEPOSIT, Errors::INVALID_STATE);

            let amount = self.amount.read();
            let token = IERC20Dispatcher { contract_address: self.token.read() };

            // mirrors: require(msg.value == amount)
            // on Starknet we enforce exact amount via transfer_from
            let success = token.transfer_from(caller, get_contract_address(), amount);
            assert(success, Errors::TRANSFER_FAILED);

            self.state.write(WAIT_RECIPIENT);
        }

        fn pay(ref self: ContractState) {
            let caller = get_caller_address();
            assert(caller == self.buyer.read(), Errors::ONLY_BUYER);
            assert(self.state.read() == WAIT_RECIPIENT, Errors::INVALID_STATE);

            self.state.write(CLOSED);

            let amount = self.amount.read();
            let token = IERC20Dispatcher { contract_address: self.token.read() };
            let success = token.transfer(self.seller.read(), amount);
            assert(success, Errors::TRANSFER_FAILED);
        }

        fn refund(ref self: ContractState) {
            let caller = get_caller_address();
            assert(caller == self.seller.read(), Errors::ONLY_SELLER);
            assert(self.state.read() == WAIT_RECIPIENT, Errors::INVALID_STATE);

            self.state.write(CLOSED);

            let amount = self.amount.read();
            let token = IERC20Dispatcher { contract_address: self.token.read() };
            let success = token.transfer(self.buyer.read(), amount);
            assert(success, Errors::TRANSFER_FAILED);
        }

        /// Returns current state: 0=WAIT_DEPOSIT, 1=WAIT_RECIPIENT, 2=CLOSED
        fn get_state(self: @ContractState) -> u8 { self.state.read() }
        fn get_buyer(self: @ContractState) -> ContractAddress { self.buyer.read() }
        fn get_seller(self: @ContractState) -> ContractAddress { self.seller.read() }
        fn get_amount(self: @ContractState) -> u256 { self.amount.read() }
        fn get_token(self: @ContractState) -> ContractAddress { self.token.read() }
    }
}