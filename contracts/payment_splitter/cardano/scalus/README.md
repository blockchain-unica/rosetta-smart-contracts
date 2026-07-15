# Payment Splitter

Splits cryptocurrency payments among a group of payees in equal shares. The set of payees is fixed at deployment.
Anyone can send ADA to the contract address; a payout transaction distributes the balance equally.

Only **ADA** is split. Both validators reject contract UTxOs that carry native tokens — otherwise, since the payout
only reconciles lovelace, the fee payer could pocket any tokens locked in the contract for free.

## How it works

This example includes two implementations to illustrate an important Cardano optimization pattern.

**Naive version** (`PaymentSplitterValidator.scala`) — the spending validator runs full validation logic for each UTxO
being spent. When spending N UTxOs in one transaction, this results in O(N^2) cost because each invocation iterates
through all inputs and outputs.