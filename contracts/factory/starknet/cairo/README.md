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

### Storage variables

struct Storage {
tag: ByteArray,  
 owner: ContractAddress,  
 factory: ContractAddress,  
}

| Field     | Type              | Description                                                             |
| --------- | ----------------- | ----------------------------------------------------------------------- |
| `tag`     | `ByteArray`       | Arbitrary string stored in the product at creation                      |
| `owner`   | `ContractAddress` | The human who triggered the transaction — set from `tx.origin`          |
| `factory` | `ContractAddress` | The Factory contract that deployed this product — set from `msg.sender` |

### Constructor

```cairo
fn constructor(ref self: ContractState, tag: ByteArray) {
    let owner = get_tx_info().unbox().account_contract_address;
    let factory = get_caller_address();

    self.owner.write(owner);
    self.factory.write(factory);
    self.tag.write(tag);
}
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

```cairo
fn get_tag(self: @ContractState) -> ByteArray {
    assert(get_caller_address() == self.owner.read(), Errors::ONLY_OWNER);
    self.tag.read()
}
```

Returns the stored tag.

Restriction:

```
Only the owner can read the tag
```

### Get factory

```cairo
fn get_factory(self: @ContractState) -> ContractAddress {
    self.factory.read()
}
```

Returns the address of the factory contract that created the product.

## Factory Contract

### Storage variables

```cairo
struct Storage {
        product_class_hash: ClassHash,
        product_list: Map<ContractAddress, Vec<ContractAddress>>,
        salt: felt252,
}
```

| Field                | Type                                         | Description                                                     |
| -------------------- | -------------------------------------------- | --------------------------------------------------------------- |
| `product_class_hash` | `ClassHash`                                  | Class hash of the `Product` contract — used by `deploy_syscall` |
| `product_list`       | `Map<ContractAddress, Vec<ContractAddress>>` | List of deployed product addresses per caller                   |
| `salt`               | `felt252`                                    | Global counter used to generate unique deployment salts         |

### Constructor

```cairo
fn constructor(ref self: ContractState, product_class_hash: ClassHash) {
        self.product_class_hash.write(product_class_hash);
    }
```

- Takes the `Product` class hash at deployment
- Required because Cairo has no `new` keyword — `deploy_syscall` needs a class hash explicitly

### Creating Product

```cairo
fn create_product(ref self: ContractState, tag: ByteArray) -> ContractAddress {
    let caller = get_caller_address();
    let mut calldata: Array<felt252> = array![];
    tag.serialize(ref calldata);
    let counter = self.salt.read();
    self.salt.write(counter + 1);
    let salt = poseidon_hash_span(array![caller.into(), counter].span());
    let (product_addr, _) = deploy_syscall(
        self.product_class_hash.read(),
        salt,
        calldata.span(),
        false,
    ).unwrap();
    self.product_list.entry(caller).push(product_addr);
    product_addr
}
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
fn get_products(self: @ContractState) -> Array<ContractAddress> {
    let caller = get_caller_address();
    let vec    = self.product_list.entry(caller);
    let mut result: Array<ContractAddress> = array![];
    let mut i: u64 = 0;
    loop {
        if i >= vec.len() { break; }
        result.append(vec.at(i).read());
        i += 1;
    };
    result
}
```

Returns the list of Product contracts created by the caller.

Internally it reads the vector stored in:

```cairo
product_list[caller]
```
