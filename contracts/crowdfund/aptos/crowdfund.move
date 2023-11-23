module crowdfund_deployer::crowdfund {
    use aptos_framework::coin::{Self, Coin};
    use aptos_framework::signer;
    use aptos_framework::block;

    struct Crowdfund<phantom CoinType> has key {
        end_donate: u64,            // last block in which users can donate
        goal: u64,                  // amount that must be donated for the crowdfunding to be succesful
        receiver: address,          // receiver of the donated funds
        funding: Coin<CoinType>,    // amount that has been donated
    }

    struct Receipt<phantom CoinType> has key {
        amount: u64,
    }

    public fun init<CoinType>(crowdFundingOwner: &signer, end_donate: u64, goal: u64, receiver: address) {
        let funding = coin::zero<CoinType>();
        let crowdfund = Crowdfund {
            end_donate,
            goal,
            receiver,
            funding,
        };
        move_to(crowdFundingOwner, crowdfund);

    }

    public fun donate<CoinType>(sender: &signer, crowdFundingOwner: address, donation: Coin<CoinType>) acquires Crowdfund {
        let crowdfund = borrow_global_mut<Crowdfund<CoinType>>(crowdFundingOwner);
        assert!(block::get_current_block_height() <= crowdfund.end_donate, 0);
        let receipt = Receipt<CoinType> {
            amount: coin::value(&donation),
        };
        coin::merge(&mut crowdfund.funding, donation);
        move_to(sender, receipt);

    }

    public fun withdraw<CoinType>(crowdFundingOwner: address) acquires Crowdfund {
        let crowdfund = borrow_global_mut<Crowdfund<CoinType>>(crowdFundingOwner);
        assert!(block::get_current_block_height() >= crowdfund.end_donate, 0);
        assert!(coin::value(&crowdfund.funding) >= crowdfund.goal, 0);
        let amount = coin::value(&crowdfund.funding);
        let funding = coin::extract(&mut crowdfund.funding, amount);
        coin::deposit(crowdfund.receiver, funding);
    }

    public fun reclaim<CoinType>(sender: &signer, crowdFundingOwner: address) acquires Crowdfund, Receipt {
        let crowdfund = borrow_global_mut<Crowdfund<CoinType>>(crowdFundingOwner);
        assert!(block::get_current_block_height() >= crowdfund.end_donate, 0);
        assert!(coin::value(&crowdfund.funding) <= crowdfund.goal, 0);
        let Receipt { amount } = move_from<Receipt<CoinType>>(signer::address_of(sender));
        let donation = coin::extract(&mut crowdfund.funding, amount);
        coin::deposit(signer::address_of(sender), donation);
    }
}