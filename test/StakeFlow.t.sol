// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.0; // 指定编译器版本，并与主合约保持一致

import "lib/forge-std/src/Test.sol"; // 引入 Foundry Test 与 cheatcodes
import "../src/stake/StakeMain.sol"; // 引入被测 StakeMain
import "../src/erc20/StakeERC20.sol"; // 引入质押代币实现
import "../src/erc20/RewardERC20.sol"; // 引入奖励代币实现

contract StakeMainHarness is StakeMain { // 简单 Harness，暴露内部状态
    function exposePool(uint256 poolId) external view returns (Pool memory) { // 读取池子
        return pools[poolId]; // 返回池子结构体
    }

    function exposeUser(uint256 poolId, address account) external view returns (User memory) { // 读取用户质押
        return users[poolId][account]; // 返回用户结构体
    }

    function exposeRequests(uint256 poolId, address account) external view returns (UnStakeRequest[] memory) { // 读取请求队列
        return users[poolId][account].requests; // 返回请求数组
    }

    function exposeTotalWeight() external view returns (uint256) { // 读取总权重
        return totalPoolWeight; // 返回 totalPoolWeight
    }
}

contract StakeFlowTest is Test { // 测试主体
    StakeMainHarness private stake; // 质押合约实例
    StakeERC20 private stakeToken; // 质押代币
    RewardERC20 private rewardToken; // 奖励代币

    address private constant USER = address(0x1234); // 测试用户
    uint256 private constant POOL_ID = 1; // 默认池子
    address private constant ADMIN_ADDRESS = 0x143eFD86e90e7464405D92F0d6fcA6c4933a738F; // 固定管理员

    uint256 private constant POOL_WEIGHT = 100; // 默认权重
    uint256 private constant MIN_DEPOSIT = 1 ether; // 最小质押
    uint256 private constant UNSTAKE_LOCK = 5; // 解质押锁定
    uint256 private constant META_PER_BLOCK = 1 ether; // 区块奖励

    function setUp() public { // 每个测试前重新部署
        stake = new StakeMainHarness(); // 部署合约
        stakeToken = new StakeERC20("Stake Token", "STK"); // 部署质押代币
        rewardToken = new RewardERC20("Reward Token", "RWD"); // 部署奖励代币

        uint256 startTime = block.timestamp; // 算息开始
        uint256 endTime = startTime + 30 days; // 算息结束

        stake.initialize( // 使用真实接口初始化
            POOL_ID,
            address(stakeToken),
            POOL_WEIGHT,
            MIN_DEPOSIT,
            UNSTAKE_LOCK,
            META_PER_BLOCK,
            startTime,
            endTime,
            address(rewardToken)
        );

        deal(address(rewardToken), address(stake), 1_000 ether); // 给合约充值奖励
        deal(address(stakeToken), USER, 1_000 ether); // 给用户充值质押

        vm.prank(USER); // 切换 msg.sender
        stakeToken.approve(address(stake), type(uint256).max); // 统一授权
    }

    function testInitializeSetsPoolState() public { // 检查初始化结果
        Pool memory pool = stake.exposePool(POOL_ID); // 读取池子
        assertEq(pool.stTokenAddress, address(stakeToken)); // 校验代币
        assertEq(pool.poolWeight, POOL_WEIGHT); // 校验权重
        assertEq(pool.minDepositAmount, MIN_DEPOSIT); // 校验最小值
        assertEq(pool.unstakeLockedBlocks, UNSTAKE_LOCK); // 校验锁定
        assertEq(pool.metaNodePerBlock, META_PER_BLOCK); // 校验奖励速率
        assertEq(pool.rewardTokenAddress, address(rewardToken)); // 校验奖励币
        assertEq(stake.exposeTotalWeight(), POOL_WEIGHT); // totalWeight 应更新
    }

    function testInitializeOnlyOnce() public { // 初始化只能一次
        vm.expectRevert(Initializable.InvalidInitialization.selector); // 预期 OZ 错误
        stake.initialize( // 尝试二次初始化
            POOL_ID,
            address(stakeToken),
            POOL_WEIGHT,
            MIN_DEPOSIT,
            UNSTAKE_LOCK,
            META_PER_BLOCK,
            block.timestamp,
            block.timestamp + 30 days,
            address(rewardToken)
        );
    }

    function testInitializeMustBeDeployer() public { // 非部署者禁止初始化
        StakeMainHarness other = new StakeMainHarness(); // 新合约
        vm.expectRevert("not deployer"); // 期待报错
        vm.prank(address(0xBEEF)); // 换成陌生地址
        other.initialize( // 调用 initialize 应失败
            99,
            address(stakeToken),
            POOL_WEIGHT,
            MIN_DEPOSIT,
            UNSTAKE_LOCK,
            META_PER_BLOCK,
            block.timestamp,
            block.timestamp + 1 days,
            address(rewardToken)
        );
    }

    function testAdminCreatesAndUpdatesPool() public { // 管理员建池并更新
        uint256 newPoolId = 2; // 新池 id
        uint256 startTime = block.timestamp + 1; // 自定义开始
        uint256 endTime = startTime + 15 days; // 自定义结束

        vm.prank(ADMIN_ADDRESS); // 切换管理员
        stake.newPool( // 创建新池
            newPoolId,
            address(stakeToken),
            POOL_WEIGHT * 2,
            MIN_DEPOSIT * 2,
            UNSTAKE_LOCK + 2,
            META_PER_BLOCK * 2,
            startTime,
            endTime,
            address(rewardToken)
        );

        Pool memory pool = stake.exposePool(newPoolId); // 读取状态
        assertEq(pool.poolWeight, POOL_WEIGHT * 2); // 新权重

        vm.prank(ADMIN_ADDRESS); // 再次管理员
        stake.updatePool(newPoolId, 500, MIN_DEPOSIT * 3, UNSTAKE_LOCK + 4, META_PER_BLOCK * 3); // 更新参数

        pool = stake.exposePool(newPoolId); // 重新读取
        assertEq(pool.poolWeight, 500); // 权重更新
        assertEq(pool.minDepositAmount, MIN_DEPOSIT * 3); // 最小值更新
        assertEq(pool.unstakeLockedBlocks, UNSTAKE_LOCK + 4); // 锁定更新
        assertEq(pool.metaNodePerBlock, META_PER_BLOCK * 3); // 奖励更新
    }

    function testNewPoolRequiresAdminRole() public { // 非管理员建池应失败
        vm.expectRevert(); // 期待 revert
        vm.prank(USER); // 普通用户
        stake.newPool( // 尝试建池
            99,
            address(stakeToken),
            POOL_WEIGHT,
            MIN_DEPOSIT,
            UNSTAKE_LOCK,
            META_PER_BLOCK,
            block.timestamp + 1,
            block.timestamp + 10 days,
            address(rewardToken)
        );
    }

    function testNewPoolRevertsWhenAlreadyExists() public { // 重复 ID 失败
        vm.prank(ADMIN_ADDRESS); // 管理员
        vm.expectRevert("Pool already exists"); // 指定报错
        stake.newPool(
            POOL_ID,
            address(stakeToken),
            POOL_WEIGHT,
            MIN_DEPOSIT,
            UNSTAKE_LOCK,
            META_PER_BLOCK,
            block.timestamp + 1,
            block.timestamp + 10 days,
            address(rewardToken)
        );
    }

    function testDepositFailsWhenBelowMinimum() public { // 小于最小值
        vm.expectRevert("st amount not enough"); // 抛错
        vm.prank(USER);
        stake.deposit(POOL_ID, MIN_DEPOSIT - 1); // 质押过小
    }

    function testDepositFailsWhenBalanceInsufficient() public { // 余额不足
        deal(address(stakeToken), USER, MIN_DEPOSIT - 1); // 降低余额
        vm.prank(USER);
        stakeToken.approve(address(stake), MIN_DEPOSIT); // 授权足够
        vm.expectRevert("balance not enough");
        vm.prank(USER);
        stake.deposit(POOL_ID, MIN_DEPOSIT);
    }

    function testDepositUpdatesUserAndPoolState() public { // 正常质押
        vm.prank(USER);
        stake.deposit(POOL_ID, 10 ether); // 质押

        User memory userInfo = stake.exposeUser(POOL_ID, USER); // 读取用户
        Pool memory pool = stake.exposePool(POOL_ID); // 读取池子
        assertEq(userInfo.stAmount, 10 ether); // 用户本金更新
        assertEq(pool.stTokenAmount, 10 ether); // 池子本金更新
    }

    function testDepositAccumulatesRewardsAndClaim() public { // 奖励积累 + 领取
        vm.startPrank(USER); // 多次操作
        stake.deposit(POOL_ID, 100 ether); // 首次质押
        vm.roll(block.number + 10); // 快进区块
        vm.warp(block.timestamp + 10); // 快进时间
        stake.deposit(POOL_ID, 50 ether); // 再次质押
        vm.stopPrank();

        User memory snapshot = stake.exposeUser(POOL_ID, USER); // 查看累计奖励
        assertGt(snapshot.pendingMetaNode, 0, "pending reward not accrued"); // 应>0

        uint256 rewardBalanceBefore = rewardToken.balanceOf(USER); // 记录奖励余额
        vm.prank(USER);
        stake.claim(POOL_ID); // 领取（目前存在逻辑缺陷，帮助暴露问题）
        assertEq(rewardToken.balanceOf(USER) - rewardBalanceBefore, snapshot.pendingMetaNode); // 领取量应等于 pending

        User memory afterClaim = stake.exposeUser(POOL_ID, USER); // 再读取
        assertEq(afterClaim.pendingMetaNode, 0, "pending reward not cleared"); // 应清零
    }

    function testClaimShouldAdvanceFinishedMetaNodeButDoesNot() public { // finishedMetaNode 应增加
        vm.prank(USER);
        stake.deposit(POOL_ID, 100 ether);
        vm.roll(block.number + 20);
        vm.warp(block.timestamp + 20);
        vm.prank(USER);
        stake.deposit(POOL_ID, 10 ether);

        User memory beforeClaim = stake.exposeUser(POOL_ID, USER);
        vm.prank(USER);
        stake.claim(POOL_ID);
        User memory afterClaim = stake.exposeUser(POOL_ID, USER);

        assertGt(afterClaim.finishedMetaNode, beforeClaim.finishedMetaNode, "finishedMetaNode not updated after claim");
    }

    function testUnstakeCreatesRequests() public { // 解质押生成请求
        vm.prank(USER);
        stake.deposit(POOL_ID, 300 ether);
        vm.prank(USER);
        stake.unstake(POOL_ID, 120 ether);

        UnStakeRequest[] memory requests = stake.exposeRequests(POOL_ID, USER);
        assertEq(requests.length, 1, "request not created");
        assertEq(requests[0].stAmount, 120 ether);
    }

    function testUnstakeRejectsExcessAmount() public { // 不能超额解质押
        vm.prank(USER);
        stake.deposit(POOL_ID, 50 ether);
        vm.expectRevert("st amount not enough");
        vm.prank(USER);
        stake.unstake(POOL_ID, 60 ether);
    }

    function testWithdrawTransfersFromContractButCurrentlyDoesNot() public { // withdraw 应返还本金（当前实现错误）
        vm.prank(USER);
        stake.deposit(POOL_ID, 100 ether);
        vm.prank(USER);
        stake.unstake(POOL_ID, 100 ether);
        vm.roll(block.number + UNSTAKE_LOCK + 1);

        uint256 beforeBalance = stakeToken.balanceOf(USER);
        vm.prank(USER);
        stake.withdraw(POOL_ID);
        uint256 afterBalance = stakeToken.balanceOf(USER);

        assertGt(afterBalance, beforeBalance, "withdraw should increase user balance but does not");
    }

    function testWithdrawSkipsLockedRequestsButLogicIsReversed() public { // 锁定期内 withdraw 应跳过
        vm.prank(USER);
        stake.deposit(POOL_ID, 200 ether);
        vm.prank(USER);
        stake.unstake(POOL_ID, 50 ether);

        vm.roll(block.number + UNSTAKE_LOCK - 1);

        uint256 beforeBalance = stakeToken.balanceOf(USER);
        vm.prank(USER);
        stake.withdraw(POOL_ID);
        uint256 afterBalance = stakeToken.balanceOf(USER);

        assertEq(afterBalance, beforeBalance, "withdraw should skip locked requests but processed them");
    }

    function testWithdrawRequiresRequest() public { // 没有请求时 withdraw 应失败
        vm.expectRevert("no unstake request");
        vm.prank(USER);
        stake.withdraw(POOL_ID);
    }

    function testPauseBlocksDepositUntilUnpaused() public { // pause/unpause 应限制质押
        vm.prank(ADMIN_ADDRESS);
        stake.pause();

        vm.prank(USER);
        vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);
        stake.deposit(POOL_ID, MIN_DEPOSIT);

        vm.prank(ADMIN_ADDRESS);
        stake.unpause();

        vm.prank(USER);
        stake.deposit(POOL_ID, MIN_DEPOSIT);
    }
}
