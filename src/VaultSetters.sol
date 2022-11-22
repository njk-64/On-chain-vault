// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {VaultStructs} from "./VaultStructs.sol";
import {VaultState} from "./VaultState.sol";

contract VaultSetters is VaultStructs, VaultState {

    function setWithdrawAddress(address allowedAddress) internal {
        _state.withdrawAddress = allowedAddress;
    }

    function setTrustedAddress(address allowedAddress) internal {
        _state.trustedAddress = allowedAddress;
    }

    function setTokenDailyLimitInfo(address token, DailyLimitInfo memory info) internal {
        _state.tokenDailyLimitInfo[token] = info;
    }

    function setLargeWithdrawInfo(uint256 identifier, LargeWithdrawInfo memory info) internal {
        _state.largeWithdrawQueue[identifier] = info;
    }

    function setDayLength(uint256 dayLength) internal {
        _state.dayLength = dayLength;
    }

    function setWithdrawQueueDuration(uint256 withdrawQueueDuration) internal {
        _state.withdrawQueueDuration = withdrawQueueDuration;
    }

}
