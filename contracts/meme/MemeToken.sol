// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Burnable} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

contract MemeToken is ERC20, ERC20Burnable, Ownable {

    using Math for uint256;

    //代币税功能:交易税
    uint256 public  transactionTaxRate = 5;
    uint256 public constant TAX_DENOMINATOR = 1000;

    address public  transactionTaxReceiver;
    mapping(address => bool) public excludedTransactionTax;

    //限制交易功能:日交易限制
    mapping(address => uint256) public dailyTransactionCount;
    mapping(address => uint256) public lastTransactionDay;
    uint256 public maxTransactionAmount;
    uint256 public maxDayTransactionCount = 5;

    //代币税功能:流动性税
    mapping(address => uint256) public liquidityProviderRewards;
    uint256 public liquidityPoolTaxRate = 5;

    event LiquidityAdded(address indexed provider, uint256 tokenAmount, uint256 ethAmount);
    event LiquidityRemoved(address indexed provider, uint256 tokenAmount, uint256 ethAmount);
    event RewardClaimed(address indexed provider, uint256 amount);


    constructor(string memory name, string memory symbol) ERC20(name, symbol) Ownable (msg.sender){
        _mint(msg.sender, 1000000 * 10 ** decimals());
        transactionTaxReceiver = msg.sender;
        (, maxTransactionAmount) = Math.tryDiv(totalSupply(), 100);
        excludedTransactionTax[msg.sender] = true;
        excludedTransactionTax[address(this)] = true;
    }

    //新的税率 (单位: 千分之一)
    function setTransactionTaxRate(uint256 _transactionTaxRate) external onlyOwner {
        require(_transactionTaxRate <= 50, "Tax rate too high");
        transactionTaxRate = _transactionTaxRate;
    }

    function setTransactionTaxReceiver(address _transactionTaxReceiver) external onlyOwner {
        require(_transactionTaxReceiver != address(0), "Invalid Transaction Tax Receiver");
        transactionTaxReceiver = _transactionTaxReceiver;
    }

    function setExcludedTransactionTax(address account, bool excluded) external onlyOwner {
        excludedTransactionTax[account] = excluded;
    }


    function setMaxTransactionAmount(uint256 _maxTransactionAmount) external onlyOwner {
        maxTransactionAmount = _maxTransactionAmount;
    }

    function setMaxDailyTransactions(uint256 _maxDayTransactionCount) external onlyOwner {
        maxDayTransactionCount = _maxDayTransactionCount;
    }

    //设置添加流动性 利率
    function setLiquidityPoolTaxRate(uint256 _liquidityPoolTaxRate) external onlyOwner {
        require(_liquidityPoolTaxRate <= 100, "Tax rate too high");
        liquidityPoolTaxRate = _liquidityPoolTaxRate;
    }
    //添加流动性 流动的奖励
    function addLiquidityPool() external payable {
        require(msg.value > 0, "Invalid amount");
        uint256 reward = Math.mulDiv(msg.value, liquidityPoolTaxRate, TAX_DENOMINATOR);
        liquidityProviderRewards[msg.sender] += reward;
        emit LiquidityAdded(msg.sender, 0, msg.value);
    }
    //提取流动性奖励
    function withdrawLiquidityPoolReward() external {
        uint256 reward = liquidityProviderRewards[msg.sender];
        liquidityProviderRewards[msg.sender] = 0;
        _transfer(address(this), msg.sender, reward);
        emit RewardClaimed(msg.sender, reward);
    }
    //移除流动性
    function removeLiquidityPool(uint256 _tokenAmount) external {
        emit LiquidityRemoved(msg.sender, _tokenAmount, 0);
    }

    function _update(address from, address to, uint256 value) internal override {

        // 如果是从零地址铸造，直接跳过交易限制和税费检查
        if (from == address(0)) {
            super._update(from, to, value);
            _updateTransactionCount(to); // 更新接收方的交易计数
            return;
        }

        //1 检查建议限制
        _checkTransactionLimit(from, value);

        //2 检查代币税
        if (!excludedTransactionTax[from] && !excludedTransactionTax[to] && transactionTaxRate > 0) {
            uint256 taxAmount = Math.mulDiv(value, transactionTaxRate, TAX_DENOMINATOR);
            uint256 transferAmount = value - taxAmount;
            // 再处理实际转账部分
            super._update(from, to, transferAmount);
        } else {//免税
            super._update(from, to, value);
        }

        //3 更新日交易计数
        _updateTransactionCount(from);

    }

    function _checkTransactionLimit(address from, uint256 value) internal {
        require(value <= maxTransactionAmount, "transaction amount exceeds limit");

        uint256 currentDay = block.timestamp / 1  days;
        if (currentDay > lastTransactionDay[from]) {
            dailyTransactionCount[from] = 0;
            lastTransactionDay[from] = currentDay;
        }
        require(dailyTransactionCount[from] <= maxDayTransactionCount, "daily transaction count limit exceeded");

    }

    function _updateTransactionCount(address from) internal {
        dailyTransactionCount[from] += 1;
    }

}
