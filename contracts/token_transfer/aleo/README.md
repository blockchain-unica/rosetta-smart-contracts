# Token Transfer Contract in Leo (Aleo)

This is an implementation of the Token Transfer contract on the [Aleo](https://aleo.org) blockchain, written in the [Leo](https://leo-lang.org) programming language. For a general introduction to Leo and the Aleo execution model, refer to the Bet contract README.

## Custom Tokens on Aleo

Unlike Ethereum, where each ERC-20 token is an independent smart contract with its own address, Aleo uses a **singleton registry model** for custom tokens. All custom tokens on Aleo are managed by a single program called `token_registry.aleo`, which implements the [ARC-21 standard](https://github.com/ProvableHQ/ARCs).

This design choice is motivated by a fundamental constraint of Aleo's execution model: **all imported programs must be known and deployed before the importing program, and dynamic cross-program calls are not currently supported**. This means that a DeFi program must be compiled with knowledge of every token program it will ever interact with. If a new token were deployed as an independent program, every DeFi application would need to be recompiled and redeployed to support it.

The `token_registry.aleo` singleton solves this problem: DeFi programs only need to import the registry once, and any new token registered with the registry is automatically usable by all programs that import it, with no redeployment needed.

This is analogous to how ERC-20 works on Ethereum, but instead of each token being a separate contract, all tokens share the same program and are distinguished by a unique `token_id: field`.

### Token Lifecycle

1. **Register**: anyone can register a new token by calling `token_registry.aleo/register_token` with a unique `token_id`, name, symbol, decimals, and max supply.
2. **Mint**: the token admin mints tokens to recipients via `mint_public` or `mint_private`.
3. **Transfer**: tokens are transferred via `transfer_public`, `transfer_public_as_signer`.

### Creating a Custom Token

To create and use a custom token on Aleo, the following steps are required:

**Step 1 — Register the token:**

```bash
leo execute register_token \
  <token_id: field> \
  <name: u128> \
  <symbol: u128> \
  <decimals: u8> \
  <max_supply: u128> \
  <external_authorization_required: bool> \
  <external_authorization_party: address>
```

- `token_id`: a unique `field` value chosen by the creator 
- `name` and `symbol`: ASCII text encoded as `u128` 
- `decimals`: number of decimal places (e.g. `6u8` like USDC)
- `max_supply`: maximum amount of tokens that can ever exist 
- `external_authorization_required`: set to `false` for standard tokens
- `external_authorization_party`: set to the zero address if not used

After registration, the caller becomes the **admin** of the token and has exclusive rights to mint and burn.

**Step 2 — Mint tokens to an account:**

```bash
leo execute mint_public \
  <token_id: field> \
  <recipient: address> \
  <amount: u128> \
  <authorized_until: u32>
```

- `authorized_until`: block height until which the tokens are authorized to be spent. 
Only the token admin (the address that called `register_token`) can call `mint_public`.

**Step 3 — Verify the balance:**

Token balances in `token_registry.aleo` are stored in a mapping `balances: field => Balance`, where the key is computed as `Poseidon2::hash(TokenOwner { account, token_id })`. This means balances cannot be queried directly via the REST API with just an address.

### Key Difference from `credits.aleo`

`credits.aleo` is the **native token** of Aleo, it is hardcoded into the genesis block of every Aleo network (mainnet, testnet, devnet) and is always available without deployment. `token_registry.aleo` is a **standard program** that must be explicitly deployed on the target network before it can be used.

### Token Identification

Unlike Ethereum where tokens are identified by their contract address, in `token_registry.aleo` each token is identified by a `token_id` of type `field`, a number in the mathematical field used by Aleo's ZK circuits. The owner specifies this ID at registration time. Amounts use `u128` instead of `u64` to support tokens with large supplies.

---

## Implementation Notes

The contract is coherent with the specification. The owner specifies the recipient address and the `token_id` at initialization. Deployment and initialization are separate steps, as is standard in Leo (see the Bet contract README).

### The `token_id` Parameter Problem

Due to the async/transition model, `token_id` must be passed explicitly as a parameter in `deposit` and `withdraw`, even though it is already stored in the contract's storage. This is because `transfer_public_as_signer` and `transfer_public` must be called in the off-chain `async transition`, where storage is not readable. The `async function` then verifies that the provided `token_id` matches the stored one.

This is the same architectural constraint described in the Bet contract README.

### Internal Balance Tracking

The contract maintains an internal `balance: u128` storage variable. This mirrors the approach used in `simple_transfer`, it is necessary because the contract cannot read the `token_registry.aleo/balances` mapping directly in the off-chain transition phase.

---

## Contract Design

### Imports

This contract imports `token_registry.aleo` as an external dependency. 

### State

| Variable | Type | Description |
|---|---|---|
| `owner` | `address` | Address of the owner, set at initialization. |
| `recipient` | `address` | Address of the recipient, set at initialization. |
| `token_id` | `field` | The unique identifier of the token in `token_registry.aleo`. |
| `balance` | `u128` | Internal balance tracker (in token units). |

### Functions

#### `initialize(recipient_, token_id_)`

Called by the **owner** to set up the contract. Stores the caller as `owner`, the provided address as `recipient`, and the token ID. Can only be called once.

On-chain checks:
- `owner` must be the zero address (prevents double initialization).
- `recipient` must be the zero address (prevents double initialization).

#### `deposit(amount_, token_id_)`

Called by the **owner** to deposit `amount_` tokens into the contract via `token_registry.aleo/transfer_public_as_signer`. The internal `balance` is incremented accordingly.

**Why `token_id_` is a parameter:** the transfer to `token_registry.aleo` must be initiated off-chain in the `async transition`, before storage is readable. The `async function` verifies that the provided `token_id_` matches the stored `token_id`.

On-chain checks:
- Caller must be the stored `owner`.
- `token_id_` must match the stored `token_id`.

#### `withdraw(amount_, token_id_)`

Called by the **recipient** to withdraw `amount_` tokens from the contract via `token_registry.aleo/transfer_public`. The internal `balance` is decremented accordingly.

**Why `token_id_` is a parameter:** same reason as `deposit`.

On-chain checks:
- Caller must be the stored `recipient`.
- `amount_` must be greater than 0.
- `token_id_` must match the stored `token_id`.
- `balance` must be >= `amount_`.

---

## Running the Contract

This contract requires `token_registry.aleo` to be deployed on the target network. It is available on the Aleo testnet but not on a local devnet.

