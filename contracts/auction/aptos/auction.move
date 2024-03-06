module smart_contracts_comparison::auction {

  use std::signer;
  use aptos_std::coin::{Self,Coin};

  struct Auction has key {
    auctioneer: address,
    top_bidder: address,
    expired: bool
  }

  struct Bid<phantom CoinType> has key {
    coins: Coin<CoinType>
  }

  public fun start<CoinType>(auctioneer: &signer, base: Coin<CoinType>) {
    let auctioneer_addr = signer::address_of(auctioneer);
    let auction =
      Auction { 
        auctioneer: auctioneer_addr,
        top_bidder: auctioneer_addr,
        expired: false
    };
    move_to(auctioneer, auction);
    move_to(auctioneer, Bid { coins: base });
  }

  public fun bid<CoinType>(acc: &signer, auctioneer: address, coins: Coin<CoinType>) acquires Auction, Bid {
    let auction = borrow_global_mut<Auction>(auctioneer);
    let Bid { coins: top_bid } = move_from<Bid<CoinType>>(auction.top_bidder);
    assert!(!auction.expired, 1);
    assert!(coin::value(&coins) > coin::value(&top_bid), 2);
    coin::deposit(auction.top_bidder, top_bid);
    auction.top_bidder = signer::address_of(acc);
    move_to(acc, Bid { coins });
  }
    
  public fun end<CoinType>(auctioneer: &signer) acquires Auction, Bid {
    let auctioneer_addr = signer::address_of(auctioneer);
    let auction = borrow_global_mut<Auction>(auctioneer_addr);
    assert!(auctioneer_addr == auction.auctioneer, 3);
    auction.expired = true;
    let Bid { coins: top_bid } = move_from<Bid<CoinType>>(auction.top_bidder);
    coin::deposit(auctioneer_addr, top_bid);
  }

}
