const hre = require("hardhat");
const keccak256 = require("keccak256");

////////////////////////////////////////////
// Constants Starts
////////////////////////////////////////////

const DEAD_ADDRESS = "0x000000000000000000000000000000000000dEaD";
const skipIfAlreadyDeployed = true;
const POOL_DEPLOY_COST = hre.ethers.utils.parseEther('0.1');

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

const emptyStage = (message) => {
  return async ({deployments}) => {
      const {log} = deployments;
      log(message);
  }
};

const getEventBody = async (eventName, contractInstance) => {
  const filter = contractInstance.filters[eventName]();
  const filterQueryResult = await contractInstance.queryFilter(filter);
  return filterQueryResult[0].args;
}

const grantRoles = async (
  utilizingTokensAddresses, 
  rolesFlags, 
  roleName, 
  deployer, 
  execute
) => {
  for (let i = 0; i < rolesFlags.length; i++) {
    if (rolesFlags[i]) {
      await execute(
        hre.names.internal.fortunnaFactory,
        {from: deployer, log: true},
        'grantRole',
        keccak256(roleName),
        utilizingTokensAddresses[i]
      )
    }
  }
}

module.exports = {
  getMockToken,
  skipIfAlreadyDeployed,
  withImpersonatedSigner,
  mintNativeTokens,
  getFakeDeployment,
  emptyStage,
  POOL_DEPLOY_COST,
  DEAD_ADDRESS,
  grantRoles,
  getEventBody
};
