const hre = require('hardhat');
const deployPoolWithParams = require("./reusable/deploy_pool_with_params");
const { DEAD_ADDRESS } = require('../../helpers');

module.exports = deployPoolWithParams(
  0, // classic fortunna pool
  30, 
  5, 
  0, 
  0, 
  1000,
  hre.ethers.utils.parseEther('0.1'), // min stake
  hre.ethers.utils.parseEther('9'), // max stake
  async ({
    deployments,
    getNamedAccounts
  }) => {
    const {get, execute} = deployments;
    const {deployer} = await getNamedAccounts();
    const wethAddress = (await get(hre.names.external.weth)).address;
    const productionMockTokenAddress = (await get(hre.names.internal.productionTestToken)).address;

    
    const fortunnaFactoryInstance = await hre.ethers.getContractAt(
      hre.names.internal.fortunnaFactory,
      (await get(hre.names.internal.fortunnaFactory)).address
      );
      
    const rewardAmountInMockTokens = hre.ethers.utils.parseEther('5');
    const [rewardFortunnaTokenAddress,] = await fortunnaFactoryInstance.predictFortunnaTokenAddress(
      0, 0, false
    );
    console.log('r1', rewardFortunnaTokenAddress);
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
      customPoolParams: [DEAD_ADDRESS]
    }
  }  
);
module.exports.tags = ["deploy_classic_pool", "pool"];
