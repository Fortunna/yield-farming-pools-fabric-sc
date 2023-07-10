const hre = require('hardhat');

module.exports =
  (
    poolArtifactName,
    getTokensAddresses
  ) => async (deployScriptParams) => {
    const {
      getNamedAccounts,
      deployments
    } = deployScriptParams;

    const { log, get } = deployments;
    const { deployer } = await getNamedAccounts();
    const tokensAddresses = await getTokensAddresses(deployScriptParams);

    const pool = await hre.ethers.getContractAt(
      poolArtifactName,
      (await get(poolArtifactName + "_Clone")).address
    );

    log('Starting checks if approvals required.');
    for (const tokenAddress of tokensAddresses) {
      const token = await (
        await hre.ethers.getContractAt(
          "@openzeppelin/contracts-new/token/ERC20/extensions/IERC20Metadata.sol:IERC20Metadata",
          tokenAddress
        )
      ).deployed();
      if ((await token.allowance(deployer, pool.address)).eq(hre.ethers.constants.Zero)) {
        const tokenApproveTxReceipt = await token.approve(pool.address, hre.ethers.constants.MaxUint256);
        await tokenApproveTxReceipt.wait();
        log(`Approving to MaxUint256 token: (${await token.symbol()}) ${token.address}`);
      }
    }
    log('Such check is done.');
  }