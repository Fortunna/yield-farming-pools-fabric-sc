const hre = require('hardhat');
const deployPoolWithParams = require("./reusable/deploy_pool_with_params");

module.exports = deployPoolWithParams(
  30, 5, 0, 0, 10, 
  async ({
    deployments
  }) => {
    const { get } = deployments;
    const wethAddress = (await get(hre.names.external.weth)).address;
    const productionMockTokenAddress = (await get(hre.names.internal.productionMockToken)).address;
    return {
      utilizingTokensAddresses: [productionMockTokenAddress, wethAddress],
      stakingTokensFlags: [true, true],
      rewardTokensFlags: [true, false]
    }
  }  
);
module.exports.tags = ["deploy_pool", "pool"];
