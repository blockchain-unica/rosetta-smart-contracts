module rosetta_smart_contracts::auction {

  use std::signer;
  use aptos_std::coin::{Self,Coin};

  // two separate datatypes, both tagged with the key ability for being stored on the blockchain
  // the first datatype stores administrative data for the Auction
  struct Auction has key {
    auctioneer: address,
    top_bidder: address,
    expired: bool
  }

  // the second datatype serves as an envelope for the current top bid to be stored on the blockchain
  struct Bid<phantom CoinType> has key {  // CoinType is a generic type: a bid can use any asset or currency type
    coins: Coin<CoinType>                 // the Coin type is not copiable and represents an actual amount of money/assets
  }

  // called by the auctioneer for initiating the auction
  public entry fun start<CoinType>(auctioneer: &signer, base: Coin<CoinType>) {
    let auctioneer_addr = signer::address_of(auctioneer);

    // instantiate the Auction datatype 
    let auction =                              
      Auction { 
        auctioneer: auctioneer_addr,
        top_bidder: auctioneer_addr,
        expired: false
    };

    move_to(auctioneer, auction);             // store the Auction on the blockchain
    move_to(auctioneer, Bid { coins: base }); // store the starting bid wrapped inside its envelope
  }

  // a bidder invokes this function passing actual money/assets as third argument
  // this literally moves the money/assets to the scope of this function
  public entry fun bid<CoinType>(acc: &signer, auctioneer: address, new_bid: Coin<CoinType>) acquires Auction, Bid {
    let auction = borrow_global_mut<Auction>(auctioneer); // get a mutable reference to the Auction without removing it from the blockchain

    // retrieve the current top bid without copying it: this moves it from the blockchain to the current scope
    let Bid { coins: top_bid } = move_from<Bid<CoinType>>(auction.top_bidder);  // top_bid binds the content of the envelope, i.e. the actual coins stored into it

    assert!(!auction.expired, 1);
    assert!(coin::value(&new_bid) > coin::value(&top_bid), 2);

    coin::deposit(auction.top_bidder, top_bid);   // we pay the original bidder back immediately to lose the ownership of the top_bid
    auction.top_bidder = signer::address_of(acc); // modify the current top bidder address 
    move_to(acc, Bid { new_bid });                // store the new bid into the blockchain inside a new envelope
  }
    
  public entry fun end<CoinType>(auctioneer: &signer) acquires Auction, Bid {
    let auctioneer_addr = signer::address_of(auctioneer);
    let auction = borrow_global_mut<Auction>(auctioneer_addr);
    assert!(auctioneer_addr == auction.auctioneer, 3);
    auction.expired = true;
    let Bid { coins: top_bid } = move_from<Bid<CoinType>>(auction.top_bidder);    // move the current top bid from the blockchain to this scope
    coin::deposit(auctioneer_addr, top_bid);    // pay the auctioneer 
  }

}
