// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import {IERC20} from "openzeppelin/token/ERC20/IERC20.sol";
import {TestState} from "./TestState.sol";
import {VaultStructs} from "../src/VaultStructs.sol";

contract TestHelpers is Test, TestState {

    function successfulWithdrawRequest(address requestedToken, uint256 requestedTokenAmount, uint256 requestId) internal {
        bool result;
        string memory reason;
        uint256 initialTokenBridgeBalance = IERC20(requestedToken).balanceOf(address(this));
        uint256 initialVaultBalance = IERC20(requestedToken).balanceOf(address(vault));
        (result, reason) = vault.withdraw(requestedToken, requestedTokenAmount, requestId);
        require(result, "withdraw request should have succeeded");
        uint256 finalTokenBridgeBalance = IERC20(requestedToken).balanceOf(address(this));
        uint256 finalVaultBalance = IERC20(requestedToken).balanceOf(address(vault));
        require(initialTokenBridgeBalance + requestedTokenAmount == finalTokenBridgeBalance, "Tokens did not transfer to tokenbridge");
        require(initialVaultBalance - requestedTokenAmount == finalVaultBalance, "Tokens did not transfer from vault");
    }

    function failedWithdrawRequest(address requestedToken, uint256 requestedTokenAmount, uint256 requestId, string memory errorMessage) internal {
        bool result;
        string memory reason;
        uint256 initialTokenBridgeBalance = IERC20(requestedToken).balanceOf(address(this));
        uint256 initialVaultBalance = IERC20(requestedToken).balanceOf(address(vault));
        (result, reason) = vault.withdraw(requestedToken, requestedTokenAmount, requestId);
        require(!result, "withdraw request should not have gone through");
        assertEq(bytes(reason), bytes(errorMessage), "withdraw request should have failed for a different reason");
        uint256 finalTokenBridgeBalance = IERC20(requestedToken).balanceOf(address(this));
        uint256 finalVaultBalance = IERC20(requestedToken).balanceOf(address(vault));
        require(initialTokenBridgeBalance == finalTokenBridgeBalance, "A token transfer occured to the tokenbridge when the request should have failed");
        require(initialVaultBalance == finalVaultBalance, "A token transfer occured from the vault when the request should have failed");
    }

    function successfulChangeLimit(address token, uint256 newLimit, uint256 requestId) internal {
        bool result;
        string memory reason;
        uint256 initialLimit = vault.getTokenDailyLimitInfo(token).dailyLimit;
        VaultStructs.Signature[] memory signatures = new VaultStructs.Signature[](1);
        signatures[0] = VaultStructs.Signature({
            fillerField: 25
        });
        (result, reason) = vault.changeLimit(token, newLimit, requestId, signatures);
        require(result, "change limit request should have succeeded");
        uint256 finalLimit = vault.getTokenDailyLimitInfo(token).dailyLimit;
        require(finalLimit == newLimit, "Limit was not set correctly");
    }

    function failedChangeLimit(address token, uint256 newLimit, uint256 requestId, string memory errorMessage) internal {
        bool result;
        string memory reason;
        uint256 initialLimit = vault.getTokenDailyLimitInfo(token).dailyLimit;
        VaultStructs.Signature[] memory signatures = new VaultStructs.Signature[](1);
        signatures[0] = VaultStructs.Signature({
            fillerField: 25
        });
        (result, reason) = vault.changeLimit(token, newLimit, requestId, signatures);
        require(!result, "withdraw request should not have gone through");
        assertEq(bytes(reason), bytes(errorMessage), "withdraw request should have failed for a different reason");
        uint256 finalLimit = vault.getTokenDailyLimitInfo(token).dailyLimit;
        require(finalLimit == initialLimit, "Limit should not have been changed");
    }

}
