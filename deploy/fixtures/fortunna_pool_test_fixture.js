const hre = require('hardhat');
const { getMockToken } = require('../helpers');
const deployPoolWithParams = require("../stages/substages/reusable/deploy_pool_with_params");

module.exports = deployPoolWithParams(
  30, 5, 1000, 500, 10, 
  async ({
    deployments,
    getNamedAccounts
  }) => {
    const { log, deploy, save, get } = deployments;
    const { deployer } = await getNamedAccounts();

    const initialSupply = hre.ethers.utils.parseEther('1000'); 
    // deploy mock tokens
    await getMockToken(
      "Mock Staking ABC", 
      "sABC", 
      initialSupply,
      deploy,
      deployer,
      save
    );
    await getMockToken(
      "Mock Staking XYZ", 
      "sXYZ", 
      initialSupply,
      deploy,
      deployer,
      save
    );
    await getMockToken(
      "Mock Reward ABC", 
      "rABC", 
      initialSupply,
      deploy,
      deployer,
      save
    );
    await getMockToken(
      "Mock Reward XYZ", 
      "rXYZ", 
      initialSupply,
      deploy,
      deployer,
      save
    );
    await getMockToken(
      "Mock Universal GHI", 
      "GHI", 
      initialSupply,
      deploy,
      deployer,
      save
    );

    return {
      utilizingTokensAddresses: [],
      stakingTokensFlags: [],
      rewardTokensFlags: []
    }
  }  
);
module.exports.tags = ["fortunna_pool_test_fixture"];
module.exports.dependencies = ["general_test_fixtures"];
