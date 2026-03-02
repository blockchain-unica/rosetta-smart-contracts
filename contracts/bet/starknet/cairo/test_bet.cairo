use snforge_std::{
    declare, ContractClassTrait, DeclareResultTrait,
    start_cheat_caller_address, stop_cheat_caller_address,
    start_cheat_block_number, stop_cheat_block_number,
};
use starknet::ContractAddress;
use bet::bet::{IBetDispatcher, IBetDispatcherTrait};
use bet::mock_erc20::MockERC20::{IMockERC20Dispatcher, IMockERC20DispatcherTrait};

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

fn deploy_token(player1: ContractAddress, player2: ContractAddress, wager: u256) -> IMockERC20Dispatcher {
    let contract = declare("MockERC20").unwrap().contract_class();
    let (token_address, _) = contract.deploy(@array![]).unwrap();
    let token = IMockERC20Dispatcher { contract_address: token_address };

    token.mint(player1, wager);
    token.mint(player2, wager);

    token
}

// Deploys the Bet contract as player1 (player1 deposits wager in constructor).
// player1 must have approved the bet contract before this — we handle that inside.
fn deploy_bet(
    player1: ContractAddress,
    oracle: ContractAddress,
    timeout: u64,
    wager: u256,
    token: IMockERC20Dispatcher,
) -> IBetDispatcher {
    let contract = declare("Bet").unwrap().contract_class();
    let mut calldata = array![];
    oracle.serialize(ref calldata);
    timeout.serialize(ref calldata);
    wager.serialize(ref calldata);
    token.contract_address.serialize(ref calldata);

    // Player1 must approve before the constructor pulls their wager
    start_cheat_caller_address(token.contract_address, player1);
    token.approve(get_bet_address_from_calldata(@calldata), wager);
    stop_cheat_caller_address(token.contract_address);

    // Deploy as player1 so get_caller_address() == player1 in constructor
    start_cheat_caller_address(starknet::contract_address_const::<0>(), player1);
    let (bet_address, _) = contract.deploy(@calldata).unwrap();
    stop_cheat_caller_address(starknet::contract_address_const::<0>());

    IBetDispatcher { contract_address: bet_address }
}

// Computes the address the contract will be deployed at so we can approve it
// before deployment. snforge exposes this via ContractClassTrait::precalculate_address.
fn get_bet_address_from_calldata(calldata: @Array<felt252>) -> ContractAddress {
    declare("Bet").unwrap().contract_class().precalculate_address(calldata)
}

// Full setup: deploy token + bet, approve token for bet contract, return everything.
fn setup() -> (IBetDispatcher, IMockERC20Dispatcher, ContractAddress, ContractAddress, ContractAddress) {
    let player1: ContractAddress = 'player1'.try_into().unwrap();
    let player2: ContractAddress = 'player2'.try_into().unwrap();
    let oracle: ContractAddress  = 'oracle'.try_into().unwrap();
    let wager: u256 = 1000;
    let timeout: u64 = 100;

    let token = deploy_token(player1, player2, wager);

    // Pre-approve the bet contract address before deploying
    let contract_class = declare("Bet").unwrap().contract_class();
    let mut calldata = array![];
    oracle.serialize(ref calldata);
    timeout.serialize(ref calldata);
    wager.serialize(ref calldata);
    token.contract_address.serialize(ref calldata);
    let bet_address = contract_class.precalculate_address(@calldata);

    // Player1 approves the bet contract to pull their wager in the constructor
    start_cheat_caller_address(token.contract_address, player1);
    token.approve(bet_address, wager);
    stop_cheat_caller_address(token.contract_address);

    // Deploy as player1
    start_cheat_caller_address(bet_address, player1);
    let (deployed_address, _) = contract_class.deploy(@calldata).unwrap();
    stop_cheat_caller_address(bet_address);

    let bet = IBetDispatcher { contract_address: deployed_address };

    // Player2 approves for when they call join()
    start_cheat_caller_address(token.contract_address, player2);
    token.approve(deployed_address, wager);
    stop_cheat_caller_address(token.contract_address);

    (bet, token, oracle, player1, player2)
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

#[test]
fn test_constructor_player1_deposits() {
    let (bet, token, _, player1, _) = setup();

    // Player1 wager should now be held by the contract
    assert(token.balance_of(player1) == 0, 'player1 balance should be 0');
    assert(token.balance_of(bet.contract_address) == 1000, 'contract should hold wager');
    assert(bet.get_player1() == player1, 'player1 mismatch');
}

#[test]
fn test_join_player2() {
    let (bet, token, _, _, player2) = setup();

    start_cheat_caller_address(bet.contract_address, player2);
    bet.join();
    stop_cheat_caller_address(bet.contract_address);

    assert(bet.get_player2() == player2, 'player2 should be set');
    assert(token.balance_of(player2) == 0, 'player2 balance should be 0');
    assert(token.balance_of(bet.contract_address) == 2000, 'contract should hold full pot');
}

#[test]
#[should_panic(expected: 'Player2 already joined')]
fn test_join_twice_reverts() {
    let (bet, _, _, _, player2) = setup();

    start_cheat_caller_address(bet.contract_address, player2);
    bet.join();
    bet.join(); // second call should revert
    stop_cheat_caller_address(bet.contract_address);
}

#[test]
#[should_panic(expected: 'Timeout')]
fn test_join_after_deadline_reverts() {
    let (bet, _, _, _, player2) = setup();

    // Fast-forward past the deadline
    start_cheat_block_number(bet.contract_address, 9999);
    start_cheat_caller_address(bet.contract_address, player2);
    bet.join(); // should revert
    stop_cheat_caller_address(bet.contract_address);
    stop_cheat_block_number(bet.contract_address);
}

#[test]
fn test_win_player1() {
    let (bet, token, oracle, player1, player2) = setup();

    // Player2 joins
    start_cheat_caller_address(bet.contract_address, player2);
    bet.join();
    stop_cheat_caller_address(bet.contract_address);

    let before = token.balance_of(player1);

    // Oracle picks player1 (index 0)
    start_cheat_caller_address(bet.contract_address, oracle);
    bet.win(0);
    stop_cheat_caller_address(bet.contract_address);

    assert(token.balance_of(player1) == before + 2000, 'player1 should get full pot');
    assert(token.balance_of(bet.contract_address) == 0, 'contract should be empty');
}

#[test]
fn test_win_player2() {
    let (bet, token, oracle, _, player2) = setup();

    // Player2 joins
    start_cheat_caller_address(bet.contract_address, player2);
    bet.join();
    stop_cheat_caller_address(bet.contract_address);

    let before = token.balance_of(player2);

    // Oracle picks player2 (index 1)
    start_cheat_caller_address(bet.contract_address, oracle);
    bet.win(1);
    stop_cheat_caller_address(bet.contract_address);

    assert(token.balance_of(player2) == before + 2000, 'player2 should get full pot');
}

#[test]
#[should_panic(expected: 'Only the oracle')]
fn test_win_not_oracle_reverts() {
    let (bet, _, _, _, player2) = setup();

    start_cheat_caller_address(bet.contract_address, player2);
    bet.join();
    bet.win(0); // player2 tries to call win — should revert
    stop_cheat_caller_address(bet.contract_address);
}

#[test]
#[should_panic(expected: 'Player2 has not joined')]
fn test_win_before_player2_joins_reverts() {
    let (bet, _, oracle, _, _) = setup();

    start_cheat_caller_address(bet.contract_address, oracle);
    bet.win(0); // player2 hasn't joined yet
    stop_cheat_caller_address(bet.contract_address);
}

#[test]
#[should_panic(expected: 'Invalid winner')]
fn test_win_invalid_index_reverts() {
    let (bet, _, oracle, _, player2) = setup();

    start_cheat_caller_address(bet.contract_address, player2);
    bet.join();
    stop_cheat_caller_address(bet.contract_address);

    start_cheat_caller_address(bet.contract_address, oracle);
    bet.win(2); // only 0 or 1 are valid
    stop_cheat_caller_address(bet.contract_address);
}

#[test]
fn test_timeout_only_player1() {
    // Player2 never joins — only player1 should be refunded
    let (bet, token, _, player1, _) = setup();

    let before = token.balance_of(player1);

    start_cheat_block_number(bet.contract_address, 9999);
    bet.timeout();
    stop_cheat_block_number(bet.contract_address);

    assert(token.balance_of(player1) == before + 1000, 'player1 should be refunded');
    assert(token.balance_of(bet.contract_address) == 0, 'contract should be empty');
}

#[test]
fn test_timeout_both_players() {
    let (bet, token, _, player1, player2) = setup();

    // Player2 joins
    start_cheat_caller_address(bet.contract_address, player2);
    bet.join();
    stop_cheat_caller_address(bet.contract_address);

    let p1_before = token.balance_of(player1);
    let p2_before = token.balance_of(player2);

    start_cheat_block_number(bet.contract_address, 9999);
    bet.timeout();
    stop_cheat_block_number(bet.contract_address);

    assert(token.balance_of(player1) == p1_before + 1000, 'player1 should be refunded');
    assert(token.balance_of(player2) == p2_before + 1000, 'player2 should be refunded');
    assert(token.balance_of(bet.contract_address) == 0, 'contract should be empty');
}

#[test]
#[should_panic(expected: 'The timeout has not passed')]
fn test_timeout_too_early_reverts() {
    let (bet, _, _, _, _) = setup();
    bet.timeout(); // deadline not reached yet
}
