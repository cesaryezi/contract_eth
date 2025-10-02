const {ethers, deployments, network} = require("hardhat")
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

        let auction;
        let auctionFactory;
        // 修改 beforeEach 钩子中的代码
        beforeEach(async function () {
            await deployments.fixture("all")
            firstAccount = (await getNamedAccounts()).firstAccount
            secondAccount = (await getNamedAccounts()).secondAccount

            const nftContract = await deployments.get("NFT")
            const auctionFactoryContract = await deployments.get("AuctionFactory")

            nft = await ethers.getContractAt("NFT", nftContract.address)
            auctionFactory = await ethers.getContractAt("AuctionFactory", auctionFactoryContract.address)

            mockV3Aggregator = await deployments.get("MockV3Aggregator")
            // console.log("mockV3Aggregator:", mockV3Aggregator.address)
            mockV3AggregatorToken = await deployments.get("TokenUsdPriceFeed")

            const mockMyTokenCon = await deployments.get("MyToken")
            mockMyToken = await ethers.getContractAt("MyToken", mockMyTokenCon.address)

            // 铸造 NFT 给 secondAccount
            await nft.safeMint(secondAccount);

            // 创建代币
            const amount = ethers.parseEther("100");
            await mockMyToken.mint(secondAccount, amount);


            // 获取签名者对象
            const [firstAccountSigner, secondAccountSigner] = await ethers.getSigners();

            // 授权给拍卖工厂
            await nft.connect(secondAccountSigner).approve(auctionFactory.target, 0);


            // 创建拍卖
            const tx = await auctionFactory.connect(secondAccountSigner).createAuction(
                nft.target,             // _nftContract
                0,                      // _nftTokenId
                ethers.parseEther("1"), // _startingPrice
                360,                   // _auctionDuration 6min
                mockMyToken.target,            // _acceptedToken
                mockV3AggregatorToken.address       // _tokenUsdFeed

            );
            const receipt = await tx.wait();

            // 获取新创建的拍卖合约地址
            const auctionCreatedEvent = receipt.logs.find(log => {
                try {
                    const parsedLog = auctionFactory.interface.parseLog(log);
                    return parsedLog.name === "AuctionCreated";
                } catch {
                    return false;
                }
            });

            const auctionAddress = auctionCreatedEvent.args.auction;
            auction = await ethers.getContractAt("Auction", auctionAddress);

            // 为拍卖合约授权代币转移权限:由 secondAccountSigner 为拍卖合约设置的
            await mockMyToken.connect(secondAccountSigner).approve(auction.target, amount);

        })

        it("test auction bidEth", async function () {
            const bidAmount = ethers.parseEther("1");
            const tx = await auction.bidEth({value: bidAmount});
            const blockNumber = await ethers.provider.getBlockNumber();
            const block = await ethers.provider.getBlock(blockNumber);

            await expect(tx)
                .to.emit(auction, "HighestBidIncreased")
                .withArgs([
                    firstAccount,
                    bidAmount,
                    true,
                    block.timestamp
                ])
        })

        it("test auction bidToken", async function () {
            const tokenAmount = ethers.parseEther("1");

            //await auction.connect(secondAccountSigner).bidToken(tokenAmount):
            // 使用 secondAccountSigner 作为交易发起者
            // 交易的 msg.sender 是 secondAccount 地址
            // 适用于需要特定账户执行操作的场景
            // await auction.bidToken(tokenAmount):
            // 使用默认签名者(通常是第一个账户)作为交易发起者
            // 交易的 msg.sender 是 firstAccount 地址
            // 适用于使用默认账户执行操作的场景

            // 获取签名者对象
            const [firstAccountSigner, secondAccountSigner] = await ethers.getSigners();
            // 使用 secondAccountSigner 调用 bidToken
            const tx = await auction.connect(secondAccountSigner).bidToken(tokenAmount);

            const blockNumber = await ethers.provider.getBlockNumber();
            const block = await ethers.provider.getBlock(blockNumber);

            await expect(tx)
                .to.emit(auction, "HighestBidIncreased")
                .withArgs([
                    secondAccount,
                    tokenAmount,
                    false,
                    block.timestamp
                ]);
        })


        it("test auction endAuction", async function () {

            // 增加时间，使拍卖结束
            await helpers.time.increase(3600); // 增加 1 小时，确保超过拍卖持续时间
            await helpers.mine(); // 挖掘新区块以确保时间更新

            const tx = await auction.endAuction();
            const blockNumber = await ethers.provider.getBlockNumber();
            const block = await ethers.provider.getBlock(blockNumber);

            // 如果没有出价，highestBidder 会是 address(0)
            await expect(tx)
                .to.emit(auction, "AuctionEnded")
                .withArgs([
                    ethers.ZeroAddress, // 没有出价时 highestBidder 是零地址
                    0,                  // 没有出价时金额为 0
                    false,              // isEthBid
                    block.timestamp
                ]);
        })

        it("test auction withdraw", async function () {

            // 获取签名者对象
            const [firstAccountSigner, secondAccountSigner] = await ethers.getSigners();

            await auction.connect(firstAccountSigner).bidEth({value: ethers.parseEther("1")});
            await auction.connect(secondAccountSigner).bidEth({value: ethers.parseEther("2")});


            const tx = await auction.connect(firstAccountSigner).withdraw();
            const blockNumber = await ethers.provider.getBlockNumber();
            const block = await ethers.provider.getBlock(blockNumber);

            // 如果没有出价，highestBidder 会是 address(0)
            await expect(tx)
                .to.emit(auction, "Withdrawal")
                .withArgs([
                    firstAccountSigner,
                    ethers.parseEther("1"),                  // 没有出价时金额为 0
                    true,              // isEthBid
                    block.timestamp
                ]);
        })


        /*it("Should create auction successfully", async function () {

            // 获取签名者对象
            const [firstAccountSigner, secondAccountSigner] = await ethers.getSigners();

            // 因为 NFT 是铸造给 secondAccount 的，所以需要用 secondAccountSigner 来授权
            await nft.connect(secondAccountSigner).approve(auctionFactory.target, 0);


            // 如果需要 secondAccount 作为卖家，则需要先将 NFT 转移给它
            // 或者直接使用 firstAccount 作为卖家创建拍卖
            // 创建拍卖
            const tx = await auctionFactory.connect(secondAccountSigner).createAuction(
                nft.target,
                0, // tokenId
                ethers.parseEther("1"), // starting price
                3600, // 1 hour
                "0x51491557b8c812165985155d50381557b8c81216",
                "0xa51614D51e6AC66fB7AA5a4Ff9Ed57aC4431a1D0"
            );


            const receipt = await tx.wait();


            // 调试信息：打印所有事件
            // console.log("All events:", receipt.events);
            // console.log("All logs:", receipt.logs);
            // 灵活的事件查找方式
            const auctionCreatedEvent = receipt.events?.find(e => e.event === "AuctionCreated") ||
                receipt.logs?.find(log => {
                    try {
                        const parsedLog = auctionFactory.interface.parseLog(log);
                        return parsedLog.name === "AuctionCreated";
                    } catch {
                        return false;
                    }
                });

            expect(auctionCreatedEvent).to.not.be.undefined;

        });*/


    });