const CollaborativeMinterFactory = artifacts.require("CollaborativeMinterFactory");
const CollaborativeMinterHolder = artifacts.require("CollaborativeMinterHolder");

module.exports = async function(deployer) {
  await deployer.deploy(CollaborativeMinterHolder);
  await deployer.link(CollaborativeMinterHolder,CollaborativeMinterFactory);
  await deployer.deploy(CollaborativeMinterFactory);
};
