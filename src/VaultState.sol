// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {VaultStructs} from "./VaultStructs.sol";

contract VaultStorage {

    struct State {
        address allowedAddress;
        address[] vaultGuardians;

        mapping(bytes32 => uint256) pendingActionQueue;
        mapping(bytes32 => bool) completedActions;

        mapping(address => VaultStructs.DailyLimitInfo) tokenDailyLimitInfo;
    }
}

contract VaultState {
    VaultStorage.State _state;
}