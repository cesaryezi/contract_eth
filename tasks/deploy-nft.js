const {task} = require("hardhat/config")
// const {ethers} = require("hardhat");


task("deploy-nft", "deploy nft contract").setAction(async(taskArgs, hre) => {
    // create factory
    const factoryNFT = await ethers.getContractFactory("NFT");
    console.log("Deploying NFT...");
    //deploy  contract from  factory
    const nft = await factoryNFT.deploy("MyNFT", "MIT");
    await nft.waitForDeployment();
    console.log("NFT deployed to:", nft.target);

} )

module.exports = {};

// task用于自动化部署，易于用户操作(其实就是 script代码)，可以在 npx hardhat --help中找到
