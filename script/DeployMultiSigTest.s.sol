//SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {MultiSigWallet} from "../src/MultiSigWallet.sol";

contract DeployMultiSigTest is Script {
    address[] public owners;
    uint256 public requiredApprovals;
    MultiSigWallet public wallet;

    constructor(address[] memory _owners, uint256 _requiredApprovals) {
        owners = _owners;
        requiredApprovals = _requiredApprovals;
    }

    function run() public returns (MultiSigWallet) {
        vm.startBroadcast();
        wallet = new MultiSigWallet(owners, requiredApprovals);
        vm.stopBroadcast();
        return wallet;
    }
}
