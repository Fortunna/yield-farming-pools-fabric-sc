const hre = require('hardhat');
const deployPoolWithParams = require("./reusable/deploy_pool_with_params");

module.exports = deployPoolWithParams(
  1, // uniswap V3 fortunna pool
  30, 
  5, 
  0, 
  0, 
  0,
  hre.ethers.utils.parseEther('0.1'), // min stake
  hre.ethers.utils.parseEther('9'), // max stake
  async ({
    deployments,
    getNamedAccounts
  }) => {
    const {get, execute} = deployments;
    const {deployer} = await getNamedAccounts();

    const nftPositionManagerAddress = (await get(hre.names.external.nftPositionManager)).address;
    const wethAddress = (await get(hre.names.external.weth)).address;
    const productionMockTokenAddress = (await get(hre.names.internal.productionTestToken)).address;

    const rewardAmountInMockTokens = hre.ethers.utils.parseEther('6');

    const fortunnaFactoryInstance = await hre.ethers.getContractAt(
      hre.names.internal.fortunnaFactory,
      (await get(hre.names.internal.fortunnaFactory)).address
    );

    const [rewardFortunnaTokenAddress,] = await fortunnaFactoryInstance.predictFortunnaTokenAddress(
      1, 1, true
    );

    await execute(
      hre.names.internal.productionTestToken,
      {from: deployer, log: true},
      'approve',
      rewardFortunnaTokenAddress,
      rewardAmountInMockTokens
    );
    
    return {
      utilizingTokensAddresses: [productionMockTokenAddress, wethAddress],
      stakingTokensFlags: [true, true],
      rewardTokensFlags: [true, false],
      initialRewardAmounts: [[0, rewardAmountInMockTokens], [1, hre.ethers.constants.Zero]],
      initialDepositAmounts: [[0, hre.ethers.constants.Zero], [1, hre.ethers.constants.Zero]],
      customPoolParams: [
        nftPositionManagerAddress
      ]
    }
  }  
);
module.exports.tags = ["deploy_uniswap_v3_pool", "uniswap_v3_pool"];
