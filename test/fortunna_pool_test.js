const hre = require("hardhat");
const {
  withImpersonatedSigner,
  mintNativeTokens,
  DEAD_ADDRESS,
  getEventBody
} = require('../deploy/helpers');
const { expect } = require('chai');
const { ethers, deployments, getNamedAccounts } = hre;
const { get } = deployments;
const { time } = require('@nomicfoundation/hardhat-network-helpers');

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
    const amount = hre.ethers.utils.parseEther('1');
    const stakingTxReceipt = await pool.stake(amount);
    expect(stakingTxReceipt).to.emit("Staked", pool).withArgs(
      deployer,
      amount
    );
  });

  it("Successful withdraw", async () => {
    const amount = hre.ethers.utils.parseEther('1');
    await pool.stake(amount);
    const withdrawTxReceipt = await pool.withdraw(amount);
    expect(withdrawTxReceipt).to.emit("Withdrawn", pool)
      .withArgs(deployer, amount);
  });

  it("Successful getReward", async () => {
    const amount = hre.ethers.utils.parseEther('1');
    await pool.stake(amount);
    await time.increase(3600 * 24 * 15);
    const getRewardTxReceipt = await pool.getReward();
    const expectedRewards = await pool.pendingRewards(deployer);
    expect(expectedRewards).to.be.greaterThan(0);
    expect(getRewardTxReceipt).to.emit("RewardPaid", pool)
      .withArgs(deployer, expectedRewards);
  });
});