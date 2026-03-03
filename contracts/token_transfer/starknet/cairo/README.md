# TokenTransfer

A Cairo smart contract on Starknet that allows an **owner** to deposit ERC20 tokens and a **recipient** to withdraw them.

## Relationship to SimpleTransfer

In Solidity, `SimpleTransfer` and `TokenTransfer` are meaningfully different contracts:

- `SimpleTransfer` operates on **native ETH** (`msg.value`, `address.call{value}`)
- `TokenTransfer` operates on an **ERC20 token** (`transferFrom`, `transfer`)

On Starknet there is no native currency opcode — everything goes through ERC20 contracts. This means the Cairo translation of `SimpleTransfer` already had to use ERC20 under the hood, making the two contracts structurally identical.

The only behavioural differences in this contract are:

| Behaviour                  | SimpleTransfer | TokenTransfer                               |
| -------------------------- | -------------- | ------------------------------------------- |
| Withdraw amount > balance  | Reverts        | Caps withdrawal to available balance        |
| Withdraw on empty contract | No check       | Reverts with `the contract balance is zero` |
| Withdraw event             | None           | Emits `Withdraw(sender, amount)`            |

## Withdraw

The different withdraw function

```py
fn withdraw(ref self: ContractState, amount: u256) {
            let caller = get_caller_address();
            assert(caller == self.recipient.read(), Errors::ONLY_RECIPIENT);

            let token = IERC20Dispatcher { contract_address: self.token.read() };
            let balance = token.balance_of(get_contract_address());
            assert(balance > 0, Errors::ZERO_BALANCE);

            // cap to available balance — mirrors the Solidity if-branch
            let actual_amount = if amount > balance { balance } else { amount };

            let success = token.transfer(self.recipient.read(), actual_amount);
            assert(success, Errors::TRANSFER_FAILED);

            self.emit(Withdraw { sender: caller, amount: actual_amount });
        }
```

# Event withdraw

It is also defined an event for withdraw success

```py
#[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        Withdraw: Withdraw,
    }

    // mirrors the Solidity event: Withdraw(address indexed sender, uint amount)
    #[derive(Drop, starknet::Event)]
    struct Withdraw {
        #[key]
        sender: ContractAddress,
        amount: u256,
    }
```
