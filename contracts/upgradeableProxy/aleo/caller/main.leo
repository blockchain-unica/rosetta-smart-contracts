import logic.aleo;

program caller.aleo {

    @noupgrade
    constructor() {}

    fn call_logic_by_proxy() -> (bool, Final) {
        let (result, f): (bool, Final) = logic.aleo::check(self.address);

        return (result, final {
            f.run();
        });
    }
}