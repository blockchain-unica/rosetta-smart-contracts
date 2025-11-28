// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC721/ERC721.sol";

contract EditableToken is ERC721 {

	//Token Data
	struct Token {
		bytes data;      // custom data.
        bool isSealed;   // editable until sealed is false
	}

	uint public lastTokenId; // Id of the last minted token

	mapping(uint => Token) _tokens;

	modifier onlyOwnerOfToken(uint tokenId) {
		require(
			msg.sender == ownerOf(tokenId),
			"You must be the owner of the token in order to manage it."
		);
		_;
	}

	constructor () 	ERC721("EditableToken","ET") {
		}

    function sealToken(uint tokenId) external onlyOwnerOfToken(tokenId) {
        require(_tokens[tokenId].isSealed == false, "The token is on sale");
          _tokens[tokenId].isSealed = true;
    }

    function setTokenData(uint tokenId, bytes memory data) external onlyOwnerOfToken(tokenId) {
        require(_tokens[tokenId].isSealed == false, "The token is sealed");
          _tokens[tokenId].data = data;
    }

	function buyToken() external{
		lastTokenId += 1;
		_safeMint(msg.sender, lastTokenId);
	}

	function tranferTo(address dest, uint256 tokenID) external{
		transferFrom(msg.sender, dest, tokenID);
	}


	function getTokenData(uint tokenId) external view returns (bytes memory data, bool isSealed) {
    	require(_ownerOf(tokenId) != address(0), "Non existent token");
		return (
    		_tokens[tokenId].data,
    		_tokens[tokenId].isSealed
    	);
	}
}
