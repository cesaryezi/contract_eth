// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Initializable} from  "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import {IAuction} from "./interfaces/IAuction.sol";

contract Auction is Initializable, OwnableUpgradeable, UUPSUpgradeable, IAuction {
    // 状态变量
    address public nftContract;
    uint256 public nftTokenId;
    uint256 public startingPrice;
    uint256 public auctionEndTime;
    address public seller;
    bool public ended;

    // 价格预言机
    AggregatorV3Interface internal ethUsdDataFeed;
    mapping(address => AggregatorV3Interface) public tokenDataFeeds;
    address public acceptedToken;

    // 拍卖状态
    address public highestBidder;
    uint256 public highestBid;
    bool public isEthBid;

    mapping(address => uint256) public pendingReturns;

    //事件
    event HighestBidIncreased(Bid _bid);
    event AuctionEnded(Bid _bid);
    event Withdrawal(Bid _bid);

    // 工厂创建拍卖时调用
    /*constructor() {
        _disableInitializers();
    }*/

    // 工厂创建拍卖后 调用initialize实例化
    function initialize(
        address _nftContract,
        uint256 _nftTokenId,
        uint256 _startingPrice,
        uint256 _auctionDuration,
        address _seller,
        address _ethUsdFeed,
        address _acceptedToken,
        address _tokenUsdFeed
    ) public initializer {

        //UUPS升级模式下的初始化函数
        __Ownable_init(_seller);
        __UUPSUpgradeable_init();

        nftContract = _nftContract;
        nftTokenId = _nftTokenId;
        startingPrice = _startingPrice;
        auctionEndTime = block.timestamp + _auctionDuration;
        seller = _seller;

        // 1,ETH价格预言机
        ethUsdDataFeed = AggregatorV3Interface(_ethUsdFeed);

        // 2,代币价格预言机
        acceptedToken = _acceptedToken;
        //address(0) 表示零地址（也称为空地址或无效地址）。
        if (_tokenUsdFeed != address(0) && _acceptedToken != address(0)) {
            tokenDataFeeds[_acceptedToken] = AggregatorV3Interface(_tokenUsdFeed);
        }
    }

    //UUPS升级模式下的授权函数
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    modifier auctionNotEnded() {
        require(!ended, "Auction has ended");
        require(block.timestamp < auctionEndTime, "Auction time has ended");
        _;
    }

    function bidEth() external payable auctionNotEnded {
        require(msg.value >= startingPrice, "Bid must be at least starting price");

        uint256 ethUsdValue = convertEthToUsd(msg.value);
        uint256 currentHighestUsd = getHighestBidInUSD();

        require(ethUsdValue > currentHighestUsd, "Bid is not higher than current highest");

        if (highestBid != 0) {
            pendingReturns[highestBidder] += highestBid;
        }

        highestBidder = msg.sender;
        highestBid = msg.value;
        isEthBid = true;


        emit HighestBidIncreased(Bid(msg.sender, msg.value, true, block.timestamp));
    }

    function bidToken(uint256 tokenAmount) external auctionNotEnded {
        //address(0) 表示零地址（也称为空地址或无效地址）。
        require(acceptedToken != address(0), "No token accepted");
        require(tokenDataFeeds[acceptedToken] != AggregatorV3Interface(address(0)), "No price feed for token");
        require(tokenAmount >= startingPrice, "Bid must be at least starting price");

        // 转移代币
        require(IERC20(acceptedToken).transferFrom(msg.sender, address(this), tokenAmount), "Token transfer failed");

        uint256 tokenUsdValue = convertTokenToUsd(acceptedToken, tokenAmount);
        uint256 currentHighestUsd = getHighestBidInUSD();

        require(tokenUsdValue > currentHighestUsd, "Bid is not higher than current highest");

        if (highestBid != 0) {
            if (isEthBid) {
                pendingReturns[highestBidder] += highestBid;
            } else {
                // 退还之前的代币出价
                require(IERC20(acceptedToken).transfer(highestBidder, highestBid), "Refund failed");
            }
        }

        highestBidder = msg.sender;
        highestBid = tokenAmount;
        isEthBid = false;

        emit HighestBidIncreased(Bid(msg.sender, tokenAmount, false, block.timestamp));
    }

    function endAuction() external {
        require(block.timestamp >= auctionEndTime || msg.sender == seller, "Auction not yet ended");
        require(!ended, "Auction already ended");

        ended = true;
        //address(0) 表示零地址（也称为空地址或无效地址）。
        if (highestBidder != address(0)) {
            // 转移 NFT 给获胜者
            IERC721(nftContract).transferFrom(address(this), highestBidder, nftTokenId);

            // 转移资金给卖家
            if (isEthBid) {
                payable(seller).transfer(highestBid);
            } else {
                require(IERC20(acceptedToken).transfer(seller, highestBid), "Payment transfer failed");
            }
        } else {
            // 无出价，NFT 归还卖家
            IERC721(nftContract).transferFrom(address(this), seller, nftTokenId);
        }


        emit AuctionEnded(Bid(highestBidder, highestBid, isEthBid, block.timestamp));
    }

    function withdraw() external {
        uint256 amount = pendingReturns[msg.sender];
        require(amount > 0, "No funds to withdraw");

        pendingReturns[msg.sender] = 0;

        (bool success,) = payable(msg.sender).call{value: amount}("");
        require(success, "ETH transfer failed");

        emit Withdrawal(Bid(msg.sender, amount, isEthBid, block.timestamp));
    }

    function getHighestBidInUSD() public view returns (uint256) {
        if (highestBid == 0) return 0;

        if (isEthBid) {
            return convertEthToUsd(highestBid);
        } else {
            return convertTokenToUsd(acceptedToken, highestBid);
        }
    }

    function convertEthToUsd(uint256 ethAmount) public view returns (uint256) {
        (, int256 answer, , ,) = ethUsdDataFeed.latestRoundData();
        require(answer > 0, "Invalid ETH price");
        return ethAmount * uint256(answer) / (10 ** 8);//  ETH/USD 精度为8
    }

    function convertTokenToUsd(address token, uint256 tokenAmount) public view returns (uint256) {
        AggregatorV3Interface feed = tokenDataFeeds[token];
        require(address(feed) != address(0), "No price feed for token");

        (, int256 answer, , ,) = feed.latestRoundData();
        require(answer > 0, "Invalid token price");

        return tokenAmount * uint256(answer) / (10 ** 8); // 假定 TOKEN/USD 精度为8
    }
}
