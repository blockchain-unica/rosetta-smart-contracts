# Factory Contract in Leo (Aleo)

This document covers the Factory use case for the [Aleo](https://aleo.org) blockchain, written in the [Leo](https://leo-lang.org) programming language. Unlike the other contracts in this project, the Factory Pattern cannot be implemented in Aleo in a way that is faithful to the specification. This README explains the reasons,  and shows what the closest possible approximation looks like.

## What the Factory Pattern Does

The Factory Pattern allows a contract to create and deploy other contracts at runtime. In the Ethereum model, a Factory contract can call `new Product(tag)` inside a transaction, which instantiates a brand-new contract at a fresh address, stores state in it, and registers its address. Each Product is a fully autonomous contract. The Factory maintains a dynamic list of Product addresses per user.

The pattern is useful whenever the number of instances is not known at deploy time.

## Why It Cannot Be Implemented in Aleo

Two required functionalities are unavailable in Aleo.

### In-Contract Deployment

Aleo does not support deploying programs from within other programs at runtime. In Solidity, `new Product(tag)` is a single opcode (`CREATE` or `CREATE2`) that the EVM executes during a transaction, producing a new contract at a deterministic address. In Aleo, program deployment is an entirely separate operation, a deployment transaction submitted independently to the network, not something that can be triggered by executing another program's code. There is no instruction in AVM analogous to `CREATE`.

This is a fundamental architectural difference. Aleo's execution model separates program deployment from program execution. Merging the two would require changes to the network's consensus and proving infrastructure that do not currently exist.

### Dynamic Arrays

Leo does not support dynamic arrays. While Leo provides storage vectors, they cannot be iterated with runtime bounds nor returned wholesale from a function.`getProducts` must return a list whose length depends on how many times `createProduct` has been called, which is inherently a runtime value and therefore not expressible in Leo.

## The Closest Approximation in Leo

To make the limitations concrete, here is what the closest possible implementation in Leo would look like. 

```leo
program factory.aleo {

    mapping product_count: address => u64;

    mapping product_tags: field => field;

    @noupgrade
    constructor() {}

    fn register_product(tag_: field) -> Final {
        let caller_: address = self.signer;

        return final {
            let count: u64 = product_count.get_or_use(caller_, 0u64);

            let key: field = Poseidon2::hash_to_field(caller_) + (count as field);
            product_tags.set(key, tag_);
            product_count.set(caller_, count + 1u64);
        };
    }
}
```

This approximation departs from the specification in every significant way:

**No Product contract exists.** There is no separate deployed program for each product. Tags are stored in the Factory's own mappings, indexed by a computed key. There is no `getTag` function on a Product, because there is no Product,there is only a mapping entry.

**`getProducts` cannot be implemented as a function.** There is no way to return a list of product identifiers from a Leo function because dynamic arrays do not exist. A user who wants to retrieve all their products must query the mapping entry by entry via the REST API, knowing the total count from `product_count[user]` and computing each key manually. This is a client-side operation, not a contract function.

**`getFactory` has no meaning.** Since no Product contract is ever deployed, there is no contract that needs to know which Factory created it.

**`getTag` access control is approximate.** In the specification, only the user who requested the creation of a Product can call `getTag`. In the mapping approximation, any user can query any mapping entry via the REST API. The only access control possible would be to encrypt the tag before storing it, but then the contract cannot verify it. Private tags could be stored in records rather than mappings, but records cannot be shared between parties without transferring ownership.

The approximation retains only the superficial structure, a "factory" mapping that records some data per user, while losing every property that makes the Factory Pattern meaningful: autonomous Product contracts, dynamic deployment, a callable Product interface, and a queryable list of addresses.

## Summary

The Factory Pattern requires two features that Aleo does not provide: runtime program deployment and dynamic arrays. The pattern exists specifically to create and address autonomous contract instances at runtime, and neither of these capabilities exists in the Aleo execution model. The closest approximationa does not create contracts, does not produce addressable products, and cannot return a list of results. It is a different pattern entirely.
