const hre = require('hardhat');
const deployPoolWithParams = require("./reusable/deploy_pool_with_params");
const { DEAD_ADDRESS, getEventBody } = require('../../helpers');

module.exports = deployPoolWithParams(
  hre.names.internal.fortunnaPool, // artifact name
  0, // classic fortunna pool
  30, // how many days the pool will distribute a reward
  5, // how many days the get rewards would be under the fee
  0, // bp fee of early withdrawal fee
  0, // deposit/witdhraw fee
  1000, // total rewards bp per distribution cycle
  hre.ethers.utils.parseEther('0.1'), // min stake
  hre.ethers.utils.parseEther('9'), // max stake

  async ({
    deployments,
    getNamedAccounts
  }) => {
    const { get, execute } = deployments;
    const { deployer } = await getNamedAccounts();
    const productionMockTokenAAddress = (await get(hre.names.internal.productionTestTokenA)).address;
    const productionMockTokenBAddress = (await get(hre.names.internal.productionTestTokenB)).address;

    const fortunnaFactoryInstance = await hre.ethers.getContractAt(
      hre.names.internal.fortunnaFactory,
      (await get(hre.names.internal.fortunnaFactory)).address
    );

    const [rewardFortunnaTokenAddress,] = await fortunnaFactoryInstance.predictFortunnaTokenAddress(
      0, 0, false
    );
    const [stakingFortunnaTokenAddress,] = await fortunnaFactoryInstance.predictFortunnaTokenAddress(
      0, 0, true
    );

    await execute(
      hre.names.internal.productionTestTokenA,
      { from: deployer, log: true },
      'approve',
      rewardFortunnaTokenAddress,
      hre.ethers.constants.MaxInt256
    );

    await execute(
      hre.names.internal.productionTestTokenB,
      { from: deployer, log: true },
      'approve',
      rewardFortunnaTokenAddress,
      hre.ethers.constants.MaxInt256
    );

    await execute(
      hre.names.internal.productionTestTokenA,
      { from: deployer, log: true },
      'approve',
      stakingFortunnaTokenAddress,
      hre.ethers.constants.MaxInt256
    );

    await execute(
      hre.names.internal.productionTestTokenB,
      { from: deployer, log: true },
      'approve',
      stakingFortunnaTokenAddress,
      hre.ethers.constants.MaxInt256
    );

    return {
      utilizingTokensAddresses: [productionMockTokenAAddress, productionMockTokenBAddress],
      stakingTokensFlags: [true, true],
      rewardTokensFlags: [true, true],
      initialRewardAmounts: [[0, hre.ethers.utils.parseEther('5')], [1, hre.ethers.utils.parseEther('10')]],
      initialDepositAmounts: [[0, hre.ethers.utils.parseEther('6')], [1, hre.ethers.utils.parseEther('9')]],
      customPoolParams: [DEAD_ADDRESS]
    }
  },

  async (poolAddress, poolArtifactName, log) => {
    const pool = await hre.ethers.getContractAt(
      poolArtifactName,
      poolAddress
    );

    log('Providing the rewards for the pool...');
    const addExpectedRewardTxReceipt = await pool
      .addExpectedRewardTokensBalanceToDistribute();
    await addExpectedRewardTxReceipt.wait();
    log(`Total reward amount: ${hre.ethers.utils.formatUnits((await getEventBody("RewardAdded", pool)).reward)}`);

    const providePartOfTotalRewardsTxReceipt = await pool
      .providePartOfTotalRewards();
    await providePartOfTotalRewardsTxReceipt.wait();
    log(`Part of reward ready to distribute: ${hre.ethers.utils.formatUnits((await getEventBody("PartDistributed", pool)).partOfTotalRewards)}`);
  }
);
module.exports.tags = ["deploy_classic_pool", "pool"];
