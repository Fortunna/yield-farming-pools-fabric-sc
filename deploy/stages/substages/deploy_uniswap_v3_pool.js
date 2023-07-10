const hre = require('hardhat');
const deployPoolWithParams = require("./reusable/deploy_pool_with_params");

module.exports = deployPoolWithParams(
  hre.names.internal.fortunnaPoolUniswapV3,
  1, // uniswap V3 fortunna pool
  30, 
  5, 
  0, 
  0, 
  0,
  hre.ethers.utils.parseEther('0.1'), // min stake
  hre.ethers.utils.parseEther('9'), // max stake
  async ({
    deployments
  }) => {
    const { get } = deployments;
    const nftPositionManagerAddress = (await get(hre.names.external.nftPositionManager)).address;
    const wethAddress = (await get(hre.names.external.weth)).address;
    const usdtAddress = (await get(hre.names.external.usdt)).address;
    return {
      utilizingTokensAddresses: [usdtAddress, wethAddress],
      stakingTokensFlags: [true, true],
      rewardTokensFlags: [true, true],
      initialRewardAmounts: [[0, hre.ethers.constants.Zero], [1, hre.ethers.constants.Zero]],
      initialDepositAmounts: [[0, hre.ethers.constants.Zero], [1, hre.ethers.constants.Zero]],
      customPoolParams: [
        nftPositionManagerAddress
      ]
    }
  },
  async (poolAddress, poolArtifactName, log) => {
    log(`Additional post actions are not required. Continue...`);
  }
);
module.exports.tags = ["deploy_uniswap_v3_pool", "uniswap_v3_pool"];
