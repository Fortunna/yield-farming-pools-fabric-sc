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
    "0xB4FBF271143F4FBf7B91A5ded31805e42b2208d6",
    hre.names.external.weth,
    save,
    log
  );
  await getFakeDeployment(
    "0x509Ee0d083DdF8AC028f2a56731412edD63223B9",
    hre.names.external.usdt,
    save,
    log
  );
}
module.exports.tags = ["inject_external_goerli_contracts", "external_goerli"];
