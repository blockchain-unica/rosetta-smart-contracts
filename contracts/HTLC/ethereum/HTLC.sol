// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

contract HTLC {
   address payable public owner;  
   address payable public verifier;
   bytes32 public hash;
   uint start;
 
   constructor(address payable v) {
       owner = payable(msg.sender);
       verifier = v;
       start = block.number;
   }

   function commit(bytes32 h) public payable {
       require (msg.sender==owner);
       require (msg.value >= 1 ether);
       hash = h;
   }

   function reveal(string memory s) public {
       require (msg.sender==owner);
       require(keccak256(abi.encodePacked(s))==hash);
       (bool success,) = owner.call{value: address(this).balance}("");
       require (success, "Transfer failed.");
   }

   function timeout() public {
       require (block.number > start + 1000);
       (bool success,) = verifier.call{value: address(this).balance}("");
       require (success, "Transfer failed.");
   }
}
