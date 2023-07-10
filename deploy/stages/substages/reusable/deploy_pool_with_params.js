const hre = require('hardhat');
const { POOL_DEPLOY_COST, grantRoles, getEventBody, getFakeDeployment } = require("../../../helpers");

module.exports =
  (
    poolArtifactName,
    poolPrototypeIdx,
    poolFunctionalityDurationInDays,
    minLockUpRewardPeriodInDays,
    earlyWithdrawalFeeBasePoints,
    depositWithdrawFeeBasePoints,
    totalRewardBasePointsPerDistribution,
    minStake,
    maxStake,
    getUtilizingTokensAndListsOfFlags,
    postPoolDeployActions
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

    const { log, execute, get, save } = deployments;
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
    await getFakeDeployment(
      poolAddress,
      poolArtifactName + "_Clone",
      save,
      log
    );

    log(`Acquired pool address from the factory: ${poolAddress}`);
    await postPoolDeployActions(poolAddress, poolArtifactName, log);
  }