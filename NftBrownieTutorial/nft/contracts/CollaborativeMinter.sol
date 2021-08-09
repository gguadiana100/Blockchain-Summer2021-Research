// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// ERC721URIStorage allows you to set tokenURI after minting
// ERC721Holder ensures that a smart contract can hold NFTs
// ERC721Burnable allows you to burn the NFT if you so choose
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
// import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";


// NFT Smart Contract Constructor
contract CollaborativeMinter is ERC721URIStorage, ERC721Holder{
    uint256 public tokenCounter;
    uint256 public currentOwner; // define whose turn it is at the current time with owners index\
    uint256 public numberOfOwners;
    address[] public owners; // keep track of all owners of the NFT
    mapping(address => bool) public isOwner; // used to check if someone is an owner

    constructor (address[] memory _owners) public ERC721 ("Collaborative Mint", "COMINT"){
      require(_owners.length > 0, "owners required");
      tokenCounter = 0;
      numberOfOwners = _owners.length;
      currentOwner = 0; // define the first owner to have an active turn
      for(uint i = 0; i < _owners.length; i++){ // define the owners
        owners.push(_owners[i]);
        isOwner[_owners[i]] = true;
      }
    }

    modifier onlyCurrentOwner { // restrict to only the active owner
      require(msg.sender == owners[currentOwner], "not your turn");
      _;
    }

    modifier onlyOwner { // restrict to only owners
      require(isOwner[msg.sender],'not an owner');
      _;
    }

    // NFT minting function where only the current owner can mint
    function collaborativeMint(string memory _tokenURI) public onlyCurrentOwner returns (uint256) {
        uint256 newItemId = tokenCounter;
        _safeMint(address(this), newItemId); // the owner of the NFT is this smart contract
        _setTokenURI(newItemId, _tokenURI);
        tokenCounter = tokenCounter + 1;
        uint256 nextOwnerId = (currentOwner + 1) % owners.length; // set up the next turn by getting the following ID
        currentOwner = nextOwnerId; // update whose turn it is
        return newItemId;
    }
}
