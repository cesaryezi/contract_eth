const {ethers, deployments, network, upgrades} = require("hardhat")
const {assert, expect} = require("chai")
const {devlopmentChains} = require("../../helper-hardhat-config")
const helpers = require("@nomicfoundation/hardhat-network-helpers")

//一般涉及资产转移的都需要 写 测试用例
//npx hardhat coverage 可以查看单元测试覆盖率
!devlopmentChains.includes(network.name)
    ? describe.skip
    : describe("test auction contract", async function () {

        let nft;
        let firstAccount;
        let secondAccount

        let mockV3Aggregator
        let mockV3AggregatorToken
        let mockMyToken

        let Auction;
        let auctionFactory;
        // 修改 beforeEach 钩子中的代码
        beforeEach(async function () {


            firstAccount = (await getNamedAccounts()).firstAccount
            secondAccount = (await getNamedAccounts()).secondAccount

            const [signer, buyer, buyer2] = await ethers.getSigners()

            //1 集成deploy插件，部署
            await deployments.fixture(["auction"])

            //2 集成deploy插件，直接获取 AuctionProxy
            const AuctionProxy = await deployments.get("AuctionProxy");
            console.log("AuctionProxy:", AuctionProxy.address);
            //获取 AuctionProxy 的实例
            Auction = await ethers.getContractAt(
                "Auction",
                AuctionProxy.address
            );

            // 2 获取 NFT 合约
            const nftContract = await deployments.get("NFT")
            nft = await ethers.getContractAt("NFT", nftContract.address)
            // 铸造 NFT 给 signer
            for (let i = 0; i < 10; i++) {
                await nft.safeMint(signer.address);
            }
            const tokenId = 1;
            // 给代理合约授权!!!!!!!!!!!!!
            await nft.connect(signer).setApprovalForAll(AuctionProxy.address, true);

            // 3 味价本身合约地址
            //ETH/USD代币 味价
            mockV3Aggregator = await deployments.get("MockV3Aggregator")
            //ERC20代币(USDC/USD) 味价
            mockV3AggregatorToken = await deployments.get("TokenUsdPriceFeed")

            // 4 味价 值
            //ERC20代币
            const mockMyTokenCon = await deployments.get("MyToken")
            mockMyToken = await ethers.getContractAt("MyToken", mockMyTokenCon.address)

            // 3 批量给两个用户转账ERC20代币 !!!!!!!!!!!!!
            let tx0 = await mockMyToken.connect(signer).transfer(buyer, ethers.parseEther("1000"))
            await tx0.wait()
            let tx1 = await mockMyToken.connect(signer).transfer(buyer2, ethers.parseEther("1000"))
            await tx1.wait()

            // 5 设置拍卖合约的代币价格
            const token2Usd = [{
                token: ethers.ZeroAddress,
                priceFeed: mockV3Aggregator.address
            }, {
                token: mockMyToken.getAddress(),
                priceFeed: mockV3AggregatorToken.address
            }]
            for (let i = 0; i < token2Usd.length; i++) {
                await Auction.setDataFeed(
                    token2Usd[i].token,
                    token2Usd[i].priceFeed
                )
            }

            // 在 beforeEach 中添加调试信息
            /*console.log("NFT address:", nft.target);
            console.log("First account:", firstAccount);
            console.log("Second account:", secondAccount);
            console.log("signer account:", signer);*/

            // 6 创建拍卖
            await Auction.createAuction(
                nft.target,
                tokenId,
                ethers.parseEther("0.01"),
                100
            );

            const auction1 = await Auction.auctions(0);
            console.log("创建拍卖成功：：", auction1);

        })


        it("test auction....", async function () {


            const [signer, buyer, buyer2] = await ethers.getSigners()

            //ETH拍卖
            const tx = await Auction.connect(buyer).bid(0, 0, ethers.ZeroAddress, {value: ethers.parseEther("0.01")})
            await tx.wait()
            console.log("bid success:", tx)
            const auction1 = await Auction.auctions(0);
            console.log("auction1:", auction1);
            0.01
            expect(auction1.highestBidder).to.equal(buyer.address);

            // s


            //ERC20代币拍卖  ethers.parseEther("101") = 101 * 10 ** 18
            // 授权代币给拍卖合约 !!!!!!!!!!!!!
            await mockMyToken.connect(buyer2).approve(Auction.getAddress(), ethers.parseEther("1000"));
            const balance = await ethers.provider.getBalance(buyer2.address);
            console.log("ERC20代币拍卖：：", balance)
            const tx2 = await Auction.connect(buyer2).bid(0, ethers.parseEther("101"), mockMyToken.getAddress())
            await tx2.wait()
            console.log("bid success:", tx2)
            const auction2 = await Auction.auctions(0);
            expect(auction2.highestBidder).to.equal(buyer2.address);

            await nft.ownerOf(1).then((res) => {
                console.log("NFT owner:", res);
                expect(res).to.not.equal(buyer2.address);
            }).catch((err) => {
                console.log("err1:", err);
            })

            //等待100秒，结束拍卖
            //await new Promise((resolve) => setTimeout(resolve, 100 * 1000));

            //多个异步任务并行执行（如发多个交易）：
            // await Promise.all([
            //   contract.connect(user1).mint(),
            //   contract.connect(user2).mint()
            // ]);

            //常用工具函数（from Ethers.js）
            // ethers.parseEther("1.0")     // 把 1 ETH 转成 wei
            // ethers.formatEther("1000000000000000000") // wei 转 ETH
            // ethers.AddressZero       // 0x000...000
            await helpers.time.increase(100);
            const tx3 = await Auction.connect(signer).endAuction(0)
            await tx3.wait()

            //查看拍卖结果
            const auction3 = await Auction.auctions(0);
            console.log("auction3:", auction3);
            expect(auction3.highestBid).to.equal(ethers.parseEther("101"));
            expect(auction3.ended).to.equal(true);

           await nft.ownerOf(1).then((res) => {
               console.log(" buyer2:", buyer2.address);
               console.log("NFT owner:", res);
               expect(res).to.equal(buyer2.address);
            }).catch((err) => {
                console.log("err2:", err);
            })

            /*const tx24 = await Auction.connect(buyer).bid(0, 0, ethers.ZeroAddress, {value: ethers.parseEther("0.01")})
            await tx24.wait()*/

        })

    });