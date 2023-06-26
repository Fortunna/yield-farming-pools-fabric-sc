const hre = require('hardhat');
const keccak256 = require('keccak256');
const { POOL_DEPLOY_COST } = require("../../../helpers");

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
    
    const grantRoles = async (flags, roleName) => {
      for (let i = 0; i < stakingTokensFlags.length; i++) {
        if (flags[i]) {
          await execute(
            hre.names.internal.fortunnaFactory,
            {from: deployer, log: true},
            'grantRole',
            keccak256(roleName),
            utilizingTokensAddresses[i]
          )
        }
      }
    }

    await grantRoles(stakingTokensFlags, "ALLOWED_STAKING_TOKEN_ROLE");
    await grantRoles(rewardTokensFlags, "ALLOWED_REWARD_TOKEN_ROLE");
    
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

    const getEventBody = async (eventName, contractInstance) => {
      const filter = contractInstance.filters[eventName]();
      const filterQueryResult = await contractInstance.queryFilter(filter);
      return filterQueryResult[0].args;
    }
    
    
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

    const approveMaxAndReturnBalance = async (fortunnaToken, typeOfFortunnaToken) => {
      const fortunnaTokenBalance = await fortunnaToken.balanceOf(deployer);
      log(`Balance of fortunna token (${typeOfFortunnaToken}) acquired: ${hre.ethers.utils.formatUnits(fortunnaTokenBalance)}`);
      if ((await fortunnaToken.allowance(deployer, poolAddress)).eq(hre.ethers.constants.Zero)) {
        log('Allowance is lower than needed, approving the sum: 2**256...');
        const fortunnaTokenApproveTxReceipt = await fortunnaToken.approve(poolAddress, hre.ethers.constants.MaxUint256);
        await fortunnaTokenApproveTxReceipt.wait();
      }
      return fortunnaTokenBalance;
    }

    await approveMaxAndReturnBalance(stakingTokenInstance, "staking");
    const rewardTokenBalance = await approveMaxAndReturnBalance(rewardTokenInstance, "reward");

    const poolInstance = await hre.ethers.getContractAt(
      hre.names.internal.fortunnaPool,
      poolAddress
    );

    log('Providing the rewards for the pool...');
    const addExpectedRewardTxReceipt = await poolInstance
      .addExpectedRewardTokensBalanceToDistribute(rewardTokenBalance);
    await addExpectedRewardTxReceipt.wait();
    log(`Total reword amount: ${hre.ethers.utils.formatUnits((await getEventBody("RewardAdded", poolInstance)).reward)}`);

    const providePartOfTotalRewardsTxReceipt = await poolInstance
      .providePartOfTotalRewards();
    await providePartOfTotalRewardsTxReceipt.wait();
    log(`Part of reward ready to distribute: ${hre.ethers.utils.formatUnits((await getEventBody("PartDistributed", poolInstance)).partOfTotalRewards)}`);
  }