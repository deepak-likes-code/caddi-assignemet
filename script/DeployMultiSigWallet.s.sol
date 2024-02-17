//SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {MultiSigWallet} from "../src/MultiSigWallet.sol";

contract DeployMultiSigWallet is Script {
    address[] public owners = [address(0x1), address(0x2), address(0x3)];
    uint256 public constant requiredApprovals = 2;
    MultiSigWallet public wallet;

    function run() public returns (MultiSigWallet) {
        vm.startBroadcast();
        wallet = new MultiSigWallet(owners, requiredApprovals);
        vm.stopBroadcast();
        return wallet;
    }
}
