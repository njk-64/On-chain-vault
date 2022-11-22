// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {VaultStructs} from "./VaultStructs.sol";

contract VaultStorage {

    struct State {
        address withdrawAddress;
        address trustedAddress;

        mapping(address => VaultStructs.DailyLimitInfo) tokenDailyLimitInfo;
        mapping(uint256 => VaultStructs.LargeWithdrawInfo) largeWithdrawQueue;

        uint256 dayLength;
        uint256 withdrawQueueDuration;
    }
}

contract VaultState {
    VaultStorage.State _state;
}