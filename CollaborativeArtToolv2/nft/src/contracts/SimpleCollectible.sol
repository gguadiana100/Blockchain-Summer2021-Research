// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";

// NFT Smart Contract Constructor
contract SimpleCollectible is ERC721URIStorage {
    // ERC721URIStorage allows you to set tokenURI after minting
    // ERC721Burnable allows you to burn the NFT if you so choose

    uint256 public tokenCounter;
    constructor () public ERC721 ("CollaborativeArt", "CART"){
        tokenCounter = 0;
    }

    // NFT deploy function that anyone can call
    function createCollectible(string memory tokenURI) public returns (uint256) { // consider changing from public to owner for higher fidelity
        uint256 newItemId = tokenCounter;
        _safeMint(msg.sender, newItemId);
        _setTokenURI(newItemId, tokenURI);
        tokenCounter = tokenCounter + 1;
        return newItemId;
    }

}
