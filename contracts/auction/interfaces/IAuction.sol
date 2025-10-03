// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

interface IAuction {
    struct Bid {
        //竞拍人
        address bidder;
        //竞拍金额
        uint256 amount;
        //竞拍时间
        uint256 timestamp;
    }

    struct AuctionPer {
        // 卖家
        address seller;
        // 拍卖持续时间
        uint256 duration;
        // 起始价格
        uint256 startPrice;
        // 开始时间
        uint256 startTime;
        // 是否结束
        bool ended;
        // 最高出价者
        address highestBidder;
        // 最高价格
        uint256 highestBid;
        // NFT合约地址
        address nftContract;
        // NFT ID
        uint256 tokenId;
        // 参与竞价的资产类型 0x 地址表示eth，其他地址表示erc20
        // 0x0000000000000000000000000000000000000000 表示eth
        address tokenAddress;
    }

    //竞拍
    function bid(uint256 _auctionID, uint256 _amount, address _tokenAddress) external payable;


    //结束竞拍
    function endAuction(uint256 _auctionID) external;

}
