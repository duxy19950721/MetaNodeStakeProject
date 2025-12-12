// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import "./StakeStorage.sol";
import "./StakeCore.sol";
import "./StakePool.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

contract StakeMain is 
    StakePool,
    UUPSUpgradeable
{
    constructor() {
        deployerAddress = msg.sender;
    }

    /**
     * 初始化质押池全局变量，且保证只能初始化一次
     * @param stTokenAddress 质押代币的地址
     * @param poolWeight 质押池的权重
     * @param minDepositAmount 最小质押金额
     * @param unstakeLockedBlocks 解除质押的锁定区块数
     * @param metaNodePerBlock 每个区块产生的奖励代币数量
     */
    function initialize(
        uint256 poolId,
        address stTokenAddress,
        uint256 poolWeight,
        uint256 minDepositAmount,
        uint256 unstakeLockedBlocks,
        uint256 metaNodePerBlock,
        uint256 interestStartTime,
        uint256 interestEndTime,
        address rewardTokenAddress
    ) external initializer {
        require(msg.sender == deployerAddress, "not deployer");

        // 初始化
        __UUPSUpgradeable_init();
        __Pausable_init();
        __AccessControl_init();

        // 初始化默认池子，后续可能需要根据实际情况进行修改
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

        // 设置变量池权限相关信息
        // 必须设置默认管理员，不然报错
        _grantRole(DEFAULT_ADMIN_ROLE, DEFAULT_ADMIN_ADDRESS);
        _grantRole(ADMIN_ROLE, ADMIN_ADDRESS);
    }

    /**
     * 紧急暂停（熔断）
     */
    function pause() external onlyRole(ADMIN_ROLE) {
        _pause();
    }

    /**
     * 取消紧急暂停(恢复)
     */
    function unpause() external onlyRole(ADMIN_ROLE) {
        _unpause();
    }

    function _authorizeUpgrade(address newImplementation) internal override view onlyRole(ADMIN_ROLE) {
        
    }
}