// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;
import "openzeppelin/token/ERC20/utils/SafeERC20.sol";

import "forge-std/console.sol";

contract Vault {

    struct DailyLimitInfo {
        uint256 dailyLimit;
        uint256 lastRequestTimestamp;
    }

    struct LargeWithdrawInfo {
        uint256 enqueuedTimestamp;
        uint256 tokenAmount;
        address token;
        bool disallowed;
        bool completed;
    }

    event dailyLimitSent(address token, uint256 tokenAmount, uint256 timestamp);
    event withdrawAboveLimitSent(address token, uint256 tokenAmount, uint256 timestamp, uint256 identifier);
    event withdrawAboveLimitPending(address token, uint256 tokenAmount, uint256 timestamp, uint256 identifier);

    address withdrawAddress;
    address trustedAddress;

    mapping(address => DailyLimitInfo) tokenDailyLimitInfo;
    mapping(uint256 => LargeWithdrawInfo) largeWithdrawQueue;

    uint256 immutable dayLength;
    uint256 immutable withdrawQueueDuration;

    modifier onlyWithdrawAddress() {
        require(msg.sender == withdrawAddress, "Sender is not the withdraw address");
        _;
    }

    modifier onlyTrustedAddress() {
        require(msg.sender == trustedAddress, "Sender is not the trusted address");
        _;
    }

    constructor(
        address _withdrawAddress,
        address _trustedAddress,
        address[] memory tokens,
        uint256[] memory dailyLimits,
        uint256 _dayLength,
        uint256 _withdrawQueueDuration
    ) {
        require(tokens.length == dailyLimits.length, "tokens and dailyLimits are of different lengths");

        withdrawAddress = _withdrawAddress;
        trustedAddress = _trustedAddress;
        dayLength = _dayLength;
        withdrawQueueDuration = _withdrawQueueDuration;

        for(uint i=0; i < tokens.length; i++) {
            DailyLimitInfo storage info = tokenDailyLimitInfo[tokens[i]];
            info.dailyLimit = dailyLimits[i];
            info.lastRequestTimestamp = block.timestamp;
        }   
    }

    function requestWithdraw(
        address token
    ) external onlyWithdrawAddress returns (bool result, string memory reason) {
        DailyLimitInfo storage info = tokenDailyLimitInfo[token];

        uint256 amount = info.dailyLimit;
        uint256 balance = IERC20(token).balanceOf(address(this));

        if(info.lastRequestTimestamp == 0) {
            return (false, "Token not valid in this vault");
        }
        if(info.lastRequestTimestamp + dayLength > block.timestamp) {
            return (false, "Has not been enough time since last daily withdraw");
        } 
        
        if(balance < amount) {
            amount = balance;
        }

        info.lastRequestTimestamp = block.timestamp;
        SafeERC20.safeTransfer(IERC20(token), withdrawAddress, amount);
        emit dailyLimitSent(token, amount, block.timestamp);
        
        return (true, "");
    }

    function requestWithdrawOutsideLimit(
        address token,
        uint256 amount,
        uint256 identifier
    ) external onlyWithdrawAddress returns (bool result, string memory reason) {
        LargeWithdrawInfo memory info = largeWithdrawQueue[identifier];

        if(info.enqueuedTimestamp !=0) {
            if(info.enqueuedTimestamp + withdrawQueueDuration > block.timestamp) {
                return (false, "Withdraw has not waited long enough in the queue");
            }

            if(info.completed) {
                return (false, "Withdraw has already been completed");
            }

            if(info.disallowed) {
                return (false, "This withdraw has been disallowed");
            } 

            info.completed = true;
            largeWithdrawQueue[identifier] = info;
            SafeERC20.safeTransfer(IERC20(info.token), withdrawAddress, info.tokenAmount);
            emit withdrawAboveLimitSent(info.token, info.tokenAmount, block.timestamp, identifier);

            return (true, "");
        }

        info = LargeWithdrawInfo({
            enqueuedTimestamp: block.timestamp,
            token: token,
            tokenAmount: amount,
            completed: false,
            disallowed: false
        });

        largeWithdrawQueue[identifier] = info;
        emit withdrawAboveLimitPending(token, amount, block.timestamp, identifier);

        return (true, "");
    }

    function disallowLargeWithdraw(
        uint256 identifier
    ) external onlyTrustedAddress {
        LargeWithdrawInfo storage info = largeWithdrawQueue[identifier];
        require(info.enqueuedTimestamp != 0, "This withdraw is not in the queue");
        info.disallowed = true;
    }

    function changeWithdrawAddress(
        address newAddress
    ) external onlyTrustedAddress {
        require(newAddress != address(0), "can't set withdraw address to zero address");
        withdrawAddress = newAddress;
    }

    function changeTrustedAddress(
        address newAddress
    ) external onlyTrustedAddress {
        require(newAddress != address(0), "can't set trusted address to zero address");
        trustedAddress = newAddress;
    }

    function changeDailyLimit(
        address token, uint256 newLimit
    ) external onlyTrustedAddress {
        // removing the valid token check as new tokens can also be added through this method
        DailyLimitInfo storage info = tokenDailyLimitInfo[token];
        info.dailyLimit = newLimit;
        
        // setting the last request timestamp for new tokens
        // open question: does the last request timestamp need to be set here for already existing tokens? 
        if (info.lastRequestTimestamp == 0){
            info.lastRequestTimestamp = block.timestamp;
        }
    }

}
