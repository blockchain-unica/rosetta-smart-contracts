**Anonymous Data**
This smart contract is designed to implement the recording of personal data anonymously.

## Specification
The Producer generates data that must be associated with a user anonymously (without using his address) so that only the
user knows that the data belongs to him.
The user owns his address but must never reveal it.
Through the smart contract, the user generates an ID (a hash of its address combined with a nonce of your choice).
The user communicates off-chain the ID to the Producer.
The Producer will associate on-chain the produced data with the user ID.

The user will always be able to read the data by reconstructing the ID via the nonce and without a transaction 
being validated in blockchain.
The manufacturer will be able to access all data anonymously.


In this use case, we define two actors: User, Producer
After creation, the following sequence of actions is possible:
- **Create ID**. Actor: Owner1.
-  ... 