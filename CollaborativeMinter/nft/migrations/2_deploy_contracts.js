const CollaborativeMinter = artifacts.require("CollaborativeMinter");

module.exports = function(deployer) {
  deployer.deploy(CollaborativeMinter);
};
