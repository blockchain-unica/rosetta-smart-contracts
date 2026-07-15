use starknet::{ContractAddress};

#[starknet::interface]
pub trait IPaymentSplitter<TContractState> {
    fn receive(ref self: TContractState, amount: u256);
    fn release(ref self: TContractState, account: ContractAddress);
    fn releasable(self: @TContractState, account: ContractAddress) -> u256;
    fn total_shares(self: @TContractState) -> u256;
    fn total_released(self: @TContractState) -> u256;
    fn shares(self: @TContractState, account: ContractAddress) -> u256;
    fn released(self: @TContractState, account: ContractAddress) -> u256;
    fn payee(self: @TContractState, index: u64) -> ContractAddress;
}

#[starknet::contract]
pub mod PaymentSplitter {
    use openzeppelin::token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
    use starknet::{ContractAddress, get_caller_address, get_contract_address};
    use starknet::storage::{
        StoragePointerReadAccess, StoragePointerWriteAccess,
        Map, StorageMapReadAccess, StorageMapWriteAccess,
        Vec, VecTrait, MutableVecTrait,
    };
    use super::IPaymentSplitter;

    #[storage]
    struct Storage {
        token: ContractAddress,
        total_shares: u256,
        total_released: u256,
        shares: Map<ContractAddress, u256>,
        released: Map<ContractAddress, u256>,
        payees: Vec<ContractAddress>,          
    }

    // ---------------------------------------------------------------------------
    // Errors
    // ---------------------------------------------------------------------------
    mod Errors {
        pub const LENGTH_MISMATCH: felt252   = 'payees and shares mismatch';
        pub const NO_PAYEES: felt252         = 'no payees';
        pub const ZERO_ADDRESS: felt252      = 'account is zero address';
        pub const ZERO_SHARES: felt252       = 'shares are 0';
        pub const ALREADY_HAS_SHARES: felt252 = 'account already has shares';
        pub const NO_SHARES: felt252         = 'account has no shares';
        pub const NOT_DUE: felt252           = 'account not due payment';
        pub const TRANSFER_FAILED: felt252   = 'transfer failed';
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        payees: Array<ContractAddress>,
        shares: Array<u256>,
        token: ContractAddress,
    ) {
        assert(payees.len() == shares.len(), Errors::LENGTH_MISMATCH);
        assert(payees.len() > 0, Errors::NO_PAYEES);

        self.token.write(token);

        let mut i = 0;
        while i < payees.len() {
            self._add_payee(*payees.at(i), *shares.at(i));
            i += 1;
        }
    }

    #[abi(embed_v0)]
    impl PaymentSplitterImpl of IPaymentSplitter<ContractState> {

        /// Anyone can deposit tokens into the contract.
        fn receive(ref self: ContractState, amount: u256) {
            let caller  = get_caller_address();
            let token   = IERC20Dispatcher { contract_address: self.token.read() };
            let success = token.transfer_from(caller, get_contract_address(), amount);
            assert(success, Errors::TRANSFER_FAILED);
        }

        /// Anyone can trigger payment release for a specific account.
        fn release(ref self: ContractState, account: ContractAddress) {
            assert(self.shares.read(account) > 0, Errors::NO_SHARES);

            let payment = Self::releasable(@self, account);
            assert(payment > 0, Errors::NOT_DUE);

            // update totals before transfer — CEI pattern
            self.total_released.write(self.total_released.read() + payment);
            self.released.write(account, self.released.read(account) + payment);

            let token   = IERC20Dispatcher { contract_address: self.token.read() };
            let success = token.transfer(account, payment);
            assert(success, Errors::TRANSFER_FAILED);

        }

        /// Returns the amount account is currently owed.
        fn releasable(self: @ContractState, account: ContractAddress) -> u256 {
            let token = IERC20Dispatcher { contract_address: self.token.read() };
            let balance = token.balance_of(get_contract_address());
            let total_received = balance + Self::total_released(self);
            self._pending_payment(account, total_received, self.released.read(account))
        }

        fn total_shares(self: @ContractState) -> u256 { self.total_shares.read() }
        fn total_released(self: @ContractState) -> u256 { self.total_released.read() }
        fn shares(self: @ContractState, account: ContractAddress) -> u256 {
            self.shares.read(account)
        }
        fn released(self: @ContractState, account: ContractAddress) -> u256 {
            self.released.read(account)
        }
        fn payee(self: @ContractState, index: u64) -> ContractAddress {
            self.payees.at(index).read()
        }
    }

    // ---------------------------------------------------------------------------
    // Internal helpers
    // ---------------------------------------------------------------------------
    #[generate_trait]
    impl InternalImpl of InternalTrait {

        fn _pending_payment(
            self: @ContractState,
            account: ContractAddress,
            total_received: u256,
            already_released: u256,
        ) -> u256 {
            (total_received * self.shares.read(account)) / self.total_shares.read()
                - already_released
        }

        fn _add_payee(ref self: ContractState, account: ContractAddress, shares: u256) {
            assert(
                account != starknet::contract_address_const::<0>(),
                Errors::ZERO_ADDRESS
            );
            assert(shares > 0, Errors::ZERO_SHARES);
            assert(self.shares.read(account) == 0, Errors::ALREADY_HAS_SHARES);

            self.payees.push(account);
            self.shares.write(account, shares);
            self.total_shares.write(self.total_shares.read() + shares);
        }
    }
}