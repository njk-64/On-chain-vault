// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {IERC20} from "openzeppelin/token/ERC20/IERC20.sol";
import {Vault} from "../src/Vault.sol";

contract TestState {
    Vault vault;
    address[] assets;
}
