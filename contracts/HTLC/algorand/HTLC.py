from pyteal import *

A = Addr("2GYIH5HXKDNXA3F7BBIAT5IX744E2WY75GIQRLEWURVRK3XXDQ6LMRAHXU")
B = Addr("3MTDHUNSO4RXC3ZPJ67C7TLEOFHFO2UNXHE34PN52VN2CSNYSEOXXHPFNY")
H = Bytes("base16",
   "2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824")
S = Int(24134000)

def htlc(a = A, b = B, h = H, start = S):
    typeOK  = And(Txn.type_enum() == TxnType.Payment, 
                  Txn.amount() == Int(0))
    reveal  = And(Sha256(Arg(0)) == h, 
                  Txn.close_remainder_to() == a)
    timeout = And(Txn.first_valid() > start + Int(1000),
                  Txn.close_remainder_to() == b)
    return And(typeOK,Or(reveal,timeout))

if __name__ == "__main__":
    print(compileTeal(htlc(), Mode.Signature))