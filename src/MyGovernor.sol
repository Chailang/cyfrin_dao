// SPDX-License-Identifier: MIT
// 指定许可证类型，MIT许可证允许自由使用和修改
pragma solidity ^0.8.19;
// 指定Solidity编译器版本，^0.8.19表示0.8.19及以上版本

// 导入OpenZeppelin治理合约的核心组件
import {Governor} from "@openzeppelin/contracts/governance/Governor.sol";
// 基础治理合约，提供提案创建、投票、执行等核心功能

import {GovernorSettings} from "@openzeppelin/contracts/governance/extensions/GovernorSettings.sol";
// 治理设置扩展，允许配置投票延迟、投票周期、提案门槛等参数

import {GovernorCountingSimple} from "@openzeppelin/contracts/governance/extensions/GovernorCountingSimple.sol";
// 简单投票计数扩展，实现支持/反对/弃权的三选一投票机制

import {GovernorVotes} from "@openzeppelin/contracts/governance/extensions/GovernorVotes.sol";
// 投票扩展，将治理与代币投票权绑定，代币持有者可以参与治理

import {GovernorVotesQuorumFraction} from
    "@openzeppelin/contracts/governance/extensions/GovernorVotesQuorumFraction.sol";
// 法定人数扩展，基于代币总供应量的百分比设置法定人数要求

import {GovernorTimelockControl} from "@openzeppelin/contracts/governance/extensions/GovernorTimelockControl.sol";
// 时间锁控制扩展，为提案执行添加时间延迟，提高安全性

import {TimelockController} from "@openzeppelin/contracts/governance/TimelockController.sol";
// 时间锁控制器，管理提案的执行时间延迟

// 导入接口定义
import {IVotes} from "@openzeppelin/contracts/governance/utils/IVotes.sol";
// 投票接口，定义代币投票功能的标准接口

import {IGovernor} from "@openzeppelin/contracts/governance/IGovernor.sol";
// 治理接口，定义治理合约的标准接口

// 定义MyGovernor合约，继承多个治理扩展
contract MyGovernor is
    Governor,                    // 基础治理合约
    GovernorSettings,           // 治理参数设置
    GovernorCountingSimple,     // 简单投票计数
    GovernorVotes,              // 代币投票功能
    GovernorVotesQuorumFraction, // 法定人数管理
    GovernorTimelockControl     // 时间锁控制
{
    // 构造函数：初始化治理合约
    constructor(IVotes _token, TimelockController _timelock)
        Governor("MyGovernor")                    // 调用基础Governor构造函数，设置治理名称
        GovernorSettings(1, /* 1 block */ 50400, /* 1 week */ 0)  // 设置治理参数
        // 参数说明：
        // 1: 投票延迟，提案创建后需要等待1个区块才能开始投票
        // 50400: 投票周期，约1周时间（假设12秒/区块）
        // 0: 提案门槛，任何人都可以创建提案（0表示无门槛）
        GovernorVotes(_token)                     // 绑定投票代币
        GovernorVotesQuorumFraction(4)            // 设置法定人数为4%
        // 4%表示需要总供应量的4%参与投票才能通过提案
        GovernorTimelockControl(_timelock)        // 绑定时间锁控制器
    {}

    // 以下函数是Solidity要求必须重写的函数，用于解决多重继承中的函数冲突

    // 获取投票延迟时间
    function votingDelay() public view override(Governor, GovernorSettings) returns (uint256) {
        // 返回提案创建后需要等待的区块数才能开始投票
        // 这里返回1，表示需要等待1个区块
        return super.votingDelay();
    }

    // 获取投票周期长度
    function votingPeriod() public view override(Governor, GovernorSettings) returns (uint256) {
        // 返回投票持续时间的区块数
        // 这里返回50400，约等于1周时间
        return super.votingPeriod();
    }

    // 计算指定区块的法定人数要求
    function quorum(uint256 blockNumber)
        public
        view
        override(Governor, GovernorVotesQuorumFraction)
        returns (uint256)
    {
        // 返回指定区块号时需要的法定人数
        // 法定人数 = 总供应量 * 4% (在构造函数中设置)
        // 用于确保有足够的社区参与度
        return super.quorum(blockNumber);
    }

    // 获取提案的当前状态
    function state(uint256 proposalId)
        public
        view
        override(Governor, GovernorTimelockControl)
        returns (ProposalState)
    {
        // 返回提案的当前状态，可能的状态包括：
        // Pending: 等待投票开始
        // Active: 投票进行中
        // Canceled: 已取消
        // Defeated: 投票失败
        // Succeeded: 投票成功
        // Queued: 排队等待执行
        // Expired: 已过期
        // Executed: 已执行
        return super.state(proposalId);
    }

    // 创建新的治理提案
    function propose(
        address[] memory targets,    // 目标合约地址数组
        uint256[] memory values,     // 发送的ETH数量数组
        bytes[] memory calldatas,    // 调用数据数组
        string memory description    // 提案描述
    ) public override(Governor) returns (uint256) {
        // 创建提案并返回提案ID
        // 任何人都可以创建提案（因为提案门槛设置为0）
        // 提案包含要执行的操作列表
        return super.propose(targets, values, calldatas, description);
    }

    // 获取创建提案的门槛要求
    function proposalThreshold() public view override(Governor, GovernorSettings) returns (uint256) {
        // 返回创建提案需要的最小代币数量
        // 这里返回0，表示任何人都可以创建提案
        return super.proposalThreshold();
    }


    // 取消提案的内部函数
    function _cancel(
        address[] memory targets,    // 目标合约地址数组
        uint256[] memory values,     // 发送的ETH数量数组
        bytes[] memory calldatas,    // 调用数据数组
        bytes32 descriptionHash      // 提案描述的哈希值
    ) internal override(Governor, GovernorTimelockControl) returns (uint256) {
        // 取消提案并返回提案ID
        // 只有提案创建者或管理员可以取消提案
        // 取消后的提案无法再被投票或执行
        return super._cancel(targets, values, calldatas, descriptionHash);
    }

    // 获取执行器地址
    function _executor() internal view override(Governor, GovernorTimelockControl) returns (address) {
        // 返回负责执行提案的地址
        // 在时间锁控制模式下，执行器是时间锁控制器
        // 时间锁控制器会延迟执行提案，提高安全性
        return super._executor();
    }

    // 检查是否支持指定的接口
    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(Governor)
        returns (bool)
    {
        // 检查合约是否支持指定的接口ID
        // 用于ERC165标准兼容性检查
        // 返回true表示支持该接口
        return super.supportsInterface(interfaceId);
    }

    // 以下函数是时间锁控制相关的必要重写函数

    // 执行提案操作
    function _executeOperations(
        uint256 proposalId,          // 提案ID
        address[] memory targets,    // 目标合约地址数组
        uint256[] memory values,     // 发送的ETH数量数组
        bytes[] memory calldatas,    // 调用数据数组
        bytes32 descriptionHash      // 提案描述的哈希值
    ) internal override(Governor, GovernorTimelockControl) {
        // 执行提案中的具体操作
        // 在时间锁控制模式下，这个函数会被时间锁控制器调用
        // 确保提案在时间锁期结束后才执行
        super._executeOperations(proposalId, targets, values, calldatas, descriptionHash);
    }

    // 将提案加入执行队列
    function _queueOperations(
        uint256 proposalId,          // 提案ID
        address[] memory targets,    // 目标合约地址数组
        uint256[] memory values,     // 发送的ETH数量数组
        bytes[] memory calldatas,    // 调用数据数组
        bytes32 descriptionHash      // 提案描述的哈希值
    ) internal override(Governor, GovernorTimelockControl) returns (uint48) {
        // 将提案加入时间锁控制器的执行队列
        // 返回提案在队列中的执行时间戳
        // 提案必须等待时间锁期结束后才能执行
        return super._queueOperations(proposalId, targets, values, calldatas, descriptionHash);
    }

    // 检查提案是否需要排队等待执行
    function proposalNeedsQueuing(uint256 proposalId)
        public
        view
        override(Governor, GovernorTimelockControl)
        returns (bool)
    {
        // 检查指定提案是否需要通过时间锁控制器排队执行
        // 在时间锁控制模式下，所有提案都需要排队
        // 返回true表示需要排队，false表示可以直接执行
        return super.proposalNeedsQueuing(proposalId);
    }
}