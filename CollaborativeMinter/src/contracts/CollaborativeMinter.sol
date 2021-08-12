// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// ERC721URIStorage allows you to set tokenURI after minting
// ERC721Holder ensures that a smart contract can hold NFTs
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";

// NFT Smart Contract Constructor
contract CollaborativeMinter is ERC721URIStorage, ERC721Holder{
    uint256 public tokenCounter;
    uint256 public currentOwner; // define whose turn it is at the current time with owners index\
    uint256 public numberOfOwners;
    address[] public owners; // keep track of all owners of the NFT
    mapping(address => bool) public isOwner; // used to check if someone is an owner
    mapping(uint256 => bool) public secondarySale; // used to check if the token sale is a secondary sale

    struct SalesTransaction {
      address from; // buyer
      address to; // recipient of token
      uint256 tokenId; // token for sale
      uint256 value; // price for token
      bool executed;
      mapping(address => bool) isConfirmed; // check if confirmed by owners
      uint256 numConfirmations;
    }

    SalesTransaction[] public salesTransactions;

    constructor (address[] memory _owners) public ERC721 ("Collaborative Mint", "COMINT"){
      require(_owners.length > 0, "owners required");
      tokenCounter = 0;
      numberOfOwners = _owners.length;
      currentOwner = 0; // define the first owner to have an active turn
      for(uint256 i = 0; i < _owners.length; i++){ // define the owners
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

    modifier salesTransactionExists(uint256 _txIndex) { // restrict only to transactions that exist
      require(_txIndex < salesTransactions.length, "sales transaction does not exist");
      _;
    }

    modifier salesTransactionNotExecuted(uint256 _txIndex) { // restrict only to transactions that are not executed
      require(!salesTransactions[_txIndex].executed, "sales transaction is already executed");
      _;
    }

    modifier salesTransactionNotConfirmed(uint256 _txIndex) { // restrict only to transactions that are not confirmed by caller
      require(!salesTransactions[_txIndex].isConfirmed[msg.sender], "sales transaction is already confirmed");
      _;
    }

    modifier onlySalesTransactionSender(uint256 _txIndex) { // restrict to the sender of the sales transaction
      require(salesTransactions[_txIndex].from == msg.sender, "not the sales transaction sender");
      _;
    }

    // NFT minting function where only the current owner can mint
    function collaborativeMint(string memory _tokenURI) public onlyCurrentOwner returns (uint256) {
        uint256 newItemId = tokenCounter;
        _safeMint(address(this), newItemId); // the owner of the NFT is this smart contract
        _setTokenURI(newItemId, _tokenURI);
        secondarySale[tokenCounter] = false; // the first token sale is not a secondary sale
        tokenCounter = tokenCounter + 1;
        uint256 nextOwnerId = (currentOwner + 1) % owners.length; // set up the next turn by getting the following ID
        currentOwner = nextOwnerId; // update whose turn it is
        return newItemId;
    }

    function submitSalesTransaction() public returns (uint256) { // buyer sends sales transaction
      return 0;
    }

    function approveSalesTransaction(uint256 _txIndex) onlyOwner public returns (bool) { // owner approves sales transaction

      if(salesTransactions[_txIndex].numConfirmations == numberOfOwners){ // execute if approved by all owners
        executeSalesTransaction(_txIndex);
      }
      return true;
    }

    function denySalesTransaction(uint256 _txIndex) onlyOwner public returns (bool) {
      return true;
    }

    function revokeSalesTransaction(uint256 _txIndex) public returns (bool) {
      return true;
    }

    function executeSalesTransaction(uint _txIndex) private returns (bool) {
      return true;
    }

    function getSalesTransaction(uint256 _txIndex) public view returns (SalesTransaction) {
      return salesTransactions[0];
    }

    function isConfirmed(uint256 _txIndex, address _owner) public view returns (bool) {
      return true;
    }

}
