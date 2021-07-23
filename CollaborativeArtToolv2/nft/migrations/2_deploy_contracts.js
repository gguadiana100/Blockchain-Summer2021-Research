const SimpleCollectible = artifacts.require("SimpleCollectible");

module.exports = function(deployer) {
  deployer.deploy(SimpleCollectible); // put this smart contract on the blockchain
};
