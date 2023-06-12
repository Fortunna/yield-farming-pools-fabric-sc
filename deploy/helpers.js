const hre = require("hardhat");

////////////////////////////////////////////
// Constants Starts
////////////////////////////////////////////

const ZERO_ADDRESS = '0x0000000000000000000000000000000000000000';
const skipDeploymentIfAlreadyDeployed = true;

////////////////////////////////////////////
// Constants Ends
////////////////////////////////////////////

const getMockToken = async (name, symbol, amount, deploy, deployer, save) => {
  let mockTokenDeployment = await deploy(hre.names.internal.mockToken, {
    from: deployer,
    args: [name, symbol, amount],
    log: true
  });
  await save(name, mockTokenDeployment);
  return await hre.ethers.getContractAt(hre.names.internal.mockToken, mockTokenDeployment.address);
}

const mintNativeTokens = async (signer, amountHex) => {
  await hre.network.provider.send("hardhat_setBalance", [
    signer.address || signer,
    amountHex
  ]);
}

const getFakeDeployment = async (address, name, save) => {
  await save(name, {address});
}

const withImpersonatedSigner = async (signerAddress, action) => {
  await hre.network.provider.request({
    method: "hardhat_impersonateAccount",
    params: [signerAddress],
  });

  const impersonatedSigner = await hre.ethers.getSigner(signerAddress);
  await action(impersonatedSigner);

  await hre.network.provider.request({
    method: "hardhat_stopImpersonatingAccount",
    params: [signerAddress],
  });
}

const emptyStage = (message) => 
  async ({deployments}) => {
      const {log} = deployments;
      log(message);
  };

module.exports = {
  getMockToken,
  skipDeploymentIfAlreadyDeployed,
  withImpersonatedSigner,
  mintNativeTokens,
  getFakeDeployment,
  ZERO_ADDRESS,
  emptyStage
};
