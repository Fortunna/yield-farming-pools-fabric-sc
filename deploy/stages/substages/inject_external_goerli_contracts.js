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

  const fortunnaTestTokenAAddress = (await deployments.get(hre.names.internal.productionTestTokenA)).address;
  const fortunnaTestTokenBAddress = (await deployments.get(hre.names.internal.productionTestTokenB)).address;

  await getFakeDeployment(
    fortunnaTestTokenAAddress,
    hre.names.external.weth,
    save,
    log
  );
  await getFakeDeployment(
    fortunnaTestTokenBAddress,
    hre.names.external.usdt,
    save,
    log
  );
}
module.exports.tags = ["inject_external_goerli_contracts", "external_goerli"];
