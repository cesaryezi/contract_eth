// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";
import {Auction} from "./Auction.sol";

contract AuctionFactory is Initializable, OwnableUpgradeable, UUPSUpgradeable {
    address public auctionImplementation;
    address public ethUsdFeed;

    mapping(address => address[]) public userAuctions;
    mapping(uint256 => address) public auctionByTokenId;

    event AuctionCreated(
        address indexed auction,
        address indexed nftContract,
        uint256 indexed nftTokenId,
        address seller
    );


   /* constructor() {
        _disableInitializers();
    }*/

    //UUPS升级模式下的初始化函数
    function initialize(address _auctionImplementation, address _ethUsdFeed) public initializer {
        __Ownable_init(msg.sender);
        __UUPSUpgradeable_init();

        auctionImplementation = _auctionImplementation;
        ethUsdFeed = _ethUsdFeed;
    }

    //UUPS升级模式下的授权函数
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    // 创建拍卖
    function createAuction(
        address _nftContract,
        uint256 _nftTokenId,
        uint256 _startingPrice,
        uint256 _auctionDuration,
        address _acceptedToken,
        address _tokenUsdFeed
    ) external returns (address) {
        // 转移 NFT 到工厂合约
        IERC721 nft = IERC721(_nftContract);
        require(nft.ownerOf(_nftTokenId) == msg.sender, "Not owner of NFT");
        nft.transferFrom(msg.sender, address(this), _nftTokenId);

        // 使用克隆模式
        address auction = Clones.clone(auctionImplementation);

        // 部署新的拍卖合约
        //address auction = address(new Auction());

        // 初始化 克隆拍卖合约
        Auction(auction).initialize(
            _nftContract,
            _nftTokenId,
            _startingPrice,
            _auctionDuration,
            msg.sender,
            ethUsdFeed,
            _acceptedToken,
            _tokenUsdFeed
        );

        // 将 NFT 转移到拍卖合约
        nft.transferFrom(address(this), auction, _nftTokenId);

        // 记录拍卖信息
        userAuctions[msg.sender].push(auction);
        auctionByTokenId[_nftTokenId] = auction;

        emit AuctionCreated(auction, _nftContract, _nftTokenId, msg.sender);

        return auction;
    }

    function getUserAuctions(address user) external view returns (address[] memory) {
        return userAuctions[user];
    }
}
