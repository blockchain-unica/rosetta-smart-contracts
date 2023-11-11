
module factory::factory {
    use sui::tx_context::{Self, TxContext};
    use sui::object::{Self, UID, ID};
    use sui::transfer;
    use sui::dynamic_field;
    use std::vector;

    const ErrorUnauthorized: u64 = 1;

    // Product can't be a Sui OWNED object, because anyone must be able to call getFactory on it.
    struct Product has key {
        id: UID,
        owner: address,
        factory: ID,
        tag: vector<u8>, // equivalent to string
    }

    // The Factory records the Products associated with each address.
    struct Factory has key {
        id: UID,
    }

    public entry fun create_factory(ctx: &mut TxContext) {
        let factory = Factory {
            id: object::new(ctx),
        };
        transfer::share_object(factory);
    }

    public entry fun createProduct(factory: &mut Factory, tag: vector<u8>, ctx: &mut TxContext) {
        let sender = tx_context::sender(ctx);
        let product = Product {
            id: object::new(ctx),
            owner: sender,
            factory: object::uid_to_inner(&factory.id),
            tag: tag,
        };

        let product_id = object::uid_to_inner(&product.id);
        if (dynamic_field::exists_with_type<address, vector<ID>>(&factory.id, sender)) {
            let products = dynamic_field::borrow_mut<address, vector<ID>>(&mut factory.id, sender);
            vector::push_back(products, product_id);
        } else {
            let products = vector::empty<ID>();
            vector::push_back(&mut products, product_id);
            dynamic_field::add(&mut factory.id, sender, products);
        };

        transfer::share_object(product);
    }

    public entry fun getProducts(factory: &mut Factory, ctx: &mut TxContext): vector<ID> {
        // The Products of an address are the IDs of the Product objects the address owns.
        let sender = tx_context::sender(ctx);
        if (dynamic_field::exists_with_type<address, vector<ID>>(&factory.id, sender)) {
            *dynamic_field::borrow<address, vector<ID>>(&factory.id, sender)
        } else {
            vector::empty<ID>()
        }
    }

    public entry fun getTag(product: &Product, ctx: &mut TxContext): vector<u8> {
        assert!(product.owner == tx_context::sender(ctx), ErrorUnauthorized);
        
        product.tag
    }

    public entry fun getFactory(product: &Product): ID {
        // The factory of a Product is the ID of the factory Object that created it
        product.factory
    }
}