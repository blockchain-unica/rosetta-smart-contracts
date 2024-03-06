module deploy_address::vesting {
    use aptos_framework::coin::{Self, Coin};
    use aptos_framework::signer;
    use aptos_framework::timestamp;
    
    struct Vesting<phantom CoinType> has key {
        owner: address,
        beneficiary: address,
        released: u64,
        start: u64,
        duration: u64,
        coins: Coin<CoinType>,
    }

    public fun init<CoinType>(owner: &signer, beneficiary: address, start: u64, duration: u64, coins: Coin<CoinType>) {
        let vesting = Vesting<CoinType> {
            owner: signer::address_of(owner),
            beneficiary: beneficiary,
            released: 0,
            start: start,
            duration: duration,
            coins: coins,
        };
        move_to(owner, vesting);
    }

    public fun release<CoinType>(owner: address) acquires Vesting {
        let vesting = borrow_global_mut<Vesting<CoinType>>(owner);
        let releasable_amount = releasable(vesting);
        vesting.released = vesting.released + releasable_amount;

        let coins = coin::extract<CoinType>(&mut vesting.coins, releasable_amount);
        coin::deposit<CoinType>(vesting.beneficiary, coins);
    }

    public fun releasable<CoinType>(vesting: &Vesting<CoinType>): u64 {
        vested_amount(vesting) - vesting.released
    }

    public fun vested_amount<CoinType>(vesting: &Vesting<CoinType>): u64 {
        vesting_schedule<CoinType>(vesting, coin::value(&vesting.coins) + vesting.released, timestamp::now_seconds())
    }

    public fun vesting_schedule<CoinType>(vesting: &Vesting<CoinType>, total_allocation: u64, timestamp: u64): u64 {
        if (timestamp < vesting.start) {
            0
        }
        else if ( timestamp >= vesting.start + vesting.duration) {
            total_allocation
        }
        else {
            (total_allocation * (timestamp - vesting.start)) / vesting.duration
        }
    }
}