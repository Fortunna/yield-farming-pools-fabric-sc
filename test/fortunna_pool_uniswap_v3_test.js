const hre = require("hardhat");
const {
  withImpersonatedSigner, 
  mintNativeTokens, 
  DEAD_ADDRESS,
} = require('../deploy/helpers');
const {ethers, deployments, getNamedAccounts} = hre;

describe("FortunnaPool", () => {

    beforeEach(async () => {
        await deployments.fixture(['debug']);
        // const accounts = await getNamedAccounts();
        // [<some signers from accounts>] = await ethers.getSigners();
        
        // someInternalContract = await ethers.getContractAt(
        //     hre.names.internal.someInternalContract, 
        //     (await deployments.get(hre.names.internal.someInternalContract)).address
        // );
        // someExternalContract = await ethers.getContractAt(
        //     hre.names.internal.someExternalContract,
        //     (await deployments.get(hre.names.external.someExternalContract)).address
        // );
    });

    it("Successful stake", async() => {

    });

    it("Successful withdraw", async() => {

    });

    it("Successful getReward", async() => {

    });
});