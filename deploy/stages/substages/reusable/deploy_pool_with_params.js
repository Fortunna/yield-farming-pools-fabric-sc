const hre = require('hardhat');
const { POOL_DEPLOY_COST, grantRoles, getEventBody, approveMaxAndReturnBalance, DEAD_ADDRESS } = require("../../../helpers");

module.exports = 
  (
    poolPrototypeIdx,
    poolFunctionalityDurationInDays,
    minLockUpRewardPeriodInDays,
    earlyWithdrawalFeeBasePoints,
    depositWithdrawFeeBasePoints,
    totalRewardBasePointsPerDistribution,
    minStake,
    maxStake,
    getUtilizingTokensAndListsOfFlags,
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
    const customPoolParams = utilizingTokensAndListsOfFlagsDTO.customPoolParams;

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
      .generateMask(stakingTokensFlags);
    const rewardTokensMask = await fortunnaFactoryInstance
      .generateMask(rewardTokensFlags);

    const createPoolTxReceipt = await fortunnaFactoryInstance.createPool(
      [
        poolPrototypeIdx,
        startTimestamp,
        endTimestamp,
        minStake,
        maxStake,
        minLockUpRewardPeriodInSec,
        earlyWithdrawalFeeBasePoints,
        depositWithdrawFeeBasePoints,
        totalRewardBasePointsPerDistribution,
        stakingTokensMask,
        rewardTokensMask,
        customPoolParams
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

    const pool = await hre.ethers.getContractAt(
      hre.names.internal.fortunnaPool,
      (await get(hre.names.internal.fortunnaPool)).address
    );

    const rewardFortunnaTokenAddress = await pool.rewardToken();
    const stakingFortunnaTokenAddress = await pool.stakingToken();

    const rewardTokenInstance = await hre.ethers.getContractAt(
      "@openzeppelin/contracts-new/token/ERC20/IERC20.sol:IERC20",
      rewardFortunnaTokenAddress
    );
    const stakingTokenInstance = await hre.ethers.getContractAt(
      "@openzeppelin/contracts-new/token/ERC20/IERC20.sol:IERC20",
      stakingFortunnaTokenAddress
    );

    console.log(rewardFortunnaTokenAddress);
    console.log(stakingFortunnaTokenAddress);

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