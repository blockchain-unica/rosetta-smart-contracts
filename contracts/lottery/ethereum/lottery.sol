// SPDX-License-Identifier: GPL-3.0-only
pragma solidity >= 0.8.2;

contract Lottery {
    address public owner;

    address payable player0;
    address payable player1; 
    address payable winner;

    bytes32 hash0;
    bytes32 hash1;

    string secret0;
    string secret1;

    enum Status {
        Join0,
        Join1,
        Commit0,
        Commit1,
	Reveal0,
	Reveal1,
	Win,
        End
    }

    uint end_join;
    uint end_reveal;
    
    // Default value is the first element listed in
    // definition of the type, in this case "Pending"
    Status public status;
    
    constructor() {
        owner = msg.sender;
	status = Status.Join0;
	end_join = block.number + 1000;
	end_reveal = end_join + 1000;	
    }

    function join0(bytes32 h) payable public {
        require (status==Status.Join0 && msg.value > .01 ether);

        player0 = payable(msg.sender);
        hash0 = h;
	status = Status.Join1;
    }

    function join1(bytes32 h) payable public {
        require (status==Status.Join1 && h!=hash0 && msg.value > .01 ether);

        player1 = payable(msg.sender);
        hash1 = h;	
	status = Status.Reveal0;
    }

    function redeem0_nojoin1() public {
	require (status==Status.Join1 && block.number > end_join);

        (bool success,) = player0.call{value: address(this).balance}("");
        require (success, "Transfer failed.");
	status = Status.End;
    } 
    
    function reveal0(string memory s) public {
        require (status==Status.Reveal0 && msg.sender==player0);
        require(keccak256(abi.encodePacked(s))==hash0);

        secret0 = s;
	status = Status.Reveal1;
    }

    function redeem1_noreveal0() public {
	require (status==Status.Reveal0 && block.number > end_reveal);

        (bool success,) = player1.call{value: address(this).balance}("");
        require (success, "Transfer failed.");
	status = Status.End;
    } 
    
    function reveal1(string memory s) public {
        require (status==Status.Reveal1 && msg.sender==player1);
        require(keccak256(abi.encodePacked(s))==hash1);

        secret1 = s;
	status = Status.Win;
    }

    function redeem0_noreveal1() public {
	require (status==Status.Reveal1 && block.number > end_reveal);

        (bool success,) = player0.call{value: address(this).balance}("");
        require (success, "Transfer failed.");
	status = Status.End;
    } 
    
    function win() public {
        require (status==Status.Win);
	
        uint256 l0 = bytes(secret0).length;
        uint256 l1 = bytes(secret1).length;

        if ((l0+l1) % 2 == 0)  winner = player0;
        else winner = player1;

        (bool success,) = winner.call{value: address(this).balance}("");
        require (success, "Transfer failed.");
	status = Status.End;
    }
}
