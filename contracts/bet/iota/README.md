# Bet

## Specification

The Bet contract involves two players and an oracle. The contract has the following parameters, defined at deployment time:
- **deadline**: a time limit (e.g. current block height plus a fixed constant); 
- **oracle**: the address of a user acting as an oracle.

After creation, the following actions are possible: 
- **join**: the two players join the contract by depositing their bets (the bets, that must be equal for both players, can be in the native cryptocurrency);
- **win**: after both players have joined, the oracle is expected to determine the winner, who receives the whole pot;
- **timeout** if the oracle does not choose the winner by the deadline, then both players can redeem their bets.

## Required functionalities

- Native tokens
- Multisig transactions
- Time constraints
- Transaction revert


## Implementation

### Introduction to IOTA

In IOTA, every address can hold balances of the native IOTA token (IOTA) and custom digital assets.

In IOTA, a foundational transaction type is the [user transaction](https://docs.iota.org/developer/iota-101/transactions/), which enables users to interact with smart contract and transfer assets, specially allow to send IOTA tokens (such as IOTA or MIOTA) between addresses. Each transaction specifies the sender’s address, the receiver’s address, and the amount of tokens being sent.Beyond basic value transfers, IOTA supports custom token transfers through its native tokenization framework.These transactions function allow users to create and send [custom assets](vhttps://docs.iota.org/developer/iota-101/create-coin/).

The fundamental unit of storage on IOTA is the object. Unlike many blockchains that focus on accounts containing key-value stores, IOTA's storage model centers around objects, each of which is addressable on-chain by a unique ID. In IOTA, a smart contract is an object known as a [package](https://docs.iota.org/references/framework/iota-framework/package), and these smart contracts interact with other objects on the IOTA network.

We will take a look at how a simple bet contract can be implemented in IOTA, using Move language.

### Logic Core

A package's utility is defined by its modules. A module contains the logic for your package. You can create any number of modules per package. In this case the module is colled bet.

```move
module bet::bet;
```

Each object value is a struct with fields that can include primitive types (such as integers and addresses), other objects, and non-object structs. In this module we have two struct: Bet and Oracle.

```move
  public struct Oracle has key, store {
    id: UID,
    addr: address,
    deadline: u64
  }

  public struct Bet<phantom T> has key {
    id: UID,
    amount: Balance<T>,
    player1: address,
    player2: address,
    oracle: address,
    timeout: u64
  }
```
After the keyword `has` we have the abilities. Abilities are a way to allow certain behaviors for a type. They are a part of the struct declaration and define which behaviors are allowed for the instances of the struct. Bet have the [key ability](https://move-book.com/reference/abilities.html#key) that allows the struct to be used as a key in a storage. Oracle instead, have also the [store ability](https://move-book.com/reference/abilities.html#store) that allows the struct to be stored in structs that have the key ability.

The first field of Bet and Oracle is the id. [UID](https://docs.iota.org/references/framework/testnet/iota-framework/object#struct-uid) is the globally unique IDs that define an object's ID in storage. Any IOTA Object, that is a struct with the key ability, must have id: UID as its first field. These are globally unique in the sense that no two values of type UID are ever equal

#### Initialization

 ```move
 public fun initialize(deadline: u64, ctx: &mut TxContext){
    let oracle = Oracle {
      id: object::new(ctx),
      addr: ctx.sender(),
      deadline: deadline 
    };
    transfer::share_object(oracle);
  }
```
The function instantiates an Oracle, which is subsequently shared across the chain via the [share_object](https://docs.iota.org/references/framework/testnet/iota-framework/transfer#function-share_object) function and get accessible the oracle instance for reads and writes by any transaction.
#### Join

The `join1` function enables a user to create a bet struct by specifying a wager amount and publish it on the blockchain. This initiates a pending state awaiting counterparty participation. A second user may then join the existing bet by invoking `join2`, which requires passing the identical wager amount originally specified in the bet struct.

```move
public fun join1<T> (
    wager: coin::Coin<T>,
    oracle: &Oracle,
    ctx: &mut TxContext
    ){
        let wager = wager.into_balance();
        let bet = Bet<T>{
          id: object::new(ctx),
          amount: wager,
          player1: ctx.sender(),
          player2: @0x0,
          oracle: oracle.addr,
          timeout: oracle.deadline,
          state: JOIN2
        };
        transfer::share_object(bet);
  }
```

To call the `join1` function has required three parameters to be passed to the contract:


- **wager**: a [coin](https://docs.iota.org/references/framework/iota-framework/coin) that enable participants to commit either the network’s native token or externally-defined fungible tokens;
- **oracle**: the oracle that decide the winner of the wager;
- **ctx**: [the transaction context](https://docs.iota.org/references/framework/testnet/iota-framework/tx_contex)

The function instantiates an bet, which is subsequently shared across the system via the [share_object](https://docs.iota.org/references/framework/testnet/iota-framework/transfer#function-share_object) function get accessible the bet instance for reads and writes by any transaction.

```move
public fun join2<T> (
    clock: &Clock,
    wager: coin::Coin<T>,
    bet: &mut Bet<T>,
    ctx: &mut TxContext
    ){
        assert!(bet.state == JOIN2, EPermissionDenied);
        assert!(wager.value() == bet.amount.value(), EWrongAmount);
        let wager = wager.into_balance();
        bet.amount.join(wager);      
        bet.player2 = ctx.sender();
        bet.timeout = bet.timeout + clock.timestamp_ms();
        bet.state = ONGOING
  }
```

To call the `join2` function instead we require four parameters to be passed to the contract:

- **clock**: [Clock struct](https://docs.iota.org/references/framework/testnet/iota-framework/clock#0x2_clock_Clock) is a Singleton shared object that exposes time to Move calls. This object can only be read (accessed via an immutable reference) by entry functions. We need it to take the timestamp to record the initiation time of the wager;
- **wager**: just explained;
- **bet**: the structure that persists on-chain in a JOIN2 state, awaiting counterparty participation. Successful execution of the join2 function triggers a state transition that activates the oracle for winner determination;
- ctx: [the transaction context](https://docs.iota.org/references/framework/testnet/iota-framework/tx_contex).

The function first validates two preconditions: (1) the bet's current state equals `JOIN2`, and (2) the caller's wager amount matches the creator's initial wager. Upon validation, it aggregates both wagers by converting coins to a balance structure via the `coin::into_balance()` method. The bet struct is then updated with the second participant's address, a countdown timer initiates, and the state transitions to `ONGOING`, enabling oracle to chose the winner.

#### Win
After both players have joined the bet, the oracle is expected to determine the winner, calling the function `win`, who receives the whole pot.

```move
public fun win<T> (bet: Bet<T>, winner: address, clock: &Clock, ctx: &mut TxContext) {
    assert!(bet.state == ONGOING, EPermissionDenied);
    assert!(timestamp_ms(clock) < bet.timeout, EOverTimeLimit);
    assert!(winner == bet.player1 || winner == bet.player2, EWinnerNotPlayer);
    assert!(bet.oracle == ctx.sender(), EPermissionDenied);

    let Bet {id: id,amount: wager, player1: _, player2: _,oracle: _, timeout: _} = bet;
    let wager = coin::from_balance(wager, ctx);
    transfer::public_transfer(wager, winner);

    object::delete(id);
  }
```
To call the `win` function we require four parameters to be passed to the contract:

- **bet**: includes all bet information, including the participating players, oracle, start time, wagered amount, and timeout duration;
- **winner**: the address of the bet winner;
- **clock**: timestamp to verify whether the time has expired;
- **ctx**: [the transaction context](https://docs.iota.org/references/framework/testnet/iota-framework/tx_contex).

The function begins with three assertion checks:

- Validation that the winner determination timeframe has expired (via timestamp verification)
- Confirmation that the declared winner's address matches either of the two registered player addresses
- Authentication that the function caller holds the designated oracle role

Upon successful validation of all assertions, the function initiates the bet resolution process. This involves the [unpacking](https://docs.iota.org/developer/iota-101/move-overview/structs-and-abilities/struct#Unpacking-a-Stuct) of bet instance to close it and then transfer the entirety of the wager amount to the winner’s address via the [public_transfer](https://docs.iota.org/references/framework/testnet/iota-framework/transfer#function-public_transfer) function (Transfer ownership of `wager` to `winner`).

#### Timeout

```move
  public fun timeout<T> (bet: Bet<T>, clock: &Clock, ctx: &mut TxContext){
    assert!(bet.state == ONGOING, EPermissionDenied);
    assert!(clock.timestamp_ms() > bet.timeout, ETimeIsNotFinish);
    let Bet {id: id, amount:mut wager, player1: p1, player2: p2,oracle: _, timeout: _} = bet;
    object::delete(id);
    let amount = wager.value();

    let wager1 = wager.split(amount /2);
    
    transfer::public_transfer(coin::from_balance(wager, ctx), p1);
    transfer::public_transfer(coin::from_balance(wager1, ctx), p2);
  }
```
The timeout function is publicly accessible, meaning anyone can trigger it. When called, it first checks —via an initial `assert` statement— whether the predefined time limit has expired. Only if this condition is confirmed will the function execute, redistributing all funds exclusively back to the original parties.

To achieve this, we first [unpack](https://docs.iota.org/developer/iota-101/move-overview/structs-and-abilities/struct#Unpacking-a-Stuct) the bet instance to close it and then We split the original coin into two equal portions and use the [public_transfer](https://docs.iota.org/references/framework/testnet/iota-framework/transfer#function-public_transfer) function to return each half to its corresponding participant.


