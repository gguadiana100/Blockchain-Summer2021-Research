// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

library CollaborativeMinterHolder {
    address public collaborativeMinter; // address of parent collaborative minter
    uint256 public latestReceived; // used to get the msg.value for secondary sales

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

    SalesTransaction[] public salesTransactions;

    mapping(uint => mapping(address => bool)) isConfirmed; // check if a transaction is confirmed by an owner

    constructor (address _collaborativeMinter) {
      collaborativeMinter = _collaborativeMinter;
      latestReceived = 0;
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
