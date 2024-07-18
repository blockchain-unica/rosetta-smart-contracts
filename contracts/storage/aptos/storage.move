module rosetta_smart_contracts::data_storage {
    use std::vector;
    use aptos_framework::signer;
    

    struct DataStorage has key {
        byte_sequence: vector<u8>,
        text_string: vector<u8>
    }

    fun init_module(sender: &signer) {
        let data_storage = DataStorage {
            byte_sequence:  vector::empty<u8>(),
            text_string:  vector::empty<u8>()
        };
        move_to(sender, data_storage);
    }

    public entry fun store_bytes(sender: &signer, byte_sequence: vector<u8>) acquires DataStorage {
        // Requires that the sender is the creator of the data storage contract, otherwise borrow_global_mut will fail at runtime
        let data_storage = borrow_global_mut<DataStorage>(signer::address_of(sender));
        data_storage.byte_sequence = byte_sequence;
    }

    public entry fun store_string(sender: &signer, text_string: vector<u8>) acquires DataStorage {
        // Requires that the sender is the creator of the data storage contract, otherwise borrow_global_mut will fail at runtime
        let data_storage = borrow_global_mut<DataStorage>(signer::address_of(sender));
        data_storage.text_string = text_string;
    }
}
