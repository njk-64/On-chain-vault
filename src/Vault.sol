// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;
import "openzeppelin/token/ERC20/utils/SafeERC20.sol";

import "forge-std/console.sol";

contract Vault {

    // Address that is allowed to withdraw from Vault
    address withdrawAddress;
    modifier onlyWithdrawAddress() {
        require(msg.sender == withdrawAddress, "Sender is not the withdraw address");
        _;
    }

    // Address that is allowed to perform governance actions in the Vault
    address governance;
    modifier onlyGovernance() {
        require(msg.sender == governance, "Sender is not the governance address");
        _;
    }

    // Map of token address => daily limit info
    struct DailyLimitInfo {
        uint256 dailyLimit;
        uint256 lastRequestTimestamp;
        bool validToken;
    }
    mapping(address => DailyLimitInfo) tokenDailyLimitInfo;

    // Map of pending withdraw requests 
    struct WithdrawOutsideLimitInfo {
        uint256 enqueuedTimestamp;
        uint256 tokenAmount;
        address token;
        bool disallowed;
        bool completed;
    }
    mapping(uint256 => WithdrawOutsideLimitInfo) pendingWithdrawsOutsideLimit;

    // Events
    event dailyLimitSent(address token, uint256 tokenAmount, uint256 timestamp);
    event withdrawOutsideLimitSent(address token, uint256 tokenAmount, uint256 timestamp, uint256 identifier);
    event withdrawOutsideLimitPending(address token, uint256 tokenAmount, uint256 timestamp, uint256 identifier);
    event withdrawDisallowed(uint256 identifier);
    event changeWithdrawAddressPending(address newWithdrawAddress);
    event withdrawAddressChanged(address newWithdrawAddress);
    event dailyLimitChanged(address token, uint256 dailyLimit, bool newToken);
    event increaseDailyLimitPending(address token, uint256 newLimit, bool newToken);

    // Protocol constants
    uint256 immutable dayLength;
    uint256 immutable withdrawQueueDuration;
    uint256 immutable changeWithdrawDuration;
    uint256 immutable increaseDailyLimitDuration;

    // Pending 'change withdraw' request
    address queuedChangeWithdrawAddress;
    uint256 changeWithdrawAddressTimestamp;

    // Pending 'increase daily limit' requests
    struct IncreaseDailyLimitInfo {
        uint256 enqueuedTimestamp;
        uint256 newLimit;
        bool isPending;
    }
    mapping (address => IncreaseDailyLimitInfo) pendingIncreaseDailyLimit;

    

    constructor(
        address _withdrawAddress,
        address _governance,
        address[] memory tokens,
        uint256[] memory dailyLimits,
        uint256 _dayLength,
        uint256 _withdrawQueueDuration,
        uint256 _changeWithdrawDuration,
        uint256 _increaseDailyLimitDuration
    ) {
        require(tokens.length == dailyLimits.length, "tokens and dailyLimits are of different lengths");

        withdrawAddress = _withdrawAddress;
        governance = _governance;
        
        dayLength = _dayLength;
        withdrawQueueDuration = _withdrawQueueDuration;
        changeWithdrawDuration = _changeWithdrawDuration;
        increaseDailyLimitDuration = _increaseDailyLimitDuration;

        for(uint i=0; i < tokens.length; i++) {
            DailyLimitInfo storage info = tokenDailyLimitInfo[tokens[i]];
            info.dailyLimit = dailyLimits[i];
            info.validToken = true;
        }

        changeWithdrawAddressTimestamp = block.timestamp;
        queuedChangeWithdrawAddress = _withdrawAddress;

    }

    function requestWithdraw(
        address token
    ) external onlyWithdrawAddress returns (bool result, string memory reason) {
        DailyLimitInfo storage info = tokenDailyLimitInfo[token];

        uint256 amount = info.dailyLimit;
        uint256 balance = IERC20(token).balanceOf(address(this));

        if(!info.validToken) {
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
        WithdrawOutsideLimitInfo memory info = pendingWithdrawsOutsideLimit[identifier];

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

            if(!tokenDailyLimitInfo[token].validToken) {
                return (false, "Token not valid in this vault");
            }

            uint256 balance = IERC20(token).balanceOf(address(this));
            
            if(balance < info.tokenAmount) {
                return (false, "Not enough vault balance to complete withdraw");
            }

            info.completed = true;
            pendingWithdrawsOutsideLimit[identifier] = info;

            SafeERC20.safeTransfer(IERC20(info.token), withdrawAddress, info.tokenAmount);
            emit withdrawOutsideLimitSent(info.token, info.tokenAmount, block.timestamp, identifier);

            return (true, "");
        }

        info = WithdrawOutsideLimitInfo({
            enqueuedTimestamp: block.timestamp,
            token: token,
            tokenAmount: amount,
            completed: false,
            disallowed: false
        });

        pendingWithdrawsOutsideLimit[identifier] = info;
        emit withdrawOutsideLimitPending(token, amount, block.timestamp, identifier);

        return (true, "");
    }

    function disallowWithdrawOutsideLimit(
        uint256 identifier
    ) external onlyGovernance {
        WithdrawOutsideLimitInfo storage info = pendingWithdrawsOutsideLimit[identifier];
        require(info.enqueuedTimestamp != 0, "This withdraw is not in the queue");
        info.disallowed = true;
        emit withdrawDisallowed(identifier);
    }

    function changeWithdrawAddress(
        address newAddress
    ) external onlyGovernance returns (bool result, string memory reason) {
        require(newAddress != address(0), "can't set withdraw address to zero address");
        if(newAddress == queuedChangeWithdrawAddress) {
            if(changeWithdrawAddressTimestamp + changeWithdrawDuration > block.timestamp) {
                return (false, "Change Withdraw has not waited long enough");
            } else {
                withdrawAddress = newAddress;
                emit withdrawAddressChanged(newAddress);
                return (true, "");
            }
        } else {
            queuedChangeWithdrawAddress = newAddress;
            changeWithdrawAddressTimestamp = block.timestamp;
            emit changeWithdrawAddressPending(newAddress);
            return (true, "");
        }
    }

    function changeDailyLimit(
        address token, uint256 newLimit
    ) external onlyGovernance returns (bool result, string memory reason) {
        // removing the valid token check as new tokens can also be added through this method
        DailyLimitInfo storage info = tokenDailyLimitInfo[token];
        IncreaseDailyLimitInfo storage pending = pendingIncreaseDailyLimit[token];
        bool changeLimit = false;
        if(info.dailyLimit >= newLimit) {
            changeLimit = true;
        } else if(pending.isPending && pending.newLimit == newLimit) {
            if(pending.enqueuedTimestamp + increaseDailyLimitDuration <= block.timestamp) {
                changeLimit = true;
            } else {
                return (false, "Increase daily limit has not waited long enough");
            }
        } else {
            pending.isPending = true;
            pending.newLimit = newLimit;
            pending.enqueuedTimestamp = block.timestamp;
            emit increaseDailyLimitPending(token, newLimit, !info.validToken);
        }

        if(changeLimit) {
            emit dailyLimitChanged(token, newLimit, !info.validToken);
            info.dailyLimit = newLimit;
            pending.isPending = false;
            if (!info.validToken)   {
                info.validToken = true;
            }
        }

        return (true, "");
    }

}
