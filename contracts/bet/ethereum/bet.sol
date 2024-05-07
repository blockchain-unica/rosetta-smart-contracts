// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

contract Bet {

    // player = players[choice]
    mapping (uint => address payable) players;
    uint deadline;
    address oracle;
    uint wager;
    bool open = true;

    modifier onlyOracle(){
        require(msg.sender == oracle, "only the oracle");
        _;
    }

    constructor(address _oracle, address payable player2, uint _timeout) payable {
        wager = msg.value;
        // lore: aggiungere un require( msg.vaule == 1 ether ); per rispettare la specifica del README
        oracle = _oracle;
        players[0] = payable(msg.sender);
        players[1] = player2;
        deadline = block.number + _timeout;
    }

    function join() payable public {
        require(msg.value == wager, "invalid value");
        require(players[1] == msg.sender, "invalid player");
        require(open, "bets are closed");
        require(deadline >= block.number, "time out");
        open = false;
    }

    function win(uint winner) external onlyOracle {
        
        require(winner <=1, "Invalid winner selector"); 
        require(address(this).balance == 2*wager, "Invalid Balance");

        address payable addressWinner = players[winner];
        (bool success,) = addressWinner.call{value: address(this).balance}("");
        require (success, "Transfer failed.");

    }

    function timeout() external payable {
        require(deadline < block.number, "The bets are still open");
        require(address(this).balance == 2*wager, "Invalid Balance");
        (bool success,) = players[0].call{value: wager}("");
        require (success, "Transfer failed.");
        (bool success2,) = players[1].call{value: wager}("");
        require (success2, "Transfer failed.");
    }
}
