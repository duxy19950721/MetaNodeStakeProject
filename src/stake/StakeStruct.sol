// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.0;

// 质押池全局变量管理
struct Pool {

    // 质押代币的地址，此处可以区分一下：
    // 1. 原生代币(如ETH)：则一般设置为address(0)或者其他特殊标识
    // 2. 其他：也可以是其他的ERC20代币合约地址
    address stTokenAddress;

    // 质押池的权重，影响奖励分配。
    // 只有在多个池子的时候才会计算，本次只有一个池子不需要考虑这个
    uint256 poolWeight;

    // 最后一次计算奖励的区块号
    uint256 lastRewardBlock;
    // 每个质押代币(ETH或者ERC20代币)累积的 MetaNode 数量
    // 简单说你质押了100个ETH，最后奖励公式就是100ETH(数量)✖️ x个MetaNode(代币数量)
    uint256 accMetaNodePerST;

    // 池中的总质押代币量
    uint256 stTokenAmount;

    // 解除质押的锁定区块数，也可以叫做冷静期
    uint256 minDepositAmount;

    // 解除质押的锁定区块数
    uint256 unstakeLockedBlocks;

    // 每个区块产生的奖励代币数量，每次更新池子的时候，都会用当前区块-上次区块
    // 这个时候✖️MetaNodePerBlock就可以得到奖励的MetaNode代币数量，再进行分配
    uint256 metaNodePerBlock;

    // 算息开始时间
    uint256 interestStartTime;

    // 算息结束时间
    uint256 interestEndTime;

    // 奖励的代币合约地址
    address rewardTokenAddress;

}

// 用户质押信息
struct User {

    // 用户质押的代币数量，简单来说就是本金数量，投了多少个ETH或者ERC20代币
    uint256 stAmount;

    // 已分配的 MetaNode 数量，准确来说这个是“债务”，每次计算利息时都要减去的
    // 如果是中途入场的话也会计算个初始的
    uint256 finishedMetaNode;

    // 待领取的 MetaNode 数量，每次加仓减仓都会计算已有奖励并增加到pendingMetaNode里
    uint256 pendingMetaNode;

    // 解质押请求列表，每个请求包含解质押数量和解锁区块
    UnStakeRequest[] requests;
}

// 解质押请求结构体
struct UnStakeRequest {

    // 解质押数量，是本金的数量
    uint256 stAmount;

    // 解锁区块号，需要解质押的时候，会锁定一个区块号，在这个区块号之前，无法解质押
    uint256 unlockBlock;
}