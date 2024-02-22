import smartpy as sp


@sp.module
def main():
    class Storage(sp.Contract):
        def __init__(self):
            self.data.bytes = sp.bytes("0x00")
            self.data.string = ""

        @sp.entrypoint
        def storeBytes(self, _bytes):
            self.data.bytes = _bytes

        @sp.entrypoint
        def storeString(self, _string):
            self.data.string = _string


@sp.add_test()
def test():
    # set scenario
    sc = sp.test_scenario("Storage", main)
    # create object
    Storage = main.Storage()
    # start scenario
    sc += Storage