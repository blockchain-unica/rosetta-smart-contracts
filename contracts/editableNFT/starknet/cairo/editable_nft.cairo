use starknet::ContractAddress;

#[derive(Drop, Serde, starknet::Store)]
pub struct Token {
    data: ByteArray,      
    is_sealed: bool,      
}

#[starknet::interface]
pub trait IEditableToken<TContractState> {
    fn buy_token(ref self: TContractState);
    fn seal_token(ref self: TContractState, token_id: u256);
    fn set_token_data(ref self: TContractState, token_id: u256, data: ByteArray);
    fn transfer_to(ref self: TContractState, dest: ContractAddress, token_id: u256);
    fn get_token_data(self: @TContractState, token_id: u256) -> (ByteArray, bool);
}

#[starknet::contract]
pub mod EditableToken {
    use openzeppelin::token::erc721::ERC721Component;
    use openzeppelin::introspection::src5::SRC5Component;
    use starknet::{ContractAddress, get_caller_address};
    use starknet::storage::{
        StoragePointerReadAccess, StoragePointerWriteAccess,
        Map, StorageMapReadAccess, StorageMapWriteAccess,
    };
    use super::{IEditableToken, Token};

    // ---------------------------------------------------------------------------
    // OZ ERC721 component — mirrors: import ERC721.sol + contract EditableToken is ERC721
    // ---------------------------------------------------------------------------
    component!(path: ERC721Component, storage: erc721, event: ERC721Event);
    component!(path: SRC5Component,   storage: src5,   event: SRC5Event);

    #[abi(embed_v0)]
    impl ERC721Impl = ERC721Component::ERC721Impl<ContractState>;
    #[abi(embed_v0)]
    impl ERC721MetadataImpl = ERC721Component::ERC721MetadataImpl<ContractState>;
    #[abi(embed_v0)]
    impl SRC5Impl          = SRC5Component::SRC5Impl<ContractState>;
    impl ERC721InternalImpl = ERC721Component::InternalImpl<ContractState>;

    impl ERC721HooksImpl of ERC721Component::ERC721HooksTrait<ContractState> {}

    #[storage]
    struct Storage {
        #[substorage(v0)]
        erc721: ERC721Component::Storage,
        #[substorage(v0)]
        src5: SRC5Component::Storage,
        last_token_id: u256,                  
        tokens: Map<u256, Token>,             
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        ERC721Event: ERC721Component::Event,
        #[flat]
        SRC5Event: SRC5Component::Event,
    }

   
    // ---------------------------------------------------------------------------
    // Errors
    // ---------------------------------------------------------------------------
    mod Errors {
        pub const NOT_OWNER: felt252         = 'not the token owner';
        pub const ALREADY_SEALED: felt252    = 'token is sealed';
        pub const NON_EXISTENT: felt252      = 'non existent token';
    }

    #[constructor]
    fn constructor(ref self: ContractState) {
        let name: ByteArray   = "EditableToken";
        let symbol: ByteArray = "ET";
        let base_uri: ByteArray = "";
        self.erc721.initializer(name, symbol, base_uri);
    }

    #[abi(embed_v0)]
    impl EditableTokenImpl of IEditableToken<ContractState> {

        fn seal_token(ref self: ContractState, token_id: u256) {
            self._only_owner_of_token(token_id);

            let token = self.tokens.read(token_id);
            assert(!token.is_sealed, Errors::ALREADY_SEALED);

            self.tokens.write(token_id, Token { data: token.data, is_sealed: true });
        }

        fn set_token_data(ref self: ContractState, token_id: u256, data: ByteArray) {
            self._only_owner_of_token(token_id);

            let token = self.tokens.read(token_id);
            assert(!token.is_sealed, Errors::ALREADY_SEALED);

            self.tokens.write(token_id, Token { data, is_sealed: false });
        }

        fn buy_token(ref self: ContractState) {
            let caller = get_caller_address();

            let token_id = self.last_token_id.read() + 1;
            self.last_token_id.write(token_id);

            self.erc721.mint(caller, token_id);

            self.tokens.write(token_id, Token { data: "", is_sealed: false });
        }
       

        fn transfer_to(ref self: ContractState, dest: ContractAddress, token_id: u256) {
            let caller = get_caller_address();
            self.erc721.transfer_from(caller, dest, token_id);
        }

        fn get_token_data(self: @ContractState, token_id: u256) -> (ByteArray, bool) {
            assert(
                self.erc721.owner_of(token_id) != starknet::contract_address_const::<0>(),
                Errors::NON_EXISTENT
            );
            let token = self.tokens.read(token_id);
            (token.data, token.is_sealed)
        }

        fn get_last_token_id(self: @ContractState) -> u256 {
            self.last_token_id.read()
        }
    }

    // ---------------------------------------------------------------------------
    // Internal
    // ---------------------------------------------------------------------------
    #[generate_trait]
    impl InternalImpl of InternalTrait {

        fn _only_owner_of_token(self: @ContractState, token_id: u256) {
            assert(
                get_caller_address() == self.erc721.owner_of(token_id),
                Errors::NOT_OWNER
            );
        }
    }
}