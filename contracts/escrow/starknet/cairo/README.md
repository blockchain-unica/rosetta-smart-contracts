# Escrow Contract

## States

The contract defines three states:

```cairo
pub enum State {
    #[default]
    WaitDeposit,    // auction has not started yet
    WaitRecipient,  // auction is running, accepting bids
    Closed,       // auction has ended
}
```

### State Description

| State            | Meaning                             |
| ---------------- | ----------------------------------- |
| `WAIT_DEPOSIT`   | Waiting for buyer to deposit funds  |
| `WAIT_RECIPIENT` | Funds locked in contract            |
| `CLOSED`         | Escrow completed (paid or refunded) |

## Storage variables

```cairo
struct Storage {
        buyer: ContractAddress,
        seller: ContractAddress,
        token: ContractAddress,
        amount: u256,
        state: u8,
    }
```

| Field    | Type              | Description                                                 |
| -------- | ----------------- | ----------------------------------------------------------- |
| `buyer`  | `ContractAddress` | Address of the buyer — deposits funds and confirms delivery |
| `seller` | `ContractAddress` | Address of the seller — must be the contract creator        |
| `token`  | `ContractAddress` | ERC20 token used for the escrow payment                     |
| `amount` | `u256`            | Fixed token amount locked in escrow                         |
| `state`  | `u8`              | Current lifecycle state of the escrow                       |

## Constructor

```cairo
fn constructor(
    ref self: ContractState,
    amount: u256,
    buyer: ContractAddress,
    seller: ContractAddress,
    token: ContractAddress,
) {
    assert(
        buyer != starknet::contract_address_const::<0>()
        && seller != starknet::contract_address_const::<0>(),
        Errors::ZERO_ADDRESS
    );
    assert(get_caller_address() == seller, Errors::SELLER_IS_CREATOR);
    self.amount.write(amount);
    self.buyer.write(buyer);
    self.seller.write(seller);
    self.token.write(token);
    self.state.write(State::WaitDeposit);
}
```

- Caller must be the `seller` — enforced on deployment
- Neither `buyer` nor `seller` can be the zero address
- Initial state is `WaitDeposit`

## Deposit

```cairo
fn deposit(ref self: ContractState) {
    let caller = get_caller_address();
    assert(caller == self.buyer.read(), Errors::ONLY_BUYER);
    assert(self.state.read() == WAIT_DEPOSIT, Errors::INVALID_STATE);

    let amount = self.amount.read();
    let token = IERC20Dispatcher { contract_address: self.token.read() };

    let success = token.transfer_from(caller, get_contract_address(), amount);
    assert(success, Errors::TRANSFER_FAILED);
    self.state.write(WAIT_RECIPIENT);
}
```

Callable only by the **buyer**

Requirements:

- Current state must be `WaitDeposit`

Actions:

- Transfers `amount` from buyer to the contract (`transfer_from`)
- Changes state to `WaitRecipient`

The buyer must call `approve()` on the ERC20 token before calling `deposit()`.

## Pay

```cairo
fn pay(ref self: ContractState) {
    let caller = get_caller_address();
    assert(caller == self.buyer.read(), Errors::ONLY_BUYER);
    assert(self.state.read() == State::WaitRecipient, Errors::INVALID_STATE);
    self.state.write(State::Closed);
    let amount = self.amount.read();
    let token = IERC20Dispatcher { contract_address: self.token.read() };
    let success = token.transfer(self.seller.read(), amount);
    assert(success, Errors::TRANSFER_FAILED);
}
```

Callable only by the **buyer**

Requirements:

- Current state must be `WaitRecipient`

Actions:

- Transfers `amount` to the seller
- Sets state to `Closed`

This represents confirmation that the seller fulfilled their obligation.

---

## refund

```cairo
fn refund(ref self: ContractState) {
    let caller = get_caller_address();
    assert(caller == self.seller.read(), Errors::ONLY_SELLER);
    assert(self.state.read() == State::WaitRecipient, Errors::INVALID_STATE);
    self.state.write(State::Closed);
    let amount = self.amount.read();
    let token = IERC20Dispatcher { contract_address: self.token.read() };
    let success = token.transfer(self.buyer.read(), amount);
    assert(success, Errors::TRANSFER_FAILED);
}
```

Callable only by the **seller**

Requirements:

- Current state must be `WaitRecipient`

Actions:

- Transfers `amount` back to the buyer
- Sets state to `Closed`

This represents cancellation or dispute resolution.
