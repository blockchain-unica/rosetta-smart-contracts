# pragma version ^0.4.0

interface IERC20:
    def transfer(_to : address, _value : uint256) -> bool : nonpayable
    def transferFrom(_from : address, _to : address, _value : uint256) -> bool: nonpayable
    def balanceOf(_to: address) -> uint256: view 


# Token addresses
t0: public(immutable(address))
t1: public(immutable(address))

r0: public(uint256)
r1: public(uint256)

is_first_deposit: bool 
token_supply: public(uint256)
minted: public(HashMap[address, uint256])   # Amount of LP tokens for each user


@deploy
def __init__(_t0: address, _t1: address):
    t0 = _t0
    t1 = _t1
    self.is_first_deposit = True 


@view
@internal
def tokenBalance(token: address, user: address) -> uint256:
    result: Bytes[32] = raw_call(
        token,
        concat(
            method_id("balanceOf(address)"),
            convert(user, bytes32),
        ),
        max_outsize=32,
        is_static_call=True,
    )
    return convert(result, uint256)


@external
def deposit(x0: uint256, x1: uint256):
    assert x0 > 0 and x1 > 0, "Deposits amounts must be greater than zero"

    # Transfer tokens
    extcall IERC20(t0).transferFrom(msg.sender, self, x0)
    extcall IERC20(t1).transferFrom(msg.sender, self, x1)

    toMint: uint256 = 0

    if (not self.is_first_deposit): 
        assert self.r0 * x1 == self.r1 * x0, "Deposit ratio does not match current pool ratio"
        toMint = x0 * self.token_supply // self.r0

    else:
        self.is_first_deposit = False 
        toMint = x0
    

    # Liquidity tokens should be greater than zero
    assert toMint > 0, "Liquidity to mint must be greater than zero"  
    
    self.minted[msg.sender] += toMint
    self.token_supply += toMint
    self.r0 += x0 
    self.r1 += x1

    res0: uint256 = self.tokenBalance(t0, self)
    assert (res0 == self.r0), "t0 balance mismatch"

    res1: uint256 = self.tokenBalance(t1, self)
    assert (res1 == self.r1), "t1 balance mismatch"


@nonreentrant
@external
def redeem(amount: uint256):
    assert amount > 0, "Amount must be greater than zero"
    assert self.minted[msg.sender] >= amount, "Insufficient liquidity token"
    assert amount <= self.token_supply, "Invalid amount"

    x0: uint256 = (amount * self.r0) // self.token_supply
    x1: uint256 = (amount * self.r1) // self.token_supply

    # Transfer tokens to user
    extcall IERC20(t0).transfer(msg.sender, x0)
    extcall IERC20(t1).transfer(msg.sender, x1)

    # Update pool state
    self.r0 -= x0
    self.r1 -= x1
    self.token_supply -= amount
    self.minted[msg.sender] -= amount

    if self.token_supply == 0:
        self.is_first_deposit = True

    # Verify token balances match
    res0: uint256 = self.tokenBalance(t0, self)
    assert (res0 == self.r0), "t0 balance mismatch"

    res1: uint256 = self.tokenBalance(t1, self)
    assert (res1 == self.r1), "t1 balance mismatch"


@external
def swap(tokenAddress: address, x_in: uint256, x_min_out: uint256):
    assert tokenAddress == t0 or tokenAddress == t1, "Wrong token address"
    assert x_in > 0, "Input amount of tokens must be greater than zero"

    is_t0: bool = (tokenAddress == t0)

    t_in: address = empty(address)
    t_out: address = empty(address)
    r_in: uint256 = 0
    r_out: uint256 = 0

    # User sends in t0 and receives t1 tokens 
    if is_t0:
        t_in = t0 
        t_out = t1 
        r_in = self.r0 
        r_out = self.r1 

    # User sends in t1 and receives t0 tokens
    else:
        t_in = t1
        t_out = t0
        r_in = self.r1
        r_out = self.r0
    
    extcall IERC20(t_in).transferFrom(msg.sender, self, x_in)

    x_out: uint256 = x_in * r_out // (r_in + x_in)

    assert x_out >= x_min_out, "Token request not met"

    extcall IERC20(t_out).transfer(msg.sender, x_out)

    if is_t0:
        self.r0 += x_in 
        self.r1 -= x_out 
    else:
        self.r1 += x_in
        self.r0 -= x_out
    
    # Verify balances match actual ERC20 balances
    res0: uint256 = self.tokenBalance(t0, self)
    assert (res0 == self.r0), "t0 balance mismatch"

    res1: uint256 = self.tokenBalance(t1, self)
    assert (res1 == self.r1), "t1 balance mismatch"
