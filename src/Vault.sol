// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;
import "openzeppelin/proxy/utils/UUPSUpgradeable.sol";
import "openzeppelin/proxy/utils/Initializable.sol";
import "openzeppelin/token/ERC20/utils/SafeERC20.sol";

import "forge-std/console.sol";

contract Vault is Initializable, UUPSUpgradeable {

    struct DailyAllowanceDetails {
        uint256 setDailyAllowance;
        uint256 usedDailyAllowance;
        uint256 dailyTimestampStart;
    }

    struct Signature {
        /// signature struct --> modify this with signature fields
        uint256 fillerField;
    }

    address allowedAddress;
    address[] vaultGuardians;

    mapping(address => DailyAllowanceDetails) tokenDailyAllowanceDetails;

    mapping(bytes32 => uint256) largeWithdrawQueue;
    mapping (bytes32 => bool) completedWithdrawRequests;

    mapping(bytes32 => uint256) governanceActionQueue;
    mapping(bytes32 => bool) completedGovernanceRequests;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {}

    function initialize(
        address tokenBridgeAddress,
        address[] calldata vaultGuardianAddresses,
        address[] calldata tokens,
        uint256[] calldata dailyLimits
    ) public initializer {
        require(tokens.length == dailyLimits.length, "tokens and dailyLimits are of different lengths");

        allowedAddress = tokenBridgeAddress;

        for(uint i=0; i < vaultGuardianAddresses.length; i++) {
            vaultGuardians.push(vaultGuardianAddresses[i]);
        }

        for(uint i=0; i < tokens.length; i++) {
            tokenDailyAllowanceDetails[tokens[i]].setDailyAllowance = dailyLimits[i];
            tokenDailyAllowanceDetails[tokens[i]].dailyTimestampStart = block.timestamp;
        }
    }

    // Do we want to verify guardian signatures on this withdraw? If so, pass in signature array on this and add verify function)
    // 'nonce' field allows for multiple messages of the same requestedToken and requestedTokenAmount
    function withdrawRequest(
        address requestedToken,
        uint256 requestedTokenAmount,
        uint32 nonce
    ) public returns (bool, string memory reason){
        
        bytes32 withdrawHash = keccak256(abi.encodePacked(uint8(2), requestedToken, requestedTokenAmount, nonce));
       
        if(completedWithdrawRequests[withdrawHash] == true) {
            return(false, "allowance already withdrawn");
        }

        if(msg.sender != allowedAddress) {
            return(false, "address requesting allowance is not allowed");
        }

        uint256 enqueuedTimestamp = largeWithdrawQueue[withdrawHash];

        if(enqueuedTimestamp != 0) {
            if(enqueuedTimestamp + 1 days <= block.timestamp) {
                largeWithdrawQueue[withdrawHash] = 0;
            }
            else {
                return(false, "wait 24 hours before withdrawing");
            }
        } else {
            DailyAllowanceDetails memory allowanceDetails = tokenDailyAllowanceDetails[requestedToken];

            if(allowanceDetails.dailyTimestampStart + 1 days <= block.timestamp) {
                allowanceDetails.dailyTimestampStart = block.timestamp;
                allowanceDetails.usedDailyAllowance = 0;
            }

            if(allowanceDetails.usedDailyAllowance + requestedTokenAmount > allowanceDetails.setDailyAllowance) {
                largeWithdrawQueue[withdrawHash] = block.timestamp;
                tokenDailyAllowanceDetails[requestedToken] = allowanceDetails;
                return(false, "transaction enqueued, wait 24 hours to withdraw");
            } else {
                allowanceDetails.usedDailyAllowance += requestedTokenAmount;
                tokenDailyAllowanceDetails[requestedToken] = allowanceDetails;
            }

        }

        IERC20 transferToken = IERC20(requestedToken);
        SafeERC20.safeTransfer(transferToken, allowedAddress, requestedTokenAmount);
        completedWithdrawRequests[withdrawHash] = true;
        return(true, "");

    }

    function verify(
        bytes32 actionHash, 
        Signature[] calldata signatures,
        uint8 action
    ) internal returns (bool){
        /// some signature verification on 'actionHash' and 'action'
        return true;
    }

    /// overriding _authorizeUpgrade
    function _authorizeUpgrade(address newImplementation) internal override {
        require(false, "always revert");
    }

    function disallowLargeWithdraw(
        bytes32 withdrawHash, 
        Signature[] calldata signatures
    ) public {
        bool verified = verify(withdrawHash, signatures, 4);

        require(verified, "signature verification failed");
        require(largeWithdrawQueue[withdrawHash] != 0, "transaction is not in queue");

        largeWithdrawQueue[withdrawHash] = 0;
    }

    function upgradeContract(
        address newImplementation,
        Signature[] calldata signatures
    ) public {
        /// action 1 is upgradeContract
        bytes32 upgradeHash = keccak256(abi.encodePacked(uint8(1), newImplementation));
        bool verified = verify(upgradeHash, signatures, 1);

        require(verified, "signature verification failed");
        require(!completedGovernanceRequests[upgradeHash], "upgrade can't be replayed");

        _upgradeToAndCallUUPS(newImplementation, new bytes(0), false);

        completedGovernanceRequests[upgradeHash] = true;
        /// check to ensure contract doesn't get bricked
    }

    // 'nonce' field allows for multiple messages of the same token and new allowances
    function changeAllowance(
        address token,
        uint256 newAllowance,
        Signature[] calldata signatures,
        uint32 nonce
    ) public returns (bool, string memory reason){
        /// action 2 is changeAllowance
        bytes32 allowanceChangeHash = keccak256(abi.encodePacked(uint8(3), token, newAllowance, nonce));
        
        bool verified = verify(allowanceChangeHash, signatures, 3);

        if(!verified) {
            return(false, "signature verification failed");
        }

        if(governanceActionQueue[allowanceChangeHash] != 0) {
            return(false, "allowance change can't be replayed");
        } 

        uint256 enqueuedTimestamp = governanceActionQueue[allowanceChangeHash];

        if(enqueuedTimestamp != 0) {
            if(enqueuedTimestamp + 1 days <= block.timestamp) {
                governanceActionQueue[allowanceChangeHash] = 0;
            }
            else {
                return(false, "wait 24 hours before governance action");
            }
        } else {
            if(tokenDailyAllowanceDetails[token].setDailyAllowance > newAllowance) {
                return(false, "transaction enqueued, wait 24 hours before increasing allowance");
            } 
        }

        tokenDailyAllowanceDetails[token].setDailyAllowance = newAllowance; 
        completedGovernanceRequests[allowanceChangeHash] = true;
        return (true, "");

    }

    function disallowChangeAllowance(
        bytes32 allowanceChangeHash, 
        Signature[] calldata signatures
    ) public {
        bool verified = verify(allowanceChangeHash, signatures, 5);

        require(verified, "signature verification failed");
        require(governanceActionQueue[allowanceChangeHash] != 0, "transaction is not in queue");

        governanceActionQueue[allowanceChangeHash] = 0;
    }

}
