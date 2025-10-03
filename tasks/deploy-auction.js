const {task} = require("hardhat/config")
// const {ethers} = require("hardhat");

task("deploy-auction", "deploy auction contract").setAction(async(taskArgs, hre) => {
    // 1 Auction Impl
    const Auction = await ethers.getContractFactory("Auction");
    console.log("Deploying Auction...");
    //deploy  contract from  factory
    const auctionImpl = await Auction.deploy();
    await auctionImpl.waitForDeployment();
    console.log("Auction deployed to:", auctionImpl.target);


    // 2 Auction  Factory
    /*const AuctionFactory = await ethers.getContractFactory("AuctionFactory");
    console.log("Deploying AuctionFactory...");
    const factory = await upgrades.deployProxy(AuctionFactory, [
        auctionImpl.target,
        "0x694AA1769357215DE4FAC081bf1f309aDC325306" // Sepolia ETH/USD feed
    ], {initializer: 'initialize'});
    await factory.waitForDeployment();
    console.log("AuctionFactory deployed to:", factory.target);*/

} )

module.exports = {};

// task用于自动化部署，易于用户操作(其实就是 script代码)，可以在 npx hardhat --help中找到
