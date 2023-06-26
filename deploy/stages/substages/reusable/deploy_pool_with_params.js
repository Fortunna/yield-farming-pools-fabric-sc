const hre = require('hardhat');
const { POOL_DEPLOY_COST, grantRoles, getEventBody, approveMaxAndReturnBalance } = require("../../../helpers");

module.exports = 
  (
    poolFunctionalityDurationInDays,
    minLockUpRewardPeriodInDays,
    earlyWithdrawalFeeBasePoints,
    depositWithdrawFeeBasePoints,
    totalRewardBasePointsPerDistribution,
    minStake,
    maxStake,
    getUtilizingTokensAndListsOfFlags
  ) => async (deployScriptParams) => {
    const {
      getNamedAccounts,
      deployments
    } = deployScriptParams;

    const utilizingTokensAndListsOfFlagsDTO = await getUtilizingTokensAndListsOfFlags(deployScriptParams);
    const utilizingTokensAddresses = utilizingTokensAndListsOfFlagsDTO.utilizingTokensAddresses;
    const stakingTokensFlags = utilizingTokensAndListsOfFlagsDTO.stakingTokensFlags;
    const rewardTokensFlags = utilizingTokensAndListsOfFlagsDTO.rewardTokensFlags;
    const initialRewardAmounts = utilizingTokensAndListsOfFlagsDTO.initialRewardAmounts;
    const initialDepositAmounts = utilizingTokensAndListsOfFlagsDTO.initialDepositAmounts;

    const { log, execute, get } = deployments;
    const { deployer } = await getNamedAccounts();

    const dayInSec = 3600 * 24;

    const poolFunctionalityDurationInSec = dayInSec * poolFunctionalityDurationInDays;

    const currentBlock = await hre.ethers.provider.getBlock();
    const startTimestamp = currentBlock.timestamp + 1;
    const endTimestamp = startTimestamp + poolFunctionalityDurationInSec;

    const minLockUpRewardPeriodInSec = dayInSec * minLockUpRewardPeriodInDays;

    if (stakingTokensFlags.length != utilizingTokensAddresses.length) {
      throw new RangeError(`Lengths of addresses and staking flags are not equal: ${stakingTokensFlags.length} != ${utilizingTokensAddresses.length}`);
    }
    if (rewardTokensFlags.length != utilizingTokensAddresses.length) {
      throw new RangeError(`Lengths of addresses and reward flags are not equal: ${rewardTokensFlags.length} != ${utilizingTokensAddresses.length}`);
    }

    const fortunnaFactoryInstance = await hre.ethers.getContractAt(
      hre.names.internal.fortunnaFactory,
      (await get(hre.names.internal.fortunnaFactory)).address
    );

    await grantRoles(
      utilizingTokensAddresses, 
      stakingTokensFlags, 
      "ALLOWED_STAKING_TOKEN_ROLE",
      deployer,
      execute
    );
    await grantRoles(
      utilizingTokensAddresses, 
      rewardTokensFlags, 
      "ALLOWED_REWARD_TOKEN_ROLE",
      deployer,
      execute
    );
    
    const stakingTokensMask = await fortunnaFactoryInstance
      .generateMaskForInitialRewardAmountsPair(stakingTokensFlags);
    const rewardTokensMask = await fortunnaFactoryInstance
      .generateMaskForInitialRewardAmountsPair(rewardTokensFlags);

    const [rewardFortunnaTokenAddress,] = await fortunnaFactoryInstance.predictFortunnaTokenAddress(
      0, deployer, false
    );
    const [stakingFortunnaTokenAddress,] = await fortunnaFactoryInstance.predictFortunnaTokenAddress(
      0, deployer, true
    );

    const createPoolTxReceipt = await fortunnaFactoryInstance.createPool(
      [
        0, // pool prototype idx
        startTimestamp,
        endTimestamp,
        minStake,
        maxStake,
        minLockUpRewardPeriodInSec,
        earlyWithdrawalFeeBasePoints,
        depositWithdrawFeeBasePoints,
        totalRewardBasePointsPerDistribution,
        stakingTokensMask,
        rewardTokensMask
      ],
      [
        utilizingTokensAddresses,
        initialRewardAmounts,
        initialDepositAmounts
      ],
      {
        value: POOL_DEPLOY_COST
      }
    );
    await createPoolTxReceipt.wait();
    
    const poolAddress = (await getEventBody("PoolCreated", fortunnaFactoryInstance)).pool;
    log(`Acquired pool address from the factory: ${poolAddress}`);

    const rewardTokenInstance = await hre.ethers.getContractAt(
      hre.names.internal.fortunnaToken,
      rewardFortunnaTokenAddress
    );
    
    const stakingTokenInstance = await hre.ethers.getContractAt(
      hre.names.internal.fortunnaToken,
      stakingFortunnaTokenAddress
    );

    await approveMaxAndReturnBalance(
      stakingTokenInstance, 
      "staking", 
      deployer,
      poolAddress,
      log
    );
    const rewardTokenBalance = await approveMaxAndReturnBalance(
      rewardTokenInstance, 
      "reward",
      deployer,
      poolAddress,
      log
    );

    const poolInstance = await hre.ethers.getContractAt(
      hre.names.internal.fortunnaPool,
      poolAddress
    );

    log('Providing the rewards for the pool...');
    const addExpectedRewardTxReceipt = await poolInstance
      .addExpectedRewardTokensBalanceToDistribute(rewardTokenBalance);
    await addExpectedRewardTxReceipt.wait();
    log(`Total reward amount: ${hre.ethers.utils.formatUnits((await getEventBody("RewardAdded", poolInstance)).reward)}`);

    const providePartOfTotalRewardsTxReceipt = await poolInstance
      .providePartOfTotalRewards();
    await providePartOfTotalRewardsTxReceipt.wait();
    log(`Part of reward ready to distribute: ${hre.ethers.utils.formatUnits((await getEventBody("PartDistributed", poolInstance)).partOfTotalRewards)}`);
  }