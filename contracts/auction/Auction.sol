// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Initializable} from  "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
//import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import {IAuction} from "./interfaces/IAuction.sol";

contract Auction is Initializable, /*OwnableUpgradeable, */UUPSUpgradeable, IAuction {


    mapping(address => AggregatorV3Interface) public priceDataFeeds;
    // 状态变量
    mapping(uint256 => AuctionPer) public auctions;
    // 下一个拍卖ID
    uint256 public nextAuctionId;
    // 管理员地址
    address public admin;

    //事件
    event HighestBidIncreased(Bid _bid);
    event AuctionEnded(address _seller, uint256 _amount);


    function initialize() public virtual initializer {
        admin = msg.sender;
    }

    function setDataFeed(address _tokenAddress, address _priceFeed) public {
        priceDataFeeds[_tokenAddress] = AggregatorV3Interface(_priceFeed);
    }

    //UUPS升级模式下的初始化函数
    // 工厂创建拍卖后 调用initialize实例化
    function createAuction(
        address _nftContract,
        uint256 _nftTokenId,
        uint256 _startingPrice,
        uint256 _auctionDuration
    ) public onlyOwner {

        // 检查参数
        require(_auctionDuration >= 10, "Duration must be greater than 10s");
        require(_startingPrice > 0, "Start price must be greater than 0");

        // 转移NFT到合约
        require(IERC721(_nftContract).ownerOf(_nftTokenId) == msg.sender, "You are not the owner of this NFT");
        IERC721(_nftContract).transferFrom(msg.sender, address(this), _nftTokenId);

        auctions[nextAuctionId++] = AuctionPer({
            seller: msg.sender,
            duration: _auctionDuration,
            startPrice: _startingPrice,
            startTime: block.timestamp,
            ended: false,
            highestBidder: address(0),
            highestBid: 0,
            nftContract: _nftContract,
            tokenId: _nftTokenId,
            tokenAddress: address(0)//默认ETH
        });

    }

    //UUPS升级模式下的授权函数
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}


    function getChainlinkDataFeedLatestAnswer(address _tokenAddress) public view returns (int) {
        AggregatorV3Interface dataFeed = priceDataFeeds[_tokenAddress];
        // prettier-ignore
        (
        /* uint80 roundID */,
            int answer,
        /*uint startedAt*/,
        /*uint timeStamp*/,
        /*uint80 answeredInRound*/
        ) = dataFeed.latestRoundData();
        return answer;
    }


    function bid(uint256 _auctionID, uint256 _amount, address _tokenAddress) external payable {

        AuctionPer storage auction = auctions[_auctionID];

        //是否已经结束
        require(
            !auction.ended &&
            auction.startTime + auction.duration > block.timestamp,
            "Auction has ended"
        );
        //是否是最高价自己在出价
//        require(auction.highestBidder != msg.sender, "You are already the highest bidder");
        //ETH和ERC20出价是否高于当前最高价：amount = msg.value
        uint256 payPrice;
        if (_tokenAddress == address(0)) {//ETH
            payPrice = convertUsd(_tokenAddress, msg.value);
        } else {
            payPrice = convertUsd(_tokenAddress, _amount);
        }
        uint256 currentStartPrice = convertUsd(_tokenAddress, auction.startPrice);
        uint256 currentHighest = convertUsd(_tokenAddress, auction.highestBid);
        require(payPrice > currentHighest, "Bid is not higher than current highest");
        require(payPrice >= currentStartPrice, "Bid is not higher than starting price");

        //转移ERC20到拍卖合约
        if (_tokenAddress != address(0)) {
            IERC20(_tokenAddress).transferFrom(msg.sender, address(this), _amount);
        }

        //退还前最高价：eth erc20分别处理
        if (auction.highestBid > 0) {
            if (auction.tokenAddress == address(0)) {//ETH
                payable(auction.highestBidder).transfer(auction.highestBid);
            } else {//ERC20
                IERC20(auction.tokenAddress).transfer(auction.highestBidder, auction.highestBid);
            }
        }

        //存储记录最高价
        auction.tokenAddress = _tokenAddress;
        auction.highestBid = _amount;
        auction.highestBidder = msg.sender;

        emit HighestBidIncreased(Bid(msg.sender, msg.value, block.timestamp));
    }


    function endAuction(uint256 _auctionID) external {

        AuctionPer storage auction = auctions[_auctionID];

        //拍卖是否结束
        require(
            !auction.ended &&
            auction.startTime + auction.duration < block.timestamp,
            "Auction not yet ended"
        );

        //修改标志位
        auction.ended = true;
        //转移NFT给拍卖highestBidder
        //IERC721接口没有 构造函数，但是在使用时必须 使用 IERC721(auction.nftContract)，他里面的方法必须是 external
        IERC721(auction.nftContract).safeTransferFrom(address(this), auction.highestBidder, auction.tokenId);
        //ETH/ERC20转移 到 卖家
        if (auction.tokenAddress == address(0)) {//ETH
            payable(auction.seller).transfer(auction.highestBid);
        } else {//ERC20
            IERC20(auction.tokenAddress).transfer(auction.seller, auction.highestBid);
        }

        emit AuctionEnded(auction.seller, auction.highestBid);
    }

    function convertUsd(address _tokenAddress, uint256 _amount) public view returns (uint256) {
        int256 answer = getChainlinkDataFeedLatestAnswer(_tokenAddress);
        require(answer > 0, "Invalid Data price");
        return _amount * uint256(answer) / (10 ** 8);
    }

    modifier onlyOwner() {
        require(msg.sender == admin, "Only admin can call this function");
        _;
    }

}
