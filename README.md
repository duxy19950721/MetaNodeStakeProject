# MetaNodeStakeProject

合约实战项目 - 质押挖矿系统

## 项目概述

这是一个基于 ERC20 代币的质押挖矿系统，用户可以质押代币获得奖励。项目采用 UUPS 可升级代理模式，支持多池子管理、解质押冷静期、紧急暂停等功能。

## 技术特点

- **可升级合约**：采用 OpenZeppelin UUPS 代理模式，支持合约逻辑升级
- **多池子支持**：支持创建和管理多个质押池
- **权限控制**：基于 AccessControl 的角色权限管理
- **紧急暂停**：支持熔断机制，紧急情况可暂停所有操作
- **安全转账**：使用 SafeERC20 库确保代币转账安全

## 项目结构

```
contract/
├── erc20/                    # ERC20 代币合约
│   ├── StakeERC20.sol        # 质押代币（用户质押的代币）
│   └── RewardERC20.sol       # 奖励代币（发放给用户的奖励）
│
└── stake/                    # 质押系统合约
    ├── StakeStruct.sol       # 数据结构定义
    ├── StakeStorage.sol      # 存储层（状态变量）
    ├── StakeCore.sol         # 核心业务逻辑
    ├── StakePool.sol         # 池子管理逻辑
    └── StakeMain.sol         # 主合约入口
```

## 合约继承关系

```
StakeStruct.sol (数据结构)
      ↓
StakeStorage.sol (存储变量 + 基础修饰器)
      ↓
StakeCore.sol (核心逻辑: 质押/解质押/提现/领取奖励)
      ↓
StakePool.sol (池子管理: 创建/更新池子)
      ↓
StakeMain.sol (主合约: 初始化 + UUPS升级 + 暂停控制)
```

## 数据结构说明

### Pool（质押池）

| 字段 | 类型 | 说明 |
|------|------|------|
| stTokenAddress | address | 质押代币地址 |
| rewardTokenAddress | address | 奖励代币地址 |
| poolWeight | uint256 | 池子权重（多池时用于分配奖励） |
| lastRewardBlock | uint256 | 最后计算奖励的区块号 |
| accMetaNodePerST | uint256 | 每个质押代币累积的奖励数量 |
| stTokenAmount | uint256 | 池中总质押量 |
| minDepositAmount | uint256 | 最小质押金额 |
| unstakeLockedBlocks | uint256 | 解质押锁定区块数（冷静期） |
| metaNodePerBlock | uint256 | 每区块产生的奖励数量 |
| interestStartTime | uint256 | 算息开始时间 |
| interestEndTime | uint256 | 算息结束时间 |

### User（用户质押信息）

| 字段 | 类型 | 说明 |
|------|------|------|
| stAmount | uint256 | 用户质押的代币数量（本金） |
| finishedMetaNode | uint256 | 已结算的奖励数量（债务） |
| pendingMetaNode | uint256 | 待领取的奖励数量 |
| requests | UnStakeRequest[] | 解质押请求列表 |

### UnStakeRequest（解质押请求）

| 字段 | 类型 | 说明 |
|------|------|------|
| stAmount | uint256 | 解质押数量 |
| unlockBlock | uint256 | 解锁区块号 |

## 核心功能

### 用户功能

| 函数 | 说明 |
|------|------|
| `deposit(poolId, amount)` | 质押代币 |
| `unstake(poolId, amount)` | 申请解质押（进入冷静期） |
| `withdraw(poolId)` | 提取已解锁的本金 |
| `claim(poolId)` | 领取奖励 |

### 管理功能

| 函数 | 权限 | 说明 |
|------|------|------|
| `initialize(...)` | 部署者 | 初始化合约（仅一次） |
| `newPool(...)` | ADMIN_ROLE | 创建新质押池 |
| `updatePool(...)` | ADMIN_ROLE | 更新池子参数 |
| `pause()` | 任意 | 紧急暂停 |
| `unpause()` | 任意 | 取消暂停 |

## 奖励计算逻辑

```
1. 每次用户操作（质押/解质押）时触发结算

2. 更新池子全局累积奖励：
   blocksPassed = 当前区块 - 上次结算区块
   newReward = blocksPassed × metaNodePerBlock × (poolWeight / totalPoolWeight)
   accMetaNodePerST += newReward

3. 计算用户待领取奖励：
   pendingReward = (用户本金 × accMetaNodePerST) - finishedMetaNode
   
4. 更新用户债务（本金变动后）：
   finishedMetaNode = 用户本金 × accMetaNodePerST
```

## 解质押流程

```
1. 用户调用 unstake(poolId, amount)
      ↓
2. 结算当前奖励
      ↓
3. 减少用户本金
      ↓
4. 创建解质押请求，设置解锁区块 = 当前区块 + unstakeLockedBlocks
      ↓
5. 等待冷静期...
      ↓
6. 用户调用 withdraw(poolId)
      ↓
7. 检查解锁区块，已解锁的转账给用户
```

## 部署流程

### 1. 部署 ERC20 代币

```javascript
// 部署质押代币
const StakeToken = await ethers.deployContract("StakeERC20", ["Stake Token", "ST"]);

// 部署奖励代币
const RewardToken = await ethers.deployContract("RewardERC20", ["MetaNode", "MN"]);
```

### 2. 部署质押合约（UUPS 代理）

```javascript
const { upgrades } = require("hardhat");

const StakeMain = await ethers.getContractFactory("StakeMain");

const proxy = await upgrades.deployProxy(
    StakeMain,
    [
        1,                              // poolId
        stakeTokenAddress,              // 质押代币地址
        100,                            // poolWeight
        ethers.parseEther("1"),         // minDepositAmount
        100,                            // unstakeLockedBlocks (约25分钟)
        ethers.parseEther("0.1"),       // metaNodePerBlock
        Math.floor(Date.now()/1000),    // interestStartTime
        Math.floor(Date.now()/1000) + 86400 * 30  // interestEndTime
    ],
    { kind: 'uups' }
);
```

### 3. 升级合约

```javascript
const StakeMainV2 = await ethers.getContractFactory("StakeMainV2");
await upgrades.upgradeProxy(proxyAddress, StakeMainV2);
```

## 安全特性

- **UUPS 升级控制**：只有 `ADMIN_ROLE` 可以升级合约
- **初始化保护**：`initializer` 修饰符确保只能初始化一次
- **暂停机制**：`whenNotPaused` 修饰符保护关键操作
- **SafeERC20**：防止代币转账异常
- **解质押冷静期**：防止闪电贷攻击

## 依赖

```json
{
  "@openzeppelin/contracts": "^5.x",
  "@openzeppelin/contracts-upgradeable": "^5.x",
  "@openzeppelin/hardhat-upgrades": "^3.x"
}
```

## 注意事项

1. **首次初始化**：部署后必须调用 `initialize()` 函数
2. **奖励代币充值**：合约需要有足够的奖励代币用于发放
3. **时间参数**：`interestEndTime` 必须大于当前时间
4. **池子 ID**：必须大于 0 且唯一
5. **升级合约**：升级时要确保存储布局兼容

## License

SEE LICENSE IN LICENSE
