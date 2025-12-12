// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.0;

import "./StakeStruct.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "./StakeStorage.sol";
import "./StakeCore.sol";

contract StakePool is 
    StakeCore,
    AccessControlUpgradeable {

    /**
     * 新建质押池
     * @param poolId 质押池ID
     * @param stTokenAddress 质押代币的地址
     * @param poolWeight 质押池权重
     * @param minDepositAmount 最小质押金额
     * @param unstakeLockedBlocks 解除质押的锁定区块数
     * @param metaNodePerBlock 每个区块产生的奖励代币数量
     */
    function newPool(
        uint256 poolId,
        address stTokenAddress,
        uint256 poolWeight,
        uint256 minDepositAmount,
        uint256 unstakeLockedBlocks,
        uint256 metaNodePerBlock,
        uint256 interestStartTime,
        uint256 interestEndTime,
        address rewardTokenAddress
    ) external onlyRole(ADMIN_ROLE) whenNotPaused {
        // 校验池子id是否已存在
        require(pools[poolId].stTokenAddress == address(0), "Pool already exists");
        // 新建池子
        _createPool(
            poolId, 
            stTokenAddress, 
            poolWeight, 
            minDepositAmount, 
            unstakeLockedBlocks, 
            metaNodePerBlock, 
            interestStartTime, 
            interestEndTime,
            rewardTokenAddress
        );
    }

    /**
     * 更新质押池信息
     * @param poolId 质押池ID
     * @param poolWeight 质押池权重
     * @param minDepositAmount 最小质押金额
     * @param unstakeLockedBlocks 解除质押的锁定区块数
     * @param metaNodePerBlock 每个区块产生的奖励代币数量
     */
    function updatePool(
        uint256 poolId, 
        uint256 poolWeight,
        uint256 minDepositAmount,
        uint256 unstakeLockedBlocks,
        uint256 metaNodePerBlock
    ) external onlyRole(ADMIN_ROLE) _checkPoolExists(poolId) whenNotPaused {
        // 只修改变量，区块数和代币总量等不可以修改
        Pool storage pool = pools[poolId];
        pool.poolWeight = poolWeight;
        pool.minDepositAmount = minDepositAmount;
        pool.unstakeLockedBlocks = unstakeLockedBlocks;
        pool.metaNodePerBlock = metaNodePerBlock;
    }

    /**
     * 初始化一个质押池
     * @param poolId 质押池ID
     * @param stTokenAddress 质押代币的地址
     * @param poolWeight 质押池权重
     * @param minDepositAmount 最小质押金额
     * @param unstakeLockedBlocks 解除质押的锁定区块数
     * @param metaNodePerBlock 每个区块产生的奖励代币数量
     */
    function _createPool(
        uint256 poolId,
        address stTokenAddress,
        uint256 poolWeight,
        uint256 minDepositAmount,
        uint256 unstakeLockedBlocks,
        uint256 metaNodePerBlock,
        uint256 interestStartTime,
        uint256 interestEndTime,
        address rewardTokenAddress
    ) internal {
        // 设置质押池变量，校验入参合法性
        require(poolId > 0, "Pool ID must be greater than 0");
        require(stTokenAddress != address(0), "StToken Address must be not 0");
        require(poolWeight > 0, "Pool Weight must be greater than 0");
        require(minDepositAmount > 0, "Min Deposit Amount must be greater than 0");
        require(unstakeLockedBlocks > 0, "Unstake Locked Blocks must be greater than 0");
        require(metaNodePerBlock > 0, "MetaNode Per Block must be greater than 0");
        require(interestStartTime > 0, "Interest Start Time must be greater than 0");
        require(interestEndTime > block.timestamp, "Interest End Time must be greater than current timestamp");

        Pool storage pool = pools[poolId];

        pool.stTokenAddress = stTokenAddress;
        pool.poolWeight = poolWeight;
        pool.minDepositAmount = minDepositAmount;
        pool.unstakeLockedBlocks = unstakeLockedBlocks;
        pool.metaNodePerBlock = metaNodePerBlock;
        pool.interestStartTime = interestStartTime;
        pool.interestEndTime = interestEndTime;
        pool.rewardTokenAddress = rewardTokenAddress;

        pool.lastRewardBlock = block.number;
        pool.accMetaNodePerST = 0;
        pool.stTokenAmount = 0;

        // 更新池子总权重
        totalPoolWeight += poolWeight;
    }
}