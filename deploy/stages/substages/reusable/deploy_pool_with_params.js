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

    await execute(
      hre.names.internal.fortunnaFactory,
      {from: deployer, log: true, value: POOL_DEPLOY_COST},
      'createPool',
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
      ]
    );

    const rewardTokenInstance = await hre.ethers.getContractAt(
      hre.names.internal.fortunnaToken,
      rewardFortunnaTokenAddress
    );

    const stakingTokenInstance = await hre.ethers.getContractAt(
      hre.names.internal.fortunnaToken,
      stakingFortunnaTokenAddress
    );

    log('Starting FortunnaToken\'s reserves initialization...');
    const rewardTokenReserveInitializationTxReceipt = await rewardTokenInstance.initializeReserves();
    await rewardTokenReserveInitializationTxReceipt.wait();

    const stakingTokenReserveInitializationTxReceipt = await stakingTokenInstance.initializeReserves();
    await stakingTokenReserveInitializationTxReceipt.wait();
    log(`Initialization of FortunnaToken\'s reserves finished.`);
  }