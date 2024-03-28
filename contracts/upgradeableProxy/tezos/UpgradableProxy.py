import smartpy as sp
    
@sp.module
def main():
    class Logic(sp.Contract):
        def __init__(self, admin):
            self.data.admin = admin
            
        @sp.onchain_view()
        def check(self, address):
                            #(function name, address of the contract, parameters, return type)
            balance = sp.view("get_balance", address, (), sp.mutez).unwrap_some() #call CallerBalance
            
            if balance < sp.tez(100):
                return True
            else:
                return False

    class Proxy(sp.Contract):
        def __init__(self, admin, logicAddress):
            self.data.admin = admin
            self.data.logicAddress = logicAddress

        # To forward the message, the Proxy has a function with the same name as the Logic function.
        @sp.onchain_view
        def check(self, address):
            sp.cast(address, sp.address)
            answer = sp.view("check", self.data.logicAddress, address, sp.bool).unwrap_some() #call Logic
            return answer
    
    class Caller(sp.Contract):
        def __init__ (self, admin):
            self.data.admin = admin
            self.data.answer = None
    
        @sp.entrypoint
        def callLogicByProxy(self, address):
            answer = sp.view("check", address, sp.self_address(), sp.bool).unwrap_some() #call Proxy
            self.data.answer = sp.Some(answer)
        
        # This function exposes the balance of the contract outside the contract.
        @sp.onchain_view()
        def get_balance(self):
            return sp.balance



@sp.add_test()
def testProxy():
    sc = sp.test_scenario("TestProxy", main)
    admin = sp.test_account("admin")
    logic = main.Logic(admin.address)
    sc += logic
    proxy = main.Proxy(admin.address, logic.address)
    sc += proxy
    caller = main.Caller(admin.address)
    caller.set_initial_balance(sp.tez(10))
    sc += caller

    caller.callLogicByProxy(proxy.address)
    

    





