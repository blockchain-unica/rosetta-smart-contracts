module algomove::auction_with_item {

    use algomove::asset::{ Self, Asset };
    use algomove::transaction;

    // two separate datatypes, both tagged with the key ability for being stored on the blockchain

    // the first datatype stores administrative data for the Auction
    // the item represents the prize of the auction
    struct Auction<ItemType : store> has key {
        item: ItemType,
        auctioneer: address,
        top_bidder: address,
        expired: bool
    }

    // the second datatype serves as an envelope for the current top bid to be stored on the blockchain
    struct Bid<phantom CoinType> has key {  // CoinType is a generic type: a bid can use any asset or currency type
        coins: Coin<CoinType>               // the Coin type is not copiable and represents an actual amount of money/assets
    }

    // called by the auctioneer for initiating the auction
    public fun start_auction<AssetType, ItemType : store>(acc: &signer, base: Asset<AssetType>, item: ItemType) {
        let auctioneer = transaction::address_of_signer(acc);
        let auction = Auction { item, auctioneer, top_bidder: auctioneer, expired: false };
        move_to(acc, auction);                  // store the Auction on the blockchain
        move_to(acc, Bid { assets: base });     // store the starting bid wrapped inside its envelope
    }

    // called by participants willing to bid. Must know the address of the auctioneer
    public fun bid<AssetType, ItemType : store>(acc: &signer, auctioneer: address, assets: Asset<AssetType>) acquires Auction, Bid {
        let auction = borrow_global_mut<Auction<ItemType>>(auctioneer);
        let Bid { assets: top_bid } = move_from<Bid<AssetType>>(auction.top_bidder);
        assert!(!auction.expired, 1);
        assert!(asset::value(&assets) > asset::value(&top_bid), 2);
        asset::deposit(auction.top_bidder, top_bid);
        auction.top_bidder = transaction::address_of_signer(acc);
        move_to(acc, Bid { assets });
    }

    // called by the auctioneed to terminate the auction
    public fun finalize_auction<AssetType, ItemType : store>(acc: &signer) acquires Auction, Bid {
        let auctioneer = transaction::address_of_signer(acc);
        let auction = borrow_global_mut<Auction<ItemType>>(auctioneer);
        assert!(auctioneer == auction.auctioneer, 3);
        auction.expired = true;
        let Bid { assets: top_bid } = move_from<Bid<AssetType>>(auction.top_bidder);
        asset::deposit(auctioneer, top_bid);
    }

    // called by the winner to retrieve the prize. Must know the address of the auctioneer
    public fun retrieve_prize<AssetType, ItemType : store>(acc: &signer, auctioneer: address): ItemType acquires Auction {
        let self = transaction::address_of_signer(acc);
        let Auction { item, auctioneer: auc, top_bidder, expired } = move_from<Auction<ItemType>>(auctioneer);
        assert!(auctioneer == auc, 3);
        assert!(self == top_bidder, 4);
        assert!(expired == true, 5);
        item
    }

}