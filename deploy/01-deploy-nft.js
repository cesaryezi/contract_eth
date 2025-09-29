// const { network } = require("hardhat")
const {devlopmentChains, networkConfig, CONFIRMATIONS} = require("../helper-hardhat-config")

// deploy  也是 task的一种
//hre 中 getNamedAccounts, deployments的两个函数
module.exports = async ({getNamedAccounts, deployments}) => {

    const {firstAccount} = await getNamedAccounts()
    const {deploy} = deployments

    /*let dataFeedAddr
    let confirmations
    if(devlopmentChains.includes(network.name)) {
        const mockV3Aggregator = await deployments.get("MockV3Aggregator")
        dataFeedAddr = mockV3Aggregator.address
        confirmations = 0
    } else {
        dataFeedAddr = networkConfig[network.config.chainId].ethUsdDataFeed
        confirmations = CONFIRMATIONS
    }*/

    await deploy("NFT", {
        from: firstAccount,
        args: ["MyNFT", "MIT"],
        log: true,
        // waitConfirmations: CONFIRMATIONS //等待5个区块确认
    })

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

module.exports.tags = ["all", "NFT"]