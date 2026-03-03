# Escrow Contract

## States

The contract defines three states:

```cairo
const WAIT_DEPOSIT: u8 = 0;
const WAIT_RECIPIENT: u8 = 1;
const CLOSED: u8 = 2;
```

### State Description

| State            | Meaning                             |
| ---------------- | ----------------------------------- |
| `WAIT_DEPOSIT`   | Waiting for buyer to deposit funds  |
| `WAIT_RECIPIENT` | Funds locked in contract            |
| `CLOSED`         | Escrow completed (paid or refunded) |

## Constructor

```cairo
#[constructor]
fn constructor(
    ref self: ContractState,
    amount: u256,
    buyer: ContractAddress,
    seller: ContractAddress,
    token: ContractAddress,
)
```

### Rules:

- The **seller must be the deployer**
- Buyer and seller cannot be the zero address
- Initial state is `WAIT_DEPOSIT`

## deposit

```py
fn deposit(ref self: ContractState) {
            let caller = get_caller_address();
            assert(caller == self.buyer.read(), Errors::ONLY_BUYER);
            assert(self.state.read() == WAIT_DEPOSIT, Errors::INVALID_STATE);

            let amount = self.amount.read();
            let token = IERC20Dispatcher { contract_address: self.token.read() };

            // mirrors: require(msg.value == amount)
            // on Starknet we enforce exact amount via transfer_from
            let success = token.transfer_from(caller, get_contract_address(), amount);
            assert(success, Errors::TRANSFER_FAILED);

            self.state.write(WAIT_RECIPIENT);
        }
```

Callable only by the **buyer**

Requirements:

- Current state must be `WAIT_DEPOSIT`

Actions:

- Transfers `amount` from buyer to the contract (`transfer_from`)
- Changes state to `WAIT_RECIPIENT`

The buyer must call `approve()` on the ERC20 token before calling `deposit()`.

## pay

```py
fn pay(ref self: ContractState) {
            let caller = get_caller_address();
            assert(caller == self.buyer.read(), Errors::ONLY_BUYER);
            assert(self.state.read() == WAIT_RECIPIENT, Errors::INVALID_STATE);

            self.state.write(CLOSED);

            let amount = self.amount.read();
            let token = IERC20Dispatcher { contract_address: self.token.read() };
            let success = token.transfer(self.seller.read(), amount);
            assert(success, Errors::TRANSFER_FAILED);
        }
```

Callable only by the **buyer**

Requirements:

- Current state must be `WAIT_RECIPIENT`

Actions:

- Transfers `amount` to the seller
- Sets state to `CLOSED`

This represents confirmation that the seller fulfilled their obligation.

---

## refund

```py
fn refund(ref self: ContractState) {
            let caller = get_caller_address();
            assert(caller == self.seller.read(), Errors::ONLY_SELLER);
            assert(self.state.read() == WAIT_RECIPIENT, Errors::INVALID_STATE);

            self.state.write(CLOSED);

            let amount = self.amount.read();
            let token = IERC20Dispatcher { contract_address: self.token.read() };
            let success = token.transfer(self.buyer.read(), amount);
            assert(success, Errors::TRANSFER_FAILED);
}
```

Callable only by the **seller**

Requirements:

- Current state must be `WAIT_RECIPIENT`

Actions:

- Transfers `amount` back to the buyer
- Sets state to `CLOSED`

This represents cancellation or dispute resolution.
