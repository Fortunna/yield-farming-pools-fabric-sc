const hre = require('hardhat');
const { skipIfAlreadyDeployed, POOL_DEPLOY_COST, DEAD_ADDRESS } = require('../../helpers');

module.exports = async ({
  getNamedAccounts,
  deployments,
  network
}) => {
  const { log, deploy, get, execute } = deployments;
  const { deployer } = await getNamedAccounts();

  const fortunnaPoolPrototypeAddress = (await get(hre.names.internal.fortunnaPool)).address;
  const fortunnaTokenPrototypeAddress = (await get(hre.names.internal.fortunnaToken)).address;

  /// TO BE REDACTED
  const fortunnaPoolUniswapV3PrototypeAddress = DEAD_ADDRESS;
  log('UNISWAP V3 POOL HAS NOT YET BEEN IMPLEMENTED.');
  /// TO BE REDACTED

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

  await deploy(hre.names.internal.productionMockToken, {
    from: deployer,
    skipIfAlreadyDeployed,
    log: true,
    args: [
      "Fortunna Test Token", 
      "FTT", 
      hre.ethers.utils.parseEther('100000'),
      [
        (await get(hre.names.internal.fortunnaFactory)),
        deployer
      ]
    ]
  });
}
module.exports.tags = ["main_stage", "main"];
