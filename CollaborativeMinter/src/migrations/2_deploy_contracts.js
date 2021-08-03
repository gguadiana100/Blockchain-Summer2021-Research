const CollaborativeMinterFactory = artifacts.require("CollaborativeMinterFactory");

module.exports = function(deployer) {
  deployer.deploy(CollaborativeMinterFactory);
};
