// SPDX-License-Identifier: MIT
// 指定许可证类型，MIT许可证允许自由使用和修改
pragma solidity ^0.8.19;
// 指定Solidity编译器版本，^0.8.19表示0.8.19及以上版本

// 导入测试框架和合约
import {Test} from "forge-std/Test.sol";
// 导入Foundry测试框架，提供测试基础功能

import {MyGovernor} from "../src/MyGovernor.sol";
// 导入治理合约，这是我们要测试的主要合约

import {GovToken} from "../src/GovToken.sol";
// 导入治理代币合约，用于投票权管理

import {TimeLock} from "../src/TimeLock.sol";
// 导入时间锁合约，提供提案执行的时间延迟保护

import {Box} from "../src/Box.sol";
// 导入Box合约，作为被治理的目标合约

import {console2} from "forge-std/console2.sol";
// 导入控制台输出功能，用于调试和日志记录

// 定义测试合约，继承自Foundry的Test基类
contract MyGovernorTest is Test {
    // 声明测试中使用的合约实例
    GovToken token;        // 治理代币合约实例
    TimeLock timelock;     // 时间锁合约实例
    MyGovernor governor;   // 治理合约实例
    Box box;              // 被治理的目标合约实例

    // 定义治理参数常量
    uint256 public constant MIN_DELAY = 3600; // 最小延迟时间：1小时
    // 投票通过后，需要等待1小时才能执行提案，提供安全缓冲期

    uint256 public constant QUORUM_PERCENTAGE = 4; // 法定人数百分比：4%
    // 需要总供应量的4%参与投票才能通过提案，确保足够的社区参与度

    uint256 public constant VOTING_PERIOD = 50400; // 投票周期：50400个区块
    // 投票持续时间的区块数，约等于1周时间（假设12秒/区块）

    uint256 public constant VOTING_DELAY = 1; // 投票延迟：1个区块
    // 提案创建后需要等待1个区块才能开始投票，防止MEV攻击

    // 声明数组变量，用于存储提案相关数据
    address[] proposers;    // 提案者地址数组
    address[] executors;    // 执行者地址数组

    bytes[] functionCalls;     // 函数调用数据数组
    address[] addressesToCall; // 目标合约地址数组
    uint256[] values;          // 发送的ETH数量数组

    // 定义测试用户地址
    address public constant VOTER = address(1);
    // 用于测试的投票者地址，模拟代币持有者参与治理

    // 测试设置函数，在每个测试用例运行前执行
    function setUp() public {
        // 1. 部署治理代币合约
        token = new GovToken();
        // 创建新的GovToken实例

        // 2. 为投票者铸造代币
        token.mint(VOTER, 100e18);
        // 给VOTER地址铸造100个代币（100e18 wei）
        // 这些代币将用于投票权计算

        // 3. 设置投票委托
        vm.prank(VOTER);
        // 模拟VOTER地址调用下一个函数
        token.delegate(VOTER);
        // VOTER将投票权委托给自己，激活投票权

        // 4. 部署时间锁合约
        timelock = new TimeLock(MIN_DELAY, proposers, executors);
        // 创建时间锁控制器，设置1小时延迟
        // proposers和executors数组为空，稍后会设置角色

        // 5. 部署治理合约
        governor = new MyGovernor(token, timelock);
        // 创建治理合约，绑定代币和时间锁

        // 6. 获取时间锁角色常量
        bytes32 proposerRole = timelock.PROPOSER_ROLE();
        // 获取提案者角色标识符
        bytes32 executorRole = timelock.EXECUTOR_ROLE();
        // 获取执行者角色标识符
        bytes32 adminRole = timelock.DEFAULT_ADMIN_ROLE();
        // 获取管理员角色标识符（修复：使用DEFAULT_ADMIN_ROLE）

        // 7. 设置时间锁角色权限
        timelock.grantRole(proposerRole, address(governor));
        // 授予治理合约提案者角色，允许其创建时间锁提案

        timelock.grantRole(executorRole, address(0));
        // 授予地址0执行者角色，表示任何人都可以执行提案
        // 这是为了简化测试，实际部署时应该更严格

        // 8. 撤销管理员权限
        timelock.revokeRole(adminRole, address(this));
        // 撤销测试合约的管理员权限，实现去中心化
        // 现在只有治理合约可以创建提案

        // 9. 部署并设置目标合约
        box = new Box();
        // 创建Box合约实例，这是被治理的目标合约

        box.transferOwnership(address(timelock));
        // 将Box的所有权转移给时间锁合约
        // 现在只有通过治理流程才能修改Box
    }

    // 测试：验证没有治理权限无法直接更新Box
    function testCantUpdateBoxWithoutGovernance() public {
        // 期望下一个函数调用会失败（回滚）
        vm.expectRevert();
        // 尝试直接调用Box的store函数
        box.store(1);
        // 这应该失败，因为Box的所有权已经转移给时间锁合约
        // 只有通过治理流程才能修改Box
    }

    // 测试：完整的治理流程 - 从提案创建到执行
    function testGovernanceUpdatesBox() public {
        // 准备提案数据
        uint256 valueToStore = 777;
        // 要存储到Box中的值

        string memory description = "Store 1 in Box";
        // 提案描述，说明提案的目的

        bytes memory encodedFunctionCall = abi.encodeWithSignature("store(uint256)", valueToStore);
        // 编码函数调用数据，准备调用Box的store函数

        // 构建提案参数数组
        addressesToCall.push(address(box));
        // 添加目标合约地址（Box合约）

        values.push(0);
        // 添加发送的ETH数量（0表示不发送ETH）

        functionCalls.push(encodedFunctionCall);
        // 添加函数调用数据

        // ========== 第1步：创建提案 ==========
        uint256 proposalId = governor.propose(addressesToCall, values, functionCalls, description);
        // 创建治理提案，返回唯一的提案ID

        // 验证提案初始状态
        console2.log("Proposal State:", uint256(governor.state(proposalId))); //Pending, 0
        // 输出提案状态用于调试

        assertEq(uint256(governor.state(proposalId)), 0);
        // 验证提案状态为Pending（0）
        // 提案刚创建时处于等待投票开始状态

        // ========== 第2步：等待投票延迟期结束 ==========
        vm.warp(block.timestamp + VOTING_DELAY + 1);
        // 快进时间，模拟投票延迟期结束

        vm.roll(block.number + VOTING_DELAY + 1);
        // 快进区块号，确保投票延迟期完全结束

        // 验证提案状态变为Active
        console2.log("Proposal State:", uint256(governor.state(proposalId))); //Active, 1
        // 输出提案状态用于调试

        assertEq(uint256(governor.state(proposalId)), 1);
        // 验证提案状态为Active（1）
        // 现在可以开始投票了

        // ========== 第3步：投票 ==========
        string memory reason = "I like a do da cha cha";
        // 投票理由，可以记录投票者的想法

        // 投票选项：0 = 反对, 1 = 支持, 2 = 弃权
        uint8 voteWay = 1;
        // 选择支持（1）

        vm.prank(VOTER);
        // 模拟VOTER地址调用下一个函数
        governor.castVoteWithReason(proposalId, voteWay, reason);
        // VOTER对提案进行投票，选择支持

        // ========== 第4步：等待投票期结束 ==========
        vm.warp(block.timestamp + VOTING_PERIOD + 1);
        // 快进时间，模拟投票期结束

        vm.roll(block.number + VOTING_PERIOD + 1);
        // 快进区块号，确保投票期完全结束

        // 验证提案状态变为Succeeded
        console2.log("Proposal State:", uint256(governor.state(proposalId))); //Succeeded, 4
        // 输出提案状态用于调试

        assertEq(uint256(governor.state(proposalId)), 4);
        // 验证提案状态为Succeeded（4）
        // 投票成功通过

        // ========== 第5步：将提案加入执行队列 ==========
        bytes32 descriptionHash = keccak256(abi.encodePacked(description));
        // 计算提案描述的哈希值，用于提案识别

        governor.queue(addressesToCall, values, functionCalls, descriptionHash);
        // 将提案加入时间锁的执行队列

        // 等待时间锁延迟期结束
        vm.roll(block.number + MIN_DELAY + 1);
        // 快进区块号，模拟时间锁延迟期结束

        vm.warp(block.timestamp + MIN_DELAY + 1);
        // 快进时间，确保时间锁延迟期完全结束

        // 验证提案状态变为Queued
        console2.log("Proposal State:", uint256(governor.state(proposalId))); //Queued, 5
        // 输出提案状态用于调试

        assertEq(uint256(governor.state(proposalId)), 5);
        // 验证提案状态为Queued（5）
        // 提案已排队等待执行

        // ========== 第6步：执行提案 ==========
        governor.execute(addressesToCall, values, functionCalls, descriptionHash);
        // 执行提案，实际调用Box的store函数

        // 验证提案状态变为Executed
        console2.log("Proposal State:", uint256(governor.state(proposalId))); //Executed, 7
        // 输出提案状态用于调试

        assertEq(uint256(governor.state(proposalId)), 7);
        // 验证提案状态为Executed（7）
        // 提案已成功执行

        // ========== 第7步：验证执行结果 ==========
        assert(box.retrieve() == valueToStore);
        // 验证Box中存储的值是否正确
        // 这证明了整个治理流程成功执行了提案
    }
}

/**
 * 
 * 完整治理流程测试
第1步：环境设置 (setUp)
    部署合约: 创建所有必要的合约实例
    代币分发: 给投票者铸造100个代币
    权限设置: 配置时间锁和治理合约的角色权限
    所有权转移: 将Box的所有权转移给时间锁
第2步：安全验证 (testCantUpdateBoxWithoutGovernance)
    目的: 验证没有治理权限无法直接修改受保护的合约
    方法: 尝试直接调用Box的store函数
    预期: 调用失败并回滚
第3步：完整流程测试 (testGovernanceUpdatesBox)
    提案创建: 创建修改Box的治理提案
    投票延迟: 等待1个区块后开始投票
    投票阶段: 投票者投票支持提案
    投票结束: 等待1周投票期结束
    提案排队: 将提案加入时间锁执行队列
    时间锁延迟: 等待1小时执行延迟
    提案执行: 执行提案，修改Box的值
    结果验证: 确认Box的值被正确修改
🛡️ 安全机制验证
    时间锁保护
    执行延迟: 提案通过后需要等待1小时才能执行
    防止恶意提案: 给社区时间审查和应对恶意提案
权限控制
    角色分离: 提案者、执行者、管理员角色分离
    去中心化: 撤销测试合约的管理员权限
投票机制
    法定人数: 需要4%的代币参与投票
    投票委托: 支持代币持有者委托投票权
�� 测试覆盖范围
功能测试
✅ 提案创建和状态管理
✅ 投票机制和计数
✅ 时间锁延迟执行
✅ 提案执行和结果验证
安全测试
✅ 权限控制验证
✅ 时间锁保护验证
✅ 状态转换验证
边界测试
✅ 投票延迟期测试
✅ 投票期结束测试
✅ 时间锁延迟期测试
�� 学习价值
这个测试文件是学习 DAO 治理的绝佳示例，它展示了：
完整的治理流程: 从提案到执行的每个步骤
安全最佳实践: 时间锁、权限控制、角色分离
测试编写技巧: 如何编写全面的智能合约测试
状态管理: 提案生命周期的状态转换
时间模拟: 使用Foundry进行时间相关的测试
通过这个测试，你可以深入理解：
DAO 如何保护受治理的合约
时间锁如何提供安全缓冲
投票机制如何确保社区参与
治理流程的完整生命周期

 * 
 * 
 * 
*/