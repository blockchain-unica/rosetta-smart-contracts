# Escrow

## Specification

The escrow contract acts as a trusted intermediary between a buyer and a seller, aiming to protect the buyer from the possible non-delivery of the purchased goods.

The seller initializes the contract by setting:
- the buyer's address;
- the amount of native cryptocurrency required as a payment.

Immediately after the initialization, the contract supports a single action:
- **deposit**, which allows the buyer to deposit the required amount in the contract.

Once the deposit action has been performed, exactly one of the following actions is possible:
- **pay**, which allows the buyer to transfer the whole contract balance to the seller.
- **refund**, which allows the seller to transfer back the whole contract balance to the buyer.

## Required functionalities

- Native tokens
- Transaction revert


# Implementation

## State variables

```py
seller: public(address)
buyer: public(address)
amount: public(uint256)
deposited: public(bool)
payed: public(bool)
refunded: public(bool)
```
- `seller`, `buyer` —  the addresses of the parties involved in the transaction.
- `amount` — the agreed-upon payment amount
- `deposited` — a boolean flag to know whether the buyer has deposited the required funds
- `payed` — a boolean flag marking that the payment has been released to the seller
- `refunded` — A boolean flag marking whether the funds have been returned to the buyer.

## Initialization

```py
@deploy
def __init__(_buyer: address, _amount: uint256):
    self.seller = msg.sender
    self.buyer = _buyer
    self.amount = _amount
```
After deployment, the contract is initialized by setting:
- the seller (always the one who deploys the contract)
- the buyer of the product
- the amount of native cryptocurrency required for the transaction to happen

## deposit

```py
@nonreentrant
@payable
@external
def deposit():
    assert not self.deposited, "Already deposited"
    assert msg.sender == self.buyer, "Only the buyer"
    assert msg.value == self.amount, "Invalid amount"

    self.deposited = True 
```

The deposit function is marked as _@payable_, allowing the buyer to send the required amount of native tokens (ETH) to the contract.

Requirements:
- The caller must be the designated `buyer`.
- The buyer must not have already deposited.

The amount of ETH sent (`msg.value`) must be exactly equal to the expected amount.

When all conditions are met:
- The correct amount of ETH is transferred into the contract (otherwise the transaction reverts and no funds move).
- The `deposited` flag is set to `True` to indicate that the payment has been successfully made.

## pay

```py
@nonreentrant
@external
def pay():
    assert self.deposited, "Empty balance, deposit first"
    assert msg.sender == self.buyer, "Only the buyer"
    assert not self.payed, "Already paid"
    assert not self.refunded, "Already refunded, cannot pay"
    self.payed = True 

    send(self.seller, self.amount)
    assert self.balance == 0, "Invalid balance"
```

The **pay** function releases the deposited funds from the buyer to the seller.

Requirements:
- A deposit must already exist (`deposited == True`).
- The caller must be the buyer.
- The payment must not have already been executed (`payed == False`).
- No refund must have been issued (`refunded == False`).

When all checks pass:
- The `payed` flag is set to `True`.
- The contract transfers the full deposited amount to the seller using `send(...)`.
- A final assertion ensures that the contract’s balance is now zero, confirming that all funds were correctly transferred.

## refund

```py
@nonreentrant
@external
def refund():
    assert self.deposited, "Empty balance"
    assert msg.sender == self.seller, "Only the seller"
    assert not self.refunded, "Buyer already refunded"
    assert not self.payed, "Already paid, cannot refund"
    self.refunded = True

    send(self.buyer, self.amount)
    assert self.balance == 0, "Invalid balance"
```

The **refund** function allows the seller to return the deposited funds to the buyer.

Requirements:
- A deposit must already exist (`deposited == True`).
- Only the `seller` is allowed to initiate the refund.
- No refund must have been processed before (`refunded == False`).
- The payment must not have already been executed (`payed == False`).

When these conditions are met:
- The `refunded` flag is set to `True`.
- The contract transfers the full deposited amount back to the buyer.
- A final assertion ensures the contract’s balance is now zero, confirming the refund was successfully executed. 


## Differences between the Vyper and Solidity implementations

Implementation is similar to Solidity.
