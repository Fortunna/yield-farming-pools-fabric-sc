const hre = require('hardhat');

module.exports = 
  (
    poolFunctionalityDurationInDays,
    minLockUpRewardPeriodInDays,
    earlyWithdrawalFeeBasePoints,
    depositWithdrawFeeBasePoints,
    totalRewardBasePointsPerDistribution,
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

    const maxStake = hre.ethers.utils.parseEther('10');
    const minStake = hre.ethers.utils.parseEther('0.1');

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
    
    const stakingTokensMask = await fortunnaFactoryInstance
      .generateMaskForInitialRewardAmountsPair(stakingTokensFlags);
    const rewardTokensMask = await fortunnaFactoryInstance
      .generateMaskForInitialRewardAmountsPair(rewardTokensFlags);

    log(stakingTokensMask);
    log(rewardTokensMask);

    await execute(
      hre.names.internal.fortunnaFactory,
      {from: deployer, log: true},
      'createPool',
      [
        1, // pool idx
        1, // chain id
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
  }