// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

interface IMetaNodeStake {
    // 数据结构
    struct Pool {
        //质押资产地址
        address stakeTokenAddress;
        //质押资产数量
        uint256 stakeTokenAmount;
        //最小质押资产数量
        uint256 minimumDepositStakeAmount;
        //解除质押锁仓区块
        uint256 unLockStakeBlocks;

        //质押池权重，分配奖励
        uint256 poolWeight;

        //最后一次计算奖励的区块号:动态更新
        uint256 lastRewardBlock;
        //每个质押代币累积的 RCC 数量:动态更新，动态计算
        uint256 accMetaNodePerStake;
    }

    //解除质押请求
    struct UnStakeRequest {
        //解除质押数量
        uint256 amount;
        //想要解锁的锁仓的 区块
        uint256 unLockStakeBlocks;
    }

    struct User {
        uint256 stakeTokenAmount;
        uint256 finishedMetaNodeAmount;//动态计算
        uint256 pendingMetaNodeAmount;//动态计算
        UnStakeRequest[] requests;
    }
}
