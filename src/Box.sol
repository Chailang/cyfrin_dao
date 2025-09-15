// contracts/Box.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract Box is Ownable {
    uint256 private value;

   

    // Emitted when the stored value changes
    event ValueChanged(uint256 newValue);


    constructor() Ownable(msg.sender) {

    }

    // Stores a new value in the contract
    function store(uint256 newValue) public onlyOwner {
        value = newValue;
        emit ValueChanged(newValue);
    }

    // Reads the last stored value
    function retrieve() public view returns (uint256) {
        return value;
    }
}
/**
 4. Box.sol - 被治理的目标合约
    核心职责：
        演示被治理的合约
    具体职责：
        ✅ 数据存储：存储一个uint256值
        ✅ 权限控制：只有所有者可以修改
        ✅ 事件记录：记录值的变化
        ✅ 治理目标：演示如何通过治理修改合约
    在治理中的作用：
        作为治理的目标合约
        演示治理流程的实际效果
        验证治理机制的有效性 
*/