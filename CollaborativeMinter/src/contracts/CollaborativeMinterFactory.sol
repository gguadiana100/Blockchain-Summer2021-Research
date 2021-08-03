// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./CollaborativeMinter.sol";

// Used to launch Collaborative Minter smart contract copies
contract CollaborativeMinterFactory {
  address[] public collaborativeMinters; // holds all of the addresses of the collaborative minter deployments

  constructor() public{}

  function createCollaborativeMinter(address[] memory _owners) public returns (address) {
    CollaborativeMinter newCollaborativeMinter = new CollaborativeMinter(_owners);
    collaborativeMinters.push(address(newCollaborativeMinter));
    return collaborativeMinters[(collaborativeMinters.length-1)];
  }
}
