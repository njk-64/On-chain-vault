// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {VaultStructs} from "./VaultStructs.sol";
import {VaultState} from "./VaultState.sol";

contract VaultGetters is VaultStructs, VaultState {

    function getWithdrawAddress() public view returns (address) {
        return _state.withdrawAddress;
    }

    function getTrustedAddress() public view returns (address) {
        return _state.trustedAddress;
    }

    function getTokenDailyLimitInfo(address token) public view returns (DailyLimitInfo memory) {
        return _state.tokenDailyLimitInfo[token];
    }

    function getLargeWithdrawInfo(uint256 identifier) public view returns (LargeWithdrawInfo memory) {
        return _state.largeWithdrawQueue[identifier];
    }

    function getDayLength() public view returns (uint256) {
        return _state.dayLength;
    }

    function getWithdrawQueueDuration() public view returns (uint256) {
        return _state.withdrawQueueDuration;
    }

    function isTokenValid(address token) public view returns (bool) {
        return getTokenDailyLimitInfo(token).exists;
    }

    modifier validToken(address token) {
        require(isTokenValid(token), "Token is not valid");
        _;
    }

    modifier onlyWithdrawAddress() {
        require(msg.sender == getWithdrawAddress(), "Sender is not the withdraw address");
        _;
    }

    modifier onlyTrustedAddress() {
        require(msg.sender == getTrustedAddress(), "Sender is not the trusted address");
        _;
    }

}
