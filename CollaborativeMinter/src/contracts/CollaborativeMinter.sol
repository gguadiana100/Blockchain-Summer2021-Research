// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// ERC721URIStorage allows you to set tokenURI after minting
// ERC721Holder ensures that a smart contract can hold NFTs
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";

library CollaborativeMinterHolder {

    struct SalesTransaction {
      address from; // buyer
      address to; // recipient of token
      uint256[] tokenIds; // tokens for sale
      uint256 value; // price for token
      bool secondarySale; // check if we have a secondary sale
      bool revoked;
      bool executed;
      bool executing; // check if library is executing transation
      bool modifying; // check if transaction is being modified
      uint256 numConfirmations;
    }

    modifier onlyOwner(CollaborativeMinter _collaborativeMinter) { // restrict to only owners
      require(_collaborativeMinter.isOwner(msg.sender),'not an owner');
      _;
    }

    // restrict only to transactions that exist
    modifier salesTransactionExists(uint256 _txIndex, SalesTransaction[] storage _salesTransactions) {
      require(_txIndex < _salesTransactions.length, "sales transaction does not exist");
      _;
    }

    // restrict only to transactions that are not executed
    modifier salesTransactionNotExecuted(uint256 _txIndex, SalesTransaction[] storage _salesTransactions) {
      require(!_salesTransactions[_txIndex].executed, "sales transaction is already executed");
      _;
    }

    // restrict only to transactions that are not confirmed by caller
    modifier salesTransactionNotConfirmed(uint256 _txIndex, CollaborativeMinter _collaborativeMinter) {
      require(!_collaborativeMinter.getConfirmation(_txIndex, msg.sender), "sales transaction is already confirmed");
      _;
    }

    // restrict only to transactions that are not revoked by original buyer
    modifier salesTransactionNotRevoked(uint256 _txIndex, SalesTransaction[] storage _salesTransactions) {
      require(!_salesTransactions[_txIndex].revoked, "sales transaction is already revoked");
      _;
    }

    // restrict to the sender of the sales transaction
    modifier onlySalesTransactionSender(uint256 _txIndex, SalesTransaction[] storage _salesTransactions) {
      require(_salesTransactions[_txIndex].from == msg.sender, "not the sales transaction sender");
      _;
    }

    // check if token IDs are valid and are owned by contract
    modifier ownedByContract(uint256[] memory _tokenIds, CollaborativeMinter _collaborativeMinter) {
      for(uint256 i = 0; i < _tokenIds.length; i++){
        require(_tokenIds[i] < _collaborativeMinter.tokenCounter(), "invalid token ID");
        require(_collaborativeMinter.isApprovedOrOwner(address(_collaborativeMinter),_tokenIds[i]),"token not owned by contract");
      }
      _;
    }

    modifier allOwnedByContract(CollaborativeMinter _collaborativeMinter) { // check if all NFTs are owned by the contract
      for(uint256 i = 0; i < _collaborativeMinter.tokenCounter(); i++){
        require(_collaborativeMinter.isApprovedOrOwner(address(_collaborativeMinter),i),"not all tokens owned by contract");
      }
      _;
    }

    function submitSalesTransaction(address _from, address _to, uint256[] memory _tokenIds, uint256 _value,
      SalesTransaction[] storage _salesTransactions, CollaborativeMinter _collaborativeMinter)
      ownedByContract(_tokenIds, _collaborativeMinter) public returns (uint256)
    { // buyer sends sales transaction, returns transaction index
      uint256 txIndex = _salesTransactions.length;

      _salesTransactions.push(SalesTransaction({
        from: _from,
        to: _to,
        tokenIds: _tokenIds,
        value: _value,
        secondarySale: false,
        revoked: false,
        executed: false,
        executing: false,
        modifying: false,
        numConfirmations: 0
      }));

      return txIndex;
    }

    function submitSecondarySalesTransaction(address _from, address _to, uint256[] memory _tokenIds, uint256 _value,
      SalesTransaction[] storage _salesTransactions)
      public returns (uint256)
    { // buyer sends sales transaction, returns transaction index
      uint256 txIndex = _salesTransactions.length;

      _salesTransactions.push(SalesTransaction({
        from: _from,
        to: _to,
        tokenIds: _tokenIds,
        value: _value,
        secondarySale: true,
        revoked: false,
        executed: false,
        executing: false,
        modifying: false,
        numConfirmations: 0
      }));

      return txIndex;
    }

    function approveSalesTransaction(uint256 _txIndex, SalesTransaction[] storage _salesTransactions,
      CollaborativeMinter _collaborativeMinter)
      onlyOwner(_collaborativeMinter)
      salesTransactionExists(_txIndex, _salesTransactions)
      salesTransactionNotExecuted(_txIndex, _salesTransactions)
      salesTransactionNotConfirmed(_txIndex, _collaborativeMinter)
      salesTransactionNotRevoked(_txIndex, _salesTransactions)
      public returns (bool)
    { // owner approves sales transaction
      // update confirmations and number of confirmations
      _salesTransactions[_txIndex].modifying = true;
      _collaborativeMinter.setConfirmation(_txIndex, msg.sender, true);
      _salesTransactions[_txIndex].modifying = false;
      _salesTransactions[_txIndex].numConfirmations += 1;

      if(_salesTransactions[_txIndex].numConfirmations == _collaborativeMinter.numberOfOwners()){ // execute if approved by all owners
        _salesTransactions[_txIndex].executing = true;
        executeSalesTransaction(_txIndex, _salesTransactions, _collaborativeMinter);
        _salesTransactions[_txIndex].executing = false;
      }
      return true;
    }

    function denySalesTransaction(uint256 _txIndex, SalesTransaction[] storage _salesTransactions,
      CollaborativeMinter _collaborativeMinter)
      onlyOwner(_collaborativeMinter)
      salesTransactionExists(_txIndex, _salesTransactions)
      salesTransactionNotExecuted(_txIndex, _salesTransactions)
      salesTransactionNotRevoked(_txIndex, _salesTransactions)
      public returns (bool)
    { // owner denies sales transaction
      // update confirmations and number of confirmations
      require(_collaborativeMinter.getConfirmation(_txIndex,msg.sender), "sales transaction not approved by owner");
      _salesTransactions[_txIndex].modifying = true;
      _collaborativeMinter.setConfirmation(_txIndex, msg.sender, false);
      _salesTransactions[_txIndex].modifying = false;
      _salesTransactions[_txIndex].numConfirmations -= 1;
      return true;
    }

    // sender revoke sales transaction to get ETH back
    function revokeSalesTransaction(uint256 _txIndex, SalesTransaction[] storage _salesTransactions) public
      salesTransactionExists(_txIndex, _salesTransactions)
      salesTransactionNotExecuted(_txIndex, _salesTransactions)
      salesTransactionNotRevoked(_txIndex, _salesTransactions)
      returns (bool)
    {
      require(_salesTransactions[_txIndex].from == msg.sender, "must be account that submitted sales transaction");
      uint256 amountToPay = _salesTransactions[_txIndex].value;
      bool success;
      (success, ) = _salesTransactions[_txIndex].from.call{value: amountToPay}("");
      require(success, "Transfer failed.");
      _salesTransactions[_txIndex].revoked = true;
      return true;
    }

    function executeSalesTransaction(uint _txIndex, SalesTransaction[] storage _salesTransactions,
      CollaborativeMinter _collaborativeMinter) internal returns (bool) {
      uint256[] memory tokens = _salesTransactions[_txIndex].tokenIds;

      if(_salesTransactions[_txIndex].secondarySale == false) { // initial sale
        // send ETH to each owner
        uint256 amountToPay = _salesTransactions[_txIndex].value / _collaborativeMinter.numberOfOwners();
        bool success;
        // pay each owner
        for(uint256 i = 0; i < _collaborativeMinter.numberOfOwners(); i++){
          (success, ) = _collaborativeMinter.owners(i).call{value:amountToPay}("");
          require(success, "Transfer failed.");
        }
      }
      else { // secondary sale
        // apply secondary sale fee and send ETH to each owner
        uint256 secondarySaleValue = _salesTransactions[_txIndex].value / 10; // 10% goes to owners
        uint256 amountToPay = secondarySaleValue / _collaborativeMinter.numberOfOwners();
        bool success;
        // pay each owner
        for(uint256 i = 0; i < _collaborativeMinter.numberOfOwners(); i++){
          (success, ) = _collaborativeMinter.owners(i).call{value:amountToPay}("");
          require(success, "Transfer failed.");
        }
      }

      // send each NFT from the smart contract to the new owner
      for(uint256 i = 0; i < tokens.length; i++){
      _collaborativeMinter.executingTransfer(_txIndex, address(_collaborativeMinter), _salesTransactions[_txIndex].to, tokens[i]);
      }

      _salesTransactions[_txIndex].executed = true;
      return true;
    }

    function safeTransferFrom(address _from, address _to, uint256 _tokenId, uint256 _latestReceived,
      SalesTransaction[] storage _salesTransactions, CollaborativeMinter _collaborativeMinter) public {
      require(_collaborativeMinter.isApprovedOrOwner(_from, _tokenId), "ERC721: transfer caller is not owner nor approved");
      // create a secondary sales transaction, send NFT to contract, execute secondary sale
      uint256[] memory tokenIdArray = new uint256[](1);
      tokenIdArray[0] = _tokenId;
      uint256 secondarySaleId = submitSecondarySalesTransaction(_from, _to, tokenIdArray, _latestReceived, _salesTransactions);
      _salesTransactions[secondarySaleId].executing = true;
      _collaborativeMinter.executingTransfer(secondarySaleId, _from, address(_collaborativeMinter), _tokenId);
      executeSalesTransaction(secondarySaleId, _salesTransactions, _collaborativeMinter);
      _salesTransactions[secondarySaleId].executing = false;
    }

}

// NFT Smart Contract Constructor
contract CollaborativeMinter is ERC721URIStorage, ERC721Holder{
    uint256 public tokenCounter;
    uint256 public currentOwner; // define whose turn it is at the current time with owners index\
    uint256 public numberOfOwners;
    bool public isMerged; // defines whether we have a composite NFT
    address[] public owners; // keep track of all owners of the NFT
    mapping(address => bool) public isOwner; // used to check if someone is an owner

    uint256 public latestReceived; // used to get the msg.value for secondary sales

    // create structs for use with CollaborativeMinterHolder library
    using CollaborativeMinterHolder for CollaborativeMinterHolder.SalesTransaction;
    CollaborativeMinterHolder.SalesTransaction[] public salesTransactions;

    mapping(uint => mapping(address => bool)) public isConfirmed;

    constructor (address[] memory _owners) ERC721 ("Collaborative Mint", "COMINT"){
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

    modifier isNotMerged() { // check if we have a composite NFT
      require(!isMerged, "NFT is a completed composite");
      _;
    }

    modifier hasBeenMinted(){ // check if an NFT has been minted
      require(tokenCounter > 0, "no NFTs have been minted");
      _;
    }

    modifier allOwnedByContract() { // check if all NFTs are owned by the contract
      for(uint256 i = 0; i < tokenCounter; i++) {
        require(_isApprovedOrOwner(address(this),i),"not all tokens owned by contract");
      }
      _;
    }

    modifier currentlyExecuting(uint256 _txIndex) { // check if the transaction is currently executing
      require(salesTransactions[_txIndex].executing,"transaction must be currently executing");
      _;
    }

    modifier currentlyModifying(uint256 _txIndex) { // check if the transaction is currently being modified
      require(salesTransactions[_txIndex].modifying,"transaction must be being modified");
      _;
    }

    receive() external payable {
      latestReceived = msg.value;
    }

    // NFT minting function where only the current owner can mint. Smart contract holds NFTs upon minting
    function collaborativeMint(string memory _tokenURI) public onlyCurrentOwner isNotMerged returns (uint256) {
      uint256 newItemId = tokenCounter;
      _safeMint(address(this), newItemId); // the owner of the NFT is the holder smart contract
      _setTokenURI(newItemId, _tokenURI);
      tokenCounter = tokenCounter + 1;
      uint256 nextOwnerId = (currentOwner + 1) % owners.length; // set up the next turn by getting the following ID
      currentOwner = nextOwnerId; // update whose turn it is
      return newItemId;
    }

    // NFT minting function where only the current owner can mint. Smart contract holds NFTs upon minting
    function _collaborativeMint(string memory _tokenURI) private returns (uint256) {
      uint256 newItemId = tokenCounter;
      _safeMint(address(this), newItemId); // the owner of the NFT is the holder smart contract
      _setTokenURI(newItemId, _tokenURI);
      tokenCounter = tokenCounter + 1;
      return newItemId;
    }

    // merge all collaborative mints and create a composite NFT
    function mergeCollaborativeMint(string memory _tokenURI) public onlyOwner
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

    function isApprovedOrOwner(address _account, uint256 _tokenId) public view returns (bool) {
      return _isApprovedOrOwner(_account, _tokenId);
    }

    // used to transfer NFTs while a transaction is being executed
    function executingTransfer(uint256 _txIndex, address _from, address _to, uint256 _tokenId)
      currentlyExecuting(_txIndex) public returns (bool) {
      _safeTransfer(_from, _to, _tokenId, "");
      return true;
    }

    // Override safeTransferFrom to allow for royalties from secondary sales
    function safeTransferFrom(address _from, address _to, uint256 _tokenId) public virtual override {
      CollaborativeMinterHolder.safeTransferFrom(_from, _to, _tokenId, latestReceived, salesTransactions, this);
    }

    // Override safeTransferFrom to allow for royalties from secondary sales
    function safeTransferFrom(address _from, address _to, uint256 _tokenId, bytes memory _data) public virtual override {
      CollaborativeMinterHolder.safeTransferFrom(_from, _to, _tokenId, latestReceived, salesTransactions, this);
    }

    // Override transferFrom to allow for royalties from secondary sales
    function transferFrom(address _from, address _to, uint256 _tokenId) public virtual override {
      CollaborativeMinterHolder.safeTransferFrom(_from, _to, _tokenId, latestReceived, salesTransactions, this);
    }

    // submit a sales transaction
    function submitSalesTransaction(address _to, uint256[] memory _tokenIds) payable public {
      CollaborativeMinterHolder.submitSalesTransaction(msg.sender, _to, _tokenIds, msg.value, salesTransactions, this);
    }

    function approveSalesTransaction(uint256 _txIndex) public returns (bool) {
      CollaborativeMinterHolder.approveSalesTransaction(_txIndex, salesTransactions, this);
      return true;
    }

    function denySalesTransaction(uint256 _txIndex) public returns (bool) {
      CollaborativeMinterHolder.denySalesTransaction(_txIndex, salesTransactions, this);
      return true;
    }

    function revokeSalesTransaction(uint256 _txIndex) public returns (bool) {
      CollaborativeMinterHolder.revokeSalesTransaction(_txIndex, salesTransactions);
      return true;
    }

    // Retreive the sales transaction data
    function getSalesTransaction(uint256 _txIndex) public view returns (CollaborativeMinterHolder.SalesTransaction memory) {
        return salesTransactions[_txIndex];
    }

    function getConfirmation(uint256 _txIndex, address _owner) public view returns (bool) {
      return isConfirmed[_txIndex][_owner];
    }

    function setConfirmation(uint256 _txIndex, address _owner, bool value)
      currentlyModifying(_txIndex) public returns (bool) {
      isConfirmed[_txIndex][_owner] = value;
      return true;
    }



}
