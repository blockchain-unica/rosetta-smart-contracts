# Editable NFT

This contract simulates a NFT (custom ERC20) that is deployed on-chain and can be called to buy tokens, edit the content, transfer ownership and sealing. After sealing a NFT, it is no longer editable, but the ownership can still be transferred.

## Technical challenges

As opposed to the Solidity implementation, that uses an Openzeppelin ERC721 token, I used a custom ERC20 implementation within the contract, because Fe can't import such token as Solidity did. Nevertheless, the implementation is fully functional.

## Contract ERC20

This contract gets deployed on-chain and later on receives calls from EditableToken that modify the state of tokens.

There are 8 functions available.

### setUp(interface: address)

This function has to be called before performing any action on the contract, and ensures only the selected interface can interact with this token.

### mint(recipient: address, _token_id: u256)

This function creates a token and sets the property (whoever bought it).

### transferFrom(from: address, to: address, _tokenID: u256)

This function transfers ownership of a contract, only if the caller of the function (the from parameter) is the owner of the contract.

### token_property(_token: u256)

This function returns the address of the owner of the provided token ID.

### isSealed(_token: u256)

This function returns true or false, depending on whether the token is sealed or not.

### get_data(_token: u256)

This function retrieves the data contained inside a token, stored in bytes32 type.

### set_data(_token; u256, data: Array<u8, 32>)

This function sets the data of a token in bytes32.

## Contract EditableToken

This contract is the actual interface to edit the tokens.

### Initialization

`pub fn __init__(mut self, ctx: Context, _token_address: address)`

At deploy time the contract takes an address, that is the ERC20 implementation of the token that will be called to execute actions.

After the contract is deployed, 5 functions can be called.

### sealToken(tokenId: u256)

This function checks for property, and if the provided tokenId belongs to the caller, the token is sealed. Once the token is sealed, its data can no longer be edited.

### setTokenData(tokenId: u256, data: Array<u8, 32>)

This function ensures the sender is the owner first, and after that edits the content of the contract data in bytes32.

### buyToken()

This function generates a token (for testing purpose it's free) and assigns ownership to the caller.

### transferTo(dest: address, tokenID: u256)

This functions transfers ownership of a token. Only the owner can give away its own ownership or the token.

### getTokenData(tokenId: u256)

This function returns (only if the token exists) the information contained in the token data in bytes32 and whether is sealed or not, in a single tuple.