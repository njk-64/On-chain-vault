// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {VaultStructs} from "./VaultStructs.sol";
import {VaultState} from "./VaultState.sol";

contract VaultGetters is VaultStructs, VaultState {

    function getAllowedAddress() public view returns (address) {
        return _state.allowedAddress;
    }

    function getVaultGuardians() public view returns (address[] memory) {
        return _state.vaultGuardians;
    }

    function getTokenDailyLimitInfo(address token) public view returns (DailyLimitInfo memory) {
        return _state.tokenDailyLimitInfo[token];
    }

    function isActionCompleted(bytes32 identifier) public view returns (bool) {
        return _state.completedActions[identifier];
    }

    function pendingActionStatus(bytes32 identifier) public view returns (uint256) {
        return _state.pendingActionQueue[identifier];
    }

    function isTokenValid(address token) external view returns (bool) {
        if(_state.tokenDailyLimitInfo[token].dailyLimit == 0) {
            return false;
        } else {
            return true;
        }
    }

}
