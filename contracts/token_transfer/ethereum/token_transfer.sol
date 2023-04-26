// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

// set the relative path
import "solidity/openzeppelin/token/ERC20/ERC20.sol";

contract TheToken is ERC20 {
    constructor() ERC20("theToken", "TTK") {}

    function mint(address recipient, uint256 quantity) public{
        _mint(recipient,quantity);
    }
}


contract TokenTransfer{

   event Withdraw(address indexed sender, uint amount);
   address payable recipient;
   address owner;
   address payable tokenAddress;
   TheToken theToken;

   constructor(address payable _recipient, address payable _tokenAddress){
       recipient = _recipient;
       owner = msg.sender;
       tokenAddress = _tokenAddress;
   }

   // "approve" required before calling deposit
   function deposit(uint256 _amount) public {
       require(msg.sender == owner, "only the owner");
       theToken = TheToken(tokenAddress);
       address contractAddress = address(this);

       (bool success) = theToken.transferFrom(msg.sender, contractAddress,_amount);
       require(success, "Deposit failed.");

   }


   function withdraw(uint256 amount) public {
       require(msg.sender == recipient, "only the recipient can withdraw");
       theToken = TheToken(tokenAddress);
       require(theToken.balanceOf(address(this)) > 0, "The contract balance is zero");

       if ( theToken.balanceOf(address(this)) < amount){
           amount = theToken.balanceOf(address(this));
       }

       (bool success ) = theToken.transfer(msg.sender, amount);
       require(success, "Transfer failed.");
       emit Withdraw(msg.sender, amount);

   }

}