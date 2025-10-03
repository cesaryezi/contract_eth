// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Auction} from "./Auction.sol";

contract AuctionV2 is Auction {

    function testHello() public pure returns (string memory) {
        return "Hello, World!";
    }

}
