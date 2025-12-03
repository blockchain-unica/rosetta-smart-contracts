# HTLC

## State variables

```py
MAX_REVEAL_KEY_SIZE: constant(uint256) = 64
receiver: public(address)
committer: public(address)
hashlock: public(bytes32)
deadline: public(uint256)
```
- `MAX_REVEAL_KEY_SIZE` — the maximum length of the preimage of the hash.
- `committer` — the address that deploys the contract and locks the funds using a hashlock.
- `receiver` — the beneficiary who receives the funds if the committer does not reveal the secret in time.
- `hashlock` — a commitment hash (`keccak256(secret)`) that must be satisfied by providing the correct reveal key.
- `deadline` — the block number after which the committer can no longer claim funds and the receiver may withdraw them.

## Initialization

```py 
@payable
@deploy
def __init__(_receiver: address, _delay: uint256, _hash: bytes32):
    assert msg.value > 0, "ETH sent is zero"
    assert msg.sender != _receiver, "Committer and receiver share the same address"

    self.committer = msg.sender 
    self.receiver = _receiver
    self.deadline = block.number + _delay
    self.hashlock = _hash 
```

This **payable constructor** function initializes the HTLC and locks ETH in the contract at deployment time. Deployment is always performed by the committer, who deposits the collateral.

It first ensures:
- ETH sent is positive (`msg.value > 0`)
- The committer and receiver addresses are different

## reveal

```py
@nonreentrant 
@external
def reveal(_reveal_key: String[MAX_REVEAL_KEY_SIZE]):
    assert msg.sender == self.committer, "Only the committer"
    assert block.number < self.deadline, "Deadline reached, cannot reveal"
    assert keccak256(convert(_reveal_key, Bytes[MAX_REVEAL_KEY_SIZE])) == self.hashlock, "Invalid reveal key"
    assert self.balance > 0, "Balance is zero"

    send(self.committer, self.balance)
    assert self.balance == 0, "Transaction error"
```
The **reveal** function allows the _committer_ to reclaim their locked funds, but only if they provide the correct secret before deadline is reached.
This function only accept one argument, the 

Requirements:
- Only the committer can call it
- The current block must be before the deadline
- The provided secret (`_reveal_key`) must satisfy the hashlock (`keccak256(_reveal_key) == hashlock`)
- The contract balance must not be zero

If all conditions hold:
- The whole balance is sent to the committer

## timeout

```py
@nonreentrant
@external
def timeout():
    assert block.number > self.deadline, "Deadline not reached"
    assert self.balance > 0, "Balance is zero"

    send(self.receiver, self.balance)
    assert self.balance == 0, "Transaction error"
```

The **timeout** function allows the _receiver_ to claim the entire contract balance if the committer does not reveal the secret before the deadline.
This failure to reveal may be either:
- **Unintentional** — the committer loses access to the secret or misses the deadline
- **Intentional** — the committer deliberately withholds the secret to forfeit the locked ETH, effectively treating the contract as a conditional payment mechanism

Before releasing the funds, the function verifies:
- The current block number is strictly greater than the deadline
- The contract still holds a positive balance

If both conditions are met, the function transfers the locked ETH to the receiver.

## Differences between the Vyper and Solidity implementations

The logic mirrors the Solidity implementation, with minor differences due to Vyper constraints, such as the need to define a maximum size for dynamically stored data at compile time.




