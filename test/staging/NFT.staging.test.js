//集成测试：
// 1 测试合约之间交互（和第三方真实服务合约交互），
// 2 真实环境的网络延时等的影响
// 3 在单元测试中无法测试的场景
// 4 真实的连上环境测试 sepolia
// 5 npx hardhat test --network sepolia

const {ethers, deployments, network} = require("hardhat")
const {assert, expect} = require("chai")
const {devlopmentChains} = require("../../helper-hardhat-config")

//一般涉及资产转移的都需要 写 测试用例
devlopmentChains.includes(network.name)
    ? describe.skip
    : describe("test nft contract", async function () {

        let nft;
        let firstAccount;
        beforeEach(async function () {
            //使用 hardhat-deployment插件 实现 测试中的合约部署
            await deployments.fixture("all")
            firstAccount = (await getNamedAccounts()).firstAccount
            //deployments 跟踪所有已经部署的合约
            /*const {address} = await deployments.get("NFT")
            mockV3Aggregator = await deployments.get("MockV3Aggregator")
            nft = await ethers.getContractAt("NFT", address)*/

            const nftContract = await deployments.get("NFT")
            // 使用已部署合约的地址直接获取合约实例
            nft = await ethers.getContractAt("NFT", nftContract.address)
        })

        // 只需  测试合约 主流程：如 NFT的 mint 和 转移
        //各个主要方法的交互逻辑

        it("test nft mint", async function () {
            //等待合约部署成功
            /*await nft.waitForDeployment();
            assert.equal(await nft.owner(), firstAccount);*/

       /*     // make sure target reached
            await fundMe.fund({value: ethers.parseEther("0.5")}) // 3000 * 0.5 = 1500
            // make sure window closed
            await new Promise(resolve => setTimeout(resolve, 181 * 1000))
            // make sure we can get receipt
            const getFundTx = await fundMe.getFund()//交易发送，但是不保证写到链上
            const getFundReceipt = await getFundTx.wait()//拿到交易回执，证明已经写到链上
       */

        })


    });
