// The 'decentralized_identity' program.
program decentralized_identity.aleo {
    
    const CHANGE_OWNER: field = 1field;
    const ADD_DELEGATE: field = 2field;

    record IdentityRecord {
        owner: address,
        identity: address,
    }

    struct ChangeOwnerMessage {
        contract_address: address,  
        operation: field,        
        nonce: u64,                  
        identity: address,         
        new_owner: address,   
    }

    struct IdentityDelegateKey {
        identity: address,
        delegate_type: field,
        delegate: address,
    }

    struct AddDelegateMessage {
        contract_address: address,
        operation: field,
        nonce: u64,
        identity: address,
        delegate_type: field,
        delegate: address,
        validity: u32,
    }

    mapping owners: address => address;

    mapping nonces: address => u64;

    mapping delegates: field => u32;

    @noupgrade
    constructor() {}

    fn generate_identity() -> IdentityRecord {
        return IdentityRecord {
            owner: self.signer,
            identity: self.signer,
        };
    }

    fn change_owner(identityRecord: IdentityRecord, new_owner: address) -> IdentityRecord {
        return IdentityRecord {
            owner: new_owner,
            identity: identityRecord.identity,
        };
    }

    fn change_owner_signed( identity_: address, new_owner_: address, sig_: signature ) -> Final {
    
        return final {
            let current_owner: address = owners.get_or_use(identity_, identity_);

            let current_nonce: u64 = nonces.get_or_use(current_owner, 0u64);

            let message: ChangeOwnerMessage = ChangeOwnerMessage {
                contract_address: self.address,   
                operation: CHANGE_OWNER, 
                nonce: current_nonce,
                identity: identity_,
                new_owner: new_owner_,
            };

            assert(signature::verify(sig_, current_owner, message));

            owners.set(identity_, new_owner_);

            nonces.set(current_owner, current_nonce + 1u64);
        };
    }

    fn add_delegate( identityRecord: IdentityRecord, delegate_type_: field, delegate_: address, validity_: u32 ) -> (IdentityRecord, Final) {

        let identity_value: address = identityRecord.identity;

        return (identityRecord, final {
            
            let key_struct: IdentityDelegateKey = IdentityDelegateKey {
                identity: identity_value,
                delegate_type: delegate_type_,
                delegate: delegate_,
            };

            let key: field = Poseidon2::hash_to_field(key_struct);

            delegates.set(key, block.height + validity_);
        });
    }

    

    fn add_delegate_signed(identity_: address, delegate_type_: field, delegate_: address, validity_: u32, sig_: signature ) -> Final {

        return final {

            let current_owner: address = owners.get_or_use(identity_, identity_);

            let current_nonce: u64 = nonces.get_or_use(current_owner, 0u64);

            let message: AddDelegateMessage = AddDelegateMessage {
                contract_address: self.address,
                operation: ADD_DELEGATE,
                nonce: current_nonce,
                identity: identity_,
                delegate_type: delegate_type_,
                delegate: delegate_,
                validity: validity_,
            };

            assert(signature::verify(sig_, current_owner, message));

            let key_struct: IdentityDelegateKey = IdentityDelegateKey {
                identity: identity_,
                delegate_type: delegate_type_,
                delegate: delegate_,
            };
            let key: field = Poseidon2::hash_to_field(key_struct);

            delegates.set(key, block.height + validity_);

            nonces.set(current_owner, current_nonce + 1u64);
        };
    }

    fn valid_delegate( identity_: address, delegate_type_: field, delegate_: address ) -> (bool, Final) {

        let success: bool = true;

        return (success, final {
    
            let key_struct: IdentityDelegateKey = IdentityDelegateKey {
                identity: identity_,
                delegate_type: delegate_type_,
                delegate: delegate_,
            };

            let key: field = Poseidon2::hash_to_field(key_struct);

            let valid_until: u32 = delegates.get_or_use(key, 0u32);

            assert(valid_until > block.height);
        });
    }

}
