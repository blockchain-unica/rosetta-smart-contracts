// SPDX-License-Identifier: MIT
// adapted from https://solidity-by-example.org/app/english-auction/

pragma solidity ^0.8.17;

contract auction {
    enum States{WAIT_START, WAIT_CLOSING, CLOSED}
    States state;

    string public object;
    address payable public seller;
    uint public endTime;
    address public highestBidder;
    uint public highestBid;

    mapping(address => uint) public bids;

    constructor(string memory _object, uint _startingBid) {
        state = States.WAIT_START;
        object = _object;
        seller = payable(msg.sender);
        highestBid = _startingBid;
    }

    function start(uint _duration) external {
        require(state == States.WAIT_START, "Auction already started");
        require(msg.sender == seller, "Only the seller");
        state = States.WAIT_CLOSING;
        endTime = block.timestamp + (_duration * 1 seconds);
    }

    function bid() external payable {
        require(state == States.WAIT_CLOSING, "Auction not started");
        require(block.timestamp < endTime, "Time ended");
        require(msg.value > highestBid, "value < highest");

        // Previous highestBid goes in the list.
        if (highestBidder != address(0)) {
            bids[highestBidder] += highestBid;
        }

        // if a participant makes a new bid, the previous one is automatically withdrawn
        if (bids[msg.sender]!= 0){
            withdraw();
        }

        highestBidder = msg.sender;
        highestBid = msg.value;
    }

    function withdraw() public {
        require(state != States.WAIT_START, "Auction not started");
        uint bal = bids[msg.sender];
        bids[msg.sender] = 0;
        (bool success, ) = payable(msg.sender).call{value: bal}("");
        require(success, "Transfer failed.");

    }

    function end() external {
        require(msg.sender == seller, "Only the seller");
        require(state == States.WAIT_CLOSING, "Auction not started");
        require(block.timestamp >= endTime, "Auction not ended");
        state = States.CLOSED;
        (bool success, ) = seller.call{value: highestBid}("");
        require(success, "Transfer failed.");
    }

}