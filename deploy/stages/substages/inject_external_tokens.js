const hre = require('hardhat');
const { getFakeDeployment } = require('../../helpers');

module.exports = async ({
  deployments
}) => {
  const {log, save} = deployments;
  await getFakeDeployment(
    "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2",
    hre.names.external.weth,
    save,
    log
  );
}
module.exports.tags = ["inject_external_tokens", "external_tokens"];
