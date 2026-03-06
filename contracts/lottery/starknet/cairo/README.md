# Lottery

### State Machine

The contract progresses through these states:

```cairo
pub enum Status {
    Join0,    // waiting for player0
    Join1,    // waiting for player1
    Reveal0,  // waiting for player0 to reveal
    Reveal1,  // waiting for player1 to reveal
    Win,      // both revealed, waiting for win() call
    End,      // finished
}
```

| Status    | Meaning                                                |
| --------- | ------------------------------------------------------ |
| `Join0`   | Waiting for Player0 to deposit and commit              |
| `Join1`   | Waiting for Player1 to match the bet and commit        |
| `Reveal0` | Waiting for Player0 to reveal secret                   |
| `Reveal1` | Waiting for Player1 to reveal secret                   |
| `Win`     | Both secrets revealed; anyone can compute & pay winner |
| `End`     | Contract finished; funds distributed                   |

### Betting Rules

- **Minimum bet**: `MIN_BET = 0.01` (expressed in token units)
- Player0 chooses the bet amount (must be > `MIN_BET`)
- Player1 must deposit **exactly the same amount**
- Player1’s committed hash must be **different** from Player0’s hash

## Storage variables

```cairo
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
```

| Field        | Type              | Description                                            |
| ------------ | ----------------- | ------------------------------------------------------ |
| `owner`      | `ContractAddress` | Contract deployer                                      |
| `token`      | `ContractAddress` | ERC20 token used for bets                              |
| `player0`    | `ContractAddress` | First player to join                                   |
| `player1`    | `ContractAddress` | Second player to join                                  |
| `winner`     | `ContractAddress` | Address of the winner — set by `win()`                 |
| `hash0`      | `u256`            | `keccak256` commitment from player0                    |
| `hash1`      | `u256`            | `keccak256` commitment from player1                    |
| `secret0`    | `ByteArray`       | Revealed secret from player0                           |
| `secret1`    | `ByteArray`       | Revealed secret from player1                           |
| `bet_amount` | `u256`            | Bet amount set by player0 — player1 must match exactly |
| `status`     | `Status`          | Current lifecycle state                                |
| `end_join`   | `u64`             | Absolute block deadline for player1 to join            |
| `end_reveal` | `u64`             | Absolute block deadline for both players to reveal     |

## Constructor

```cairo
fn constructor(
    ref self: ContractState,
    token: ContractAddress,
) {
    self.owner.write(get_caller_address());
    self.token.write(token);
    self.status.write(Status::Join0);
    let current_block = get_block_info().unbox().block_number;
    let end_join = current_block + 1000;
    self.end_join.write(end_join);
    self.end_reveal.write(end_join + 1000);
}
```

- Caller becomes the `owner`
- Initial status is `Join0`

Deadlines are set at deployment:

- `end_join = current_block + 1000`
- `end_reveal = end_join + 1000`

Meaning:

- Player1 must join before `end_join`
- Secrets must be revealed before `end_reveal`

### Secret Type

Secrets are passed as `ByteArray`(equivalent to string in Cairo), so the commitment is over **bytes**.

## Player0 Joins

```cairo
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
```

Requirements:

- Status = `Join0`
- `amount > MIN_BET`

Actions:

- Transfers `amount` from Player0 to the contract (`transfer_from`)
- Stores `player0`, `hash0`, `bet_amount`
- Status → `Join1`

## Player1 Joins

```cairo
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
```

Requirements:

- Status = `Join1`
- `hash != hash0`
- `amount == bet_amount`

Actions:

- Transfers `amount` from Player1 to the contract
- Stores `player1`, `hash1`
- Status → `Reveal0`

## Refund if Player1 Never Joins

```cairo
fn redeem0_nojoin1(ref self: ContractState) {
    assert(self.status.read() == Status::Join1, Errors::WRONG_STATUS);
    let current_block = get_block_info().unbox().block_number;
    assert(current_block > self.end_join.read(), Errors::DEADLINE_NOT_PASSED);
    self._transfer_all(self.player0.read());
    self.status.write(Status::End);

}
```

Requirements:

- Status = `Join1`
- `current_block > end_join`

Action:

- Transfers the entire pot back to Player0
- Status → `End`

## Player0 Reveals

```cairo
fn reveal0(ref self: ContractState, secret: ByteArray) {
    assert(self.status.read() == Status::Reveal0, Errors::WRONG_STATUS);
    assert(get_caller_address() == self.player0.read(), Errors::WRONG_SENDER);
    let computed_hash = compute_keccak_byte_array(@secret);
    assert(computed_hash == self.hash0.read(), Errors::WRONG_SECRET);
    self.secret0.write(secret);
    self.status.write(Status::Reveal1);
}
```

Requirements:

- Status = `Reveal0`
- Caller is Player0
- `keccak256(secret) == hash0`

Action:

- Stores `secret0`
- Status → `Reveal1`

## Refund if Player0 Never Reveals

```cairo
fn redeem1_noreveal0(ref self: ContractState) {
    assert(self.status.read() == Status::Reveal0, Errors::WRONG_STATUS);
    let current_block = get_block_info().unbox().block_number;
    assert(current_block > self.end_reveal.read(), Errors::DEADLINE_NOT_PASSED);

    self._transfer_all(self.player1.read());
    self.status.write(Status::End);
}
```

Requirements:

- Status = `Reveal0`
- `current_block > end_reveal`

Action:

- Transfers the entire pot to Player1
- Status → `End`

## Player1 Reveals

```cairo
fn reveal1(ref self: ContractState, secret: ByteArray) {
    assert(self.status.read() == Status::Reveal1, Errors::WRONG_STATUS);
    assert(get_caller_address() == self.player1.read(), Errors::WRONG_SENDER);

    let computed_hash = compute_keccak_byte_array(@secret);
    assert(computed_hash == self.hash1.read(), Errors::WRONG_SECRET);
    self.secret1.write(secret);
    self.status.write(Status::Win);
}
```

Requirements:

- Status = `Reveal1`
- Caller is Player1
- `keccak256(secret) == hash1`

Action:

- Stores `secret1`
- Status → `Win`

## Refund if Player1 Never Reveals

```cairo
fn redeem0_noreveal1(ref self: ContractState) {
    assert(self.status.read() == Status::Reveal1, Errors::WRONG_STATUS);
    let current_block = get_block_info().unbox().block_number;
    assert(current_block > self.end_reveal.read(), Errors::DEADLINE_NOT_PASSED);

    self._transfer_all(self.player0.read());
    self.status.write(Status::End);

}
```

Requirements:

- Status = `Reveal1`
- `current_block > end_reveal`

Action:

- Transfers the entire pot to Player0
- Status → `End`

## Win

```cairo
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
```

Requirements:

- Status = `Win`

Winner rule (as implemented):

- Compute `l0 = len(secret0)` and `l1 = len(secret1)`
- If `(l0 + l1) % 2 == 0` → **Player0 wins**
- Else → **Player1 wins**

Actions:

- Sets `winner`
- Transfers entire contract balance to `winner`
- Status → `End`

This is a simple deterministic rule based on secret lengths.
