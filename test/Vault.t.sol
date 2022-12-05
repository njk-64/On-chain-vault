// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import {Vault} from "../src/Vault.sol";

import {IERC20} from "openzeppelin/token/ERC20/IERC20.sol";
import {ERC20} from "openzeppelin/token/ERC20/ERC20.sol";

contract VaultTest is Test {
 
    address[] assets;
    Vault vault;
    address withdraw_address;
    address governance;
    uint256 dayLength;
    uint256 withdrawQueueDuration;

    function setUp() public {
        
        ERC20 eth = new ERC20("Ether", "ETH");
        ERC20 avax = new ERC20("Avax", "AVAX");
        ERC20 bnb = new ERC20("Bnb", "BNB");
        assets.push(address(eth)); 
        assets.push(address(avax));
        assets.push(address(bnb));

        withdraw_address = address(0x1);
        governance = address(0x2);

        uint256[] memory initialDailyLimits = new uint256[](0);
        address[] memory assetsBlank = new address[](0);

        dayLength = 1 days;
        withdrawQueueDuration = 1 days;

        skip(100 days);
    
        vault = new Vault(
            withdraw_address,
            governance,
            assetsBlank,
            initialDailyLimits,
            dayLength,
            withdrawQueueDuration
        );

    }

    function testNormalWithdraws(uint256 dailyLimit, uint256 totalBalance) public {
        vm.assume(dailyLimit > 0);
        vm.assume(totalBalance/dailyLimit < 1e4);

        vm.prank(governance);
        vault.changeDailyLimit(assets[0], dailyLimit);

        deal(assets[0], address(vault), totalBalance);
        
        
        for(uint256 i=0; i<(totalBalance/dailyLimit + 1); i++) {
            vm.prank(withdraw_address);
            (bool result, string memory reason) = vault.requestWithdraw(assets[0]);
            console.log(reason);
            assertTrue(result, "Withdraw should have gone through");

            skip(dayLength - 1);

            vm.prank(withdraw_address);
            (result, reason) = vault.requestWithdraw(assets[0]);

            console.log(reason);

            assertTrue(!result, "Withdraw should not have gone through");
            assertEq(reason, "Has not been enough time since last daily withdraw", "Wrong reason for not granting withdraw");

            skip(1);
        }

        assertTrue(IERC20(assets[0]).balanceOf(withdraw_address) == totalBalance, "Not all assets were transferred to withdraw_address");
        assertTrue(IERC20(assets[0]).balanceOf(address(vault)) == 0, "Not all assets were withdrawn from vault");
    }



}
