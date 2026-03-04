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

### Deadlines

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
join0(hash: u256, amount: u256)
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
join1(hash: u256, amount: u256)
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
redeem0_nojoin1()
```

Requirements:

- Status = `Join1`
- `current_block > end_join`

Action:

- Transfers the entire pot back to Player0
- Status → `End`

## Player0 Reveals

```cairo
reveal0(secret: ByteArray)
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
redeem1_noreveal0()
```

Requirements:

- Status = `Reveal0`
- `current_block > end_reveal`

Action:

- Transfers the entire pot to Player1
- Status → `End`

## Player1 Reveals

```cairo
reveal1(secret: ByteArray)
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
redeem0_noreveal1()
```

Requirements:

- Status = `Reveal1`
- `current_block > end_reveal`

Action:

- Transfers the entire pot to Player0
- Status → `End`

## Win

```cairo
win()
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
