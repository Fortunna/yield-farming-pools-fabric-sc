const hre = require('hardhat');
const deployPoolWithParams = require("./reusable/deploy_pool_with_params");

module.exports = deployPoolWithParams(
  30, 
  5, 
  0, 
  0, 
  10,
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

    const rewardAmountInMockTokens = hre.ethers.utils.parseEther('5');

    const fortunnaFactoryInstance = await hre.ethers.getContractAt(
      hre.names.internal.fortunnaFactory,
      (await get(hre.names.internal.fortunnaFactory)).address
    );

    const [rewardFortunnaTokenAddress,] = await fortunnaFactoryInstance.predictFortunnaTokenAddress(
      0, deployer, false
    );

    await execute(
      hre.names.internal.productionTestToken,
      {from: deployer, log: true},
      'approve',
      rewardFortunnaTokenAddress,
      rewardAmountInMockTokens
    );
    console.log("spending token", (await get(hre.names.internal.productionTestToken)).address);
    console.log("spender", rewardFortunnaTokenAddress);

    return {
      utilizingTokensAddresses: [productionMockTokenAddress, wethAddress],
      stakingTokensFlags: [true, true],
      rewardTokensFlags: [true, false],
      initialRewardAmounts: [[0, rewardAmountInMockTokens], [1, hre.ethers.constants.Zero]],
      initialDepositAmounts: [[0, hre.ethers.constants.Zero], [1, hre.ethers.constants.Zero]]
    }
  }  
);
module.exports.tags = ["deploy_pool", "pool"];
