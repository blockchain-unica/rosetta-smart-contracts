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

    constructor() {
        owner = msg.sender;
    }

    function join0() payable public {
        require (player0==address(0) && msg.value > .01 ether);
        player0 = payable(msg.sender);
    }

    function join1() payable public {
        require (player1==address(0) && msg.value > .01 ether);
        player1 = payable(msg.sender);
    }

    function commit0(bytes32 h) public {
        require (msg.sender==player0 && hash0==0);
        hash0 = h;
    }

    function commit1(bytes32 h) public {
        require (msg.sender==player1 && hash1==0);
        hash1 = h;
    }

    function reveal0(string memory s) public {
        require (msg.sender==player0);
        require (hash0!=0 && hash1!=0 &&  hash0 != hash1);
        require(keccak256(abi.encodePacked(s))==hash0);
        secret0 = s;
    }

    function reveal1(string memory s) public {
        require (msg.sender==player1);
        require (hash0!=0 && hash1!=0 &&  hash0 != hash1);
        require(keccak256(abi.encodePacked(s))==hash1);
        secret1 = s;
    }

    function win() public {
        uint256 l0 = bytes(secret0).length;
        uint256 l1 = bytes(secret1).length;
        require (l0!=0 && l1!=0);
        if ((l0+l1) % 2 == 0) {
            winner = player0;
        }
        else {
            winner = player1;
        }
        winner.transfer(address(this).balance);

        // reset state for next round
        player0 = player1 = payable(address(0));
        hash0 = hash1 = 0;
        secret0 = secret1 = "";
    }
}
