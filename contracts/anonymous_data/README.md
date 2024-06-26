# Anonymous data

## Specification

The anonymous data allows multiple users to store data inside a smart contract. Data is associated with a cryptographic hash in a way that only the user who can generate that hash can retrieve it.

Once the smart contract is deployed, the following actions are possible:

- **getID**: the user gets the cryptographic hash of their address, salted with a freely chosen nonce passed as an argument.
- **storeData**: if data is not already associated, the user associates binary data to their ID, as obtained with getID.
- **getMyData**: the user passes the nonce used to generate the ID and retrieves the stored data.

Note: a user can always use a new nonce to generate a new ID and store new data.

## Expected Features

- Abort conditions
- Hash


## Implementations

- **Solidity/Ethereum**:  implementation coherent with the specification. Uses all features (the hashing process uses the built in encoding funtion to combine the user's address with the nonce). 
- **Anchor/Solana**: 
- **Aiken/Cardano**:
- **PyTeal/Algorand**:
- **SmartPy/Tezos**:
- **Move/Aptos**:
