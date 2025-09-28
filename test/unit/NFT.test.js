const {ethers, deployments} = require("hardhat")
const {assert} = require("chai")

//一般涉及资产转移的都需要 写 测试用例

describe("test nft contract", async function () {

    let nft;
    let firstAccount;
    let mockV3Aggregator
    beforeEach(async function () {
        //使用 hardhat-deployment插件 实现 测试中的合约部署
        await deployments.fixture("all")
        firstAccount = (await getNamedAccounts()).firstAccount
        //deployments 跟踪所有已经部署的合约
        const {address} = await deployments.get("NFT")
        mockV3Aggregator = await deployments.get("MockV3Aggregator")
        nft = await ethers.getContractAt("NFT", address)
    })

    it("test if the owner is msg.sender", async function () {
        //等待合约部署成功
        await nft.waitForDeployment();
        assert.equal(await nft.owner(), firstAccount);
    })



});