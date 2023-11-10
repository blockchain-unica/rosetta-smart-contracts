
module storage::htlc {
    use sui::tx_context::{Self, TxContext};
    use sui::object::{Self, UID};
    use sui::transfer;
    use std::vector;

    struct Storage has key {
        id: UID,
        byteSequence: vector<u8>,
        textString: vector<u8>,    // There is no string type in Move, so we have to use vector
    }

    public entry fun create_storage(ctx: &mut TxContext) {
        let storage = Storage {
            id: object::new(ctx),
            byteSequence: vector::empty<u8>(),
            textString: vector::empty<u8>(),
        };
        transfer::transfer(storage, tx_context::sender(ctx));
    }

    public entry fun storeBytes(storage: &mut Storage, byteSequence: vector<u8>) {
        storage.byteSequence = byteSequence;
    }

    public entry fun withdraw(storage: &mut Storage, textString: vector<u8>) {
        storage.textString = textString;
    }
}