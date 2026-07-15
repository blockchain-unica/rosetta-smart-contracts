# Upgradeable Proxy in Leo (Aleo)

This is an implementation of the Upgradeable Proxy use case on the [Aleo](https://aleo.org) blockchain, written in the [Leo](https://leo-lang.org) programming language. For a general introduction to Leo and the Aleo execution model, refer to the Bet contract README.

## Overview

In Aleo, Program upgradeability is a native feature of the protocol, not an application-level workaround. When a program is upgraded to a new version, its program ID stays the same, all existing storage (mappings and records) is preserved, and any other program that imports it automatically uses the new version. The proxy pattern is therefore unnecessary, the protocol itself plays the role of the proxy.

## Implementation Notes

### Cannot Implement: delegatecall and Dynamic Arrays

The specification requires two features that Aleo does not provide: `delegatecall` and dynamic arrays. `delegatecall` is a low-level EVM instruction that executes external code in the caller's own storage context. Aleo has no equivalent because each program has a separate, isolated storage. Dynamic arrays are not supported in Leo, which uses compile-time-fixed array sizes.

### Two Contracts Instead of Three

Rather than the three-contract architecture of the specification (Logic, TheProxy, Caller), this implementation uses two:

**`logic.aleo`**: the upgradeable logic contract. It implements the `check` function and uses the `@admin` upgrade annotation, which restricts future upgrades to a single hardcoded admin address. This is the functional equivalent of the `upgradeTo` mechanism in the Solidity reference: only the designated admin can change the implementation.

**`caller.aleo`**: imports `logic.aleo` directly and calls its `check` function. After an upgrade of `logic.aleo`, `caller.aleo` automatically uses the new version without any modification.

**TheProxy is omitted** because it is structurally redundant in Aleo. The role it plays in Ethereum, maintaining a stable address while the implementation changes, is handled natively by the protocol. Caller does not need to address a proxy; it addresses `logic.aleo` directly, and the network ensures the most recent approved version is used.

### Native Upgradeability: The Four Modes

Aleo's upgradeability framework provides four distinct modes, declared via annotations on the constructor:

**`@noupgrade`**: the program is permanently immutable..

**`@admin`**: upgrades are restricted to a single hardcoded address. The compiled constructor asserts `program_owner == admin_address`, so only the account that holds the admin key can submit a successful upgrade transaction.

**`@checksum`**: upgrade authority is delegated to an external governance program. The constructor reads an approved checksum from a mapping in another program and verifies it against the new program's checksum. This enables decentralized upgrade governance without a single point of failure.

**`@custom`**: the developer writes the entire upgrade policy from scratch inside the constructor body.

One critical property applies to all modes: the constructor's logic is immutable after the first deployment. Any bugs introduced there are permanent. 

### What an Upgrade Can and Cannot Change

The Aleo protocol enforces strict rules to protect dependent applications:

An upgrade can change the internal logic of existing function bodies (the computation inside `fn` and `final { }` blocks), and it can add new structs, records, mappings, and functions.

An upgrade cannot change the input or output signatures of any existing entry function, modify or delete any existing struct, record, or mapping, or change the constructor itself.

### The `check` Function: Semantics and Limitations

The specification requires `check` to return `true` if the balance of the given address is lower than 100, and `false` otherwise. In Leo, a function can return a value computed off-chain alongside a `Final` block for on-chain computation, but the return value must be known before the `final { }` block executes, that is, it must be computable without reading on-chain storage.

Since the balance of an arbitrary address is on-chain data (stored in `credits.aleo::account`), it cannot be read off-chain. The implementation therefore uses an approximation: `check` always returns `true` as its off-chain value, and enforces the balance condition via an `assert` inside the `final { }` block. The effective semantics are:

- If `credits.aleo::account[a_] < 100u64`: the transaction succeeds and the caller receives `true`.
- If `credits.aleo::account[a_] >= 100u64`: the `assert` fails and the entire transaction reverts. The caller receives no value.

This maps "returns false" to "transaction reverts" rather than to an actual `false` boolean.

### Considered Alternative: Mapping-Based Result

An alternative implementation of `check` would write the result to a public mapping instead of asserting:

```leo
mapping check_result: address => bool;

fn check(a_: address) -> Final {
    return final {
        let bal: u64 = credits.aleo::account.get_or_use(a_, 0u64);
        check_result.set(a_, bal < 100u64);
    };
}
```

This version never reverts and stores both `true` and `false` results on-chain, readable by anyone via the REST API. It is semantically more faithful to the specification. I chose the assert-based approach to keep the interface closer to a function that "returns a boolean", and to demonstrate the revert mechanism required by the specification.


### Testing the Upgrade

To demonstrate the upgrade mechanism, `logic.aleo` can be upgraded by modifying the `check` function (e.g. changing the threshold from 100 to 200) and redeploying with the admin key. After the upgrade, `caller.aleo` automatically uses the new logic without any changes. This is the core claim of the pattern: the caller is decoupled from the specific version of the implementation.

---

## Contract Design

### `logic.aleo`

#### State

This contract has no mappings or storage variables. All logic is stateless, it reads from `credits.aleo` but writes nothing permanently.

#### Functions

##### `constructor()`

Annotated with `@admin(address="aleo1rhgdu77hgyqd3xjj8ucu3jj9r2krwz6mnzyd80gncr5fxcwlh5rsvzp9px")`. The compiled constructor asserts that any upgrade transaction is submitted by the admin address. This function is immutable after the first deployment.

##### `check(a_)`

Checks whether the public credit balance of `a_` is strictly less than 100 microcredits.

| Parameter | Type | Description |
|---|---|---|
| `a_` | `address` | The address whose balance is checked. |

On-chain checks:
- `credits.aleo::account.get_or_use(a_, 0u64) < 100u64`. If this condition is false the transaction reverts.

Returns `(bool, Final)` where the `bool` is always `true` off-chain (the actual condition is enforced by the on-chain assert).

---

### `caller.aleo`

#### State

This contract has no mappings or storage variables.

#### Functions

##### `call_logic_by_proxy()`

Calls `logic.aleo::check` passing `self.address` (the address of the `caller.aleo` program itself) as the argument.


On-chain checks:
- Delegates to `logic.aleo::check(self.address)`, which asserts `credits.aleo::account[self.address] < 100u64`. If the assert fails, the entire transaction reverts.

Returns `(bool, Final)` where the `bool` propagates from `logic.aleo::check`.