const {network, deployments, upgrades, ethers} = require("hardhat")
const {devlopmentChains, networkConfig, CONFIRMATIONS} = require("../helper-hardhat-config")

const fs = require("fs");
const path = require("path");

// deploy  也是 task的一种
//hre 中 getNamedAccounts, deployments的两个函数

//在 hardhat-deploy 插件中，deploy 函数返回的对象使用 address 属性，
// 而在 ethers.js 中部署合约时使用 target 属性。
module.exports = async ({getNamedAccounts, deployments}) => {

    const {firstAccount} = await getNamedAccounts()
    const {save} = deployments

    /*let dataFeedAddr
    let confirmations
    if (devlopmentChains.includes(network.name)) {
        const mockV3Aggregator = await deployments.get("MockV3Aggregator")
        dataFeedAddr = mockV3Aggregator.address
        confirmations = 0
        console.log("Deploying DataFeed from MockV3Aggregator...");
    } else {
        dataFeedAddr = networkConfig[network.config.chainId].ethUsdDataFeed
        confirmations = CONFIRMATIONS
        console.log("Deploying DataFeed from ETH...");
    }*/


    // 1 获取合约
    const Auction = await ethers.getContractFactory("Auction");
    console.log("Deploying Auction...");

    //通过uups 部署代理合约
    const auctionProxy = await upgrades.deployProxy(
        Auction,
        [],
        {initializer: 'initialize'}
    );
    await auctionProxy.waitForDeployment();

    //获取代理合约地址
    const auctionProxyAddress = await auctionProxy.getAddress();
    console.log("Auction Proxy deployed to:", auctionProxyAddress);

    //获取实现合约地址
    const auctionImplAddress = await upgrades.erc1967.getImplementationAddress(auctionProxyAddress)
    console.log("Auction Impl deployed to:", auctionImplAddress);

    //保存数据 到本地
    const storePath = path.resolve(__dirname, "./.cache/auctionProxy.json")
    //先删除
    if (fs.existsSync(storePath)) {
        fs.unlinkSync(storePath)
    }
    fs.writeFileSync(
        storePath,
        JSON.stringify({
            auctionProxyAddress,
            auctionImplAddress,
            abi: Auction.interface.format("json")//写进json文件的键值就是  auctionProxyAddress，auctionImplAddress，abi
        }))

    //信息整合到 hardhat-deploy 的部署管理系统中
    await save(
        "AuctionProxy", //代理合约名称:自定义
        {
            abi: Auction.interface.format("json"),
            address: auctionProxyAddress
        }
    )


    /* console.log("Deploying Auction...")
     const auctionImpl = await deploy("Auction", {
         from: firstAccount,
         args: [],
         log: true,
         waitConfirmations: confirmations //等待5个区块确认
     })
     console.log("Auction deployed to:", auctionImpl.address);

     // 2 Auction  Factory
     console.log("Deploying AuctionFactory...")
     const factory = await deploy("AuctionFactory", {
         from: firstAccount,
         proxy: {
             proxyContract: "UUPS",
             execute: {
                 init: {
                     methodName: "initialize",
                     args: [auctionImpl.address, dataFeedAddr]
                 }
             }
         },
         log: true,
         waitConfirmations: confirmations
     })
     console.log("AuctionFactory deployed to:", factory.address);*/


    /*if (hre.network.config.chainId === 1115515 && process.env.ETHERSCAN_API_KEY) {
    console.log("Waiting for block confirmations...");
    await nft.deployTransaction().wait(5);
    //verify
    await verify(nft.target, ["MyNFT","MIT"])
} else {
    console.log("Not on sepolia network. No need to verify");
}*/

}

/*async function verify(address, args){

    console.log("Verifying contract...");
    try{
        await hre.run("verify:verify", {
            address: address,
            constructorArguments: args,
        })
    } catch (e) {
        if(e.message.toLowerCase().includes("already verified")){
            console.log("Already Verified!");
        } else {
            console.log(e);
        }
    }
}*/

module.exports.tags = ["all", "auction"]