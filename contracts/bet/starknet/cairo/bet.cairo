use starknet::ContractAddress;

// ---------------------------------------------------------------------------
// Minimal ERC-20 interface — no external dependencies needed.
// ---------------------------------------------------------------------------
#[starknet::interface]
trait IERC20<TContractState> {
    fn transfer(ref self: TContractState, recipient: ContractAddress, amount: u256) -> bool;
    fn transfer_from(
        ref self: TContractState,
        sender: ContractAddress,
        recipient: ContractAddress,
        amount: u256,
    ) -> bool;
}

// ---------------------------------------------------------------------------
// Public interface of the Bet contract
// ---------------------------------------------------------------------------
#[starknet::interface]
pub trait IBet<TContractState> {
    fn join(ref self: TContractState);
    fn win(ref self: TContractState, winner: u8);
    fn timeout(ref self: TContractState);
}

#[starknet::contract]
pub mod Bet {
    use starknet::{
        ContractAddress, get_caller_address, get_block_number, get_contract_address,
        contract_address_const,
    };
    use starknet::storage::{StoragePointerReadAccess, StoragePointerWriteAccess};
    use super::{IERC20Dispatcher, IERC20DispatcherTrait};

    #[storage]
    struct Storage {
        player1: ContractAddress,
        player2: ContractAddress, // zero address means player2 has not joined yet
        oracle: ContractAddress,
        wager: u256,
        deadline: u64,
        token: ContractAddress,
    }

    // -----------------------------------------------------------------------
    // Errors
    // -----------------------------------------------------------------------
    mod Errors {
        pub const INVALID_VALUE: felt252         = 'Invalid value';
        pub const PLAYER2_ALREADY_JOINED: felt252 = 'Player2 already joined';
        pub const TIMEOUT: felt252               = 'Timeout';
        pub const ONLY_ORACLE: felt252           = 'Only the oracle';
        pub const PLAYER2_NOT_JOINED: felt252    = 'Player2 has not joined';
        pub const INVALID_WINNER: felt252        = 'Invalid winner';
        pub const TIMEOUT_NOT_PASSED: felt252    = 'The timeout has not passed';
        pub const TRANSFER_FAILED: felt252       = 'Transfer failed';
    }

    // Player1 is the deployer. They deposit `wager` tokens immediately.
    // Before deploying, player1 must approve this contract for `wager` tokens.
    //
    //   oracle   – address authorised to call win()
    //   timeout  – number of blocks from now until timeout is active
    //   wager    – amount player1 deposits (player2 must match it in join())
    //   token    – ERC-20 contract address used as the wagered currency
    // -----------------------------------------------------------------------
    #[constructor]
    fn constructor(
        ref self: ContractState,
        oracle: ContractAddress,
        timeout: u64,
        wager: u256,
        token: ContractAddress,
    ) {
        let player1 = get_caller_address();

        self.player1.write(player1);
        self.oracle.write(oracle);
        self.wager.write(wager);
        self.deadline.write(get_block_number() + timeout);
        self.token.write(token);

        // Player1 deposits immediately at construction
        let erc20 = IERC20Dispatcher { contract_address: token };
        let ok = erc20.transfer_from(player1, get_contract_address(), wager);
        assert(ok, Errors::TRANSFER_FAILED);
    }

    #[abi(embed_v0)]
    impl BetImpl of super::IBet<ContractState> {

        fn join(ref self: ContractState) {
            let zero = contract_address_const::<0>();
            // Player2 must not have joined yet
            assert(self.player2.read() == zero, Errors::PLAYER2_ALREADY_JOINED);

            // Deadline must not have passed
            assert(get_block_number() <= self.deadline.read(), Errors::TIMEOUT);

            let player2 = get_caller_address();
            let wager = self.wager.read();
            let erc20 = IERC20Dispatcher { contract_address: self.token.read() };
            let ok = erc20.transfer_from(player2, get_contract_address(), wager);
            assert(ok, Errors::INVALID_VALUE); // transfer_from fails if approved amount != wager

            self.player2.write(player2);
        }

        fn win(ref self: ContractState, winner: u8) {
            assert(get_caller_address() == self.oracle.read(), Errors::ONLY_ORACLE);
            assert(self.player2.read() != contract_address_const::<0>(), Errors::PLAYER2_NOT_JOINED);
            assert(winner <= 1, Errors::INVALID_WINNER);

            let winner_address = if winner == 0 {
                self.player1.read()
            } else {
                self.player2.read()
            };

            let prize = self.wager.read() * 2;
            let erc20 = IERC20Dispatcher { contract_address: self.token.read() };
            let ok = erc20.transfer(winner_address, prize);
            assert(ok, Errors::TRANSFER_FAILED);

        }

        fn timeout(ref self: ContractState) {
            assert(get_block_number() > self.deadline.read(), Errors::TIMEOUT_NOT_PASSED);

            let wager = self.wager.read();
            let erc20 = IERC20Dispatcher { contract_address: self.token.read() };
            let zero = contract_address_const::<0>();

            // Always refund player1
            let ok1 = erc20.transfer(self.player1.read(), wager);
            assert(ok1, Errors::TRANSFER_FAILED);

            // Refund player2 only if they joined
            let player2 = self.player2.read();
            let player2_refunded = player2 != zero;
            if player2_refunded {
                let ok2 = erc20.transfer(player2, wager);
                assert(ok2, Errors::TRANSFER_FAILED);
            }
        }
    }
}
