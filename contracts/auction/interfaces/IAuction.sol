// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

interface IAuction {
    struct Bid {
        //竞拍人
        address bidder;
        //竞拍金额
        uint256 amount;
        //是否是ETH
        bool isEth;
        //竞拍时间
        uint256 timestamp;
    }

    function initialize(
        address _nftContract,//nft合约
        uint256 _nftTokenId,//nft tokenId
        uint256 _startingPrice,//起拍价
        uint256 _auctionDuration,//竞拍时长
        address _seller,//卖家
        address _ethUsdFeed,//ethUsdFeed
        address _acceptedToken,//接受的代币
        address _tokenUsdFeed//tokenUsdFeed
    ) external;

    //ETH竞拍
    function bidEth() external payable;

    //代币竞拍
    function bidToken(uint256 tokenAmount) external;

    //结束竞拍
    function endAuction() external;

    //提现
    function withdraw() external;
}
