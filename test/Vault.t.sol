// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import {Vault} from "../src/Vault.sol";

import {IERC20} from "openzeppelin/token/ERC20/IERC20.sol";
import {TestHelpers} from "./TestHelpers.sol";
import {TestState} from "./TestState.sol";

contract VaultTest is Test, TestState, TestHelpers {
 
    function setUp() public {
        vault = new Vault();
        assets.push(0xB97EF9Ef8734C71904D8002F8b6Bc66Dd9c48a6E); // 10 billion USDC

        address[] memory vaultGuardianAddresses = new address[](1);
        vaultGuardianAddresses[0] = address(this);

        uint256[] memory initialDailyLimits = new uint256[](1);
        initialDailyLimits[0] = 1 * 10 ** 6;
        
        vault.initialize(
            address(this),
            vaultGuardianAddresses,
            assets,
            initialDailyLimits
        );
    }

    function testNormalFlow() public {

        deal(assets[0], address(vault), 1 * 10 ** 16);
        
        successfulWithdrawRequest(assets[0], 1 * 10 ** 5, 0);
        successfulWithdrawRequest(assets[0], 1 * 10 ** 5, 1);
        successfulWithdrawRequest(assets[0], 1 * 10 ** 5, 2);
        successfulWithdrawRequest(assets[0], 1 * 10 ** 5, 3);

        skip(1 days);
    }

    function testLargeWithdraw() public {

        deal(assets[0], address(vault), 1 * 10 ** 16);
        
        successfulWithdrawRequest(assets[0], 1 * 10 ** 5, 0);
        successfulWithdrawRequest(assets[0], 1 * 10 ** 5, 1);
        successfulWithdrawRequest(assets[0], 1 * 10 ** 5, 2);
        successfulWithdrawRequest(assets[0], 1 * 10 ** 5, 3);

        failedWithdrawRequest(assets[0], 1 * 10 ** 10, 0, "Action enqueued, wait 24 hours to complete action");
        
        skip(1 days / 2);

        failedWithdrawRequest(assets[0], 1 * 10 ** 10, 0, "Wait 24 hours before completing action");

        skip(1 days / 2);
    
        successfulWithdrawRequest(assets[0], 1 * 10 ** 10, 0);

    }

    function testChangeLimit() public {

        deal(assets[0], address(vault), 1 * 10 ** 16);
        
        successfulWithdrawRequest(assets[0], 1 * 10 ** 5, 0);
        successfulWithdrawRequest(assets[0], 1 * 10 ** 5, 1);
        successfulWithdrawRequest(assets[0], 1 * 10 ** 5, 2);
        successfulWithdrawRequest(assets[0], 1 * 10 ** 5, 3);

        failedWithdrawRequest(assets[0], 1 * 10 ** 10, 0, "Action enqueued, wait 24 hours to complete action");
        
        skip(1 days / 2);

        failedWithdrawRequest(assets[0], 1 * 10 ** 10, 0, "Wait 24 hours before completing action");

        skip(1 days / 2);
    
        successfulWithdrawRequest(assets[0], 1 * 10 ** 10, 0);

        failedWithdrawRequest(assets[0], 1 * 10 ** 10, 13, "Action enqueued, wait 24 hours to complete action");

        successfulChangeLimit(assets[0], 10, 0);

        failedChangeLimit(assets[0], 10 ** 15, 2, "Action enqueued, wait 24 hours to complete action");

        skip(1 days / 2);

        failedChangeLimit(assets[0], 10 ** 15, 2, "Wait 24 hours before completing action");

        skip(1 days / 3);

        failedChangeLimit(assets[0], 10 ** 15, 2, "Wait 24 hours before completing action");

        failedWithdrawRequest(assets[0], 11, 2334, "Action enqueued, wait 24 hours to complete action");

        skip(1 days / 6);

        successfulChangeLimit(assets[0], 10 ** 15, 2);

        successfulWithdrawRequest(assets[0], 1 * 10 ** 15, 1245);

        skip(5 days / 6);

        failedWithdrawRequest(assets[0], 1, 1246, "Action enqueued, wait 24 hours to complete action");

        skip(1 days / 6);
        
        successfulWithdrawRequest(assets[0], 1, 1247);

        failedWithdrawRequest(assets[0], 1, 1246, "Wait 24 hours before completing action");



    }
}
