// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.0;

import "./StakeStruct.sol";

contract StakeStorage {
     // 质押池全局变量
    mapping(uint256 => Pool) internal pools;
    // 质押池总权重
    uint256 internal totalPoolWeight;
    // 存储所有用户的质押信息
    mapping(uint256 => mapping(address => User)) internal users;
    // 普通管理员角色
    bytes32 internal constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    // 管理员地址，这里设置自己的账户地址，既可以操作池子，又可以升级合约
    address internal constant ADMIN_ADDRESS = 0x143eFD86e90e7464405D92F0d6fcA6c4933a738F;
    // 默认权限管理员地址
    address internal constant DEFAULT_ADMIN_ADDRESS = 0x143eFD86e90e7464405D92F0d6fcA6c4933a738F;
    // 部署者地址，校验StakeMain.sol的初始化方法的
    address internal deployerAddress;


    // ===================== check 、modifier ====================
    // 检查池子ID是否存在
    modifier _checkPoolExists(uint256 poolId) {
        require(pools[poolId].stTokenAddress != address(0), "pool not exists");
        _;
    }
}