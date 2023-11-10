
module vesting::htlc {
    use sui::tx_context::{TxContext};
    use sui::object::{Self, UID};
    use sui::transfer;
    use sui::coin;
    use sui::clock::{Clock, timestamp_ms};

    struct Vesting<phantom T> has key {
        id: UID,
        startTimestampMs: u64,
        durationMs: u64,
        money: coin::Coin<T>,
        released: u64, // amount of money already released
    }

    public entry fun create_vesting<T>(beneficiary: address, startTimestampMs: u64, durationMs: u64, money: coin::Coin<T>, ctx: &mut TxContext) {
        let vesting = Vesting<T> {
            id: object::new(ctx),
            startTimestampMs: startTimestampMs,
            durationMs: durationMs,
            money: money,
            released: 0,
        };
        transfer::transfer(vesting, beneficiary);
    }

    public entry fun release<T>(vesting: &mut Vesting<T>, coin: &mut coin::Coin<T>, clock: &Clock, ctx: &mut TxContext) {
        let releasable = releasable(vesting, clock);
        vesting.released = vesting.released + releasable;
        coin::join(coin, coin::split(&mut vesting.money, releasable, ctx));
    }

    public fun releasable<T>(vesting: &Vesting<T>, clock: &Clock): u64 {
        vestedAmount(vesting, clock) - vesting.released
    }

    public fun vestedAmount<T>(vesting: &Vesting<T>, clock: &Clock): u64 {
        vestingSchedule(vesting, coin::value(&vesting.money) + vesting.released, timestamp_ms(clock))
    }

    fun vestingSchedule<T>(vesting: &Vesting<T>, totalAllocation: u64, timestampMs: u64): u64 {
        if (timestampMs < vesting.startTimestampMs) {
            0
        } else if (timestampMs > vesting.startTimestampMs + vesting.durationMs) {
            totalAllocation
        } else {
            (totalAllocation * (timestampMs - vesting.startTimestampMs)) / vesting.durationMs
        }
    }
}