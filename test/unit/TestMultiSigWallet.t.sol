//SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test, console} from "forge-std/Test.sol";
import {MultiSigWallet} from "../../src/MultiSigWallet.sol";
import {DeployMultiSigTest} from "../../script/DeployMultiSigTest.s.sol";
import {StdCheats} from "forge-std/StdCheats.sol";

contract MutliSigWalletTest is StdCheats, Test {
    MultiSigWallet wallet;
    address[] owners;
    uint256 requiredApprovals;
    address owner1 = makeAddr("0x1");
    address owner2 = makeAddr("0x2");
    address owner3 = makeAddr("0x3");

    function setUp() public {
        owners = [owner1, owner2, owner3];
        requiredApprovals = 2;
        DeployMultiSigTest deploy = new DeployMultiSigTest(owners, requiredApprovals);
        wallet = deploy.run();
    }

    function testConstructor() public {
        assertEq(wallet.owners(0), address(owner1));
        assertEq(wallet.owners(1), address(owner2));
        assertEq(wallet.owners(2), address(owner3));
        assertEq(wallet.requiredApprovals(), requiredApprovals);
    }

    function testSubmitTransaction() public {
        // Submit a transaction as the first owner
        vm.prank(owners[0]);
        wallet.proposeTransaction(address(0x4), 1 ether, "");

        // Check that the transaction count increased
        assertEq(wallet.getTransactionCount(), 1);
    }

    function testFailProposeTransactionByNonOwner() public {
        // This test is expected to fail as a non-owner tries to propose a transaction
        vm.prank(address(0x5));
        wallet.proposeTransaction(address(0x4), 1 ether, "");
    }

    function testApproveTransaction() public {
        // Setup: Submit a transaction
        vm.prank(owners[0]);
        wallet.proposeTransaction(address(0x4), 1 ether, "");

        // Second owner approves the transaction
        vm.prank(owners[1]);
        wallet.approveTransaction(0);

        // Check approval count for the transaction
        (,,,, uint256 approvalCount) = wallet.getTransactionDetails(0);
        assertEq(approvalCount, 1);
    }

    function testExecuteTransaction() public {
        // Propose and approve a transaction first
        vm.prank(owners[0]);
        wallet.proposeTransaction(address(0x4), 1 ether, "");
        vm.prank(owners[1]);
        wallet.approveTransaction(0);

        vm.prank(owners[2]);
        wallet.approveTransaction(0);

        // Execute the transaction
        vm.prank(owners[0]);
        wallet.executeTransaction(0);

        // Verify that the transaction has been executed
        (,,, bool executed,) = wallet.getTransactionDetails(0);
        console.log("executed:", executed);
        assertTrue(executed);
    }
}
