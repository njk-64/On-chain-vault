// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

contract VaultStructs {

    struct DailyLimitInfo {
        uint256 dailyLimit;
        uint256 lastRequestTimestamp;
        bool exists;
    }

    struct LargeWithdrawInfo {
        uint256 enqueuedTimestamp;
        address token;
        uint256 tokenAmount;
        bool exists;
        bool disallowed;
        bool completed;
    }

    event dailyLimitSent(address token, uint256 tokenAmount, uint256 timestamp);
    event largeWithdrawSent(address token, uint256 tokenAmount, uint256 timestamp, uint256 identifier);
    event largeWithdrawPending(address token, uint256 tokenAmount, uint256 timestamp, uint256 identifier);


}
