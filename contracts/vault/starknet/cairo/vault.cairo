use starknet::{ContractAddress};

#[starknet::interface]
pub trait IVault<TContractState> {
    fn receive(ref self: TContractState, amount: u256);
    fn withdraw(ref self: TContractState, receiver: ContractAddress, amount: u256);
    fn finalize(ref self: TContractState);
    fn cancel(ref self: TContractState);
}

#[starknet::contract]
pub mod Vault {
    use openzeppelin::token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
    use starknet::{ContractAddress, get_caller_address, get_contract_address, get_block_info};
    use starknet::storage::{StoragePointerReadAccess, StoragePointerWriteAccess};
    use super::IVault;

    // ---------------------------------------------------------------------------
    // States
    // ---------------------------------------------------------------------------
    const IDLE: u8 = 0;
    const REQ: u8  = 1;

    // ---------------------------------------------------------------------------
    // Storage
    // ---------------------------------------------------------------------------
    #[storage]
    struct Storage {
        owner: ContractAddress,
        recovery: ContractAddress,
        token: ContractAddress,
        wait_time: u64,
        state: u8,
        receiver: ContractAddress,
        request_block: u64,
        amount: u256,
    }

    // ---------------------------------------------------------------------------
    // Errors
    // ---------------------------------------------------------------------------
    mod Errors {
        pub const ONLY_OWNER: felt252         = 'only the owner';
        pub const ONLY_RECOVERY: felt252      = 'only the recovery key';
        pub const NOT_IDLE: felt252           = 'state must be idle';
        pub const NOT_REQ: felt252            = 'no pending request';
        pub const WAIT_NOT_ELAPSED: felt252   = 'wait time not elapsed';
        pub const INSUFFICIENT_BALANCE: felt252 = 'insufficient balance';
        pub const TRANSFER_FAILED: felt252    = 'transfer failed';
    }

    // ---------------------------------------------------------------------------
    // Constructor
    // ---------------------------------------------------------------------------
    /// Owner deploys vault specifying the recovery address and wait time in blocks.
    /// The initial deposit is handled via deposit() since we use ERC20.
    #[constructor]
    fn constructor(
        ref self: ContractState,
        recovery: ContractAddress,
        wait_time: u64,
        token: ContractAddress,
    ) {
        self.owner.write(get_caller_address());
        self.recovery.write(recovery);
        self.wait_time.write(wait_time);
        self.token.write(token);
        self.state.write(IDLE);
    }

    // ---------------------------------------------------------------------------
    // Implementation
    // ---------------------------------------------------------------------------
    #[abi(embed_v0)]
    impl VaultImpl of IVault<ContractState> {

        /// Depositor must call approve(vault, amount) on the token first.
        fn receive(ref self: ContractState, amount: u256) {
            let caller  = get_caller_address();
            let token   = IERC20Dispatcher { contract_address: self.token.read() };
            let success = token.transfer_from(caller, get_contract_address(), amount);
            assert(success, Errors::TRANSFER_FAILED);
        }

        /// Owner issues a withdraw request. Transitions IDLE -> REQ.
        fn withdraw(ref self: ContractState, receiver: ContractAddress, amount: u256) {
            assert(get_caller_address() == self.owner.read(), Errors::ONLY_OWNER);
            assert(self.state.read() == IDLE, Errors::NOT_IDLE);

            let token   = IERC20Dispatcher { contract_address: self.token.read() };
            let balance = token.balance_of(get_contract_address());
            assert(amount <= balance, Errors::INSUFFICIENT_BALANCE);

            let current_block = get_block_info().unbox().block_number;
            self.request_block.write(current_block);
            self.amount.write(amount);
            self.receiver.write(receiver);
            self.state.write(REQ);
        }

        /// Owner finalizes the withdraw after wait time has elapsed. REQ -> IDLE.
        fn finalize(ref self: ContractState) {
            assert(get_caller_address() == self.owner.read(), Errors::ONLY_OWNER);
            assert(self.state.read() == REQ, Errors::NOT_REQ);

            let current_block = get_block_info().unbox().block_number;
            assert(
                current_block >= self.request_block.read() + self.wait_time.read(),
                Errors::WAIT_NOT_ELAPSED
            );

            self.state.write(IDLE);

            let amount   = self.amount.read();
            let receiver = self.receiver.read();
            let token    = IERC20Dispatcher { contract_address: self.token.read() };
            let success  = token.transfer(receiver, amount);
            assert(success, Errors::TRANSFER_FAILED);
        }

        /// Recovery key cancels the pending withdraw request. REQ -> IDLE.
        fn cancel(ref self: ContractState) {
            assert(get_caller_address() == self.recovery.read(), Errors::ONLY_RECOVERY);
            assert(self.state.read() == REQ, Errors::NOT_REQ);

            self.state.write(IDLE);
        }
    }
}
