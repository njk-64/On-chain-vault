// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {VaultStructs} from "./VaultStructs.sol";
import {VaultState} from "./VaultState.sol";

contract VaultSetters is VaultStructs, VaultState {

    function setAllowedAddress(address allowedAddress) internal {
        _state.allowedAddress = allowedAddress;
    }

    function addVaultGuardian(address vaultGuardian) internal {
        _state.vaultGuardians.push(vaultGuardian);
    }

    function setTokenDailyLimit(address token, uint256 dailyLimit) internal {
        _state.tokenDailyLimitInfo[token].dailyLimit = dailyLimit;
    }

    function resetTokenDailyLimit(address token) internal {
        _state.tokenDailyLimitInfo[token].used = 0;
        _state.tokenDailyLimitInfo[token].dayStart = block.timestamp;
    }

    function updateDailyUsed(address token, uint256 amount) internal {
        _state.tokenDailyLimitInfo[token].used += amount;
    }

    function setActionCompleted(bytes32 identifier) internal {
         _state.completedActions[identifier] = true;
    }

    function setActionPending(bytes32 identifier) internal {
        _state.pendingActionQueue[identifier] = block.timestamp;
    }

    function removeActionFromPendingQueue(bytes32 identifier) internal {
        _state.pendingActionQueue[identifier] = 0;
    }

}
