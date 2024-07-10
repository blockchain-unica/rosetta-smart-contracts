// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

contract Bet {

    address payable player1;
    address payable player2;
    uint deadline;
    address oracle;
    uint wager;
    bool open = true;

    constructor(address _oracle, address payable _player2, uint _timeout) payable {
        wager = msg.value;
        oracle = _oracle;
        player1 = payable(msg.sender);
        player2 = _player2;
        deadline = block.number + _timeout;
    }

    function join() payable public {
        require(msg.value == wager, "invalid value");
        require(player2 == msg.sender, "invalid player");
        require(open, "bets are closed");
        require(deadline >= block.number, "time out");
        open = false;
    }

    function win(uint winner) external  {
        require(msg.sender == oracle, "only the oracle");
        require(winner <=1, "Invalid winner selector"); 
        require(address(this).balance == 2*wager, "Invalid Balance");
        address payable addressWinner = (winner == 0) ? player1 : player2;
        (bool success,) = addressWinner.call{value: address(this).balance}("");
        require (success, "Transfer failed.");

    }

    function timeout() external payable {
        require(deadline < block.number, "The bets are still open");
        require(address(this).balance == 2*wager, "Invalid Balance");
        (bool success,) = player1.call{value: wager}("");
        require (success, "Transfer failed.");
        (bool success2,) = player2.call{value: wager}("");
        require (success2, "Transfer failed.");
    }
}
