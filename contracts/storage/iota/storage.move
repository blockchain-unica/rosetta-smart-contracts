module storage::storage;

public struct Storage has key {
    id: UID,
    bytes_sequence: vector<u8>,
    string: vector<u8>
}

fun init(ctx: &mut TxContext){
    let storage = Storage {
        id: object::new(ctx),
        bytes_sequence: vector::empty<u8>(),
        string: vector::empty<u8>()
    };
    transfer::share_object(storage);
}

public fun storeBytes(storage: &mut Storage, bytes_sequence: vector<u8>){
    storage.bytes_sequence = bytes_sequence;
}

public fun storeString(storage: &mut Storage, string: vector<u8>){
    storage.string = string;
}

#[test_only]
public fun init_test(ctx: &mut TxContext){
    let storage = Storage {
        id: object::new(ctx),
        bytes_sequence: vector::empty<u8>(),
        string: vector::empty<u8>()
    };
    transfer::share_object(storage);
}