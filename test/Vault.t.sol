// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import {Vault} from "../src/Vault.sol";
import {IVault} from "../src/IVault.sol";

import {IERC20} from "openzeppelin/token/ERC20/IERC20.sol";
import {ERC20} from "openzeppelin/token/ERC20/ERC20.sol";

contract VaultTest is Test {
 
    
    IVault vault;

    struct Constants {
        TokenConstants token0;
        TokenConstants token1; // not initially in vault
        TokenConstants token2; // not initially in vault
        address withdraw_address;
        address governance;
        uint128 dayLength;
        uint128 withdrawQueueDuration;
        uint128 changeWithdrawDuration;
        uint128 increaseDailyLimitDuration;
    }

    struct TokenConstants {
        uint128 initialDailyLimit;
        string name;
        string symbol;
    }

    function setUpVault(Constants memory c) internal returns (address[] memory tokens) {
        tokens = new address[](3);
        tokens[0] = address(new ERC20(c.token0.name, c.token0.symbol));
        tokens[1] = address(new ERC20(c.token1.name, c.token1.symbol));
        tokens[2] = address(new ERC20(c.token2.name, c.token2.symbol));

        address[] memory tokensInitial = new address[](1);
        tokensInitial[0] = address(tokens[0]);
        uint256[] memory initialDailyLimits = new uint256[](1);
        initialDailyLimits[0] = c.token0.initialDailyLimit;
        vault = new Vault(
            c.withdraw_address,
            c.governance,
            tokensInitial,
            initialDailyLimits,
            c.dayLength,
            c.withdrawQueueDuration,
            c.changeWithdrawDuration,
            c.increaseDailyLimitDuration
        );
    }

    function testNormalWithdraws(Constants memory c, uint256 totalBalance) public {
        vm.assume(c.token0.initialDailyLimit > 0);
        vm.assume(totalBalance/c.token0.initialDailyLimit < 1e4);
        vm.assume(c.dayLength >= 1);
        vm.assume(c.governance != address(0x0));
        vm.assume(c.withdraw_address != address(0x0));

        address[] memory tokens = setUpVault(c);

        skip(c.dayLength);

        deal(tokens[0], address(vault), totalBalance);
        
        bool result; 
        string memory reason;
        
        for(uint256 i=0; i<(totalBalance/c.token0.initialDailyLimit + 1); i++) {
           
            vm.prank(c.withdraw_address);
            (result, reason) = vault.withdrawDailyLimit(tokens[0]);
            console.log(reason);
            assertTrue(result, "Withdraw should have gone through");

            skip(c.dayLength - 1);

            vm.prank(c.withdraw_address);
            (result, reason) = vault.withdrawDailyLimit(tokens[0]);

            console.log(reason);

            assertTrue(!result, "Withdraw should not have gone through");
            assertEq(reason, "Has not been enough time since last daily withdraw", "Wrong reason for not granting withdraw");

            skip(1);
        }

        assertTrue(IERC20(tokens[0]).balanceOf(c.withdraw_address) == totalBalance, "Not all assets were transferred to withdraw_address");
        assertTrue(IERC20(tokens[0]).balanceOf(address(vault)) == 0, "Not all assets were withdrawn from vault");

        vm.prank(c.withdraw_address);
        (result, reason) = vault.withdrawDailyLimit(tokens[1]);
        assertTrue(!result, "Withdraw should not have gone through");
        assertEq(reason, "Token not valid in this vault", "Wrong reason for not granting withdraw");

        vm.prank(c.withdraw_address);
        (result, reason) = vault.withdrawDailyLimit(tokens[0]); // transfers nothing
        assertTrue(result, "Withdraw should have gone through");
    }

    function testLargeWithdraws(Constants memory c, uint256 iters, uint256 amount, uint256 totalBalance) public {
        vm.assume(c.token1.initialDailyLimit > 0);
        vm.assume(iters < 1e4);
        vm.assume(iters > 0);
        vm.assume(amount < 1e70/iters);
        vm.assume(2*amount > c.token1.initialDailyLimit);
        vm.assume(totalBalance > amount*iters);
        vm.assume(c.withdrawQueueDuration >= 1);
        vm.assume(c.governance != address(0x0));
        vm.assume(c.withdraw_address != address(0x0));
        

        address[] memory tokens = setUpVault(c);

        vm.prank(c.governance);
        vault.changeDailyLimit(tokens[1], c.token1.initialDailyLimit);
        skip(c.increaseDailyLimitDuration);
        vm.prank(c.governance);
        vault.changeDailyLimit(tokens[1], c.token1.initialDailyLimit);

        deal(tokens[1], address(vault), totalBalance);
        
        
        bool result; 
        string memory reason;

        vm.prank(c.withdraw_address);
        vault.requestWithdrawOutsideLimit(tokens[0], amount, iters+1);
        
        for(uint256 i=0; i<iters; i++) {
            vm.prank(c.withdraw_address);
            (result, reason) = vault.requestWithdrawOutsideLimit(tokens[1], amount, i);
            assertTrue(result, "Withdraw should have been added to queue");
        }

        assertTrue(IERC20(tokens[1]).balanceOf(c.withdraw_address) == 0, "Nothing was transferred yet");


        skip(c.withdrawQueueDuration - 1);

        for(uint256 i=0; i<iters; i++) {
            vm.prank(c.withdraw_address);
            (result, reason) = vault.requestWithdrawOutsideLimit(tokens[1], amount, i);

            assertTrue(!result, "Withdraw should not have gone through");
            assertEq(reason, "Withdraw has not waited long enough in the queue", "Wrong reason for not granting withdraw");
        }

        skip(1);

        for(uint256 i=0; i<iters; i++) {
            vm.prank(c.withdraw_address);
            (result, reason) = vault.requestWithdrawOutsideLimit(tokens[1], amount*iters, i);

            assertTrue(result, "Withdraw should have gone through");
            

            assertTrue(IERC20(tokens[1]).balanceOf(c.withdraw_address) == (i+1)*amount, "Not all assets were transferred to withdraw_address");
            assertTrue(IERC20(tokens[1]).balanceOf(address(vault)) == totalBalance - (i+1)*amount, "Not all assets were withdrawn from vault");
        }
    
        vm.prank(c.withdraw_address);
        (result, reason) = vault.requestWithdrawOutsideLimit(tokens[2], amount, iters+1);
        assertTrue(!result, "Withdraw should not have gone through");
        assertEq(reason, "Token not valid in this vault", "Wrong reason for not granting withdraw");

        for(uint256 i=0; i<iters; i++) {
            vm.prank(c.withdraw_address);
            (result, reason) = vault.requestWithdrawOutsideLimit(tokens[1], amount, i);

            assertTrue(!result, "Withdraw should not have gone through");
            assertEq(reason, "Withdraw has already been completed", "Wrong reason for not granting withdraw");
        }

        vm.prank(c.withdraw_address);
        vault.requestWithdrawOutsideLimit(tokens[1], totalBalance - iters*amount + 1, iters+2);
        skip(c.withdrawQueueDuration);
        vm.prank(c.withdraw_address);
        (result, reason) = vault.requestWithdrawOutsideLimit(tokens[1], totalBalance - iters*amount + 1, iters+2);
        assertTrue(!result, "Withdraw should not have gone through");
        assertEq(reason, "Not enough vault balance to complete withdraw", "Wrong reason for not granting withdraw");

        vm.prank(c.withdraw_address);
        vault.requestWithdrawOutsideLimit(tokens[1], totalBalance - iters*amount, iters+3);
        
        skip(c.withdrawQueueDuration-1);
        vm.prank(c.governance);
        vault.disallowWithdrawOutsideLimit(iters+3);
        skip(1);

        vm.prank(c.withdraw_address);
        (result, reason) = vault.requestWithdrawOutsideLimit(tokens[1], totalBalance - iters*amount, iters+3);
        assertTrue(!result, "Withdraw should not have gone through");
        assertEq(reason, "This withdraw has been disallowed", "Wrong reason for not granting withdraw");


    }

    function testChangeWithdrawAddress(Constants memory c, address newWithdrawAddress) public {
        vm.assume(c.changeWithdrawDuration >= 1);
        vm.assume(newWithdrawAddress != address(0x0));
        vm.assume(c.governance != address(0x0));
        vm.assume(c.withdraw_address != address(0x0));
        vm.assume(c.withdraw_address != newWithdrawAddress);
        vm.assume(c.withdraw_address != c.governance);

        address[] memory tokens = setUpVault(c);

        skip(c.dayLength);

        bool result;
        string memory reason;

        deal(tokens[0], address(vault), c.token0.initialDailyLimit);

        vm.prank(c.governance);
        (result, reason) = vault.changeWithdrawAddress(newWithdrawAddress);
        assertTrue(result, "Withdraw request did not go through");
        
        skip(c.changeWithdrawDuration - 1);
        vm.prank(c.governance);
        (result, reason) = vault.changeWithdrawAddress(newWithdrawAddress);
        assertTrue(!result, "Change should not have worked");
        assertEq(reason, "Change Withdraw has not waited long enough", "Wrong Reason");

        skip(1);
        vm.prank(c.withdraw_address);
        vm.expectRevert("Sender is not the governance address");
        (result, reason) = vault.changeWithdrawAddress(newWithdrawAddress);

        vm.prank(c.governance);
        (result, reason) = vault.changeWithdrawAddress(newWithdrawAddress);
        assertTrue(result, "Should have worked");

        vm.prank(newWithdrawAddress);
        vault.withdrawDailyLimit(tokens[0]);

        assertTrue(IERC20(tokens[0]).balanceOf(newWithdrawAddress) == c.token0.initialDailyLimit, "Not all assets were transferred to new withdraw address");
        assertTrue(IERC20(tokens[0]).balanceOf(address(vault)) == 0, "Not all assets were withdrawn from vault");

    }

    function testIncreaseDailyLimit(Constants memory c, uint128 newDailyLimit1, uint128 newDailyLimit2, uint256 totalBalance) public {
        vm.assume(c.increaseDailyLimitDuration >= 1);
        vm.assume(c.governance != address(0x0));
        vm.assume(c.withdraw_address != address(0x0));
        vm.assume(c.withdraw_address != c.governance);
        uint256 sum = uint256(0) + c.token0.initialDailyLimit + newDailyLimit1 + newDailyLimit2;
        vm.assume(totalBalance >= sum);
        vm.assume(c.token0.initialDailyLimit <= newDailyLimit2);
        vm.assume(newDailyLimit1 > newDailyLimit2);

        address[] memory tokens = setUpVault(c);

        skip(c.dayLength);

        deal(tokens[0], address(vault), totalBalance);

        vm.prank(c.governance);
        vault.changeDailyLimit(tokens[0], newDailyLimit1);

        skip(c.increaseDailyLimitDuration - 1);

        vm.prank(c.withdraw_address);
        vault.withdrawDailyLimit(tokens[0]);

        skip(c.dayLength + uint256(1));

        vm.prank(c.governance);
        vault.changeDailyLimit(tokens[0], newDailyLimit1);

        vm.prank(c.withdraw_address);
        vault.withdrawDailyLimit(tokens[0]);

        vm.prank(c.governance);
        vault.changeDailyLimit(tokens[0], newDailyLimit2);

        skip(c.dayLength);

        vm.prank(c.withdraw_address);
        vault.withdrawDailyLimit(tokens[0]);

        

        assertTrue(IERC20(tokens[0]).balanceOf(c.withdraw_address) == sum, "Not all assets were transferred to new withdraw address");
        assertTrue(IERC20(tokens[0]).balanceOf(address(vault)) == totalBalance - sum, "Not all assets were withdrawn from vault");






    }



}
