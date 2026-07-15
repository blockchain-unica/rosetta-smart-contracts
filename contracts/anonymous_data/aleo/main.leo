
program anonymous_data.aleo {

    struct HashInput {
        addr: address,
        nonce: field,
    }

    struct StoredData {
        content: [field; 4],
    }

    mapping data_storage: field => StoredData;

    @noupgrade
    constructor() {}

    fn get_id(nonce_: field) -> field {

        let input: HashInput = HashInput {
            addr: self.signer,
            nonce: nonce_,
        };

        return Poseidon2::hash_to_field(input);

    }

    fn store_data(nonce_: field, data: StoredData) -> Final {
        let input: HashInput = HashInput {
            addr: self.signer,
            nonce: nonce_,
        };
        let id: field = Poseidon2::hash_to_field(input);

        return final {
            assert(data_storage.contains(id) == false);
            data_storage.set(id,data);
        };
    }

    fn get_my_data(nonce_: field) -> (bool, Final) {
    
        let success: bool = true;
        let input: HashInput = HashInput {
            addr: self.signer,
            nonce: nonce_,
        };
        let id: field = Poseidon2::hash_to_field(input);
        
        return (success, final {
            assert(data_storage.contains(id));
        });
    }
}
