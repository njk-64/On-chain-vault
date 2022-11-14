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

    modifier onlyAllowedAddress() {
        require(msg.sender == getAllowedAddress(), "Not allowed address");
        _;
    }

    function initialize(
        address tokenBridgeAddress,
        address[] calldata vaultGuardianAddresses,
        address[] calldata tokens,
        uint256[] calldata dailyLimits
    ) public initializer {
        require(tokens.length == dailyLimits.length, "tokens and dailyLimits are of different lengths");

        for(uint i=0; i < vaultGuardianAddresses.length; i++) {
           addVaultGuardian(vaultGuardianAddresses[i]);
        }
        for(uint i=0; i < tokens.length; i++) {
            setTokenDailyLimit(tokens[i], dailyLimits[i]);
        }

        setAllowedAddress(tokenBridgeAddress);        
    }


    function withdraw(
        address token,
        uint256 tokenAmount,
        uint256 requestId
    ) public onlyAllowedAddress returns (bool result, string memory reason){
        
        bytes32 withdrawHash = keccak256(abi.encodePacked(Action.Withdraw, token, tokenAmount, requestId));
        DailyLimitInfo memory info = getTokenDailyLimitInfo(token);

        if(info.dayStart + 1 days <= block.timestamp) {
            resetTokenDailyLimit(token);
            info = getTokenDailyLimitInfo(token);
        }

        bool withinLimits = info.used + tokenAmount <= info.dailyLimit;

        (result, reason) = tryExecutingAction(withdrawHash, withinLimits);

        if(result) {
            updateDailyUsed(token, tokenAmount);
            SafeERC20.safeTransfer(IERC20(token), getAllowedAddress(), tokenAmount);
        }
    }

    function changeLimit(
        address token,
        uint256 newLimit,
        uint256 requestId,
        Signature[] calldata signatures
    ) public returns (bool result, string memory reason){

        bytes32 allowanceChangeHash = keccak256(abi.encodePacked(Action.ChangeLimit, token, newLimit, requestId));
        
        bool verified = verify(keccak256(abi.encodePacked(ActionType.Allow, allowanceChangeHash)), signatures);

        if(!verified) {
            return(false, "signature verification failed");
        }

        bool isDecrease = getTokenDailyLimitInfo(token).dailyLimit >= newLimit;

        (result, reason) = tryExecutingAction(allowanceChangeHash, isDecrease);

        if(result) {
            setTokenDailyLimit(token, newLimit);
        } 
    }

    function upgradeContract(
        address newImplementation,
        uint256 requestId,
        Signature[] calldata signatures
    ) public returns (bool result, string memory reason) {

        bytes32 upgradeHash = keccak256(abi.encodePacked(Action.UpgradeContract, newImplementation, requestId));
        bool verified = verify(keccak256(abi.encodePacked(ActionType.Allow, upgradeHash)), signatures);

        if(!verified) {
            return(false, "signature verification failed");
        }
        
        (result, reason) = tryExecutingAction(upgradeHash, false);

        if(result) {
            _upgradeToAndCallUUPS(newImplementation, new bytes(0), false);
        }

    }

    function disallowAction(bytes32 identifier, Signature[] calldata signatures) public returns (bool result, string memory reason) {
        bool verified = verify(keccak256(abi.encodePacked(ActionType.Disallow, identifier)), signatures);

        if(!verified) {
            return(false, "signature verification failed");
        }

        removeActionFromPendingQueue(identifier);

        return (true, "");
    }




    function tryExecutingAction(bytes32 identifier, bool wouldExecuteInstantly) internal returns (bool shouldExecute, string memory reason) {
        
        if(isActionCompleted(identifier)) {
            shouldExecute = false;
            reason = "Action already completed";
        } else if(pendingActionStatus(identifier) != 0) {
            if(pendingActionStatus(identifier) + 1 days <= block.timestamp) {
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
