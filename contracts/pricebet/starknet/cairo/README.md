# PriceBet

## Constructor

```cairo
#[constructor]
fn constructor(
    ref self: ContractState,
    oracle: ContractAddress,
    deadline: u64,
    exchange_rate: u256,
    initial_pot: u256,
    token: ContractAddress,
)
```

Parameters:

| Parameter       | Description                                 |
| --------------- | ------------------------------------------- |
| `oracle`        | Address of the oracle contract              |
| `deadline`      | Number of blocks until expiration           |
| `exchange_rate` | Target price to win the bet                 |
| `initial_pot`   | Stake amount required from each participant |
| `token`         | ERC20 token used for the bet                |

Deployment behavior:

- The deployer becomes the **owner**.
- The owner deposits `initial_pot` tokens into the contract.
- The deadline is set as:

```cairo
deadline_block = current_block + deadline
```

The owner must approve the contract before deployment:

```cairo
token.approve(contract_address, initial_pot)
```

## Join

```cairo
fn join(amount: u256)
```

Requirements:

- No player has joined yet
- `amount` must equal `initial_pot`

Actions:

- Transfers tokens from the player to the contract
- Registers the player address

Example:

```
token.approve(contract_address, initial_pot)
price_bet.join(initial_pot)
```

---

## Win

```cairo
fn win()
```

Callable only by the **player**.

Requirements:

- Current block must be **before the deadline**
- Oracle exchange rate must be **greater than or equal to the target rate**

Actions:

- Queries the oracle:

```cairo
oracle.get_exchange_rate()
```

- If the condition is satisfied, transfers the **entire contract balance** to the player.

---

## Timeout

```cairo
fn timeout()
```

Callable after the deadline.

Requirements:

- Current block must be **greater than or equal to `deadline_block`**

Actions:

- Transfers the entire contract balance back to the owner.
