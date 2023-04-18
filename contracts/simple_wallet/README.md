# Simple transfer

Consider a simple wallet contract involving a single owner and the use of the blockchain's native cryptocurrency. The contract acts as a cryptocurrency deposit and allows for the creation and execution of transactions to a specific address. The owner can withdraw the total amount of cryptocurrency in the balance at any time.

The owner initializes the contract, specifying the address that he intends to authorize. Subsequently, the owner can deposit a certain amount of cryptocurrency. The owner can create a transaction by specifying the recipient, the value, and the date field. After creation, the owner can execute the transaction, specifying the transaction ID. This transaction will be successful only if the balance of the contract is sufficient and if the transaction ID exists and has not yet been executed. Finally, the owner can withdraw the balance of the contract, emptying it.
