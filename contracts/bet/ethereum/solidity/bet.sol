// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

contract Bet {

    address payable player1;
    address payable player2;
    uint deadline;
    address oracle;
    uint wager;

    constructor(address _oracle, uint _timeout) payable {
        player1 = payable(msg.sender);
        wager = msg.value;
        oracle = _oracle;
        deadline = block.number + _timeout;
    }

    function join() payable public {
        require(msg.value == wager, "Invalid value");
        require(player2 == address(0), "Player2 already joined");
        require(block.number <= deadline, "Timeout");
        player2 = payable(msg.sender);
    }

    function win(uint winner) external  {
        require(msg.sender == oracle, "Only the oracle");
        require(player2 != address(0), "Player2 has not joined");
        require(winner <= 1, "Invalid winner"); 

        address payable addressWinner = (winner == 0) ? player1 : player2;
        (bool success,) = addressWinner.call{value: address(this).balance}("");
        require (success, "Transfer failed.");
    }

    function timeout() external payable {
        require(block.number > deadline, "The timeout has not passed");

        (bool success,) = player1.call{value: wager}("");
        require (success, "Transfer failed.");

        if (player2 != address(0)) {
            (bool success2,) = player2.call{value: wager}("");
            require (success2, "Transfer failed.");
        }

        // warning: extra funds may remain frozen in the contract
    }
}
