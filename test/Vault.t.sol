// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import {Vault} from "../src/Vault.sol";

import {IERC20} from "openzeppelin/token/ERC20/IERC20.sol";
import {TestHelpers} from "./TestHelpers.sol";
import {TestState} from "./TestState.sol";

contract VaultTest is Test, TestState, TestHelpers {
 
    function setUp() public {
        assets.push(0xB97EF9Ef8734C71904D8002F8b6Bc66Dd9c48a6E); // 10 billion USDC

        uint256[] memory initialDailyLimits = new uint256[](1);
        initialDailyLimits[0] = 1 * 10 ** 6;

        vault = new Vault(
            address(this),
            address(this),
            assets,
            initialDailyLimits,
            1 days,
            1 days
        );
    }

}
