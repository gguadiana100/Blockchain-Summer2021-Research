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
    bool public isMerged; // defines whether we have a composite NFT
    address[] public owners; // keep track of all owners of the NFT
    mapping(address => bool) public isOwner; // used to check if someone is an owner

    struct SalesTransaction {
      address from; // buyer
      address to; // recipient of token
      uint256[] tokenIds; // tokens for sale
      uint256 value; // price for token
      bool secondarySale; // check if we have a secondary sale
      bool revoked;
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
      isMerged = false;
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

    modifier salesTransactionNotRevoked(uint256 _txIndex) {
      require(!salesTransactions[_txIndex].revoked, "sales transaction is already revoked");
      _;
    }

    modifier onlySalesTransactionSender(uint256 _txIndex) { // restrict to the sender of the sales transaction
      require(salesTransactions[_txIndex].from == msg.sender, "not the sales transaction sender");
      _;
    }

    modifier ownedByContract(uint256[] _tokenIds) { // check if token IDs are valid and are owned by contract
      for(uint256 i = 0; i < _tokenIds.length; i++){
        require(_tokenIds[i] < tokenCounter, "invalid token ID");
        require(address(this) == _owners(_tokenIds[i]),"token not owned by contract");
      }
      _;
    }

    modifier allOwnedByContract() { // check if all NFTs are owned by the contract
      for(uint256 i = 0; i < tokenCounter; i++){
        require(address(this) == _owners(i),"not all tokens owned by contract");
      }
      _;
    }

    modifier isNotMerged() { // check if we have a composite NFT
      require(!isMerged, "NFT is a completed composite");
      _;
    }

    modifier hasBeenMinted(){ // check if an NFT has been minted
      require(tokenCounter > 0, "no NFTs have been minted");
      _;
    }

    // NFT minting function where only the current owner can mint. Smart contract holds NFTs upon minting
    function collaborativeMint(string memory _tokenURI) public onlyCurrentOwner isNotMerged returns (uint256) {
      uint256 newItemId = tokenCounter;
      _safeMint(address(this), newItemId); // the owner of the NFT is this smart contract
      _setTokenURI(newItemId, _tokenURI);
      tokenCounter = tokenCounter + 1;
      uint256 nextOwnerId = (currentOwner + 1) % owners.length; // set up the next turn by getting the following ID
      currentOwner = nextOwnerId; // update whose turn it is
      return newItemId;
    }

    // NFT minting function where only the current owner can mint. Smart contract holds NFTs upon minting
    function _collaborativeMint(string memory _tokenURI) private returns (uint256) {
      uint256 newItemId = tokenCounter;
      _safeMint(address(this), newItemId); // the owner of the NFT is this smart contract
      _setTokenURI(newItemId, _tokenURI);
      tokenCounter = tokenCounter + 1;
      return newItemId;
    }

    // merge all collaborative mints and create a composite NFT
    function mergeCollaborativeMint(string memory _tokenURI) public isOwner
      hasBeenMinted
      isNotMerged
      allOwnedByContract
      returns (bool)
    {
      isMerged = true;

      // burn all collaborative mints
      for(uint256 i = 0; i < tokenCounter; i++) {
        _burn(i);
      }

      // create a composite NFT
      _collaborativeMint(_tokenURI);
      return true;
    }

    receive() external payable {

    }

    function submitSalesTransaction(address memory _to, uint256[] memory _tokenIds)
      payable ownedByContract(_tokenIds) public returns (uint256)
    { // buyer sends sales transaction, returns transaction index
      uint256 txIndex = salesTransactions.length;

      salesTransactions.push(SalesTransaction({
        from: msg.sender;
        to: _to;
        tokenIds: _tokenIds;
        value: msg.value;
        secondarySale: false;
        revoked: false;
        executed: false;
        numConfirmations: 0;
      }));

      return txIndex;
    }

    function submitSecondarySalesTransaction(address memory _to, uint256[] memory _tokenIds, uint256 _value)
      public returns (uint256)
    { // buyer sends sales transaction, returns transaction index
      uint256 txIndex = salesTransactions.length;

      salesTransactions.push(SalesTransaction({
        from: msg.sender;
        to: _to;
        tokenIds: _tokenIds;
        value: _value;
        secondarySale: true;
        revoked: false;
        executed: false;
        numConfirmations: 0;
      }));

      return txIndex;
    }

    function approveSalesTransaction(uint256 _txIndex) onlyOwner
      salesTransactionExists(_txIndex)
      salesTransactionNotExecuted(_txIndex)
      salesTransactionNotConfirmed(_txIndex)
      salesTransactionNotRevoked(_txIndex)
      public returns (bool)
    { // owner approves sales transaction
      // update confirmations and number of confirmations
      salesTransactions[_txIndex].isConfirmed[msg.sender] = true;
      salesTransactions[_txIndex].numConfirmations += 1;

      if(salesTransactions[_txIndex].numConfirmations == numberOfOwners){ // execute if approved by all owners
        executeSalesTransaction(_txIndex);
      }
      return true;
    }

    function denySalesTransaction(uint256 _txIndex) onlyOwner
      salesTransactionExists(_txIndex)
      salesTransactionNotExecuted(_txIndex)
      salesTransactionNotRevoked(_txIndex)
      public returns (bool)
    { // owner denies sales transaction
      // update confirmations and number of confirmations
      require(salesTransactions[_txIndex].isConfirmed[msg.sender], "sales transaction not approved by owner")
      salesTransactions[_txIndex].isConfirmed[msg.sender] = false;
      salesTransactions[_txIndex].numConfirmations -= 1;
      return true;
    }

    // sender revoke sales transaction to get ETH back
    function revokeSalesTransaction(uint256 _txIndex) public returns (bool)
      salesTransactionExists(_txIndex)
      salesTransactionNotExecuted(_txIndex)
      salesTransactionNotRevoked(_txIndex)
    {
      require(salesTransactions[_txIndex].from == msg.owner, "must be account that submitted sales transaction")
      uint256 amountToPay = salesTransactions[_txIndex].value;
      bool success;
      (success, ) = salesTransactions[_txIndex].from.call.value(amountToPay)("");
      require(success, "Transfer failed.");
      salesTransactions[_txIndex].revoked = true;
      return true;
    }

    function executeSalesTransaction(uint _txIndex) private returns (bool) {
      uint256[] tokens = salesTransactions[_txIndex].tokenIds

      if(salesTransactions[_txIndex].secondarySale == false) { // initial sale
        // send ETH to each owner
        uint256 amountToPay = salesTransactions[_txIndex].value / numberOfOwners;
        bool success;
        // pay each owner
        for(uint256 i = 0; i < numberOfOwners; i++){
          (success, ) = owners[i].call.value(amountToPay)("");
          require(success, "Transfer failed.");
        }
      }
      else { // secondary sale
        // apply secondary sale fee and send ETH to each owner
        uint256 secondarySaleValue = salesTransactions[_txIndex].value / 10; // 10% goes to owners
        uint256 amountToPay = secondarySaleValue / numberOfOwners;
        bool success;
        // pay each owner
        for(uint256 i = 0; i < numberOfOwners; i++){
          (success, ) = owners[i].call.value(amountToPay)("");
          require(success, "Transfer failed.");
        }
      }

      // send each NFT from this smart contract to the new owner
      for(uint256 i = 0; i < tokens.length; i++){
        _safeTransfer(address(this), salesTransactions[_txIndex].to, tokens[i])
      }

      salesTransactions[_txIndex].executed = true;
      return true;
    }

    // Override safeTransferFrom to allow for royalties from secondary sales
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public virtual override {
      require(_isApprovedOrOwner(_msgSender(), tokenId), "ERC721: transfer caller is not owner nor approved");
      // create a secondary sales transaction, send NFT to contract, execute secondary sale
      uint256 secondarySaleId = submitSecondarySalesTransaction(to, [tokenId], msg.value);
      safeTransferFrom(from, address(this), tokenId, "");
      executeSalesTransaction(secondarySaleId);
    }

    // Override safeTransferFrom to allow for royalties from secondary sales
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        bytes memory _data
    ) public virtual override {
        require(_isApprovedOrOwner(_msgSender(), tokenId), "ERC721: transfer caller is not owner nor approved");
        // create a secondary sales transaction, send NFT to contract, execute secondary sale
        uint256 secondarySaleId = submitSecondarySalesTransaction(to, [tokenId], msg.value);
        safeTransferFrom(from, address(this), tokenId, "");
        executeSalesTransaction(secondarySaleId);
    }

    // Override transferFrom to allow for royalties from secondary sales
    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public virtual override {
        require(_isApprovedOrOwner(_msgSender(), tokenId), "ERC721: transfer caller is not owner nor approved");
        // create a secondary sales transaction, send NFT to contract, execute secondary sale
        uint256 secondarySaleId = submitSecondarySalesTransaction(to, [tokenId], msg.value);
        safeTransferFrom(from, address(this), tokenId, "");
        executeSalesTransaction(secondarySaleId);
    }

    function getSalesTransaction(uint256 _txIndex) public view returns (SalesTransaction) {
      return salesTransactions[_txIndex];
    }

    function isConfirmed(uint256 _txIndex, address _owner) public view returns (bool) {
      return salesTransactions[_txIndex].isConfirmed[_owner];
    }

}
