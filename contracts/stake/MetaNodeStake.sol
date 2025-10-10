// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

import {IMetaNodeStake} from "./interfaces/IMetaNodeStake.sol";

contract MetaNodeStake is Initializable, PausableUpgradeable, AccessControlUpgradeable, UUPSUpgradeable, IMetaNodeStake {

    // Libraries
    using SafeERC20 for IERC20;
    using Address for address;
    using Math for uint256;

    //RBAC
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");

    uint256 public constant ETH_POOL_PID = 0;

    //奖励代币资产
    IERC20 public metaNodeERC20;
    uint256 public startBlock;
    uint256 public endBlock;
    uint256 public metaNodeRewardPerBlock;

    // 暂停withdraw
    bool public withdrawPaused;
    // 暂停claim
    bool public claimPaused;

    //所有池子的总权重
    uint256 public totalPoolWeight;
    Pool[] public pools;

    //pid => userAddress => UserInfo
    mapping(uint256 => mapping(address => User)) public user;

    //合约事件
    event AddPool(address indexed stTokenAddress, uint256 indexed poolWeight, uint256 indexed lastRewardBlock, uint256 minDepositAmount, uint256 unstakeLockedBlocks);

    event UpdatePoolInfo(uint256 indexed poolId, uint256 indexed minDepositAmount, uint256 indexed unstakeLockedBlocks);

    event SetPoolWeight(uint256 indexed poolId, uint256 indexed poolWeight, uint256 totalPoolWeight);

    event UpdatePool(uint256 indexed poolId, uint256 indexed lastRewardBlock, uint256 totalMetaNode);

    event Deposit(address indexed user, uint256 indexed poolId, uint256 amount);

    event RequestUnStake(address indexed user, uint256 indexed poolId, uint256 amount);

    event Withdraw(address indexed user, uint256 indexed poolId, uint256 amount, uint256 indexed blockNumber);

    event Claim(address indexed user, uint256 indexed poolId, uint256 MetaNodeReward);

    //合约初始化
    function initialize(IERC20 _metaNodeERC20, uint256 _startBlock, uint256 _endBlock, uint256 _metaNodeRewardPerBlock) public initializer {

        require(_startBlock <= _endBlock && _metaNodeRewardPerBlock > 0, "MetaNode: startBlock must be less than endBlock");

        __Pausable_init();
        __AccessControl_init();
        __UUPSUpgradeable_init();

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);
        _grantRole(UPGRADER_ROLE, msg.sender);

        // 奖励代币资产设置
        setMetaNodeERC20(_metaNodeERC20);

        startBlock = _startBlock;
        endBlock = _endBlock;
        metaNodeRewardPerBlock = _metaNodeRewardPerBlock;
    }

    //修饰函数
    modifier checkPid(uint256 _pid) {
        require(_pid < pools.length, "invalid pid");
        _;
    }

    modifier whenNotClaimPaused() {
        require(!claimPaused, "claim is paused");
        _;
    }

    modifier whenNotWithdrawPaused() {
        require(!withdrawPaused, "withdraw is paused");
        _;
    }

    function setMetaNodeERC20(IERC20 _metaNodeERC20) public onlyRole(ADMIN_ROLE) {
        metaNodeERC20 = _metaNodeERC20;
    }

    function setStartBlock(uint256 _startBlock) public onlyRole(ADMIN_ROLE) {
        require(endBlock < _startBlock, "startBlock must be greater than endBlock");
        startBlock = _startBlock;
    }

    function setEndBlock(uint256 _endBlock) public onlyRole(ADMIN_ROLE) {
        require(startBlock < _endBlock, "endBlock must be greater than startBlock");
        endBlock = _endBlock;
    }

    function setMetaNodeRewardPerBlock(uint256 _metaNodeRewardPerBlock) public onlyRole(ADMIN_ROLE) {
        require(_metaNodeRewardPerBlock > 0, "metaNodeRewardPerBlock must be greater than 0");
        metaNodeRewardPerBlock = _metaNodeRewardPerBlock;
    }

    function pauseWithdraw() public onlyRole(ADMIN_ROLE) {
        require(!withdrawPaused, "withdraw is already paused");
        withdrawPaused = true;
    }

    function unpauseWithdraw() public onlyRole(ADMIN_ROLE) {
        require(withdrawPaused, "withdraw is already unpaused");
        withdrawPaused = false;
    }

    function pauseClaim() public onlyRole(ADMIN_ROLE) {
        require(!claimPaused, "claim is already paused");
        claimPaused = true;
    }

    function unpauseClaim() public onlyRole(ADMIN_ROLE) {
        require(claimPaused, "claim is already unpaused");
        claimPaused = false;
    }

    // UUPS升级
    function _authorizeUpgrade(address newImplementation) internal override onlyRole(UPGRADER_ROLE) {

    }

    //添加质押代币到池子
    function addPool(address _stakeTokenAddress, uint256 _poolWeight, uint256 _minimumDepositStakeAmount, uint256 _unLockStakeBlocks, bool _withUpdate) public onlyRole(ADMIN_ROLE) {
        if (pools.length > 0) {
            require(_stakeTokenAddress != address(0x0), "invalid staking token address");
        } else {//ETH_POOL
            require(_stakeTokenAddress == address(0x0), "invalid staking token address");
        }

        require(_unLockStakeBlocks > 0, "invalid unLock stake blocks");
        require(block.number < endBlock, "Already ended");

        // 更新所有池子
        if (_withUpdate) {
            massUpdatePools();
        }

        // 计算当前块的奖励  在 startBlock设置时， block.number已经开始挖矿 几个了
        uint256 lastRewardBlock = block.number > startBlock ? block.number : startBlock;
        // 总权重计算
        bool success;
        (success, totalPoolWeight) = totalPoolWeight.tryAdd(_poolWeight);
        require(success, "addPool: totalPoolWeight overflow");

        pools.push(Pool({
            stakeTokenAddress: _stakeTokenAddress,
            poolWeight: _poolWeight,
            stakeTokenAmount: 0,
            accMetaNodePerStake: 0,
            lastRewardBlock: lastRewardBlock,
            minimumDepositStakeAmount: _minimumDepositStakeAmount,
            unLockStakeBlocks: _unLockStakeBlocks
        }));

        emit AddPool(_stakeTokenAddress, _poolWeight, lastRewardBlock, _minimumDepositStakeAmount, _unLockStakeBlocks);

    }

    //修改池子信息: 最小质押金额，锁仓期（锁定多少个block才能开始兑换）
    function updatePool(uint256 _pid, uint256 _minimumDepositStakeAmount, uint256 _unLockStakeBlocks) public onlyRole(ADMIN_ROLE) checkPid(_pid) {
        pools[_pid].minimumDepositStakeAmount = _minimumDepositStakeAmount;
        pools[_pid].unLockStakeBlocks = _unLockStakeBlocks;

        emit UpdatePoolInfo(_pid, _minimumDepositStakeAmount, _unLockStakeBlocks);

    }

    //修改池子权重
    function setPoolWeight(uint256 _pid, uint256 _poolWeight, bool _withUpdate) public onlyRole(ADMIN_ROLE) checkPid(_pid) {
        require(_poolWeight > 0, "invalid pool weight");

        if (_withUpdate) {
            massUpdatePools();
        }

        // 更新总权重
        totalPoolWeight = totalPoolWeight - pools[_pid].poolWeight + _poolWeight;
        pools[_pid].poolWeight = _poolWeight;

        emit SetPoolWeight(_pid, _poolWeight, totalPoolWeight);
    }

    //获取池子数量
    function poolLength() external view returns (uint256) {
        return pools.length;
    }

    //获取 区间区块  奖励 乘数：区间区块数 * 每一个代币奖励的MetaNodeERC20Reward
    function getMultiplier(uint256 _from, uint256 _to) public view returns (uint256 multiplier) {
        require(_from <= _to, "invalid block");
        if (_from < startBlock) {_from = startBlock;}
        if (_to > endBlock) {_to = endBlock;}
        require(_from <= _to, "end block must be greater than start block");
        bool success;
        (success, multiplier) = (_to - _from).tryMul(metaNodeRewardPerBlock);
        require(success, "multiplier overflow");
    }

    //获取用户在具体池子的  待领取的奖励
    function pendingMetaNode(uint256 _pid, address _user) external checkPid(_pid) view returns (uint256) {
        //通过最新区块  获取用户在具体池子  待领取的奖励
        return _pendingMetaNodeByBlockNumber(_pid, _user, block.number);
    }

    //通过最新区块  获取用户在具体池子  待领取的奖励
    function _pendingMetaNodeByBlockNumber(uint256 _pid, address _user, uint256 _blockNumber) internal checkPid(_pid) view returns (uint256) {
        Pool storage pool_ = pools[_pid];
        User storage user_ = user[_pid][_user];
        // 获取池子每份代币的奖励
        uint256 accMetaNodePerST = pool_.accMetaNodePerStake;
        // 获取池子代币供应量
        uint256 stSupply = pool_.stakeTokenAmount;

        // 计算当前池子  每份代币的奖励
        if (_blockNumber > pool_.lastRewardBlock && stSupply != 0) {//池子最近一次计算奖励的块 在_blockNumber块之前
            //计算 区间块 的奖励
            uint256 multiplier = getMultiplier(pool_.lastRewardBlock, _blockNumber);
            //根据池子权重换算 区间块的奖励：区间块的奖励 * 池子权重 / 总权重
            uint256 MetaNodeForPool = Math.mulDiv(multiplier, pool_.poolWeight, totalPoolWeight);


            //池子每份代币的奖励 = 池子每份代币的奖励ori + 池子权重中区间块的奖励 / 池子代币供应量
            accMetaNodePerST = accMetaNodePerST + MetaNodeForPool * (1 ether) / stSupply;
        }

        // 获取用户在池子待领取的奖励: 用户代币数量 * 池子每份代币的奖励 - 用户待领取的奖励 + 用户待领取的奖励(之前待领取)
        return user_.stakeTokenAmount * accMetaNodePerST / (1 ether) - user_.finishedMetaNodeAmount + user_.pendingMetaNodeAmount;
    }

    //获取用户质押的代币数量
    function stakingBalance(uint256 _pid, address _user) external checkPid(_pid) view returns (uint256) {
        return user[_pid][_user].stakeTokenAmount;
    }

    //获取用户待提取的代币数量:要提取的代币数量 , 待提取的代币数量(之前待提取的代币数量)
    function withdrawAmount(uint256 _pid, address _user) public checkPid(_pid) view returns (uint256 _requestAmount, uint256 _pendingWithdrawAmount) {
        User storage user_ = user[_pid][_user];

        for (uint256 i = 0; i < user_.requests.length; i++) {
            // 判断是否可以提取
            if (user_.requests[i].unLockStakeBlocks <= block.number) {
                _pendingWithdrawAmount = _pendingWithdrawAmount + user_.requests[i].amount;
            }
            _requestAmount = _requestAmount + user_.requests[i].amount;
        }

        return (_requestAmount, _pendingWithdrawAmount);
    }

    //批量更新池子（触发条件：【质押，解除质押，结算收益，添加代币到池子（可选），更新池子权重（可选）】）:计算累计奖励，更新池子最近一次计算奖励的块
    function updatePool(uint256 _pid) public checkPid(_pid) {
        Pool storage pool_ = pools[_pid];

        // 池子最近一次计算奖励的块 在当前块之前
        if (block.number <= pool_.lastRewardBlock) {
            return;
        }
        // 根据池子权重 获取池子 里 区间块（可以提取）的代币奖励
        (bool success1, uint256 totalMetaNode) = getMultiplier(pool_.lastRewardBlock, block.number).tryMul(pool_.poolWeight);
        require(success1, "overflow");

        // 根据总权重 换算区间块的代币奖励
        (success1, totalMetaNode) = totalMetaNode.tryDiv(totalPoolWeight);
        require(success1, "overflow");

        uint256 stSupply = pool_.stakeTokenAmount;
        if (stSupply > 0) {//池子代币供应量 > 0
            // 111 根据总权重 得到的 区间块的代币奖励  *   1 ether  /  池子代币供应量
            (bool success2, uint256 totalMetaNode_) = totalMetaNode.tryMul(1 ether);
            require(success2, "overflow");
            (success2, totalMetaNode_) = totalMetaNode_.tryDiv(stSupply);
            require(success2, "overflow");

            // 每个质押代币累积的 RCC 数量 = 池子每份代币的累计值奖励 + 111的结果
            (bool success3, uint256 accMetaNodePerST) = pool_.accMetaNodePerStake.tryAdd(totalMetaNode_);
            require(success3, "overflow");
            pool_.accMetaNodePerStake = accMetaNodePerST;
        }

        // 更新池子最近一次计算奖励的块
        pool_.lastRewardBlock = block.number;

        emit UpdatePool(_pid, pool_.lastRewardBlock, totalMetaNode);
    }

    //批量更新池子
    function massUpdatePools() public {
        uint256 length = pools.length;
        for (uint256 pid = 0; pid < length; pid++) {
            updatePool(pid);
        }
    }

    //质押 ETH本币
    function depositETH() public whenNotPaused() payable {
        Pool storage pool_ = pools[ETH_POOL_PID];
        require(pool_.stakeTokenAddress == address(0x0), "invalid staking token address");

        uint256 _amount = msg.value;
        require(_amount >= pool_.minimumDepositStakeAmount, "deposit amount is too small");

        _deposit(ETH_POOL_PID, _amount);
    }

    //质押 ERC20代币
    function deposit(uint256 _pid, uint256 _amount) public whenNotPaused() checkPid(_pid) {
        require(_pid != 0, "deposit not support ETH staking");
        Pool storage pool_ = pools[_pid];
        require(_amount > pool_.minimumDepositStakeAmount, "deposit amount is too small");

        if (_amount > 0) {
            // erc20代币 转移, erc20代币msg.sende已经有 approve权限了
            IERC20(pool_.stakeTokenAddress).safeTransferFrom(msg.sender, address(this), _amount);
        }

        _deposit(_pid, _amount);
    }

    //质押: 更新池子,更新用户
    function _deposit(uint256 _pid, uint256 _amount) internal {
        Pool storage pool_ = pools[_pid];
        User storage user_ = user[_pid][msg.sender];

        //更新池子：计算累计奖励，更新池子最近一次计算奖励的块
        updatePool(_pid);

        if (user_.stakeTokenAmount > 0) {//计算用户待领取的代币数量
            // uint256 accST = user_.stAmount.mulDiv(pool_.accMetaNodePerST, 1 ether);
            (bool success1, uint256 accST) = user_.stakeTokenAmount.tryMul(pool_.accMetaNodePerStake);
            require(success1, "user stAmount mul accMetaNodePerST overflow");
            (success1, accST) = accST.tryDiv(1 ether);
            require(success1, "accST div 1 ether overflow");

            (bool success2, uint256 pendingMetaNode_) = accST.trySub(user_.finishedMetaNodeAmount);
            require(success2, "accST sub finishedMetaNode overflow");

            if (pendingMetaNode_ > 0) {
                (bool success3, uint256 _pendingMetaNode) = user_.pendingMetaNodeAmount.tryAdd(pendingMetaNode_);
                require(success3, "user pendingMetaNode overflow");
                user_.pendingMetaNodeAmount = _pendingMetaNode;
            }
        }

        if (_amount > 0) {//更新用户 质押代币数量
            (bool success4, uint256 stAmount) = user_.stakeTokenAmount.tryAdd(_amount);
            require(success4, "user stAmount overflow");
            user_.stakeTokenAmount = stAmount;
        }

        ////更新池子：池中代币供应量
        (bool success5, uint256 stTokenAmount) = pool_.stakeTokenAmount.tryAdd(_amount);
        require(success5, "pool stTokenAmount overflow");
        pool_.stakeTokenAmount = stTokenAmount;

        //更新用户:用户已领取的代币数量
        // user_.finishedMetaNode = user_.stAmount.mulDiv(pool_.accMetaNodePerST, 1 ether);
        (bool success6, uint256 finishedMetaNode) = user_.stakeTokenAmount.tryMul(pool_.accMetaNodePerStake);
        require(success6, "user stAmount mul accMetaNodePerST overflow");
        (success6, finishedMetaNode) = finishedMetaNode.tryDiv(1 ether);
        require(success6, "finishedMetaNode div 1 ether overflow");
        user_.finishedMetaNodeAmount = finishedMetaNode;

        emit Deposit(msg.sender, _pid, _amount);
    }

    //用户解除 代币质押：whenNotWithdrawPaused()是对 whenNotPaused()扩展
    function unStake(uint256 _pid, uint256 _amount) public whenNotPaused() checkPid(_pid) whenNotWithdrawPaused() {
        Pool storage pool_ = pools[_pid];
        User storage user_ = user[_pid][msg.sender];

        require(user_.stakeTokenAmount >= _amount, "Not enough staking token balance");

        // 更新池子:计算累计奖励，更新池子最近一次计算奖励的块
        updatePool(_pid);

        //计算用户 待领取的代币数量
        uint256 pendingMetaNode_ = user_.stakeTokenAmount * pool_.accMetaNodePerStake / (1 ether) - user_.finishedMetaNodeAmount;
        if (pendingMetaNode_ > 0) {
            user_.pendingMetaNodeAmount = user_.pendingMetaNodeAmount + pendingMetaNode_;
        }

        if (_amount > 0) {
            // 更新用户的代币数量
            user_.stakeTokenAmount = user_.stakeTokenAmount - _amount;
            // 添加解除代币请求：解锁块 = 当前块 + 解锁块数
            user_.requests.push(UnStakeRequest({
                amount: _amount,
                unLockStakeBlocks: block.number + pool_.unLockStakeBlocks
            }));
        }

        // 更新池子代币供应量
        pool_.stakeTokenAmount = pool_.stakeTokenAmount - _amount;
        // 更新用户 已经领取的代币数量
        user_.finishedMetaNodeAmount = user_.stakeTokenAmount * pool_.accMetaNodePerStake / (1 ether);

        emit RequestUnStake(msg.sender, _pid, _amount);
    }

    //用户提取代币：用户  unStake解除质押 请求后，用户可以提取代币
    function withdraw(uint256 _pid) public whenNotPaused() checkPid(_pid) whenNotWithdrawPaused() {
        Pool storage pool_ = pools[_pid];
        User storage user_ = user[_pid][msg.sender];

        uint256 pendingWithdraw_;
        uint256 popNum_;
        for (uint256 i = 0; i < user_.requests.length; i++) {
            //请求时按照顺序存入的，如果请求块数大于当前块数，则跳出循环
            if (user_.requests[i].unLockStakeBlocks > block.number) {
                break;
            }
            pendingWithdraw_ = pendingWithdraw_ + user_.requests[i].amount;
            popNum_++;
        }

        //删除用户请求:将requests中的数据进行 整理，将剩余的元素前移
        for (uint256 i = 0; i < user_.requests.length - popNum_; i++) {
            user_.requests[i] = user_.requests[i + popNum_];
        }

        //清理删除的元素：pop从数组的最后一个元素开始
        for (uint256 i = 0; i < popNum_; i++) {
            user_.requests.pop();
        }

        if (pendingWithdraw_ > 0) {
            if (pool_.stakeTokenAddress == address(0x0)) {
                _safeETHTransfer(msg.sender, pendingWithdraw_);
            } else {//原始代币返还
                IERC20(pool_.stakeTokenAddress).safeTransfer(msg.sender, pendingWithdraw_);
            }
        }

        emit Withdraw(msg.sender, _pid, pendingWithdraw_, block.number);
    }

    //给用户 结算收益
    function claim(uint256 _pid) public whenNotPaused() checkPid(_pid) whenNotClaimPaused() {
        Pool storage pool_ = pools[_pid];
        User storage user_ = user[_pid][msg.sender];

        //更新池子:计算累计奖励，更新池子最近一次计算奖励的块
        updatePool(_pid);

        //计算用户 待领取的代币数量
        uint256 pendingMetaNode_ = user_.stakeTokenAmount * pool_.accMetaNodePerStake / (1 ether) - user_.finishedMetaNodeAmount + user_.pendingMetaNodeAmount;

        if (pendingMetaNode_ > 0) {
            user_.pendingMetaNodeAmount = 0;//必须先置0！！！！！！
            //给用户 MetaNodeERC20 代币 计算收益
            _safeMetaNodeTransfer(msg.sender, pendingMetaNode_);
        }

        //更新用户 已经领取的代币数量
        user_.finishedMetaNodeAmount = user_.stakeTokenAmount * pool_.accMetaNodePerStake / (1 ether);

        emit Claim(msg.sender, _pid, pendingMetaNode_);
    }

    // 结算MetaNodeERC20代币收益  转账
    function _safeMetaNodeTransfer(address _to, uint256 _amount) internal {
        // 合约账户拥有的MetaNodeERC20代币余额
        uint256 MetaNodeBal = metaNodeERC20.balanceOf(address(this));
        if (_amount > MetaNodeBal) {
            metaNodeERC20.transfer(_to, MetaNodeBal);
        } else {
            metaNodeERC20.transfer(_to, _amount);
        }
    }

    // ETH代币安全转账
    function _safeETHTransfer(address _to, uint256 _amount) internal {
        (bool success, bytes memory data) = address(_to).call{value: _amount}("");
        require(success, "ETH transfer call failed");
        if (data.length > 0) {
            require(abi.decode(data, (bool)), "ETH transfer operation did not succeed");
        }
    }


}
