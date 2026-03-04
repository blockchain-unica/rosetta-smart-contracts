use starknet::{ContractAddress};

#[starknet::interface]
pub trait IAuction<TContractState> {
    fn start(ref self: TContractState, duration: u64);
    fn bid(ref self: TContractState, amount: u256);
    fn withdraw(ref self: TContractState);
    fn end(ref self: TContractState);
}

#[starknet::contract]
pub mod Auction {
    use openzeppelin::token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
    use starknet::{ContractAddress, get_caller_address, get_contract_address, get_block_info};
    use starknet::storage::{
        StoragePointerReadAccess, StoragePointerWriteAccess,
        Map, StorageMapReadAccess, StorageMapWriteAccess,
    };
    use super::IAuction;

    const WAIT_START: u8   = 0;
    const WAIT_CLOSING: u8 = 1;
    const CLOSED: u8       = 2;

    #[storage]
    struct Storage {
        seller: ContractAddress,
        token: ContractAddress,
        object: felt252,           // notarization string as felt252
        state: u8,
        highest_bidder: ContractAddress,
        highest_bid: u256,
        end_block: u64,
        bids: Map<ContractAddress, u256>,  // mapping of pending withdrawals
    }

    mod Errors {
        pub const ONLY_SELLER: felt252          = 'only the seller';
        pub const ALREADY_STARTED: felt252      = 'auction already started';
        pub const NOT_STARTED: felt252          = 'auction not started';
        pub const NOT_OPEN: felt252             = 'auction not started or closed';
        pub const BIDDING_EXPIRED: felt252      = 'bidding time expired';
        pub const BID_TOO_LOW: felt252          = 'bid must beat highest bid';
        pub const AUCTION_NOT_ENDED: felt252    = 'auction not ended yet';
        pub const TRANSFER_FAILED: felt252      = 'transfer failed';
        pub const NOTHING_TO_WITHDRAW: felt252  = 'nothing to withdraw';
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        object: felt252,
        starting_bid: u256,
        token: ContractAddress,
    ) {
        self.seller.write(get_caller_address());
        self.token.write(token);
        self.object.write(object);
        self.highest_bid.write(starting_bid);
        self.state.write(WAIT_START);
    }

    #[abi(embed_v0)]
    impl AuctionImpl of IAuction<ContractState> {

        fn start(ref self: ContractState, duration: u64) {
            assert(get_caller_address() == self.seller.read(), Errors::ONLY_SELLER);
            assert(self.state.read() == WAIT_START, Errors::ALREADY_STARTED);

            let current_block = get_block_info().unbox().block_number;
            self.end_block.write(current_block + duration);
            self.state.write(WAIT_CLOSING);
        }

        fn bid(ref self: ContractState, amount: u256) {
            assert(self.state.read() == WAIT_CLOSING, Errors::NOT_OPEN);

            let current_block = get_block_info().unbox().block_number;
            assert(current_block < self.end_block.read(), Errors::BIDDING_EXPIRED);
            assert(amount > self.highest_bid.read(), Errors::BID_TOO_LOW);

            let caller = get_caller_address();
            let token  = IERC20Dispatcher { contract_address: self.token.read() };

            // pull the new bid from the caller into the contract
            let success = token.transfer_from(caller, get_contract_address(), amount);
            assert(success, Errors::TRANSFER_FAILED);

            // store previous highest bidder's bid so they can withdraw
            let prev_highest_bidder = self.highest_bidder.read();
            if prev_highest_bidder != starknet::contract_address_const::<0>() {
                let prev_amount = self.highest_bid.read();
                let existing   = self.bids.read(prev_highest_bidder);
                self.bids.write(prev_highest_bidder, existing + prev_amount);
            }

            // if caller had a pending withdrawal, refund it automatically
            let pending = self.bids.read(caller);
            if pending > 0 {
                self.withdraw();
            }

            self.highest_bidder.write(caller);
            self.highest_bid.write(amount);
        }

        fn withdraw(ref self: ContractState) {
            assert(self.state.read() != WAIT_START, Errors::NOT_STARTED);

            let caller = get_caller_address();
            let bal    = self.bids.read(caller);
            assert(bal > 0, Errors::NOTHING_TO_WITHDRAW);

            self.bids.write(caller, 0);

            let token   = IERC20Dispatcher { contract_address: self.token.read() };
            let success = token.transfer(caller, bal);
            assert(success, Errors::TRANSFER_FAILED);
        }

        fn end(ref self: ContractState) {
            assert(get_caller_address() == self.seller.read(), Errors::ONLY_SELLER);
            assert(self.state.read() == WAIT_CLOSING, Errors::NOT_STARTED);

            let current_block = get_block_info().unbox().block_number;
            assert(current_block >= self.end_block.read(), Errors::AUCTION_NOT_ENDED);

            self.state.write(CLOSED);

            let highest_bid    = self.highest_bid.read();
            let token          = IERC20Dispatcher { contract_address: self.token.read() };
            let success        = token.transfer(self.seller.read(), highest_bid);
            assert(success, Errors::TRANSFER_FAILED);
        }
    }
}
