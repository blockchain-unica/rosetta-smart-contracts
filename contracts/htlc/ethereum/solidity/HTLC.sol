// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

contract HTLC {
   address payable public owner;  
   address payable public verifier;
   bytes32 public hash;
   uint reveal_timeout;
       
   constructor(address payable v, bytes32 h, uint delay) payable {
       require (msg.value >= 1 ether);
       owner = payable(msg.sender);
       verifier = v;
       hash = h;
       reveal_timeout = block.number + delay;
   }

   function reveal(string memory s) public {
       require (msg.sender==owner);
       require(keccak256(abi.encodePacked(s))==hash);
       (bool success,) = owner.call{value: address(this).balance}("");
       require (success, "Transfer failed.");
   }

   function timeout() public {
       require (block.number > reveal_timeout);
       (bool success,) = verifier.call{value: address(this).balance}("");
       require (success, "Transfer failed.");
   }
}
