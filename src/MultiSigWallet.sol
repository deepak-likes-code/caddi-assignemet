//SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

// Layout of Contract:
// version
// imports
// errors
// interfaces, libraries, contracts
// Type declarations
// State variables
// Events
// Modifiers
// Functions

// Layout of Functions:
// constructor
// receive function (if exists)
// fallback function (if exists)
// external
// public
// internal
// private
// view & pure functions

/**
 * @title Multi-Signature Wallet Contract
 * @author Deepak Komma
 * @dev Allows multiple owners to collectively approve transactions before execution.
 * @dev submit a transaction
 * @dev approve and revoke approval of pending transactions
 * @dev anyone can execute a transaction after enough owners has approved it.
 */
contract MultiSigWallet is ReentrancyGuard {
    ///////////////////////////////
    ////////// Errors /////////////
    ///////////////////////////////

    error MultiSigWallet__NotOwner();
    error MultiSigWallet__TransactionDoesNotExist(uint256 txIndex);
    error MultiSigWallet__TransactionAlreadyExecuted(uint256 txIndex);
    error MultiSigWallet__TransactionAlreadyApproved(uint256 txIndex);
    error MultiSigWallet__OwnersRequired();
    error MultiSigWallet__InvalidNumberOfConfirmations();
    error MultiSigWallet__InvalidOwnerAddress();
    error MultiSigWallet__OwnerNotUnique();
    error MultiSigWallet__InsufficientApprovals();
    error MultiSigWallet__TransactionExecutionFailed();
    error MultiSigWallet__TransactionNotApproved(uint256 txIndex);

    /////////////////////////////////////
    ////////// State Variables //////////
    /////////////////////////////////////

    address[] public owners;
    mapping(address => bool) public isOwner;
    uint256 public requiredApprovals;

    struct Transaction {
        address to;
        uint256 value;
        bytes data;
        bool executed;
        uint256 approvalCount;
    }

    mapping(uint256 transactionId => mapping(address ownerAddress => bool hasApproved)) public hasApproved;

    Transaction[] public transactions;

    ///////////////////////////////
    ////////// Events /////////////
    ///////////////////////////////

    event FundsDeposited(address indexed sender, uint256 amount, uint256 balance);
    event TransactionProposed(
        address indexed owner, uint256 indexed txIndex, address indexed to, uint256 value, bytes data
    );
    event TransactionApproved(address indexed owner, uint256 indexed txIndex);
    event ApprovalRevoked(address indexed owner, uint256 indexed txIndex);
    event TransactionExecuted(address indexed owner, uint256 indexed txIndex);

    ///////////////////////////////
    ////////// Modifiers //////////
    ///////////////////////////////

    modifier onlyOwner() {
        // Checks if the caller is an owner, reverts with a custom error if not
        if (!isOwner[msg.sender]) revert MultiSigWallet__NotOwner();
        _;
    }

    modifier transactionExists(uint256 _txIndex) {
        // Checks if the transaction exists, reverts with a custom error if it doesn't
        if (_txIndex >= transactions.length) revert MultiSigWallet__TransactionDoesNotExist(_txIndex);
        _;
    }

    modifier notYetExecuted(uint256 _txIndex) {
        // Checks if the transaction has not been executed yet, reverts with a custom error if it has
        if (transactions[_txIndex].executed) revert MultiSigWallet__TransactionAlreadyExecuted(_txIndex);
        _;
    }

    modifier notYetApproved(uint256 _txIndex) {
        // Checks if the transaction has not been approved by the caller yet, reverts with a custom error if it has
        if (hasApproved[_txIndex][msg.sender]) revert MultiSigWallet__TransactionAlreadyApproved(_txIndex);
        _;
    }

    ///////////////////////////////
    ////////// Functions //////////
    ///////////////////////////////

    /**
     * @dev Constructor to initialize the wallet with owners and required number of confirmations.
     * @param _owners Array of owner addresses.
     * @param _requiredApprovals Number of required approvals for a transaction to be executed.
     */
    constructor(address[] memory _owners, uint256 _requiredApprovals) {
        if (_owners.length == 0) revert MultiSigWallet__OwnersRequired();
        if (_requiredApprovals == 0 || _requiredApprovals > _owners.length) {
            revert MultiSigWallet__InvalidNumberOfConfirmations();
        }
        for (uint256 i = 0; i < _owners.length; i++) {
            address owner = _owners[i];

            if (owner == address(0)) revert MultiSigWallet__InvalidOwnerAddress();
            if (isOwner[owner]) revert MultiSigWallet__OwnerNotUnique();

            isOwner[owner] = true;
            owners.push(owner);
        }

        requiredApprovals = _requiredApprovals;
    }

    /**
     * @dev Fallback function to deposit funds into the wallet.
     */
    receive() external payable {
        emit FundsDeposited(msg.sender, msg.value, address(this).balance);
    }

    /**
     * @dev Propose a new transaction by an owner.
     * @param _to Transaction recipient address.
     * @param _value Amount of ether to send.
     * @param _data Transaction data payload.
     */
    function proposeTransaction(address _to, uint256 _value, bytes memory _data) external onlyOwner {
        uint256 txIndex = transactions.length;

        transactions.push(Transaction({to: _to, value: _value, data: _data, executed: false, approvalCount: 0}));

        emit TransactionProposed(msg.sender, txIndex, _to, _value, _data);
    }

    /**
     * @dev Approve a transaction by an owner.
     * @param _txIndex Index of the transaction in the transactions array.
     */
    function approveTransaction(uint256 _txIndex)
        external
        onlyOwner
        transactionExists(_txIndex)
        notYetExecuted(_txIndex)
        notYetApproved(_txIndex)
    {
        Transaction storage transaction = transactions[_txIndex];
        transaction.approvalCount += 1;
        hasApproved[_txIndex][msg.sender] = true;

        emit TransactionApproved(msg.sender, _txIndex);
    }

    /**
     * @dev Execute a transaction after required approvals are met.
     * @param _txIndex Index of the transaction in the transactions array.
     */
    function executeTransaction(uint256 _txIndex)
        external
        onlyOwner
        transactionExists(_txIndex)
        notYetExecuted(_txIndex)
    {
        Transaction storage transaction = transactions[_txIndex];

        if (transaction.approvalCount < requiredApprovals) {
            revert MultiSigWallet__InsufficientApprovals();
        }

        transaction.executed = true;

        (bool success,) = transaction.to.call{value: transaction.value}(transaction.data);

        if (!success) {
            revert MultiSigWallet__TransactionExecutionFailed();
        }

        emit TransactionExecuted(msg.sender, _txIndex);
    }

    /**
     * @dev Revoke approval for a transaction by an owner.
     * @param _txIndex Index of the transaction in the transactions array.
     */
    function revokeApproval(uint256 _txIndex) external onlyOwner transactionExists(_txIndex) notYetExecuted(_txIndex) {
        if (hasApproved[_txIndex][msg.sender] == false) revert MultiSigWallet__TransactionNotApproved(_txIndex);

        Transaction storage transaction = transactions[_txIndex];
        transaction.approvalCount -= 1;
        hasApproved[_txIndex][msg.sender] = false;

        emit ApprovalRevoked(msg.sender, _txIndex);
    }

    /////////////////////////////////////
    ////////// External View Functions //////////
    /////////////////////////////////////

    function getOwners() external view returns (address[] memory) {
        return owners;
    }

    function getTransactionCount() external view returns (uint256) {
        return transactions.length;
    }

    function getTransactionDetails(uint256 _txIndex)
        external
        view
        returns (address to, uint256 value, bytes memory data, bool executed, uint256 approvalCount)
    {
        Transaction storage transaction = transactions[_txIndex];

        return (transaction.to, transaction.value, transaction.data, transaction.executed, transaction.approvalCount);
    }
}
