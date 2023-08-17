const hre = require('hardhat');
const { skipIfAlreadyDeployed, POOL_DEPLOY_COST } = require('../../helpers');

module.exports = async ({
  getNamedAccounts,
  deployments,
  network
}) => {
  const { execute } = deployments;
  const { deployer } = await getNamedAccounts();
  const receiver = "0x2ef73f60F33b167dC018C6B1DCC957F4e4c7e936";
  const finalReceivers = [deployer, receiver];
  for (const address of finalReceivers) {
    await execute(
      hre.names.internal.productionTestTokenA,
      {from: deployer, log: true},
      'mint',
      address,
      hre.ethers.utils.parseEther('1000000000')
    );
    await execute(
      hre.names.internal.productionTestTokenB,
      {from: deployer, log: true},
      'mint',
      address,
      hre.ethers.utils.parseEther('1000000000')
    );
  }
}
module.exports.tags = ["mint_production_test_tokens", "mint"];
