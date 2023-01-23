// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

interface IVault {

    // Map of token address => daily limit info
    struct DailyLimitInfo {
        uint256 dailyLimit;
        uint256 lastRequestTimestamp;
        bool validToken;
    }

    // Map of pending withdraw requests 
    struct WithdrawOutsideLimitInfo {
        uint256 enqueuedTimestamp;
        uint256 tokenAmount;
        address token;
        bool disallowed;
        bool completed;
    }

    // Pending 'increase daily limit' requests
    struct IncreaseDailyLimitInfo {
        uint256 enqueuedTimestamp;
        uint256 newLimit;
        bool isPending;
    }

    // *****
    // Only the permissioned withdraw address (WITHDRAW_ADDRESS)
    // is allowed to call these two functions
    // *****

    // When called, the Vault will send `dailyLimit` tokens to 
    // the WITHDRAWAL_ADDRESS, provided that the last request was 
    // made at least dayLength ago and specified the desired token.
    function withdrawDailyLimit(address token) external returns (bool result, string memory reason);

    // During periods of high demand, withdrawal requests may 
    // surpass the permitted daily allowance — such requests are 
    // called through this function and will only execute once the 
    // request has been stored in the state for at least 
    // withdrawQueueDuration time and not rejected by GOVERNANCE calling 
    // disallowWithdrawOutsideLimit. Until then, the Vault stores 
    // the withdrawal request in the state along with a timestamp.
    function requestWithdrawOutsideLimit(
            address token, 
            uint256 amount, 
            uint256 identifier
    ) external returns (bool result, string memory reason);

    // *****
    // Only the governance address (GOVERNANCE)
    // is allowed to call these three functions 
    // *****

    // While outsized withdrawal requests wait withdrawQueueDuration 
    // time, GOVERNANCE can assess the request's validity and 
    // reject it. Suppose GOVERNANCE identifies the request as 
    // malicious and calls the disallowWithdrawOutsideLimit function. 
    // In that case, the Vault will remove the withdrawal request 
    // specified by the identifier from the state, preventing it 
    // from being executed.
    function disallowWithdrawOutsideLimit(uint256 identifier) external;

    // If GOVERNANCE identifies WITHDRAW_ADDRESS as malicious and 
    // has waited changeWithdrawDuration time with a selected newAddress, 
    // then WITHDRAW_ADDRESS is set to newAddress. Until then, the Vault
    // stores the withdrawal request in the state along with a timestamp.
    function changeWithdrawAddress(address newAddress) external returns (bool result, string memory reason);

    // Following changes in demand or risk appetite, GOVERNANCE can 
    // adjust the daily limit for any given token to newLimit. 
    // If newLimit is less than currentLimit, the effect is immediate.
    // Otherwise increaseLimitDuration will need to pass before 
    // it can take effect.
    function changeDailyLimit(address token, uint256 newLimit) external returns (bool result, string memory reason);
}