// SPDX-License-Identifier: GPL-3.0-only
pragma solidity >= 0.8.2;

contract Crowdfund {

    uint end_donate;    // last block in which users can donate
    uint goal;          // amount of ETH that must be donated for the crowdfunding to be succesful
    address receiver;   // receiver of the donated funds
    mapping(address => uint) public donors;

    constructor (address payable receiver_, uint end_donate_, uint256 goal_) {
        receiver = receiver_;
        end_donate = end_donate_;
	goal = goal_;	
    }
    
    function donate() public payable {
        require (block.number <= end_donate);
        donors[msg.sender] += msg.value;
    }

    function withdraw() public {
        require (block.number >= end_donate);
        require (address(this).balance >= goal);
        (bool succ,) = receiver.call{value: address(this).balance}("");
        require(succ);
    }
    
    function reclaim() public { 
        require (block.number >= end_donate);
        require (address(this).balance < goal);
        require (donors[msg.sender] > 0);
        uint amount = donors[msg.sender];
        donors[msg.sender] = 0;
        (bool succ,) = msg.sender.call{value: amount}("");
        require(succ);
    }
}
