# Bet Contract in Anchor

This is an implementation of the contract in [Anchor](https://www.anchor-lang.com), a [Rust](https://www.rust-lang.org)-based framework for Solana smart contracts. The purpose of this document is to simplify the understanding of the code by providing a high-level overview of the implementation.

The full specification and possible deviations from it are described in the [specification](../../README.md). Here we describe the implementation details.

The methodology consists in explaining each action and the involved accounts that are required to store state and other purposes without going into the details of the Rust code. 


## Anchor overview
If you are not familiar with Anchor, you can find a brief overview in the [Anchor overview](../../../../AnchorOverview.md) document where we provide an overview of Anchor through an example. A more deep dive into Anchor is advised by reading the [Anchor documentation](https://www.anchor-lang.com).

## Contract actions

The actions provided by the contract are `bet` and `win` and `timeout` defined in a Rust module.