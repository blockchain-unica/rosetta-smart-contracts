# Token transfer

The contract TokenTransfer allows a user (the *owner*)
to transfer an amount of token to the contract, 
and another user (the *recipient*) to withdraw.

At contract creation, the owner specifies the receiver's address and the token address.

After contract creation, the contract allows two actions:
- **deposit**, which allows the owner to deposit an arbitrary amount of tokens
in the contract;
- **withdraw**, which allows the receiver to withdran 
any amount of the token deposited in the contract.

Note: in EVM based systems, the token is implemented by importing an Openzeppelin ERC20 token. 
This implies that the deposit function of the TokenTransfer can be activated only after calling 
the ERC20's "approve" function to specify the address of the TokenTransfer.

