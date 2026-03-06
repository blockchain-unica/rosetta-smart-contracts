use starknet::{ContractAddress};
#[derive(Drop, Serde, PartialEq, Copy, starknet::Store)]
pub enum Status {
    #[default]
    Join0,    // waiting for player0
    Join1,    // waiting for player1
    Reveal0,  // waiting for player0 to reveal
    Reveal1,  // waiting for player1 to reveal
    Win,      // both revealed, waiting for win() call
    End,      // finished
}

#[starknet::interface]
pub trait ILottery<TContractState> {
    fn join0(ref self: TContractState, hash: u256, amount: u256);
    fn join1(ref self: TContractState, hash: u256, amount: u256);
    fn redeem0_nojoin1(ref self: TContractState);
    fn reveal0(ref self: TContractState, secret: ByteArray);
    fn redeem1_noreveal0(ref self: TContractState);
    fn reveal1(ref self: TContractState, secret: ByteArray);
    fn redeem0_noreveal1(ref self: TContractState);
    fn win(ref self: TContractState);
}

#[starknet::contract]
pub mod Lottery {
    use openzeppelin::token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
    use starknet::{ContractAddress, get_caller_address, get_contract_address, get_block_info};
    use starknet::storage::{StoragePointerReadAccess, StoragePointerWriteAccess};
    use core::keccak::compute_keccak_byte_array;
    use super::{ILottery, Status};

    // value for .01 ether
    const MIN_BET: u256 = 10_000_000_000_000_000_u256;

    #[storage]
    struct Storage {
        owner: ContractAddress,            
        token: ContractAddress,
        player0: ContractAddress,          
        player1: ContractAddress,          
        winner: ContractAddress,           
        hash0: u256,                    
        hash1: u256,                    
        secret0: ByteArray,                  
        secret1: ByteArray,                  
        bet_amount: u256,                  
        status: Status,                    
        end_join: u64,                     
        end_reveal: u64,                  
    }

    // ---------------------------------------------------------------------------
    // Errors
    // ---------------------------------------------------------------------------
    mod Errors {
        pub const WRONG_STATUS: felt252        = 'wrong status';
        pub const WRONG_SENDER: felt252        = 'wrong sender';
        pub const WRONG_AMOUNT: felt252        = 'amount must equal bet';
        pub const BET_TOO_LOW: felt252         = 'bet below minimum';
        pub const SAME_HASH: felt252           = 'hashes must differ';
        pub const WRONG_SECRET: felt252        = 'secret does not match hash';
        pub const DEADLINE_NOT_PASSED: felt252 = 'deadline not passed';
        pub const TRANSFER_FAILED: felt252     = 'transfer failed';
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        token: ContractAddress,
    ) {
        self.owner.write(get_caller_address());
        self.token.write(token);
        self.status.write(Status::Join0);

        let current_block = get_block_info().unbox().block_number;
        let end_join      = current_block + 1000;

        self.end_join.write(end_join);
        self.end_reveal.write(end_join + 1000);
    }

    #[abi(embed_v0)]
    impl LotteryImpl of ILottery<ContractState> {

        /// Player0 joins by depositing bet and committing to a hash.
        fn join0(ref self: ContractState, hash: u256, amount: u256) {
            assert(self.status.read() == Status::Join0, Errors::WRONG_STATUS);
            assert(amount > MIN_BET, Errors::BET_TOO_LOW);

            let caller  = get_caller_address();
            let token   = IERC20Dispatcher { contract_address: self.token.read() };
            let success = token.transfer_from(caller, get_contract_address(), amount);
            assert(success, Errors::TRANSFER_FAILED);

            self.player0.write(caller);
            self.hash0.write(hash);
            self.status.write(Status::Join1);
            self.bet_amount.write(amount);
        }

        /// Player1 joins by depositing the exact same bet and committing to a different hash.
        fn join1(ref self: ContractState, hash: u256, amount: u256) {
            assert(self.status.read() == Status::Join1, Errors::WRONG_STATUS);
            assert(hash != self.hash0.read(), Errors::SAME_HASH);
            assert(amount == self.bet_amount.read(), Errors::WRONG_AMOUNT);

            let caller  = get_caller_address();
            let token   = IERC20Dispatcher { contract_address: self.token.read() };
            let success = token.transfer_from(caller, get_contract_address(), amount);
            assert(success, Errors::TRANSFER_FAILED);

            self.player1.write(caller);
            self.hash1.write(hash);
            self.status.write(Status::Reveal0);
        }

        /// Player0 redeems if player1 never joined after end_join.
        fn redeem0_nojoin1(ref self: ContractState) {
            assert(self.status.read() == Status::Join1, Errors::WRONG_STATUS);

            let current_block = get_block_info().unbox().block_number;
            assert(current_block > self.end_join.read(), Errors::DEADLINE_NOT_PASSED);

            self._transfer_all(self.player0.read());
            self.status.write(Status::End);
            
        }

        /// Player0 reveals secret — must match committed hash.
        fn reveal0(ref self: ContractState, secret: ByteArray) {
            assert(self.status.read() == Status::Reveal0, Errors::WRONG_STATUS);
            assert(get_caller_address() == self.player0.read(), Errors::WRONG_SENDER);

            let computed_hash = compute_keccak_byte_array(@secret);
            assert(computed_hash == self.hash0.read(), Errors::WRONG_SECRET);

            self.secret0.write(secret);
            self.status.write(Status::Reveal1);
        }

        /// Player1 redeems if player0 never revealed after end_reveal.
        fn redeem1_noreveal0(ref self: ContractState) {
            assert(self.status.read() == Status::Reveal0, Errors::WRONG_STATUS);

            let current_block = get_block_info().unbox().block_number;
            assert(current_block > self.end_reveal.read(), Errors::DEADLINE_NOT_PASSED);
            
            self._transfer_all(self.player1.read());
            self.status.write(Status::End);
            
        }

        /// Player1 reveals secret — must match committed hash.
        fn reveal1(ref self: ContractState, secret: ByteArray) {
            assert(self.status.read() == Status::Reveal1, Errors::WRONG_STATUS);
            assert(get_caller_address() == self.player1.read(), Errors::WRONG_SENDER);
            
            let computed_hash = compute_keccak_byte_array(@secret);
            assert(computed_hash == self.hash1.read(), Errors::WRONG_SECRET);

            self.secret1.write(secret);
            self.status.write(Status::Win);
        }

        /// Player0 redeems if player1 never revealed after end_reveal.
        fn redeem0_noreveal1(ref self: ContractState) {
            assert(self.status.read() == Status::Reveal1, Errors::WRONG_STATUS);

            let current_block = get_block_info().unbox().block_number;
            assert(current_block > self.end_reveal.read(), Errors::DEADLINE_NOT_PASSED);
            
            self._transfer_all(self.player0.read());
            self.status.write(Status::End);
            
        }

        /// Anyone triggers winner computation once both secrets are revealed.
        /// Winner formula: (secret0 + secret1) % 2 == 0 → player0, else player1
        fn win(ref self: ContractState) {
            assert(self.status.read() == Status::Win, Errors::WRONG_STATUS);

            let l0: u256 = self.secret0.read().len().into();
            let l1: u256 = self.secret1.read().len().into();

            // mirrors: if ((l0+l1) % 2 == 0) winner = player0; else winner = player1;
            let winner = if ((l0 + l1) % 2) == 0 {
                self.player0.read()
            } else {
                self.player1.read()
            };

            self.winner.write(winner);   
            
            let token   = IERC20Dispatcher { contract_address: self.token.read() };
            let balance = token.balance_of(get_contract_address());
            let success = token.transfer(winner, balance);
            assert(success, Errors::TRANSFER_FAILED);
            self.status.write(Status::End);

        }
    }

    // ---------------------------------------------------------------------------
    // Internal
    // ---------------------------------------------------------------------------
    #[generate_trait]
    impl InternalImpl of InternalTrait {
        fn _transfer_all(ref self: ContractState, to: ContractAddress) {
            let token   = IERC20Dispatcher { contract_address: self.token.read() };
            let balance = token.balance_of(get_contract_address());
            let success = token.transfer(to, balance);
            assert(success, Errors::TRANSFER_FAILED);
        }
    }
}
