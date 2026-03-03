#[cfg(test)]
mod tests {
    use snforge_std::{
        declare, ContractClassTrait, DeclareResultTrait,
        start_cheat_caller_address, stop_cheat_caller_address,
        start_cheat_block_number, stop_cheat_block_number,
        CheatSpan, cheat_caller_address,
        Token, TokenImpl, TokenTrait, set_balance,
    };

    use starknet::{ContractAddress, get_block_info};
    use token_transfer::htlc::{IHTLCDispatcher, IHTLCDispatcherTrait, IHTLCSafeDispatcher, IHTLCSafeDispatcherTrait};

    use openzeppelin::token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
    use core::poseidon::poseidon_hash_span;
    use core::keccak::compute_keccak_byte_array;


    const MIN_DEPOSIT: u256 = 1_000_000_000_000_000_000_u256;

    fn addr(x: felt252) -> ContractAddress {
        x.try_into().unwrap()
    }

    /// Deploys HTLC while satisfying "constructor pulls collateral":
    /// 1) fund owner
    /// 2) precalculate HTLC address
    /// 3) owner approves HTLC address
    /// 4) cheat constructor caller so owner is set correctly
    /// 5) deploy
    fn deploy_htlc(
        owner: ContractAddress,
        receiver: ContractAddress,
        secret: ByteArray,
        delay: u64,
        amount: u256,
    ) -> (ContractAddress, ContractAddress) {
        // Predeployed ETH token in snforge
        let token_enum = Token::ETH;
        let token_addr = token_enum.contract_address();

        // Fund owner
        set_balance(owner, amount, token_enum);

        // Compute committed hash (Poseidon over [secret])
        let hash = compute_keccak_byte_array(@secret);

        // Declare contract class
        let class = declare("HTLC").unwrap().contract_class();

        // Serialize constructor calldata:
        // constructor(receiver, hash, delay, amount, token)
        let mut calldata: Array<felt252> = array![];
        receiver.serialize(ref calldata);
        hash.serialize(ref calldata);
        delay.serialize(ref calldata);
        amount.serialize(ref calldata);
        token_addr.serialize(ref calldata);

        // Precalculate HTLC address so we can approve it before deploy
        let predicted = class.precalculate_address(@calldata);

        // owner approves predicted HTLC address
        start_cheat_caller_address(token_addr, owner);
        let mut token = IERC20Dispatcher { contract_address: token_addr };
        let ok = token.approve(predicted, amount);
        assert(ok, 'approve failed');
        stop_cheat_caller_address(token_addr);

        // Cheat constructor caller so owner := get_caller_address() == owner
        // Only for the constructor call (1 target call)
        cheat_caller_address(predicted, owner, CheatSpan::TargetCalls(1));

        // Deploy (must be the very next deployment for precalculated address to match)
        let (deployed, _) = class.deploy(@calldata).unwrap();
        assert(deployed == predicted, 'unexpected deployed address');

        (deployed, token_addr)
    }

    #[test]
    fn reveal_success_owner_redeems_all() {
        let owner = addr(0x111);
        let receiver = addr(0x222);
        let secret: ByteArray = "12345";
        let amount = MIN_DEPOSIT;
        let delay: u64 = 100;

        let (htlc_addr, token_addr) = deploy_htlc(owner, receiver, secret.clone(), delay, amount);

        // Sanity: HTLC has the collateral
        let token = IERC20Dispatcher { contract_address: token_addr };
        let bal = token.balance_of(htlc_addr);
        assert(bal == amount, 'collateral not locked');

        // Owner reveals
        start_cheat_caller_address(htlc_addr, owner);
        let htlc = IHTLCDispatcher { contract_address: htlc_addr };
        htlc.reveal(secret);
        stop_cheat_caller_address(htlc_addr);

        // HTLC drained
        let bal_after = token.balance_of(htlc_addr);
        assert(bal_after == 0_u256, 'htlc not drained');
    }

    #[test]
    fn timeout_success_after_deadline_receiver_gets_all() {
        let owner = addr(0x111);
        let receiver = addr(0x222);
        let secret: ByteArray = "777";
        let amount = MIN_DEPOSIT;
        let delay: u64 = 10;

        let (htlc_addr, token_addr) = deploy_htlc(owner, receiver, secret, delay, amount);

        let htlc = IHTLCDispatcher { contract_address: htlc_addr };
        let token = IERC20Dispatcher { contract_address: token_addr };

        // Move block number past reveal_timeout
        let current_block = get_block_info().unbox().block_number;
        start_cheat_block_number(htlc_addr, current_block + delay + 1);

        // Anyone can call timeout (no caller cheat needed)
        htlc.timeout();

        stop_cheat_block_number(htlc_addr);

        // Receiver should have received funds
        let recv_bal = token.balance_of(receiver);
        assert(recv_bal >= amount, 'receiver did not get funds');

        let contract_bal = token.balance_of(htlc_addr);
        assert(contract_bal == 0_u256, 'htlc not drained');
    }

    // ----------------------------
    // Failure cases (SafeDispatcher)
    // ----------------------------

    #[test]
    #[feature("safe_dispatcher")]
    fn reveal_fails_if_not_owner() {
        let owner = addr(0x111);
        let receiver = addr(0x222);
        let attacker = addr(0x333);
        let secret: ByteArray = "999";
        let amount = MIN_DEPOSIT;
        let delay: u64 = 100;

        let (htlc_addr, _) = deploy_htlc(owner, receiver, secret.clone(), delay, amount);

        // attacker tries to reveal
        start_cheat_caller_address(htlc_addr, attacker);
        let htlc = IHTLCSafeDispatcher { contract_address: htlc_addr };
        let res = htlc.reveal(secret);
        stop_cheat_caller_address(htlc_addr);

        assert(res.is_err(), 'expected error');
    }

    #[test]
    #[feature("safe_dispatcher")]
    fn reveal_fails_if_wrong_secret() {
        let owner = addr(0x111);
        let receiver = addr(0x222);
        let secret: ByteArray = "123";
        let wrong_secret: ByteArray = "456";
        let amount = MIN_DEPOSIT;
        let delay: u64 = 100;

        let (htlc_addr, _) = deploy_htlc(owner, receiver, secret, delay, amount);

        start_cheat_caller_address(htlc_addr, owner);
        let htlc = IHTLCSafeDispatcher { contract_address: htlc_addr };
        let res = htlc.reveal(wrong_secret);
        stop_cheat_caller_address(htlc_addr);

        assert(res.is_err(), 'expected invalid secret');
    }

    #[test]
    #[feature("safe_dispatcher")]
    fn timeout_fails_if_too_early() {
        let owner = addr(0x111);
        let receiver = addr(0x222);
        let secret: ByteArray = "1";
        let amount = MIN_DEPOSIT;
        let delay: u64 = 50;

        let (htlc_addr, _) = deploy_htlc(owner, receiver, secret, delay, amount);

        let htlc = IHTLCSafeDispatcher { contract_address: htlc_addr };
        let res = htlc.timeout();
        assert(res.is_err(), 'expected deadline not reached');
    }

    #[test]
    fn deploy_fails_if_below_min_deposit() {
        let owner = addr(0x111);
        let receiver = addr(0x222);
        let secret: felt252 = 42;
        let delay: u64 = 10;
        let amount: u256 = (MIN_DEPOSIT - 1_u256);

        // Predeployed ETH token
        let token_enum = Token::ETH;
        let token_addr = token_enum.contract_address();

        // Fund owner (even though it's below min, to isolate the failure reason)
        set_balance(owner, amount, token_enum);

        let hash = poseidon_hash_span(array![secret].span());
        let class = declare("HTLC").unwrap().contract_class();

        let mut calldata: Array<felt252> = array![];
        receiver.serialize(ref calldata);
        hash.serialize(ref calldata);
        delay.serialize(ref calldata);
        amount.serialize(ref calldata);
        token_addr.serialize(ref calldata);

        // Need predicted address to approve (even though constructor should fail before transfer_from)
        let predicted = class.precalculate_address(@calldata);

        start_cheat_caller_address(token_addr, owner);
        let mut token = IERC20Dispatcher { contract_address: token_addr };
        let _ = token.approve(predicted, amount);
        stop_cheat_caller_address(token_addr);

        cheat_caller_address(predicted, owner, CheatSpan::TargetCalls(1));

        let res = class.deploy(@calldata);
        assert(res.is_err(), 'expected deploy to fail');
    }
}