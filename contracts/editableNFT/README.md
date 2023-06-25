# Editable Non Fungible Token

## Specification
This contract implements a non fungible token characterized by simple editable data.
Each token is identified by its ID. It contains a arbitrary long data and a boolean variable to seal the token.
The token is editable by its owner until he seals it.

In this use case, we define two actors: Owner1, Onwer2
After creation, the following sequence of actions is possible:
- **Buy a token**. Actor: Owner1.
This action is intended for minting a new token with empty data and assigning ownership to Owner 1.
After this action, a new token with ID = 1 is assigned to Owner1.

- **Edit Token**. Actor: Owner1
This action is intended to allow the current owner to change the byte sequence in the data field of the token.
Owner1 performs this action by passing the token ID and the sequence of bytes he wants to store in the token.
This action is only possible if the token is not already sealed.

- **Tranfer to**. Actor: Owner1.
This action is intended to change the ownership of a token. In particular, Owner1 performs this action.
to transfer the ownership of the token with ID 1 to Owner2.

- **Seal Token**. Actor: Owner2
This action is intended to allow the current owner to seal a specific token.
Owner2 seals a token by passing the token ID of the token he wants to seal.


Note: in EVM based systems, the token is implemented by importing an Openzeppelin ERC721 token.