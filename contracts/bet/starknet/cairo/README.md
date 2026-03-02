# Bet Smart Contract (Starknet / Cairo)

---

## State variables

```py
player1	Deployer and first participant
player2	Second participant (zero address if absent)
oracle	Trusted resolver
wager	Stake amount
deadline	Block-based expiration
token	ERC-20 token used for transfers
```

## Token

Unlike Ethereum L1 contracts, Starknet contracts do not receive native ETH via payable.

All value transfers are executed using ERC-20 tokens:

```py
transfer_from(sender, contract, amount)
transfer(recipient, amount)
```

Cairo requires explicit interfaces when interacting with contracts:
`IERC20Dispatcher { contract_address: token }`
This replaces Solidity’s implicit contract calls.

## Contract Deployment

```py
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
```

The contract is deployed by **Player 1**.

During deployment:

- `player1` becomes the deployer (`get_caller_address()`)
- the oracle address is stored
- the wager amount is fixed
- a deadline is computed
- Player 1 immediately deposits their wager

Constructor parameters:

| Parameter | Description                                       |
| --------- | ------------------------------------------------- |
| `oracle`  | Address allowed to declare the winner             |
| `timeout` | Number of blocks before timeout becomes available |
| `wager`   | Token amount each player must deposit             |
| `token`   | ERC-20 token used for the bet                     |

## join()

```py
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
```

Called by **player2** to enter the bet. Pulls `wager` tokens from player2.
`contract_address_const::<0>()` is equal to `address(0)` in soldity which stays for null address

Reverts if:

- Player2 has already joined
- The deadline has passed
- Player2 has not approved the contract for the correct amount

## win

```py
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
```

Called by the **oracle** only. `winner` must be `0` (player1) or `1` (player2). Transfers the full pot (`wager × 2`) to the winner.

Reverts if:

- Caller is not the oracle
- Player2 has not joined yet
- `winner` is not `0` or `1`

## timeout

```py
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
```

Callable by **anyone** after the deadline has passed. Refunds player1 always, and player2 only if they had joined.

Reverts if:

- The deadline has not been reached yet
