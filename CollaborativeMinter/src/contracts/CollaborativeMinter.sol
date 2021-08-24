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
      uint256 numConfirmations;
    }

    modifier onlyOwner { // restrict to only owners
      require(CollaborativeMinter(collaborativeMinter).isOwner(msg.sender),'not an owner');
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
      require(!isConfirmed[_txIndex][msg.sender], "sales transaction is already confirmed");
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

    modifier ownedByContract(uint256[] memory _tokenIds) { // check if token IDs are valid and are owned by contract
      for(uint256 i = 0; i < _tokenIds.length; i++){
        require(_tokenIds[i] < CollaborativeMinter(collaborativeMinter).tokenCounter(), "invalid token ID");
        require(CollaborativeMinter(collaborativeMinter).checkApprovedOrOwner(address(this),_tokenIds[i]),"token not owned by contract");
      }
      _;
    }

    modifier allOwnedByContract() { // check if all NFTs are owned by the contract
      for(uint256 i = 0; i < CollaborativeMinter(collaborativeMinter).tokenCounter(); i++){
        require(CollaborativeMinter(collaborativeMinter).checkApprovedOrOwner(address(this),i),"not all tokens owned by contract");
      }
      _;
    }

    modifier onlyThisOrMinter(){
      require((msg.sender == address(this)) || (msg.sender == collaborativeMinter), "Not collaborative minter or holder");
      _;
    }

    receive() external payable {
      latestReceived = msg.value;
    }

    function submitSalesTransaction(address _to, uint256[] memory _tokenIds)
      payable ownedByContract(_tokenIds) public returns (uint256)
    { // buyer sends sales transaction, returns transaction index
      uint256 txIndex = salesTransactions.length;

      salesTransactions.push(SalesTransaction({
        from: msg.sender,
        to: _to,
        tokenIds: _tokenIds,
        value: msg.value,
        secondarySale: false,
        revoked: false,
        executed: false,
        numConfirmations: 0
      }));

      return txIndex;
    }

    function submitSecondarySalesTransaction(address _to, uint256[] memory _tokenIds, uint256 _value)
      public returns (uint256)
    { // buyer sends sales transaction, returns transaction index
      uint256 txIndex = salesTransactions.length;

      salesTransactions.push(SalesTransaction({
        from: msg.sender,
        to: _to,
        tokenIds: _tokenIds,
        value: _value,
        secondarySale: true,
        revoked: false,
        executed: false,
        numConfirmations: 0
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
      isConfirmed[_txIndex][msg.sender] = true;
      salesTransactions[_txIndex].numConfirmations += 1;

      if(salesTransactions[_txIndex].numConfirmations == CollaborativeMinter(collaborativeMinter).numberOfOwners()){ // execute if approved by all owners
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
      require(isConfirmed[_txIndex][msg.sender], "sales transaction not approved by owner");
      isConfirmed[_txIndex][msg.sender] = false;
      salesTransactions[_txIndex].numConfirmations -= 1;
      return true;
    }

    // sender revoke sales transaction to get ETH back
    function revokeSalesTransaction(uint256 _txIndex) public
      salesTransactionExists(_txIndex)
      salesTransactionNotExecuted(_txIndex)
      salesTransactionNotRevoked(_txIndex)
      returns (bool)
    {
      require(salesTransactions[_txIndex].from == msg.sender, "must be account that submitted sales transaction");
      uint256 amountToPay = salesTransactions[_txIndex].value;
      bool success;
      (success, ) = salesTransactions[_txIndex].from.call{value: amountToPay}("");
      require(success, "Transfer failed.");
      salesTransactions[_txIndex].revoked = true;
      return true;
    }

    function executeSalesTransaction(uint _txIndex) onlyThisOrMinter public returns (bool) {
      uint256[] memory tokens = salesTransactions[_txIndex].tokenIds;

      if(salesTransactions[_txIndex].secondarySale == false) { // initial sale
        // send ETH to each owner
        uint256 amountToPay = salesTransactions[_txIndex].value / CollaborativeMinter(collaborativeMinter).numberOfOwners();
        bool success;
        // pay each owner
        for(uint256 i = 0; i < CollaborativeMinter(collaborativeMinter).numberOfOwners(); i++){
          (success, ) = CollaborativeMinter(collaborativeMinter).owners(i).call{value:amountToPay}("");
          require(success, "Transfer failed.");
        }
      }
      else { // secondary sale
        // apply secondary sale fee and send ETH to each owner
        uint256 secondarySaleValue = salesTransactions[_txIndex].value / 10; // 10% goes to owners
        uint256 amountToPay = secondarySaleValue / CollaborativeMinter(collaborativeMinter).numberOfOwners();
        bool success;
        // pay each owner
        for(uint256 i = 0; i < CollaborativeMinter(collaborativeMinter).numberOfOwners(); i++){
          (success, ) = CollaborativeMinter(collaborativeMinter).owners(i).call{value:amountToPay}("");
          require(success, "Transfer failed.");
        }
      }

      // send each NFT from this smart contract to the new owner
      for(uint256 i = 0; i < tokens.length; i++){
        CollaborativeMinter(collaborativeMinter).approve(collaborativeMinter,tokens[i]); // approve collaborative minter to send NFT
        CollaborativeMinter(collaborativeMinter).sendFromHolder(address(this), salesTransactions[_txIndex].to, tokens[i]); // send NFT
      }

      salesTransactions[_txIndex].executed = true;
      return true;
    }

    function getSalesTransaction(uint256 _txIndex) public view returns (SalesTransaction memory) {
      return salesTransactions[_txIndex];
    }
}

// NFT Smart Contract Constructor
contract CollaborativeMinter is ERC721URIStorage {
    uint256 public tokenCounter;
    uint256 public currentOwner; // define whose turn it is at the current time with owners index\
    uint256 public numberOfOwners;
    bool public isMerged; // defines whether we have a composite NFT
    address[] public owners; // keep track of all owners of the NFT
    mapping(address => bool) public isOwner; // used to check if someone is an owner
    address public collaborativeMinterHolder; // holder of NFTs and submitted transactions

    uint256 public latestReceived; // used to get the msg.value for secondary sales

    using CollaborativeMinterHolder for CollaborativeMinterHolder.SalesTransaction;
    CollaborativeMinterHolder.SalesTransaction[] public salesTransactions;

    mapping(uint => mapping(address => bool)) isConfirmed; // check if a transaction is confirmed by an owner

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
      CollaborativeMinterHolder newCollaborativeMinterHolder = new CollaborativeMinterHolder(address(this));
      collaborativeMinterHolder = address(newCollaborativeMinterHolder);
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
      for(uint256 i = 0; i < tokenCounter; i++){
        require(_isApprovedOrOwner(collaborativeMinterHolder,i),"not all tokens owned by contract");
      }
      _;
    }

    // NFT minting function where only the current owner can mint. Smart contract holds NFTs upon minting
    function collaborativeMint(string memory _tokenURI) public onlyCurrentOwner isNotMerged returns (uint256) {
      uint256 newItemId = tokenCounter;
      _safeMint(collaborativeMinterHolder, newItemId); // the owner of the NFT is the holder smart contract
      _setTokenURI(newItemId, _tokenURI);
      tokenCounter = tokenCounter + 1;
      uint256 nextOwnerId = (currentOwner + 1) % owners.length; // set up the next turn by getting the following ID
      currentOwner = nextOwnerId; // update whose turn it is
      return newItemId;
    }

    // NFT minting function where only the current owner can mint. Smart contract holds NFTs upon minting
    function _collaborativeMint(string memory _tokenURI) private returns (uint256) {
      uint256 newItemId = tokenCounter;
      _safeMint(collaborativeMinterHolder, newItemId); // the owner of the NFT is the holder smart contract
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

    // Override safeTransferFrom to allow for royalties from secondary sales
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public virtual override {
      require(_isApprovedOrOwner(_msgSender(), tokenId), "ERC721: transfer caller is not owner nor approved");
      // create a secondary sales transaction, send NFT to contract, execute secondary sale
      uint256[] memory tokenIdArray = new uint256[](1);
      tokenIdArray[0] = tokenId;
      CollaborativeMinterHolder cMH = CollaborativeMinterHolder(collaborativeMinterHolder);
      uint256 secondarySaleId = cMH.submitSecondarySalesTransaction(to, tokenIdArray, cMH.latestReceived());
      _safeTransfer(from, collaborativeMinterHolder, tokenId, "");
      cMH.executeSalesTransaction(secondarySaleId);
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
        uint256[] memory tokenIdArray = new uint256[](1);
        tokenIdArray[0] = tokenId;
        CollaborativeMinterHolder cMH = CollaborativeMinterHolder(collaborativeMinterHolder);
        uint256 secondarySaleId = cMH.submitSecondarySalesTransaction(to, tokenIdArray, cMH.latestReceived());
        _safeTransfer(from, collaborativeMinterHolder, tokenId, _data);
        cMH.executeSalesTransaction(secondarySaleId);
    }

    // Override transferFrom to allow for royalties from secondary sales
    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public virtual override {
        // create a secondary sales transaction, send NFT to contract, execute secondary sale
        uint256[] memory tokenIdArray = new uint256[](1);
        tokenIdArray[0] = tokenId;
        CollaborativeMinterHolder cMH = CollaborativeMinterHolder(collaborativeMinterHolder);
        uint256 secondarySaleId = cMH.submitSecondarySalesTransaction(to, tokenIdArray, cMH.latestReceived());
        _transfer(from, collaborativeMinterHolder, tokenId);
        cMH.executeSalesTransaction(secondarySaleId);
    }

    // send NFTs from holder to execute sales transactions
    function sendFromHolder(address _from, address _to, uint256 _tokenId) public returns (bool) {
      require(msg.sender == collaborativeMinterHolder, "Not collaborativeMinterHolder as sender");
      _safeTransfer(_from, _to, _tokenId, "");
      return true;
    }

    function checkApprovedOrOwner(address _spender, uint256 _tokenId) public view returns (bool){
      return _isApprovedOrOwner(_spender, _tokenId);
    }

}
