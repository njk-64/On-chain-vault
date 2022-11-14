// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/Vault.sol";

import {IERC20} from "openzeppelin/token/ERC20/IERC20.sol";

contract VaultTest is Test {
    Vault public vault;

    address[] assets;
 
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

        failedWithdrawRequest(assets[0], 1 * 10 ** 10, 0, "transaction enqueued, wait 24 hours to withdraw");
        
        skip(1 days / 2);

        failedWithdrawRequest(assets[0], 1 * 10 ** 10, 0, "wait 24 hours before withdrawing");

        skip(1 days / 2);
    
        successfulWithdrawRequest(assets[0], 1 * 10 ** 10, 0);

    }

    

    // Test Helpers
    function successfulWithdrawRequest(address requestedToken, uint256 requestedTokenAmount, uint32 nonce) internal {
        bool result;
        string memory reason;
        uint256 initialTokenBridgeBalance = IERC20(requestedToken).balanceOf(address(this));
        uint256 initialVaultBalance = IERC20(requestedToken).balanceOf(address(vault));
        (result, reason) = vault.withdrawRequest(requestedToken, requestedTokenAmount, nonce);
        require(result, "withdraw request should have succeeded");
        uint256 finalTokenBridgeBalance = IERC20(requestedToken).balanceOf(address(this));
        uint256 finalVaultBalance = IERC20(requestedToken).balanceOf(address(vault));
        require(initialTokenBridgeBalance + requestedTokenAmount == finalTokenBridgeBalance, "Tokens did not transfer to tokenbridge");
        require(initialVaultBalance - requestedTokenAmount == finalVaultBalance, "Tokens did not transfer from vault");
    }

    // Test Helpers
    function failedWithdrawRequest(address requestedToken, uint256 requestedTokenAmount, uint32 nonce, string memory errorMessage) internal {
        bool result;
        string memory reason;
        uint256 initialTokenBridgeBalance = IERC20(requestedToken).balanceOf(address(this));
        uint256 initialVaultBalance = IERC20(requestedToken).balanceOf(address(vault));
        (result, reason) = vault.withdrawRequest(requestedToken, requestedTokenAmount, nonce);
        require(!result, "withdraw request should not have gone through");
        assertEq(bytes(reason), bytes(errorMessage), "withdraw request should have failed for a different reason");
        uint256 finalTokenBridgeBalance = IERC20(requestedToken).balanceOf(address(this));
        uint256 finalVaultBalance = IERC20(requestedToken).balanceOf(address(vault));
        require(initialTokenBridgeBalance == finalTokenBridgeBalance, "A token transfer occured to the tokenbridge when the request should have failed");
        require(initialVaultBalance == finalVaultBalance, "A token transfer occured from the vault when the request should have failed");
    
    }

}
