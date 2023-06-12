const hre = require('hardhat');

module.exports = async ({
  getNamedAccounts,
  deployments,
  network
}) => {
  const { log } = deployments;
  const unpackedAccounts = await getNamedAccounts();
}
module.exports.tags = ["deploy_prototypes", "prototypes"];
