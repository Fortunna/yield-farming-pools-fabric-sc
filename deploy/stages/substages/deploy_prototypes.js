const hre = require('hardhat');
const { skipIfAlreadyDeployed } = require('../../helpers');

module.exports = async ({
  getNamedAccounts,
  deployments,
  network
}) => {
  const { log, deploy, get } = deployments;
  const { deployer } = await getNamedAccounts();

  await deploy(hre.names.internal.fortunnaLib, {
    from: deployer,
    skipIfAlreadyDeployed,
    log: true
  });

  const libraries = {
    FortunnaLib: (await get(hre.names.internal.fortunnaLib)).address 
  }
  log(`Acquired libaries settings: ${JSON.stringify(libraries)}`);

  await deploy(hre.names.internal.fortunnaPool, {
    from: deployer,
    skipIfAlreadyDeployed,
    log: true,
    libraries
  });

  await deploy(hre.names.internal.fortunnaToken, {
    from: deployer,
    skipIfAlreadyDeployed,
    log: true,
    libraries
  });

  await deploy(hre.names.internal.productionTestToken, {
    from: deployer,
    skipIfAlreadyDeployed,
    log: true,
    args: [
      "Fortunna Test Token", 
      "FTT", 
      hre.ethers.utils.parseEther('100000')
    ]
  });
}
module.exports.tags = ["deploy_prototypes", "prototypes"];
