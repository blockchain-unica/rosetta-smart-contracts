
module editable_nft::editable_nft {
    use sui::tx_context::{Self, TxContext};
    use sui::object::{Self, UID};
    use sui::transfer;

    struct Token has key {
        id: UID,
        tid: u64,
        data: vector<u8>,
        isSealed: bool,
    }

    struct ModuleState has key {
        id: UID,
        lastTokenId: u64,
    }

    fun init(ctx: &mut TxContext) {
        let state = ModuleState {
            id: object::new(ctx),
            lastTokenId: 0,
        };
        transfer::share_object(state);
    }

    public entry fun sealToken(token: &mut Token) {
        // The sender must be the owner of the token. We don't need to check that.
        token.isSealed = true;
    }

    public entry fun setTokenData(token: &mut Token, data: vector<u8>) {
        token.data = data;
    }

    public entry fun buyToken(state: &mut ModuleState, ctx: &mut TxContext) {
        // TODO: anyone should be able to buy a token ?
        state.lastTokenId = state.lastTokenId + 1;
        let token = Token {
            id: object::new(ctx),
            tid: state.lastTokenId,
            data: vector<u8>[],
            isSealed: false,
        };
        transfer::transfer(token, tx_context::sender(ctx));
    }

    public entry fun transferTo(token: Token, recipient: address) {
        transfer::transfer(token, recipient);
    }

    public entry fun getTokenData(token: &Token): (vector<u8>, bool) {
        // TODO: anyone should be able to read any token data ?
        (token.data, token.isSealed)
    }
}