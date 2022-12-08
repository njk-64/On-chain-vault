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
    uint256 changeWithdrawDuration;

    function setUp() public {
        
        ERC20 eth = new ERC20("Ether", "ETH");
        ERC20 avax = new ERC20("Avax", "AVAX");
        ERC20 bnb = new ERC20("Bnb", "BNB");
        assets.push(address(eth)); 
        assets.push(address(avax));
        assets.push(address(bnb));

        withdraw_address = address(this);
        governance = address(0x2);

        uint256[] memory initialDailyLimits = new uint256[](0);
        address[] memory assetsBlank = new address[](0);

        dayLength = 1 days;
        withdrawQueueDuration = 1 days;
        changeWithdrawDuration = 1 days;

        skip(100 days);
    
        vault = new Vault(
            withdraw_address,
            governance,
            assetsBlank,
            initialDailyLimits,
            dayLength,
            withdrawQueueDuration,
            changeWithdrawDuration
        );

    }

    function testNormalWithdraws(uint256 dailyLimit, uint256 totalBalance) public {
        vm.assume(dailyLimit > 0);
        vm.assume(totalBalance/dailyLimit < 1e4);

        vm.prank(governance);
        vault.changeDailyLimit(assets[0], dailyLimit);

        deal(assets[0], address(vault), totalBalance);
        
        bool result; 
        string memory reason;
        
        for(uint256 i=0; i<(totalBalance/dailyLimit + 1); i++) {
           
            (result, reason) = vault.requestWithdraw(assets[0]);
            console.log(reason);
            assertTrue(result, "Withdraw should have gone through");

            skip(dayLength - 1);

           
            (result, reason) = vault.requestWithdraw(assets[0]);

            console.log(reason);

            assertTrue(!result, "Withdraw should not have gone through");
            assertEq(reason, "Has not been enough time since last daily withdraw", "Wrong reason for not granting withdraw");

            skip(1);
        }

        assertTrue(IERC20(assets[0]).balanceOf(withdraw_address) == totalBalance, "Not all assets were transferred to withdraw_address");
        assertTrue(IERC20(assets[0]).balanceOf(address(vault)) == 0, "Not all assets were withdrawn from vault");

       
        (result, reason) = vault.requestWithdraw(assets[1]);
        assertTrue(!result, "Withdraw should not have gone through");
        assertEq(reason, "Token not valid in this vault");

        (result, reason) = vault.requestWithdraw(assets[0]); // transfers nothing
        assertTrue(result, "Withdraw should have gone through");
    }

    function testLargeWithdraws(uint256 dailyLimit, uint256 iters, uint256 amount, uint256 totalBalance) public {
        vm.assume(dailyLimit > 0);
        vm.assume(iters < 1e4);
        vm.assume(iters > 0);
        vm.assume(amount < 1e70/iters);
        vm.assume(2*amount > dailyLimit);
        vm.assume(totalBalance > amount*iters);
        vm.prank(governance);
        vault.changeDailyLimit(assets[1], dailyLimit);

        deal(assets[1], address(vault), totalBalance);
        
        bool result; 
        string memory reason;

        vault.requestWithdrawOutsideLimit(assets[0], amount, iters+1);
        
        for(uint256 i=0; i<iters; i++) {
            (result, reason) = vault.requestWithdrawOutsideLimit(assets[1], amount, i);
            assertTrue(result, "Withdraw should have been added to queue");
        }

        assertTrue(IERC20(assets[1]).balanceOf(withdraw_address) == 0, "Nothing was transferred yet");


        skip(withdrawQueueDuration - 1);

        for(uint256 i=0; i<iters; i++) {
            (result, reason) = vault.requestWithdrawOutsideLimit(assets[1], amount, i);

            assertTrue(!result, "Withdraw should not have gone through");
            assertEq(reason, "Withdraw has not waited long enough in the queue", "Wrong reason for not granting withdraw");
        }

        skip(1);

        for(uint256 i=0; i<iters; i++) {
            (result, reason) = vault.requestWithdrawOutsideLimit(assets[1], amount*iters, i);

            assertTrue(result, "Withdraw should have gone through");
            

            assertTrue(IERC20(assets[1]).balanceOf(withdraw_address) == (i+1)*amount, "Not all assets were transferred to withdraw_address");
            assertTrue(IERC20(assets[1]).balanceOf(address(vault)) == totalBalance - (i+1)*amount, "Not all assets were withdrawn from vault");
        }
    
       
        (result, reason) = vault.requestWithdrawOutsideLimit(assets[0], amount, iters+1);
        assertTrue(!result, "Withdraw should not have gone through");
        assertEq(reason, "Token not valid in this vault", "Wrong reason for not granting withdraw");

        for(uint256 i=0; i<iters; i++) {
            (result, reason) = vault.requestWithdrawOutsideLimit(assets[1], amount, i);

            assertTrue(!result, "Withdraw should not have gone through");
            assertEq(reason, "Withdraw has already been completed", "Wrong reason for not granting withdraw");
        }

        vault.requestWithdrawOutsideLimit(assets[1], totalBalance - iters*amount + 1, iters+2);
        skip(withdrawQueueDuration);
        (result, reason) = vault.requestWithdrawOutsideLimit(assets[1], totalBalance - iters*amount + 1, iters+2);
        assertTrue(!result, "Withdraw should not have gone through");
        assertEq(reason, "Not enough vault balance to complete withdraw", "Wrong reason for not granting withdraw");

        vault.requestWithdrawOutsideLimit(assets[1], totalBalance - iters*amount, iters+3);
        
        vm.prank(governance);
        skip(withdrawQueueDuration-1);
        vault.disallowLargeWithdraw(iters+3);
        skip(1);

        (result, reason) = vault.requestWithdrawOutsideLimit(assets[1], totalBalance - iters*amount, iters+3);
        assertTrue(!result, "Withdraw should not have gone through");
        assertEq(reason, "This withdraw has been disallowed", "Wrong reason for not granting withdraw");


    }


}
