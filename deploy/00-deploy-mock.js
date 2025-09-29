const { DECIMAL, INITIAL_ANSWER, devlopmentChains} = require("../helper-hardhat-config")
const {network} = require("hardhat");

// deploy  也是 task的一种，一种更自动化 的部署方式  npx hardhat deploy --network xxxx
//task中  手动一个一个执行，查看每个步骤的输出结果
//hre 中 getNamedAccounts, deployments的两个函数
module.exports= async({getNamedAccounts, deployments}) => {


    if(devlopmentChains.includes(network.name)) {
        const {firstAccount} = await getNamedAccounts()
        const {deploy} = deployments

        await deploy("MockV3Aggregator",{
            from: firstAccount,
            args: [DECIMAL, INITIAL_ANSWER],
            log: true
        })
    } else {
        console.log("environment is not local, mock contract depployment is skipped")
    }

}

module.exports.tags = ["all", "mock"]
