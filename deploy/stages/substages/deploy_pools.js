const hre = require('hardhat');
const { skipDeploymentIfAlreadyDeployed } = require('../../helpers');

module.exports = async ({
  getNamedAccounts,
  deployments,
  network
}) => {
  const { log, deploy, get, execute } = deployments;
  const { deployer } = await getNamedAccounts();

//   await execute(
//     hre.names.internal.fortunnaFactory,
//     {from: deployer, log: true},
//     'createPool',
//     [
//         ...
//     ]
//   );
}
module.exports.tags = ["deploy_pools", "pools"];
