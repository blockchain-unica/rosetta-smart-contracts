import credits.aleo;

program logic.aleo {
    
    @admin(address="aleo1rhgdu77hgyqd3xjj8ucu3jj9r2krwz6mnzyd80gncr5fxcwlh5rsvzp9px")
    constructor() {}

    fn check(a_:address) -> (bool,Final) {
        
        let success: bool = true;

        return (success,final{
            let bal: u64 = credits.aleo::account.get_or_use(a_, 0u64);

            assert(bal < 100u64);
        });
    }
}
