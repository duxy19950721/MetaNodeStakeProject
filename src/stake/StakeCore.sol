// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.0;

import "./StakeStorage.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";

contract StakeCore is 
    StakeStorage,
    PausableUpgradeable
{

    using SafeERC20 for IERC20;

    /**
     * 质押
     * @param poolId 质押池ID
     * @param stAmount 质押金额
     */
    function deposit(
        uint256 poolId, 
        uint256 stAmount
    ) public _checkStakeEndTime(poolId) _checkPoolExists(poolId) whenNotPaused {
        Pool storage pool = pools[poolId];
        User storage user = users[poolId][msg.sender];

        // 校验质押金额是否大于最小要求
        require(stAmount >= pool.minDepositAmount, "st amount not enough");

        // 校验最小金额是否满足
        require(IERC20(pool.stTokenAddress).balanceOf(msg.sender) >= stAmount, "balance not enough");
        
        // 触发用户的奖励结算，然后再算之后本金的奖励
        updateStakeInfo(poolId, msg.sender);

        // 实际转账给当前合约
        IERC20(pool.stTokenAddress).safeTransferFrom(msg.sender, address(this), stAmount);
        
        // 更新本金，stAmount+=
        user.stAmount += stAmount;
        // 更新质押池的总数
        pool.stTokenAmount += stAmount;

        // 更新finishedMetaNode
        user.finishedMetaNode = _calculateFinishedMetaNode(poolId, msg.sender);
    }

    /**
     * 解除质押
     * @param poolId 质押池ID
     * @param stAmount 解质押金额
     */
    function unstake(
        uint256 poolId, 
        uint256 stAmount
    ) public _checkStakeEndTime(poolId) _checkPoolExists(poolId) whenNotPaused {
        Pool storage pool = pools[poolId];
        User storage user = users[poolId][msg.sender];

        // 校验解质押金额是否足够
        require(stAmount <= user.stAmount, "st amount not enough");

        // 触发用户的奖励结算，然后再算之后本金的奖励
        updateStakeInfo(poolId, msg.sender);

        // 更新本金，stAmount+=
        user.stAmount -= stAmount;
        // 更新质押池的总数
        pool.stTokenAmount -= stAmount;

        // 更新finishedMetaNode
        user.finishedMetaNode = _calculateFinishedMetaNode(poolId, msg.sender);

        // 解质押请求加到requests里
        _addUnstakeRequest(poolId, msg.sender, stAmount);
    }

    /**
     * 提现(本金)
     * @param poolId 质押池ID
     */
    function withdraw(uint256 poolId) public _checkPoolExists(poolId) whenNotPaused {
        Pool storage pool = pools[poolId];
        UnStakeRequest[] storage requests = users[poolId][msg.sender].requests;
        require(requests.length > 0, "no unstake request");
        
        // 循环处理请求
        for (uint256 i = requests.length; i > 0; i--) {
            // 未解锁，不处理
            if (requests[i-1].unlockBlock > block.number) {
                continue;
            }

            // 已解锁，转账给用户
            uint256 stAmount = requests[i-1].stAmount;
            IERC20(pool.stTokenAddress).safeTransfer(msg.sender, stAmount);
            
            // 移除这个请求
            requests[i-1] = requests[requests.length - 1];
            requests.pop();
        }
    }

    /**
     * 领取奖励
     * @param poolId 质押池ID
     */
    function claim(uint256 poolId) public _checkPoolExists(poolId) whenNotPaused {
        User storage user = users[poolId][msg.sender];
        Pool storage pool = pools[poolId];
        require(user.pendingMetaNode > 0, "no pending meta node");

        // 把奖励代币 转账给用户
        IERC20(pool.rewardTokenAddress).safeTransfer(msg.sender, user.pendingMetaNode);

        // 清空pendingMetaNode
        user.pendingMetaNode = 0;
    }

    /**
     * 更新用户的质押信息，这里只是惰性结算，其他的质押和解质押单独调用
     * @param poolId 质押池ID
     * @param userAddress 用户地址
     */
    function updateStakeInfo(
        uint256 poolId, 
        address userAddress
    ) private _checkPoolExists(poolId) {
        // 获取质押池和用户信息
        User storage user = users[poolId][userAddress];
        Pool storage pool = pools[poolId];

        // 更新质押池全局信息
        uint256 blocksPassed = block.number - pool.lastRewardBlock;
        uint256 lastAccMetaNodePerST = (blocksPassed * pool.metaNodePerBlock) * pool.poolWeight / totalPoolWeight;
        pool.accMetaNodePerST += (lastAccMetaNodePerST * 1e18);
        pool.lastRewardBlock = block.number;

        // 更新用户的质押信息
        uint256 pendingMetaNode = (user.stAmount * pool.accMetaNodePerST) / 1e18 - user.finishedMetaNode;
        user.pendingMetaNode = pendingMetaNode;

        // 此处不更新finishedMetaNode字段,需要计算好本金后再重新计算这个字段
    }

    /**
     * 触发User的finishedMetaNode值计算
     * @param userAddress 用户地址
     * @return 已分配的 MetaNode 数量
     */
    function _calculateFinishedMetaNode(
        uint256 poolId,
        address userAddress
    ) private view returns (uint256) {
        User storage user = users[poolId][userAddress];
        Pool storage pool = pools[poolId];
        return user.stAmount * pool.accMetaNodePerST;
    }

    /**
     * 解质押后加到request里
     * @param poolId 质押池ID
     * @param userAddress 用户地址
     * @param stAmount 解质押金额
     */
    function _addUnstakeRequest(
        uint256 poolId,
        address userAddress,
        uint256 stAmount
    ) private {
        User storage user = users[poolId][userAddress];
        Pool storage pool = pools[poolId];

        user.requests.push(UnStakeRequest({
            stAmount : stAmount,
            unlockBlock : block.number + pool.unstakeLockedBlocks
        }));
    }

    // ===================== check 、modifier ====================
    // 检查质押活动是否结束，结束则不允许质押
    modifier _checkStakeEndTime(uint256 poolId) {
        Pool storage pool = pools[poolId];
        require(block.timestamp < pool.interestEndTime, "stake has ended");
        _;
    }
}