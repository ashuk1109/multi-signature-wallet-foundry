// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

interface MultiSignatureWalletEvents {
    /** Events */
    event TxSubmitted(
        uint256 indexed txIndex,
        address to,
        uint256 value,
        bytes data
    );
    event TxApproved(uint256 indexed txIndex, address owner);
    event TxExecuted(uint256 indexed txIndex, address owner);
    event TxCancelled(uint256 indexed txIndx, address owner);
    event TxCancelledAndRemoved(uint256 indexed txIndx, address owner);
}

contract MultiSignatureWallet is MultiSignatureWalletEvents {
    /** Errors */
    error MultiSignatureWallet__OnlyOwner();
    error MultiSignatureWallet__InvalidTxId();
    error MultiSignatureWallet__TxAlreadyApproved();
    error MultiSignatureWallet__TxAlreadyExecuted();
    error MultiSignatureWallet__EthTransferFailed();
    error MultiSignatureWallet__TxNotApproved();
    error MultiSignatureWallet__AtleastOneOwnerRequired();
    error MultiSignatureWallet__InvalidApprovalCount();
    error MultiSignatureWallet__InvalidOwner();
    error MultiSignatureWallet__OwnerAlreadyExists();

    /** Type Declarations */
    struct Transaction {
        address to;
        uint256 value;
        bytes data;
        bool executed;
        uint256 approvals;
    }

    /** Variables */
    address public immutable i_owner;
    address[] public s_owners;
    uint256 public s_approvalsRequired;
    Transaction[] public s_transactions;
    mapping(address => bool) public s_isOwner;
    mapping(uint256 => mapping(address => bool)) public s_isApproved;
    mapping(uint256 => address) public s_transactionSubmittedBy;

    /** Modifiers */
    modifier onlyOwner() {
        if (!s_isOwner[msg.sender]) {
            revert MultiSignatureWallet__OnlyOwner();
        }
        _;
    }

    modifier validTx(uint256 txIndex) {
        if (txIndex >= s_transactions.length) {
            revert MultiSignatureWallet__InvalidTxId();
        }
        _;
    }

    modifier notExecuted(uint256 txIndex) {
        if (s_transactions[txIndex].executed) {
            revert MultiSignatureWallet__TxAlreadyExecuted();
        }
        _;
    }

    modifier notApproved(uint256 txIndex) {
        if (s_isApproved[txIndex][msg.sender]) {
            revert MultiSignatureWallet__TxAlreadyApproved();
        }
        _;
    }

    /** Functions */
    constructor(address[] memory _owners, uint256 _approvalsRequired) {
        if (_owners.length <= 0) {
            revert MultiSignatureWallet__AtleastOneOwnerRequired();
        }

        if (_approvalsRequired > _owners.length || _approvalsRequired <= 0) {
            revert MultiSignatureWallet__InvalidApprovalCount();
        }

        for (uint256 i = 0; i < _owners.length; i++) {
            if (_owners[i] == address(0)) {
                revert MultiSignatureWallet__InvalidOwner();
            }

            if (s_isOwner[_owners[i]]) {
                revert MultiSignatureWallet__OwnerAlreadyExists();
            }
            s_owners.push(_owners[i]);
            s_isOwner[_owners[i]] = true;
        }

        s_approvalsRequired = _approvalsRequired;
        i_owner = msg.sender;
        s_isOwner[i_owner] = true;
    }

    function submitTransaction(
        address _to,
        bytes memory _data
    ) public payable onlyOwner {
        uint256 txIndex = s_transactions.length;
        uint256 _value = msg.value;
        s_transactions.push(
            Transaction({
                to: _to,
                value: _value,
                data: _data,
                executed: false,
                approvals: 0
            })
        );

        s_transactionSubmittedBy[txIndex] = msg.sender;

        emit TxSubmitted(txIndex, _to, _value, _data);
    }

    function approveTranscation(
        uint256 _txIndex
    )
        public
        onlyOwner
        validTx(_txIndex)
        notExecuted(_txIndex)
        notApproved(_txIndex)
    {
        Transaction storage txn = s_transactions[_txIndex];
        txn.approvals++;
        s_isApproved[_txIndex][msg.sender] = true;

        emit TxApproved(_txIndex, msg.sender);
    }

    function executeTransaction(
        uint256 _txIndex
    ) public payable onlyOwner validTx(_txIndex) notExecuted(_txIndex) {
        Transaction storage txn = s_transactions[_txIndex];

        if (txn.approvals < s_approvalsRequired) {
            revert MultiSignatureWallet__TxNotApproved();
        }
        (bool success, ) = txn.to.call{value: txn.value}(txn.data);
        if (!success) {
            revert MultiSignatureWallet__EthTransferFailed();
        }
        txn.executed = true;

        emit TxExecuted(_txIndex, msg.sender);
    }

    function cancelTransaction(
        uint256 _txIndex
    ) public onlyOwner validTx(_txIndex) notExecuted(_txIndex) {
        Transaction storage txn = s_transactions[_txIndex];
        if (!s_isApproved[_txIndex][msg.sender]) {
            revert MultiSignatureWallet__TxNotApproved();
        }

        txn.approvals--;
        s_isApproved[_txIndex][msg.sender] = false;

        if (txn.approvals == 0) {
            address submittedBy = s_transactionSubmittedBy[_txIndex];
            (bool success, ) = submittedBy.call{value: txn.value}(txn.data);
            if (!success) {
                revert MultiSignatureWallet__EthTransferFailed();
            }

            delete s_transactionSubmittedBy[_txIndex];
            removeTransaction(_txIndex);

            emit TxCancelledAndRemoved(_txIndex, msg.sender);
        } else {
            emit TxCancelled(_txIndex, msg.sender);
        }
    }

    function removeTransaction(uint256 index) internal {
        s_transactions[index] = s_transactions[s_transactions.length - 1];
        s_transactions.pop();
    }

    /** Getter Functions */
    function getOwners() public view returns (address[] memory) {
        return s_owners;
    }

    function getTransaction(
        uint256 _txIndex
    )
        public
        view
        returns (
            address to,
            uint256 value,
            bytes memory data,
            bool executed,
            uint256 approvals
        )
    {
        Transaction storage txn = s_transactions[_txIndex];
        return (txn.to, txn.value, txn.data, txn.executed, txn.approvals);
    }

    function isTransactionApproved(
        uint256 _txIndex,
        address _owner
    ) external view returns (bool) {
        return s_isApproved[_txIndex][_owner];
    }

    function getNumberOfTransactions() public view returns (uint256) {
        return s_transactions.length;
    }
}

/**
 * 0x5B38Da6a701c568545dCfcB03FcB875f56beddC4
 *[ 0xAb8483F64d9C6d1EcF9b849Ae677dD3315835cb2 , 0x4B20993Bc481177ec7E8f571ceCaE8A9e22C02db, 0x78731D3Ca6b7E34aC0F824c42a7cC18A495cabaB]
 * 0x4B20993Bc481177ec7E8f571ceCaE8A9e22C02db
 * 0x78731D3Ca6b7E34aC0F824c42a7cC18A495cabaB
 * 0x1aE0EA34a72D944a8C7603FfB3eC30a6669E454C
 *
 */
