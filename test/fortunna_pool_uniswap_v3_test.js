const hre = require("hardhat");
const {
  withImpersonatedSigner,
  mintNativeTokens
} = require('../deploy/helpers');
const { expect } = require('chai');
const { ethers, deployments, getNamedAccounts } = hre;
const { get } = deployments;
const { time } = require('@nomicfoundation/hardhat-network-helpers');

describe("FortunnaPoolUniswapV3", () => {
  const wethWhale = "0xF04a5cC80B1E94C69B48f5ee68a08CD2F09A7c3E";
  const usdtWhale = "0xF977814e90dA44bFA03b6295A0616a897441aceC";

  const wethBalance = ethers.utils.parseUnits('1', 6);
  const usdtBalance = ethers.utils.parseUnits('1', 6);
  let deployer;


  let pool;
  let token0Instance;
  let token1Instance;

  beforeEach(async () => {
    await deployments.fixture(['debug']);
    const accounts = await getNamedAccounts();
    deployer = accounts.deployer;
    pool = await hre.ethers.getContractAt(
      hre.names.internal.fortunnaPoolUniswapV3,
      (await get(hre.names.internal.fortunnaPoolUniswapV3 + "_Clone")).address
    );
    token0Instance = await hre.ethers.getContractAt(
      hre.names.external.specifiedIERC20,
      await pool.tokens(0)
    );
    token1Instance = await hre.ethers.getContractAt(
      hre.names.external.specifiedIERC20,
      await pool.tokens(1)
    );

    await withImpersonatedSigner(wethWhale, async (wethWhaleSigner) => {
      await mintNativeTokens(wethWhaleSigner, "0x1000000000000000000000000");
      await token1Instance.connect(wethWhaleSigner).transfer(deployer, wethBalance);
    });
    await withImpersonatedSigner(usdtWhale, async (usdtWhaleSigner) => {
      await mintNativeTokens(usdtWhaleSigner, "0x1000000000000000000000000");
      await token0Instance.connect(usdtWhaleSigner).transfer(deployer, usdtBalance);
    });
  });

  it("Successful stake", async () => {
    const stakingTxReceipt = await pool.stake(usdtBalance, wethBalance);
    // expect(stakingTxReceipt).to.emit("Staked", pool).withArgs(
    //   deployer,
    //   amount
    // );
  });

  // it("Successful withdraw", async () => {
  //   const amount = hre.ethers.utils.parseEther('1');
  //   await pool.stake(amount);
  //   const withdrawTxReceipt = await pool.withdraw(amount);
  //   expect(withdrawTxReceipt).to.emit("Withdrawn", pool)
  //     .withArgs(deployer, amount);
  // });

  // it("Successful getReward", async () => {
  //   const amount = hre.ethers.utils.parseEther('1');
  //   await pool.stake(amount);
  //   await time.increase(3600 * 24 * 15);
  //   const getRewardTxReceipt = await pool.getReward();
  //   const expectedRewards = await pool.pendingRewards(deployer);
  //   expect(expectedRewards).to.be.greaterThan(0);
  //   expect(getRewardTxReceipt).to.emit("RewardPaid", pool)
  //     .withArgs(deployer, expectedRewards);
  // });
});