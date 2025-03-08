const { ethers } = require("hardhat");
const {getAddress, setAddress} = require('../scripts/saveaddress.js');


module.exports = async ({getNamedAccounts, deployments, network}) => {
    const {deploy} = deployments;
    const {deployer} = await getNamedAccounts();


    // Define the constructor parameters
    const vestingToken = await ethers.getContractFactory("VestingToken");
    
    // deploy VestingToken
    const vestingTokenInst = await vestingToken.deploy();
    await vestingTokenInst.waitForDeployment();
    console.log(`### Vesting Token deployed at ${vestingTokenInst.target}`);
    await setAddress("VestingToken", vestingTokenInst.target);

    return true;
};
module.exports.tags = ["VestingToken"];
module.exports.id = "VestingToken";
