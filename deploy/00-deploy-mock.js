const {DECIMAL, INITIAL_ANSWER, devlopmentChains} = require("../helper-hardhat-config")
const {network, ethers} = require("hardhat");

// deploy  也是 task的一种，一种更自动化 的部署方式  npx hardhat deploy --network xxxx
//task中  手动一个一个执行，查看每个步骤的输出结果
//hre 中 getNamedAccounts, deployments的两个函数
module.exports = async ({getNamedAccounts, deployments}) => {


    if (devlopmentChains.includes(network.name)) {
        const {firstAccount} = await getNamedAccounts()
        const {deploy} = deployments


        await deploy("MyToken", {
            from: firstAccount,
            // args: [firstAccount],
            args: [],
            log: true,
            // waitConfirmations: CONFIRMATIONS //等待5个区块确认
        })

        await deploy("MockV3Aggregator", {
            from: firstAccount,
            args: [DECIMAL, INITIAL_ANSWER],
            log: true
        })

        // 部署 TOKEN/USD 价格预言机
        await deploy("TokenUsdPriceFeed", {
            from: firstAccount,
            contract: "MockV3Aggregator", // 指定使用 MockV3Aggregator 合约
            args: [DECIMAL, INITIAL_ANSWER], // 例如: [8, 100000000] 表示 $1
            // args: [DECIMAL, ethers.parseEther("1")], // 例如: [8, 100000000] 表示 $1
            log: true
        })

    } else {
        console.log("environment is not local, mock contract depployment is skipped")
    }

}

module.exports.tags = ["all", "mock", "auction"]
