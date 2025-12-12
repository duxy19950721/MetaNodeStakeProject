// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
 * 奖励用的ERC20代币，用于发利息的
 */
contract RewardERC20 is ERC20 {
    constructor(string memory name, string memory symbol) ERC20(name, symbol) {
    }
}