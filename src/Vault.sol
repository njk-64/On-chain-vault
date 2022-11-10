// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;
import "openzeppelin/proxy/utils/UUPSUpgradeable.sol";
import "openzeppelin/proxy/utils/Initializable.sol";
import "openzeppelin/token/ERC20/utils/SafeERC20.sol";

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

    function withdrawRequest(
        bytes32 vaaHash,
        address requestedToken,
        uint256 requestedTokenAmount
    ) public returns (bool, string memory reason){

        if(completedWithdrawRequests[vaaHash] == true) {
            return(false, "allowance already withdrawn");
        }

        if(msg.sender != allowedAddress) {
            return(false, "address requesting allowance is not allowed");
        }

        uint256 enqueuedTimestamp = largeWithdrawQueue[vaaHash];

        if(enqueuedTimestamp != 0) {
            if(enqueuedTimestamp + 1 days <= block.timestamp) {
                largeWithdrawQueue[vaaHash] = 0;
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
                largeWithdrawQueue[vaaHash] = block.timestamp;
                tokenDailyAllowanceDetails[requestedToken] = allowanceDetails;
                return(false, "transaction enqueued, wait 24 hours to withdraw");
            } else {
                allowanceDetails.usedDailyAllowance += requestedTokenAmount;
                tokenDailyAllowanceDetails[requestedToken] = allowanceDetails;
            }

        }

        IERC20 transferToken = IERC20(requestedToken);
        SafeERC20.safeTransfer(transferToken, allowedAddress, requestedTokenAmount);
        completedWithdrawRequests[vaaHash] = true;
        return(true, "");

    }

    function verify(
        bytes32 vaaHash, 
        Signature[] calldata signatures
    ) internal returns (bool){
        /// some signature verification
        return true;
    }

    /// overriding _authorizeUpgrade
    function _authorizeUpgrade(address newImplementation) internal override {
        require(false, "always revert");
    }

    function disallowLargeWithdraw(
        bytes32 vaaHash, 
        Signature[] calldata signatures
    ) public {
        bool verified = verify(vaaHash, signatures);

        require(verified, "signature verification failed");
        require(largeWithdrawQueue[vaaHash] != 0, "transaction is not in queue");

        largeWithdrawQueue[vaaHash] = 0;
    }

    function upgradeContract(
        address newImplementation,
        Signature[] calldata signatures
    ) public {
        /// action 1 is upgradeContract
        bytes32 upgradeHash = keccak256(abi.encodePacked(uint8(1), newImplementation));
        bool verified = verify(upgradeHash, signatures);

        require(verified, "signature verification failed");
        require(!completedGovernanceRequests[upgradeHash], "upgrade can't be replayed");

        _upgradeToAndCallUUPS(newImplementation, new bytes(0), false);

        completedGovernanceRequests[upgradeHash] = true;
        /// check to ensure contract doesn't get bricked
    }

    function changeAllowance(
        address token,
        uint256 newAllowance,
        Signature[] calldata signatures
    ) public returns (bool, string memory reason){
        /// action 2 is changeAllowance
        bytes32 allowanceChangeHash = keccak256(abi.encodePacked(uint(2), token, newAllowance));
        bool verified = verify(allowanceChangeHash, signatures);

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
        bool verified = verify(allowanceChangeHash, signatures);

        require(verified, "signature verification failed");
        require(governanceActionQueue[allowanceChangeHash] != 0, "transaction is not in queue");

        governanceActionQueue[allowanceChangeHash] = 0;
    }

}
