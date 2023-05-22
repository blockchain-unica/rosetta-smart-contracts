// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

contract TinyAMM {
    IERC20 public immutable t0;
    IERC20 public immutable t1;

    uint public r0;
    uint public r1;

    bool ever_deposited;
    uint public supply;
    mapping(address => uint) public minted;
      
    constructor(address t0_, address t1_) {
	    t0 = IERC20(t0_);
	    t1 = IERC20(t1_);
    }

    function deposit(uint x0, uint x1) public {
	    require (x0>0 && x1>0);
	
	    t0.transferFrom(msg.sender, address(this), x0);
	    t1.transferFrom(msg.sender, address(this), x1);
       
	    uint toMint;
       
	    if (ever_deposited) {
    	    require(r0 * x1 == r1 * x0);
	        toMint = (x0 * supply) / r0;
	    }
	    else {
    	    ever_deposited = true;
	        toMint = x0;
	    }
       
    	require(toMint > 0);
       
        minted[msg.sender] += toMint;
        supply += toMint;
        r0 += x0;
        r1 += x1;
       
        assert(t0.balanceOf(address(this)) == r0);
        assert(t1.balanceOf(address(this)) == r1);
    }

    function redeem(uint x) public {
        require (minted[msg.sender] >= x);
        require (x < supply);

        uint x0 = (x * r0) / supply;
        uint x1 = (x * r1) / supply;
            
        t0.transferFrom(address(this), msg.sender, x0);
        t1.transferFrom(address(this), msg.sender, x1);

        r0 -= x0;
        r1 -= x1;
        supply -= x;
        minted[msg.sender] -= x;
        
        assert(t0.balanceOf(address(this)) == r0);
        assert(t1.balanceOf(address(this)) == r1);	
    }

    function swap(address t, uint x_in, uint x_out_min) public {
        require(t == address(t0) || t == address(t1));
        require(x_in > 0);
        
        bool is_t0 = t == address(t0);
        (IERC20 t_in, IERC20 t_out, uint r_in, uint r_out) = is_t0
            ? (t0, t1, r0, r1)
            : (t1, t0, r1, r0);
        
        t_in.transferFrom(msg.sender, address(this), x_in);
        
        uint x_out = x_in * r_out * (r_in + x_in);
        
        require (x_out >= x_out_min);

        t_out.transfer(msg.sender, x_out);
        
        (r0,r1) = is_t0
            ? (r0 + x_in, r1 - x_out)
            : (r0 - x_out, r1 + x_in);
        
        assert(t0.balanceOf(address(this)) == r0);
        assert(t1.balanceOf(address(this)) == r1);
    }
}

interface IERC20 {
    event Transfer(address indexed from, address indexed to, uint256 value);

    event Approval(address indexed owner, address indexed spender, uint256 value);

    function totalSupply() external view returns (uint256);

    function balanceOf(address account) external view returns (uint256);

    function transfer(address to, uint256 amount) external returns (bool);

    function allowance(address owner, address spender) external view returns (uint256);

    function approve(address spender, uint256 amount) external returns (bool);

    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}
