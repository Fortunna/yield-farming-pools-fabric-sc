const hre = require("hardhat");
const {
  withImpersonatedSigner,
  mintNativeTokens,
  DEAD_ADDRESS,
} = require('../deploy/helpers');
const { ethers, deployments, getNamedAccounts } = hre;
const { get } = deployments;

describe("FortunnaPool", () => {
  let deployer;

  let pool;
  let rewardTokenInstance;
  let stakingTokenInstance;

  beforeEach(async () => {
    await deployments.fixture(['debug']);
    const accounts = await getNamedAccounts();
    deployer = accounts.deployer;
    pool = await hre.ethers.getContractAt(
      hre.names.internal.fortunnaPool,
      (await get(hre.names.internal.fortunnaPool + "_Clone")).address
    );
    rewardTokenInstance = await hre.ethers.getContractAt(
      hre.names.internal.fortunnaToken,
      await pool.rewardToken()
    );
    stakingTokenInstance = await hre.ethers.getContractAt(
      hre.names.internal.fortunnaToken,
      await pool.stakingToken()
    );
  });

  it("Successful stake", async () => {
    const balance = await stakingTokenInstance.balanceOf(deployer);
    console.log(balance.toString());
    const stakingTxReceipt = await pool.stake(balance);
    console.log(stakingTxReceipt);
  });

  // it("Successful withdraw", async () => {

  // });

  // it("Successful getReward", async () => {

  // });
});