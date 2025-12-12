// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
 * 质押用的ERC20代币，用于质押和解质押
 */
contract StakeERC20 is ERC20 {
    constructor(string memory name, string memory symbol) ERC20(name, symbol) {
    }
}