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

    function setTokenDailyLimitInfo(address token, DailyLimitInfo memory info) internal {
        _state.tokenDailyLimitInfo[token] = info;
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
