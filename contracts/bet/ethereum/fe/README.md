# The Fe Contract Language

Fe is an emerging smart contract programming language made to work with the **Ethereum** blockchain. Inspired from the chemical symbol for iron, Fe is built to deliver safety, efficiency, and reliability in smart contract development. Developed primarily in Rust, Fe aims to combine strong safetyguards with a user-friendly syntax, making it accessible to both new and experienced blockchain developers.

⚠️ Fe is undergoing a major compiler rewrite, which means the language is temporarily not in a compilable state. As a result, all contract examples in this thesis are based on the **latest stable and working release prior to the rewrite (Fe v0.26.0)**. This ensures that the code samples are functional, even as the language is currently not ready to compile or production.

As [Fe&#39;s documentation](https://fe-lang.org/docs/index.html?highlight=python#who-is-fe-for "Fe's documentation") says, Fe aims to make contract writing easier and more secure. The developers aknowledge problems with other Smart Contract (**SC**) languages:

> One of the pain points with smart contract languages is that there can be ambiguities in how the compiler translates the human readable code into EVM bytecode. This can lead to security flaws and unexpected behaviours.

> The details of the EVM can also cause the higher level languages to be less intuitive and harder to master than some other languages. These are some of the pain points Fe aims to solve. By striving to *maximize both human readability and bytecode predictability* , Fe will provide an enhanced developer experience for everyone working with the EVM.

> Fe shares similar syntax with the popular languages [Rust](https://doc.rust-lang.org/book/) and [Python](https://www.python.org/), easing the learning curve for new users. It also implements the best features from Rust to limit dynamic behaviour while also maximizing expressiveness, meaning you can write clean, readable code without sacrificing compile time guarantees.

As a result of these design vision, Fe aims to be a concise SC language, and it is particularly noticeable when compared to Solidity, which is the most widely used language for Ethereum SCs. Fe's syntax is intentionally less verbose, making it easier to learn and mantain secure and readable, mantainable code.

This thesis aims to provide a comprehensive overview of Fe, highlighting both its strengths and weaknesses. By walking through the language's core concepts and use cases, readers will gain a primitive understanding of how Fe could operate in real-world scenarios.

In the following sections, we will first break down the fundamental aspects of Fe. Afterwards, we will present a practical use case to further illustrate the language's features and demonstrate its application in SC development.

## Contracts

Contracts are defined using the `contract` keyword, contain **variables** that persist between function calls, and **functions.**

### Global variables

Global variables have to be declared right after the contract declaration, following this syntax:

Syntax: `<name_variable>: <type>`

**Example:**

```
contract Example {
    variable_1: address
    variable_2: bool
[...]
}
```

> 💡 Note: there are no semicolons after each line, as Fe aims to be a language that is less verbose and more Python-like as said by the developers themselves.
>
> Contracts in Fe work in a similar way as classes of an OO language.

### Functions

Functions can be public or private, the `pub` keyword is optional, its absense implying the function is **private**. A private function is **only callable by other functions of the contract** and not by outside of it.

A public function can be called from **outside the contract**.

**Example:**

`<pub> fn func_name(mut self, ctx: Context)`

### Self

The `self` parameter **is mandatory and must be the first one**, which can be mutable `mut` when global variables of the contract are intended to be modified, brings inside the function the scope of the contract. All functions and global variables.

**Example:** `self|mut self`

> The `self` parameter is automatically retrieved when a function is called via `cast` but it has to be passed explicitly when the function is called from another Fe function. All functions require the context object.

### Context

The `Context` parameter **is mandatory and must be the second one**, which brings all the blockchain context and gives access to functions that alter the blockchain. If altering the blockchain is intended, this variable must be defined as `mut`.

**Example:** `ctx: Context|mut ctx: Context`

The context parameter gives access to important functions that interact with the blockchain, I will put here a non-exhaustive list of Context functions, and others will be introduced later on in the thesis:

- `ctx.msg_value()`: To be called inside a function and returns the amount of WEI received with the transaction call
- `ctx.msg_sender()`: Returns the address of the transaction sender
- `ctx.block_number()`: Returns the current blockchain block number
- `ctx.self_address()`: Return the address of the current contract
- `ctx.balance_of(<address>)`: Returns ETH balance of any address
- `ctx.send_value(to: <address>, wei, <u256>)`: Sends ETH to the specified address with the amount in WEI

> The Context object is automatically retrieved when a function is called via `cast` but it has to be passed explicitly when the function is called from another Fe function. All functions require the context object.

#### Other parameters

Other parameters can be declared after the first mandatory two, and are declared the same way as global variables.

**Example:** `parameter: address`

#### Return type

Defining the return type is mandatory only if the function returns something via the `return` keyword. The definition of the return type is similar to Rust.

**Example:** `fn function(mut self, ctx: Context) -> bool`

This function signature describes a function called "function" that doesn't take any parameter except the mandatory two and returns boolean. It expects to receive a boolean as a return.

**Example** `return true`

### Local variables

Declaring local variables in Fe is done with the `let` keyword.

**Example:** `let variable_name: bool`

```
<pub> fn <name_function>(<mut> self, <mut> ctx: Context, <name_parameter>: <type>) -> <return_type> {

    let <name_internal_variable>: <type>
    [content of function]
    [...]

    return <expr of type of return_type>
}
```

### Constructor

Each function can have a constructor, like OO languages. In Fe, the constructor function must be declared as public and is called `__init__`.

It is autonomously called at deploy time. The contract requires at deploy time all the parameters in `__init__` (except `self` and `ctx`, that are managed by Fe in this instance).

**Example of Fe's \_\_init\_\_ function:**

```fe
    pub fn __init__(mut self, ctx: Context, param1: bool) {
        self.open = param1
    }
```

This `__init__` function implies there is a global `open` parameter in the contract.

> 💡 Note that accessing a global function via any function requires to access is through `self` by doing `self.<global_variable>`.

### Error handling with assertions

Fe uses `assert` statements for validation and error handling. Asserts take 1 or 2 arguments, with the first being a boolean expression, and the second an optional string containing the error to return to the user if the boolean is false.

When an assertion fails:

1. The transaction is**reverted**
2. All state changes are**undone**
3. The**optional** custom error message is**returned**

Keep in mind that the error message is optional.

The syntax is: `assert <booleann condition>, "error message" | assert <boolean condition>`

The following example shows an **assert statement** that checks whether the address of the sender is valid or not and prompts "invalid address" in case of failure of assert. **"0x0"** is not considered to be a valid address.

**Example:**

```fe
pub fn function(mut self, mut ctx: Context) {
        assert ctx.msg_sender() != 0x0, "invalid address"
    }
```

## Value Transfers

Fe provides ETH transfers through the context object.

To send ETH **(expressed in WEI)**, this is the syntax.

`ctx.send_value(to: <address>, wei: <u256>)`

Where `to` is the recipient and `wei` is the amount of WEI to send.

**Example of this in a function:**

```fe
pub fn send_eth(mut self, mut ctx: Context, person1: address, amount: u256) {
    ctx.send_value(to: person1, wei: amount)
}
```

### Warning on transactions

Failure of transactions should always be prevented by checking contract balance and addresses first (if possible), because Fe usually returns a cryptic `custom error` when there's an error in a transaction and it's not clear enough what is happening.

## Calling a function

Fe uses named parameters for clarity (`to:`, `wei:`) as seen in `ctx.send_value()`. This is valid for every function call in Fe, even functions that call other functions between the same contract.

## Safety

`ctx.send_value()` automatically handles:

### Gas limits for the transfer

Every transaction on the blockchain incurs a "Gas fee," which is the cost required to execute operations. Fe automatically ensures that the sender's balance is sufficient to cover both the gas fees and any additional ETH explicitly sent with the transaction.

### Reverting on failure

Fe ensures transactional safety by automatically reverting any changes if a failure occurs, such as a failed assertion or an error during contract execution. This means that if something goes wrong, all state modifications made during the function call are undone, preserving the integrity of the contract and preventing partial updates.


# The Bet contract in Fe

The bet contract involves two players and one oracle. The two players place their bet and the oracle decides the winner.

## Initialization

`pub fn __init__(mut self, ctx: Context, _oracle: address, _timeout: u256)`

At deploy time, the contract requires 2 parameters:

- _oracle: the address of the user that is going to be the oracle deciding the winner of the bet
- _timeout: the timeout after which the bet is no longer valid, in case the oracle does not decide who is the winner.

The player1 is the contract deployer, and at deploy time also sends native cryptocurrency that will be automatically set to be the wager of this bet.

## Technical challenges and workarounds

Unlike Solidity, Fe does not support ternary operator yet, so I used a, if-else statement to resolve the winner.

Unlike Solidity, Fe automatically checks for transaction to be successful, so there is no necessity to actively check for successful transactions.

Failure of transactions should anyways be prevented by checking contract balance first, because otherwise a cryptic `custom error` is launched.

## Execution

After the contract is deployed, 3 functions can be called.

### join()

This function lets the player2 join the Bet, they have to send the exact amount of WEI that was previously decided by player1 at deploy time. If no player2 joined yet, the caller of join() becomes automatically "player2" if the bet is open.

### win(winner: address)

This function is only callable by the oracle (that was decided by player1 at deploy time) and checks whether player2 has joined in order to choose a winner. It is implied that if both players have joined there is a total of ETH of wager*2 in order to guarantee the winner gets the right amount of ETH (whole contract balance)

The parameter `winner` is the address of the winner decided by the oracle. An if-else statement resolves the winner decision and immediately after, currency is sent to designated winner.

### timeout()

This function is callable by everyone and checks whether the bet has timed out. If oracle doesn't decide the winner in time, this function prevents frozen ETH inside the contract.

First, it checks whether the deadline (in block numbers) is exceeded, otherwise the bet is still open. After that checks if one or both players placed their bet. If so, player1 or both player1 and player2 get refunded immediately.
