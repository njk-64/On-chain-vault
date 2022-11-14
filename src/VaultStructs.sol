// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

contract VaultStructs {

    struct DailyLimitInfo {
        uint256 dailyLimit;
        uint256 used;
        uint256 dayStart;
    }

    struct Signature {
        /// signature struct --> modify this with signature fields
        uint256 fillerField;
    }

    enum Action {Withdraw, ChangeLimit, UpgradeContract}

    enum ActionType {Allow, Disallow}

}
