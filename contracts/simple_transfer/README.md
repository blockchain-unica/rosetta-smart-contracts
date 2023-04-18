# Simple transfer

The contract SimpleTransfer allows a user (the *owner*)
to deposit native cryptocurrency
in the contract, and another user (the *recipient*) to withdraw.

At contract creation, the owner specifies the receiver's address.

After contract creation, the contract allows two actions:
- **deposit**, which allows the owner to deposit an arbitrary amount of native
cryptocurrency in the contract;
- **withdraw**, which allows the receiver to withdran 
any amount of the cryptocurrency deposited in the contract.
