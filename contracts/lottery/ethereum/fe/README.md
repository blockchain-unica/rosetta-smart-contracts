# Lottery

This contract acts as an intermediary between two users that commit an equal amount of native cryptocurrency. To achieve fairness both players first commit to the hash of the secret, then reveal their secret (which must be a preimage of the committed hash), and finally the winner is computed as a fair function of the secrets.

## Initialization

`pub fn __init__(mut self, ctx: Context)`

At deploy time the contract doesn't take any parameter and just sets the owner as the deployer, and sets up static timeouts for fairness in case one of the two players does not act honestly.

## Enum

This contract makes a wide use of *enums* that in Fe are verbose and complex to use as seen in previous contracts like Escrow.

In this contract, every function changes a variable that holds the Status of the contract, to ensure only the correct one can be called at any time, since there is a specific order in which things are supposed to happen in a Lottery protocol.

## Technical challenges

Fe does not support public variables yet, so this contract doesn't make use of it.

Below the error:

`pub owner: address
^^^^^^^^^^^^^^^^^^ not yet implemented`

Also, I experienced the same problems with keccak256 as explained in HTLC.

## Execution

After the contract is deployed, 9 functions can be called.

### join0(h: u256)

This function checks the contract to be in the correct status and if the joining player is sending more than zero Wei. After that, sets them as player0, takes the *h* parameter (hash) and stores it, then updates the status to let player1 join and sets the bet to the value that player1 needs to send (equal to player0's).

### join1(h: u256)

This function checks the contract to be in the correct status and if the parameter *h* (hash) provided is different from player0's. Player1 is set as the caller of the function. After that, it checks the amount of ETH sent matches player0's, then updates the status to let player0 reveal their secret.

### redeem0_nojoin1()

This function checks the contract to be in the correct status and if time has expired. This function has to be callable only if Player1 does not join in order to give back to Player0 their bet.

After that, the lottery is set in a END state, and the contract is no longer usable.

### reveal0(s: Array<u8, 32>)

This function checks the contract to be in the correct status and can be called only by player0.

Player0 needs to send the parameter *s* which contains the secret, and is checked to match the hash provided previously.

After reveal is successful, the state is put in REVEAL_1, which means it's Player1's turn to reveal their secret.

### redeem1_noreveal0()

This function checks the contract to be in the correct status of waiting for player0 reveal and if time has expired. This function has to be callable only if Player0 does not reveal in time in order to give back to Player1 the whole pot.

After that, the lottery is set in a END state, and the contract is no longer usable.

### reveal1(s: Array<u8, 32>)

This function checks the contract to be in the correct status and can be called only by player1.

Player1 needs to send the parameter *s* which contains the secret, and is checked to match the hash provided previously.

After reveal is successful, the state is put in WIN, which means it's time to call win() function to see who is the winner of the lottery.

### redeem0_noreveal1()

This function checks the contract to be in the correct status of waiting for player1 reveal and if time has expired. This function has to be callable only if Player1 does not reveal in time in order to give back to Player0 the whole pot.

After that, the lottery is set in a END state, and the contract is no longer usable.

### win()

This function is callable only after player1 revealed his secret, which means both players revealed their secrets. Now it's time to randomize the winner.

To prevent overflow, I calculate the module (%) of each secret, then I sum then and do again module (%) operation. If this leaves us with a zero, player0 won, otherwise, player1 won. The winner immediately gets the whole pot and the contract is set to END state and is no longer usable.
