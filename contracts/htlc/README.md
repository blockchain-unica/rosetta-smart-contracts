# HTLC

## Specification

The Hash Timed Locked Contract (HTLC) involves two users,
allows one participant to commit to a secret and reveal it afterwards.
The commit is the Keccak-256 digest of the secret (a bitstring).
At contract creation, the committer:
- deposits a collateral (in native cryptocurrency) in the contract;
- specifies a deadline for the secret revelation, in terms of a delay from the publication of the contract;
- specifies the receiver of the collateral, 
in case the deposit is not revealed within the deadline.

After contract creation, the HTLC allows two actions:
- **reveal**, which requires the caller to provide a preimage of the commit,
and tranfers the whole contract balance to the committer;
- **timeout**, which can be called only after the deadline, and tranfers the whole contract balance to the receiver.

## Implementations

- **Solidity/Ethereum**: implementation coherent with the specification.
- **Anchor/Solana**: a step has been added for initializing the data of the contract (owner, verifier, deadline, etc.).
- **Aiken/Cardano**: implementation coherent with the specification.
- **PyTeal/Algorand**: TODO lore
- **SmartPy/Tezos**:
- **Move/Aptos**: implementation coherent with the specification.
