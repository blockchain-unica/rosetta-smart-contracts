/* SPDX-License-Identifier: MIT */

pragma solidity ^0.8.6;

contract SimpleEthereumDIDRegistry {

  // owner = owners[identity]
  mapping(address => address) public owners;

  // validity = delegates[identity][keccak of delegateType][delegate]
  mapping(address => mapping(bytes32 => mapping(address => uint))) public delegates;


  modifier onlyOwner(address identity, address actor) {
    require (actor == identityOwner(identity), "bad_actor");
    _;
  }

  function identityOwner(address identity) public view returns(address) {
     address owner = owners[identity];
     if (owner != address(0x00)) {
       return owner;
     }
     return identity;
  }

  function checkSignature(
      address identity,
      uint8 sigV,
      bytes32 sigR,
      bytes32 sigS,
      bytes32 hash)
      internal
      returns(address) {
    address signer = ecrecover(hash, sigV, sigR, sigS);
    require(signer == identityOwner(identity), "bad_signature");
    nonce[signer]++;
    return signer;
  }

  function validDelegate(
    address identity,
    bytes32 delegateType,
    address delegate)
    public
    view
    returns(bool) {
    uint validity = delegates[identity][keccak256(abi.encode(delegateType))][delegate];
    return (validity > block.timestamp);
  }

  function changeOwner(
    address identity,
    address actor,
    address newOwner)
    internal
    onlyOwner(identity, actor) {
    owners[identity] = newOwner;
    changed[identity] = block.number;
  }

  function changeOwner(
    address identity,
    address newOwner)
    public {
    changeOwner(identity, msg.sender, newOwner);
  }


  function changeOwnerSigned(
    address identity,
    uint8 sigV,
    bytes32 sigR,
    bytes32 sigS,
    address newOwner)
    public {
    bytes32 hash = keccak256(abi.encodePacked(bytes1(0x19), bytes1(0), this, nonce[identityOwner(identity)], identity, "changeOwner", newOwner));
    changeOwner(identity, checkSignature(identity, sigV, sigR, sigS, hash), newOwner);
  }

  function addDelegate(
    address identity,
    address actor,
    bytes32 delegateType,
    address delegate,
    uint validity)
    internal
    onlyOwner(identity, actor) {
    delegates[identity][keccak256(abi.encode(delegateType))][delegate] = block.timestamp + validity;
    changed[identity] = block.number;
  }

  function addDelegate(
    address identity,
    bytes32 delegateType,
    address delegate,
    uint validity)
    public {
    addDelegate(identity, msg.sender, delegateType, delegate, validity);
  }

  function addDelegateSigned(
    address identity,
    uint8 sigV,
    bytes32 sigR,
    bytes32 sigS,
    bytes32 delegateType,
    address delegate,
    uint validity)
    public {
    bytes32 hash = keccak256(abi.encodePacked(bytes1(0x19), bytes1(0), this, nonce[identityOwner(identity)], identity, "addDelegate", delegateType, delegate, validity));
    addDelegate(identity, checkSignature(identity, sigV, sigR, sigS, hash), delegateType, delegate, validity);
  }




}