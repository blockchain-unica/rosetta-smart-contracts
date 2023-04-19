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
- **timeout**, which can be called only after the deadline, and
and tranfers the whole contract balance to the receiver.

## Execution traces

### Trace 1

1. The committer creates the contract, setting a deadline of 100 rounds;
1. After 50 rounds, A performs the **reveal** action.

### Trace 2

1. The committer creates the contract, setting a deadline of 100 rounds;
1. After 100 rounds, the receiver performs the **timeout** action.