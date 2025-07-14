module price_bet::oracle;

public struct Oracle has key, store {
    id: UID,
    addr: address,
    exchange_rate: u64
}

public fun addr(self: &Oracle): address{
    self.addr
}

public fun exchange_rate(self: &Oracle): u64{
    self.exchange_rate
}

public fun createOracle(addr: address, exchange_rate: u64, ctx: &mut TxContext){
    let oracle = Oracle {
        id: object::new(ctx),
        addr,
        exchange_rate
    };
    transfer::share_object(oracle);
}