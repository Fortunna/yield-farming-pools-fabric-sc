const hre = require('hardhat');
const { getFakeDeployment } = require('../../helpers');

module.exports = async ({
  deployments
}) => {
  const {log, save} = deployments;
  await getFakeDeployment(
    "0xC36442b4a4522E871399CD717aBDD847Ab11FE88",
    hre.names.external.nftPositionManager,
    save,
    log
  );
  await getFakeDeployment(
    "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2",
    hre.names.external.weth,
    save,
    log
  );
  await getFakeDeployment(
    "0xdAC17F958D2ee523a2206206994597C13D831ec7",
    hre.names.external.usdt,
    save,
    log
  );
}
module.exports.tags = ["inject_external_contracts", "external"];
