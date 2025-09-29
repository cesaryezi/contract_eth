const {ethers, upgrades} = require("hardhat");

//script 需要手动执行 js脚本  npx hardhat run scripts/deploy.js --network sepolia
async function main() {

    // 1 Auction Impl
    const Auction = await ethers.getContractFactory("Auction");
    console.log("Deploying Auction...");
    //deploy  contract from  factory
    const auctionImpl = await Auction.deploy();
    await auctionImpl.waitForDeployment();
    console.log("Auction deployed to:", auctionImpl.target);


    // 2 Auction  Factory
    const AuctionFactory = await ethers.getContractFactory("AuctionFactory");
    console.log("Deploying AuctionFactory...");
    const factory = await upgrades.deployProxy(AuctionFactory, [
        auctionImpl.target,
        "0x694AA1769357215DE4FAC081bf1f309aDC325306" // Sepolia ETH/USD feed
    ], {initializer: 'initialize'});
    await factory.waitForDeployment();
    console.log("AuctionFactory deployed to:", factory.target);


    // const instance = await upgrades.upgradeProxy(
    //         "0xProxyAddress",  // 现有代理地址
    //         MyContractV2       // 新的实现合约
    //     );


    /*if (hre.network.config.chainId === 1115515 && process.env.ETHERSCAN_API_KEY) {
        console.log("Waiting for block confirmations...");
        await auction.deployTransaction().wait(5);
        //verify
        await verify(auction.target, [])
    } else {
        console.log("Not on sepolia network. No need to verify");
    }*/

}

async function verify(address, args) {

    console.log("Verifying contract...");
    try {
        await hre.run("verify:verify", {
            address: address,
            constructorArguments: args,
        })
    } catch (e) {
        if (e.message.toLowerCase().includes("already verified")) {
            console.log("Already Verified!");
        } else {
            console.log(e);
        }
    }
}


// call main function
main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    })

