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

/*    let dataFeedAddr
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


    // 1 Auction Impl
    // 读取 .cache/proxyNftAuction.json文件,获取代理合约 abi和address
    const storePath = path.resolve(__dirname, "./.cache/auctionProxy.json");
    const storeData = fs.readFileSync(storePath, "utf-8");
    const { auctionProxyAddress, auctionImplAddress, abi } = JSON.parse(storeData);

    // 升级版的业务合约
    const AuctionV2 = await ethers.getContractFactory("AuctionV2")


    // 通过原始合约的代理合约  和 目前 最新的业务合约  创建部署代理合约
    const auctionV2Proxy = await upgrades.upgradeProxy(
        auctionProxyAddress,
        AuctionV2
    )
    await auctionV2Proxy.waitForDeployment();
    const auctionV2ProxyAddress = await auctionV2Proxy.getAddress()
    console.log("AuctionV2 Proxy deployed to:", auctionV2ProxyAddress);


    //信息整合到 hardhat-deploy 的部署管理系统中
    await save(
        "AuctionV2Proxy", //最新的业务合约 代理名称:自定义
        {
            abi,//从本地文件解析出abi
            address: auctionV2ProxyAddress
        }
    )

    console.log("Upgrading proxy from:", auctionProxyAddress);
    console.log("Old implementation:", auctionImplAddress);


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

module.exports.tags = ["all", "auctionUpgrade"]