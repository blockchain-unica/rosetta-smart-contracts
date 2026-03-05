# Factory

The system contains two contracts:

### Product Contract

Represents an individual product created by the factory.

Each product stores:

- a **tag string**
- the **owner** who requested the product creation
- the **factory address** that deployed it

### Factory Contract

Responsible for:

- deploying new `Product` contracts
- tracking which products belong to each user

## Important Cairo Concept: `deploy_syscall`

Unlike Solidity, Cairo **cannot create contracts using `new`**.

### Solidity

```solidity
Product p = new Product(_tag);
```

### Cairo / Starknet

Contracts are deployed using the **`deploy_syscall`**:

```cairo
deploy_syscall(
    class_hash,
    salt,
    calldata,
    deploy_from_zero
)
```

Parameters:

| Parameter          | Description                                 |
| ------------------ | ------------------------------------------- |
| `class_hash`       | Identifier of the compiled contract class   |
| `salt`             | Value used to compute deterministic address |
| `calldata`         | Constructor arguments                       |
| `deploy_from_zero` | Whether deployment ignores caller address   |

The syscall returns:

```
(contract_address, constructor_retdata)
```

In this project the factory deploys products like this:

```cairo
let (product_addr, _) = deploy_syscall(
    self.product_class_hash.read(),
    salt,
    calldata.span(),
    false,
).unwrap();
```

---

## Product Contract

### Constructor

```cairo
fn constructor(ref self: ContractState, tag: ByteArray)
```

Behavior:

- The **owner** is retrieved from the transaction info:

```cairo
get_tx_info().unbox().account_contract_address
```

- The **factory address** is the caller of the constructor:

```cairo
get_caller_address()
```

### Get tag

Returns the stored tag.

Restriction:

```
Only the owner can read the tag
```

### Get factory

Returns the address of the factory contract that created the product.

## Factory Contract

### Creating Product

```cairo
fn create_product(tag: ByteArray) -> ContractAddress
```

Steps:

1. Serialize constructor arguments.
2. Generate a unique **salt** using Poseidon hash:

```cairo
poseidon_hash_span(array![caller.into(), counter].span())
```

3. Deploy the contract using `deploy_syscall`.
4. Store the new product address in `product_list`.

### Getting User Products

```cairo
fn get_products() -> Array<ContractAddress>
```

Returns the list of Product contracts created by the caller.

Internally it reads the vector stored in:

```cairo
product_list[caller]
```
