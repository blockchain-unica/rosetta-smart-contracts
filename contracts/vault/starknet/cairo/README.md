# Vault Contract

## States

The contract defines two states:

```cairo
    const IDLE: u8 = 0;
    const REQ: u8  = 1;
```

| State  | Meaning                                                          |
| ------ | ---------------------------------------------------------------- |
| `IDLE` | No withdrawal request is pending                                 |
| `REQ`  | A withdrawal request is active and waiting for the delay to pass |

## Constructor

```cairo
#[constructor]
fn constructor(
    ref self: ContractState,
    recovery: ContractAddress,
    wait_time: u64,
    token: ContractAddress,
)
```

Parameters:

| Parameter   | Description                                              |
| ----------- | -------------------------------------------------------- |
| `recovery`  | Address authorized to cancel withdrawals                 |
| `wait_time` | Number of blocks required before finalizing a withdrawal |
| `token`     | ERC20 token used by the vault                            |

Deployment effects:

- The deployer becomes the **owner**
- The vault starts in the **IDLE** state
- The vault initially contains no tokens

## Receive

```py
fn receive(amount: u256)
```

Anyone can deposit tokens into the vault.

Requirements:

- Caller must approve the vault contract to transfer tokens.

Example:

```py
token.approve(vault_address, amount)
vault.receive(amount)
```

Actions:

- Transfers tokens from caller to the vault.

## Withdraw

```py
fn withdraw(receiver: ContractAddress, amount: u256)
```

Callable only by the **owner**.

Requirements:

- Vault must be in `IDLE` state.
- Vault must have sufficient balance.

Actions:

- Records:
  - withdrawal amount
  - receiver address
  - current block number
- Changes state from `IDLE` → `REQ`.

This begins the **time-lock waiting period**.

## Finalize

```py
fn finalize()
```

Callable only by the **owner**.

Requirements:

- Vault must be in `REQ` state.
- The waiting period must have elapsed:

```py
current_block >= request_block + wait_time
```

Actions:

- Transfers tokens to the requested receiver.
- Resets state to `IDLE`.

---

## Cancel

```py
fn cancel()
```

Callable only by the **recovery key**.

Requirements:

- Vault must be in `REQ` state.

Actions:

- Cancels the pending withdrawal.
- Returns vault state to `IDLE`.

This mechanism protects funds if the owner account is compromised.
