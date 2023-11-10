// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

contract OracleBet {

    // player = players[choice]
    mapping (uint => address payable) players;

    uint timeout;
    bool open = true;
    address oracle;
    uint wager;

    event newBet(address bet, address player, uint choice);

    modifier onlyOracle(){
        require(msg.sender == oracle, "only the oracle");
        _;
    }

    constructor(uint _timeout, uint _wager) {
        wager = _wager;
        oracle = msg.sender;
        timeout = block.number + _timeout;
    }

    function bet(uint choice) payable public {
        require(msg.value == wager, "invalid value");
        require(choice > 0 && choice <= 2 , "invalid choice");
        require(open, "bets are closed");
        require(timeout >= block.number, "time out");
        require(players[choice] == address(0), "choice already selected" );

        players[choice] = payable(msg.sender);
        emit newBet(address(this), msg.sender, choice);

    }

    function oracleSetResult(uint result) external onlyOracle {
        require(timeout < block.number, "The bets are still open");
        require(open, "Results had already been set");

        open = false;
        address payable winner = players[result];
        (bool success,) = winner.call{value: address(this).balance}("");
        require (success, "Transfer failed.");



    }


}
