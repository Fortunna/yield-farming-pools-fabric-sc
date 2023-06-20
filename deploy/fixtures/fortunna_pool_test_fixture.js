const hre = require('hardhat');
const helpers = require('../helpers');

module.exports = async ({
  getNamedAccounts,
  deployments,
  network
}) => {
  const { log, deploy, save } = deployments;
  const { deployer } = await getNamedAccounts();

  // deploy mock tokens
  await helpers.getMockToken(
    "Mock Staking ABC", 
    "sABC", 
    hre.ethers.utils.parseEther('1000'),
    deploy,
    deployer,
    save
  );
  await helpers.getMockToken(
    "Mock Staking XYZ", 
    "sXYZ", 
    hre.ethers.utils.parseEther('1000'),
    deploy,
    deployer,
    save
  );
  await helpers.getMockToken(
    "Mock Reward ABC", 
    "rABC", 
    hre.ethers.utils.parseEther('1000'),
    deploy,
    deployer,
    save
  );
  await helpers.getMockToken(
    "Mock Reward XYZ", 
    "rXYZ", 
    hre.ethers.utils.parseEther('1000'),
    deploy,
    deployer,
    save
  );
  await helpers.getMockToken(
    "Mock Universal GHI", 
    "GHI", 
    hre.ethers.utils.parseEther('1000'),
    deploy,
    deployer,
    save
  );

  // add some pools with them

}
module.exports.tags = ["fortunna_pool_test_fixture"];
module.exports.dependencies = ["general_test_fixtures"];
