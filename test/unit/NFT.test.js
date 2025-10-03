const {ethers, deployments, network} = require("hardhat")
const {assert, expect} = require("chai")
const {devlopmentChains} = require("../../helper-hardhat-config")
const helpers = require("@nomicfoundation/hardhat-network-helpers")

//一般涉及资产转移的都需要 写 测试用例
//npx hardhat coverage 可以查看单元测试覆盖率
!devlopmentChains.includes(network.name)
    ? describe.skip
    : describe("test nft contract", async function () {

        let nft;
        let secondAccountNft;
        let firstAccount;
        let secondAccount
        let mockV3Aggregator
        beforeEach(async function () {
            //使用 hardhat-deployment插件 实现 测试中的合约部署
            await deployments.fixture("all")
            firstAccount = (await getNamedAccounts()).firstAccount
            secondAccount = (await getNamedAccounts()).secondAccount
            //deployments 跟踪所有已经部署的合约
            /*const {address} = await deployments.get("NFT")
            mockV3Aggregator = await deployments.get("MockV3Aggregator")
            nft = await ethers.getContractAt("NFT", address)*/

            const nftContract = await deployments.get("NFT")
            mockV3Aggregator = await deployments.get("MockV3Aggregator")
            // 使用已部署合约的地址直接获取合约实例
            nft = await ethers.getContractAt("NFT", nftContract.address)
            //通过合约名称和账户地址获取合约实例
            secondAccountNft = await ethers.getContract("NFT", secondAccount)
        })

        /*    it("test if the owner is msg.sender", async function () {
                //等待合约部署成功
                await nft.waitForDeployment();
                assert.equal(await nft.owner(), firstAccount);
            })*/

        it("test if the nft can be minted successfully", async function () {
            await nft.safeMint(firstAccount)
            const owner = await nft.ownerOf(1)
            expect(owner).to.equal(firstAccount)
        })

        it("test safeMint only owner", async function () {
            await expect(secondAccountNft.safeMint(secondAccount))
                // .to.be.revertedWith("Ownable: caller is not the owner")
                .to.be.revertedWithCustomError(nft, "OwnableUnauthorizedAccount")
                .withArgs(secondAccount);

            //expect(balance).to.equal(ethers.parseEther("0.1"))
            //可以使用发布事件的方式测试合约中复杂的资金转移（加 减混杂）逻辑 的测试
            /*  await expect(auction.bidEth())
                  .to.emit(auction, "HighestBidIncreased")
                  .withArgs(firstAccount, ethers.parseEther("0.1"))*/

           /* //将网络时间向前推进200秒，用于模拟时间流逝，确保众筹窗口期结束。
            await helpers.time.increase(200)
            //手动挖出一个新区块，使时间变化生效
            await helpers.mine()*/
        })


    });