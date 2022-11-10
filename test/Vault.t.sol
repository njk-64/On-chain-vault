// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/Vault.sol";

import {IERC20} from "openzeppelin/token/ERC20/IERC20.sol";

contract VaultTest is Test {
    Vault public vault;

    address[] assets;
 
    function setUp() public {
        vault = new Vault();
        assets.push(0xB97EF9Ef8734C71904D8002F8b6Bc66Dd9c48a6E); // 10 billion USDC

        address[] memory vaultGuardianAddresses = new address[](1);
        vaultGuardianAddresses[0] = address(this);

        uint256[] memory initialDailyLimits = new uint256[](1);
        initialDailyLimits[0] = 1 * 10 ** 6;

         
        
        vault.initialize(
            address(this),
            vaultGuardianAddresses,
            assets,
            initialDailyLimits
        );
    }

    function testNormalFlow() public {

        deal(assets[0], address(vault), 1 * 10 ** 16);
        
        bool result; 
        string memory reason;
        (result, reason) = vault.withdrawRequest(bytes32("request hash 1"), assets[0], 1 * 10 ** 5);
        require(result, reason);
        (result, reason) = vault.withdrawRequest(bytes32("request hash 2"), assets[0], 1 * 10 ** 5);
        require(result, reason);
        (result, reason) = vault.withdrawRequest(bytes32("request hash 3"), assets[0], 1 * 10 ** 5);
        require(result, reason);
        (result, reason) = vault.withdrawRequest(bytes32("request hash 4"), assets[0], 1 * 10 ** 5);
        require(result, reason);

        skip(1 days);
    }
}
