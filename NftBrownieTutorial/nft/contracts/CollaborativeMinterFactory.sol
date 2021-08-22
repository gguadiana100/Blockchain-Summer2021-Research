// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./CollaborativeMinter.sol";

// Used to launch Collaborative Minter smart contract copies
contract CollaborativeMinterFactory {
  address[] public collaborativeMinters; // holds all of the addresses of the collaborative minter deployments
  mapping(address => uint[]) public accountToCominters; // holds arrays of collaborative minter index

  constructor() {}

  function createCollaborativeMinter(address[] memory _owners) public returns (address) {
    CollaborativeMinter newCollaborativeMinter = new CollaborativeMinter(_owners);
    collaborativeMinters.push(address(newCollaborativeMinter));
    for(uint i = 0; i < _owners.length; i++){ // add minter index for each owner
      accountToCominters[_owners[i]].push(collaborativeMinters.length-1);
    }
    return collaborativeMinters[(collaborativeMinters.length-1)];
  }

  function getNumberOfCollaborativeMinters(address _account) public view returns(uint256){
    return accountToCominters[_account].length;
  }

}
