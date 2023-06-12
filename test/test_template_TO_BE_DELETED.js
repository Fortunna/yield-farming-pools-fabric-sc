const {expect} = require("chai");
const hre = require("hardhat");
const {
  withImpersonatedSigner, 
  mintNativeTokens, 
  ZERO_ADDRESS,
} = require('../deploy/helpers');
const {ethers, deployments, getNamedAccounts} = hre;

describe("<SOME CONTRACT>", () => {

    beforeEach(async () => {
        // await deployments.fixture(['general_test_fixtures']);
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

    it("Successful something", async() => {

    });
});