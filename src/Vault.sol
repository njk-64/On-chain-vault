// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;
import "openzeppelin/token/ERC20/utils/SafeERC20.sol";

import "forge-std/console.sol";

import {VaultStructs} from "./VaultStructs.sol";
import {VaultState} from "./VaultState.sol";
import {VaultGetters} from "./VaultGetters.sol";
import {VaultSetters} from "./VaultSetters.sol";

contract Vault is VaultStructs, VaultState, VaultGetters, VaultSetters {

    constructor(
        address withdrawAddress,
        address trustedAddress,
        address[] memory tokens,
        uint256[] memory dailyLimits,
        uint256 dayLength,
        uint256 withdrawQueueDuration
    ) {
        require(tokens.length == dailyLimits.length, "tokens and dailyLimits are of different lengths");

        setWithdrawAddress(withdrawAddress);
        setTrustedAddress(trustedAddress);

        for(uint i=0; i < tokens.length; i++) {
            DailyLimitInfo memory info = DailyLimitInfo({
                dailyLimit: dailyLimits[i],
                lastRequestTimestamp: block.timestamp,
                exists: true
            });
            setTokenDailyLimitInfo(tokens[i], info);
        }   

        setDayLength(dayLength);
        setWithdrawQueueDuration(withdrawQueueDuration);
    }

 
    function withdrawDailyLimit(
        address token
    ) external onlyWithdrawAddress validToken(token) returns (bool result, string memory reason) {
        
        DailyLimitInfo memory info = getTokenDailyLimitInfo(token);

        uint256 amount = info.dailyLimit;
        uint256 balance = IERC20(token).balanceOf(address(this));

        if(!info.exists) {
            return (false, "Token not valid in this vault");
        }
        if(info.lastRequestTimestamp + getDayLength() > block.timestamp) {
            return (false, "Has not been enough time since last daily withdraw");
        } 
        
        if(balance < info.dailyLimit) {
            amount = balance;
        }

        info.lastRequestTimestamp = block.timestamp;
        setTokenDailyLimitInfo(token, info);
        SafeERC20.safeTransfer(IERC20(token), getWithdrawAddress(), amount);
        emit dailyLimitSent(token, amount, block.timestamp);
        
        return (true, "");
    }

    function startWithdrawLargeAmount(
        address token,
        uint256 amount,
        uint256 identifier
    ) external onlyWithdrawAddress validToken(token) returns (bool result, string memory reason){


        LargeWithdrawInfo memory info = getLargeWithdrawInfo(identifier);

        if(info.exists) {
            return (false, "This withdraw is already in the queue");
        }

        info = LargeWithdrawInfo({
            enqueuedTimestamp: block.timestamp,
            token: token,
            tokenAmount: amount,
            exists: true,
            completed: false,
            disallowed: false
        });

        setLargeWithdrawInfo(identifier, info);

    }

    function completeWithdrawLargeAmount(uint256 identifier) external onlyWithdrawAddress returns (bool result, string memory reason){
        
        LargeWithdrawInfo memory info = getLargeWithdrawInfo(identifier);

        if(!info.exists) {
            return (false, "This withdraw is not in the queue");
        }
        if(info.completed) {
            return (false, "Withdraw has already been completed");
        }
        if(info.disallowed) {
            return (false, "Withdraw is disallowed");
        }
        if(info.enqueuedTimestamp + getWithdrawQueueDuration() > block.timestamp) {
            return (false, "Withdraw has not waited long enough in the queue");
        }
        info.completed = true;
        setLargeWithdrawInfo(identifier, info);
        SafeERC20.safeTransfer(IERC20(info.token), getWithdrawAddress(), info.tokenAmount);
        emit largeWithdrawSent(info.token, info.tokenAmount, block.timestamp, identifier);

        return (true, "");

    }

    function disallowLargeWithdraw(uint256 identifier) external onlyTrustedAddress returns (bool result, string memory reason) {
       
        LargeWithdrawInfo memory info = getLargeWithdrawInfo(identifier);

        if(!info.exists) {
            return (false, "This withdraw is not in the queue");
        }

        info.disallowed = true;

        setLargeWithdrawInfo(identifier, info);

        return (true, "");
    }

    function changeWithdrawAddress(address newAddress) external onlyTrustedAddress {
        setWithdrawAddress(newAddress);
    }
    
    function changeDailyLimit(address token, uint256 newLimit) external onlyTrustedAddress validToken(token) {
        DailyLimitInfo memory info = getTokenDailyLimitInfo(token);
        info.dailyLimit = newLimit;
        setTokenDailyLimitInfo(token, info);
    }

   
}
