const hre = require('hardhat');
const { skipDeploymentIfAlreadyDeployed } = require('../../helpers');

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
  const fortunnaPoolUniswapV3PrototypeAddress = (await get(hre.names.internal.fortunnaPool)).address;
  log('UNISWAP V3 POOL HAS NOT YET BEEN IMPLEMENTED.');
  /// TO BE REDACTED

  await deploy(hre.names.internal.fortunnaFactory, {
    from: deployer,
    skipIfAlreadyDeployed: skipDeploymentIfAlreadyDeployed,
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
      hre.ethers.utils.parseEther('0.1')
    ]
  );
}
module.exports.tags = ["main_stage", "main"];
