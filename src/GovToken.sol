// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import {ERC20Votes} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";

import {Nonces} from "@openzeppelin/contracts/utils/Nonces.sol";
/**
 * 1. GovToken.sol - 治理代币合约
        核心职责：管理 DAO 的投票权
具体职责：
    ✅ 代币管理：铸造、销毁、转账代币
    ✅ 投票权计算：1个代币 = 1个投票权
    ✅ 委托投票：支持投票权委托给其他地址
    ✅ 历史记录：防止闪电贷攻击的投票快照
    ✅ 权限控制：只有授权地址可以铸造代币
在治理中的作用：
    决定谁可以参与投票
    计算投票权重
    提供投票权的历史记录
 * 
*/

contract GovToken is ERC20, ERC20Permit, ERC20Votes, AccessControl {
    // 定义角色
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");
    
    constructor() ERC20("MyToken", "MTK") ERC20Permit("MyToken") {
        // 将部署者设置为默认管理员
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        // 部署者同时拥有铸币和销毁权限
        _grantRole(MINTER_ROLE, msg.sender);
        _grantRole(BURNER_ROLE, msg.sender);
    }

    // The following functions are overrides required by Solidity.

    function mint(address to, uint256 amount) public onlyRole(MINTER_ROLE) {
        _mint(to, amount);
    }
    
    function burn(address from, uint256 amount) public onlyRole(BURNER_ROLE) {
        _burn(from, amount);
    }
    
    // 允许用户销毁自己的代币
    function burnSelf(uint256 amount) public {
        _burn(msg.sender, amount);
    }
    
    // 角色管理函数
    function grantMinterRole(address account) public onlyRole(DEFAULT_ADMIN_ROLE) {
        _grantRole(MINTER_ROLE, account);
    }
    
    function revokeMinterRole(address account) public onlyRole(DEFAULT_ADMIN_ROLE) {
        _revokeRole(MINTER_ROLE, account);
    }
    
    function grantBurnerRole(address account) public onlyRole(DEFAULT_ADMIN_ROLE) {
        _grantRole(BURNER_ROLE, account);
    }
    
    function revokeBurnerRole(address account) public onlyRole(DEFAULT_ADMIN_ROLE) {
        _revokeRole(BURNER_ROLE, account);
    }


    function nonces(address owner) 
        public 
        view 
        virtual 
        override(ERC20Permit, Nonces) 
        returns (uint256) 
    {
        return super.nonces(owner);
    }
    
    function _update(
        address from,
        address to,
        uint256 amount
    ) internal virtual override(ERC20, ERC20Votes) {
        super._update(from, to, amount);
    }


}
/**
 * GovToken 合约解释
    这个 GovToken 合约是一个治理代币，专门用于去中心化自治组织（DAO）的治理。让我详细解释它的功能：

继承结构：
    ERC20: 基础代币功能（转账、余额查询等）
    ERC20Permit: 支持离线签名授权，用户无需先发送交易就能授权他人使用代币
    ERC20Votes: 投票功能，支持代币持有者参与治理投票

主要功能：
    代币基本信息：
    名称：MyToken
    符号：MTK
    标准 ERC20 代币功能
    
    投票功能：
    代币持有者可以委托投票权给其他地址
    支持历史投票记录查询（防止闪电贷攻击）
    投票权与代币余额 1:1 对应

    离线签名：
    支持 EIP-2612 离线签名授权
    用户可以通过签名授权他人使用代币，无需先发送交易

    治理集成：
    与 OpenZeppelin 的 Governor 合约兼容
    支持复杂的治理提案和投票机制

    使用场景：
    这个代币通常用于：
    DAO 治理投票
    提案创建和表决
    社区决策制定
    去中心化协议治理

    关键方法：
    mint(): 铸造新代币（注意：这里没有访问控制，实际部署时需要添加权限控制）
    delegate(): 委托投票权
    getVotes(): 查询当前投票权
    getPastVotes(): 查询历史投票权
    这个合约是构建去中心化治理系统的基础组件，为 DAO 提供了完整的代币投票机制。
 */