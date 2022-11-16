// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;
import "openzeppelin/proxy/utils/UUPSUpgradeable.sol";
import "openzeppelin/proxy/utils/Initializable.sol";
import "openzeppelin/token/ERC20/utils/SafeERC20.sol";

import "forge-std/console.sol";

import {VaultStructs} from "./VaultStructs.sol";
import {VaultState} from "./VaultState.sol";
import {VaultGetters} from "./VaultGetters.sol";
import {VaultSetters} from "./VaultSetters.sol";

contract Vault is Initializable, UUPSUpgradeable, VaultStructs, VaultState, VaultGetters, VaultSetters {
    event withdrawPending(bytes32 identifier, address token, uint256 tokenAmount, uint256 requestId, uint256 timestamp);
    event changeLimitPending(bytes32 identifier, address token, uint256 newLimit, uint256 requestId, uint256 timestamp);
    event upgradeContractPending(bytes32 identifier, address newImplementation, uint256 requestId, uint256 timestamp);

    modifier onlyAllowedAddress() {
        require(msg.sender == getAllowedAddress(), "Not allowed address");
        _;
    }

    function initialize(
        address allowedAddress,
        address[] calldata vaultGuardianAddresses,
        address[] calldata tokens,
        uint256[] calldata dailyLimits
    ) external initializer {
        require(tokens.length == dailyLimits.length, "tokens and dailyLimits are of different lengths");

        for(uint i=0; i < vaultGuardianAddresses.length; i++) {
           addVaultGuardian(vaultGuardianAddresses[i]);
        }
        for(uint i=0; i < tokens.length; i++) {
            DailyLimitInfo memory info = DailyLimitInfo({
                dailyLimit: dailyLimits[i],
                used: 0,
                dayStart: block.timestamp
            });
            setTokenDailyLimitInfo(tokens[i], info);
        }

        setAllowedAddress(allowedAddress);        
    }


    function withdraw(
        address token,
        uint256 tokenAmount,
        uint256 requestId
    ) external onlyAllowedAddress returns (bool result, string memory reason){
        
        bytes32 withdrawHash = keccak256(abi.encodePacked(Action.Withdraw, token, tokenAmount, requestId));
        DailyLimitInfo memory info = getTokenDailyLimitInfo(token);

        require(info.dailyLimit != 0, "Token not set in the vault");

        if(info.dayStart + 1 days <= block.timestamp) {
            info.used = 0;
            info.dayStart = block.timestamp;
        }

        bool withinLimits = info.used + tokenAmount <= info.dailyLimit;

        bool isPending;

        (result, reason, isPending) = tryExecutingAction(withdrawHash, withinLimits);

        if(result) {
            info.used += tokenAmount;
        }

        setTokenDailyLimitInfo(token, info);

        if(result) {
            SafeERC20.safeTransfer(IERC20(token), getAllowedAddress(), tokenAmount);
        }

        if(isPending) {
            emit withdrawPending(withdrawHash, token, tokenAmount, requestId, block.timestamp);
        }
    }

    function changeLimit(
        address token,
        uint256 newLimit,
        uint256 requestId,
        Signature[] calldata signatures
    ) external returns (bool result, string memory reason){

        bytes32 allowanceChangeHash = keccak256(abi.encodePacked(Action.ChangeLimit, token, newLimit, requestId));
        
        bool verified = verify(keccak256(abi.encodePacked(ActionType.Allow, allowanceChangeHash)), signatures);

        if(!verified) {
            return(false, "signature verification failed");
        }

        DailyLimitInfo memory info = getTokenDailyLimitInfo(token);

        bool isDecrease = info.dailyLimit >= newLimit;

        bool isPending;

        (result, reason, isPending) = tryExecutingAction(allowanceChangeHash, isDecrease);

        if(result) {
            info.dailyLimit = newLimit;
            setTokenDailyLimitInfo(token, info);
        } 

        if(isPending) {
            emit changeLimitPending(allowanceChangeHash, token, newLimit, requestId, block.timestamp);
        }
    }

    function upgradeContract(
        address newImplementation,
        uint256 requestId,
        Signature[] calldata signatures
    ) external returns (bool result, string memory reason) {

        bytes32 upgradeHash = keccak256(abi.encodePacked(Action.UpgradeContract, newImplementation, requestId));
        bool verified = verify(keccak256(abi.encodePacked(ActionType.Allow, upgradeHash)), signatures);

        if(!verified) {
            return(false, "signature verification failed");
        }
        
        bool isPending;

        (result, reason, isPending) = tryExecutingAction(upgradeHash, false);

        if(result) {
            _upgradeToAndCallUUPS(newImplementation, new bytes(0), false);
        }

        if(isPending) {
            emit upgradeContractPending(upgradeHash, newImplementation, requestId, block.timestamp);
        }

    }

    function disallowAction(bytes32 identifier, Signature[] calldata signatures) external returns (bool result, string memory reason) {
        bool verified = verify(keccak256(abi.encodePacked(ActionType.Disallow, identifier)), signatures);

        if(!verified) {
            return(false, "signature verification failed");
        }

        removeActionFromPendingQueue(identifier);

        return (true, "");
    }

    function tryExecutingAction(bytes32 identifier, bool wouldExecuteInstantly) internal returns (bool shouldExecute, string memory reason, bool isPending) {
        
        uint256 timestampOfAction = pendingActionStatus(identifier);

        if(isActionCompleted(identifier)) {
            shouldExecute = false;
            reason = "Action already completed";
        } else if(timestampOfAction != 0) {
            if(timestampOfAction + 1 days <= block.timestamp) {
                shouldExecute = true;
                removeActionFromPendingQueue(identifier);
            } else {
                shouldExecute = false;
                reason = "Wait 24 hours before completing action";
            }
        } else {
            if(wouldExecuteInstantly) {
                shouldExecute = true;
            } else {
                shouldExecute = false;
                reason = "Action enqueued, wait 24 hours to complete action";
                isPending = true;
                setActionPending(identifier);
            }
        }

        if(shouldExecute){
            setActionCompleted(identifier);
            reason = "";
        }
    }

    function verify(
        bytes32 actionHash, 
        Signature[] calldata signatures
    ) internal returns (bool) {
        return true;
    }

    /// overriding _authorizeUpgrade
    function _authorizeUpgrade(address newImplementation) internal override {
        require(false, "always revert");
    }
   
}
