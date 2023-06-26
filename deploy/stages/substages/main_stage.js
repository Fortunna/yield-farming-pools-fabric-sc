const hre = require('hardhat');
const { skipIfAlreadyDeployed, POOL_DEPLOY_COST } = require('../../helpers');

module.exports = async ({
  getNamedAccounts,
  deployments,
  network
}) => {
  const { deploy, get, execute } = deployments;
  const { deployer } = await getNamedAccounts();

  const fortunnaPoolPrototypeAddress = (await get(hre.names.internal.fortunnaPool)).address;
  const fortunnaTokenPrototypeAddress = (await get(hre.names.internal.fortunnaToken)).address;
  const fortunnaPoolUniswapV3PrototypeAddress = (await get(hre.names.internal.fortunnaPoolUniswapV3)).address;

  await deploy(hre.names.internal.fortunnaFactory, {
    from: deployer,
    skipIfAlreadyDeployed,
    args: [
      fortunnaTokenPrototypeAddress,
      fortunnaPoolPrototypeAddress,
      fortunnaPoolUniswapV3PrototypeAddress,
      [
        hre.ethers.constants.AddressZero
      ]
    ],
    log: true
  });

  await execute(
    hre.names.internal.fortunnaFactory,
    {from: deployer, log: true},
    'setPaymentInfo',
    [
      hre.ethers.constants.AddressZero,
      POOL_DEPLOY_COST
    ]
  );
}
module.exports.tags = ["main_stage", "main"];
