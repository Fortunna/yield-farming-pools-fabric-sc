const hre = require('hardhat');
const { skipDeploymentIfAlreadyDeployed } = require('../../helpers');

module.exports = async ({
  getNamedAccounts,
  deployments,
  network
}) => {
  const { log, deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  await deploy(hre.names.internal.fortunnaLib, {
    from: deployer,
    skipIfAlreadyDeployed: skipDeploymentIfAlreadyDeployed,
    log: true
  });

  const libraries = {
    FortunnaLib: (await deployments.get(hre.names.internal.fortunnaLib)).address 
  }
  log(`Acquired libaries settings: ${JSON.stringify(libraries)}`);

  await deploy(hre.names.internal.fortunnaPool, {
    from: deployer,
    skipIfAlreadyDeployed: skipDeploymentIfAlreadyDeployed,
    log: true,
    libraries
  });

  await deploy(hre.names.internal.fortunnaToken, {
    from: deployer,
    skipIfAlreadyDeployed: skipDeploymentIfAlreadyDeployed,
    log: true,
    libraries
  });
}
module.exports.tags = ["deploy_prototypes", "prototypes"];
