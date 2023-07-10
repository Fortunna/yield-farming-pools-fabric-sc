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

  await deploy(hre.names.internal.fortunnaErrorsLib, {
    from: deployer,
    skipIfAlreadyDeployed,
    log: true
  });

  await deploy(hre.names.internal.fortunnaBitMaskLib, {
    from: deployer,
    skipIfAlreadyDeployed,
    log: true
  });

  const fortunnaLibAddress = (await get(hre.names.internal.fortunnaLib)).address;

  const libraries = {
    FortunnaLib: fortunnaLibAddress,
    FortunnaErrorsLib: (await get(hre.names.internal.fortunnaErrorsLib)).address,
    FortunnaBitMaskLib: (await get(hre.names.internal.fortunnaBitMaskLib)).address 
  }
  log(`Acquired libaries settings: ${JSON.stringify(libraries)}`);

  await deploy(hre.names.internal.fortunnaPool, {
    from: deployer,
    skipIfAlreadyDeployed,
    log: true,
    libraries
  });

  await deploy(hre.names.internal.fortunnaPoolUniswapV3, {
    from: deployer,
    skipIfAlreadyDeployed,
    log: true,
    libraries: {
      FortunnaLib: fortunnaLibAddress
    }
  });

  await deploy(hre.names.internal.fortunnaToken, {
    from: deployer,
    skipIfAlreadyDeployed,
    log: true,
    libraries
  });

  await deploy(hre.names.internal.productionTestTokenA, {
    from: deployer,
    skipIfAlreadyDeployed,
    log: true,
    args: [
      "Fortunna Test Token A", 
      "FTA", 
      hre.ethers.utils.parseEther('100000')
    ]
  });

  await deploy(hre.names.internal.productionTestTokenB, {
    from: deployer,
    skipIfAlreadyDeployed,
    log: true,
    args: [
      "Fortunna Test Token B", 
      "FTB", 
      hre.ethers.utils.parseEther('100000')
    ]
  });
}
module.exports.tags = ["deploy_prototypes", "prototypes"];
