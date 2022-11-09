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
    mapping(bytes32 => uint256) governanceActionReplayProtect;
    mapping (bytes32 => bool) completedWithdrawRequests;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() initializer {}

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
        bytes32 upgradeHash, 
        Signature[] calldata signatures
    ) public {
        require(keccak256(abi.encodePacked(newImplementation)) == upgradeHash, "upgrade hash doesn't match with new implementation address");
        
        bool verified = verify(upgradeHash, signatures);

        require(verified, "signature verification failed");
        require(governanceActionReplayProtect[upgradeHash] == 0, "upgrade can't be replayed");

        _upgradeToAndCallUUPS(newImplementation, new bytes(0), false);

        governanceActionReplayProtect[upgradeHash] = block.timestamp;
        /// check to ensure contract doesn't get bricked
    }

    function changeAllowance(
        address token,
        uint256 newAllowance,
        Signature[] calldata signatures
    ) public {
        /// change allowance code
    }

}
