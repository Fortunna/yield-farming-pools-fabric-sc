const hre = require('hardhat');
const { skipIfAlreadyDeployed, POOL_DEPLOY_COST } = require('../../helpers');

module.exports = async ({
  getNamedAccounts,
  deployments,
  network
}) => {
  const { execute } = deployments;
  const { deployer } = await getNamedAccounts();

  await execute(
    hre.names.internal.productionTestTokenA,
    {from: deployer, log: true},
    'mint',
    deployer,
    hre.ethers.utils.parseEther('1000000000')
  );
  await execute(
    hre.names.internal.productionTestTokenB,
    {from: deployer, log: true},
    'mint',
    deployer,
    hre.ethers.utils.parseEther('1000000000')
  );
}
module.exports.tags = ["mint_production_test_tokens", "mint"];
