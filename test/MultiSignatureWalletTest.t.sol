// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Test, console} from "forge-std/Test.sol";
import {StdCheats} from "forge-std/StdCheats.sol";
import {MultiSignatureWallet, MultiSignatureWalletEvents as events} from "../src/MultiSignatureWallet.sol";
import {DeployMultiSignatureWallet} from "../script/DeployMultiSingatureWallet.s.sol";

contract MultiSignatureWalletTest is StdCheats, Test {
    DeployMultiSignatureWallet deployer;
    MultiSignatureWallet wallet;
    address[] owners;
    address walletOwner;

    function setUp() external {
        deployer = new DeployMultiSignatureWallet();
        wallet = deployer.run();
        owners = wallet.getOwners();
        for (uint8 i = 0; i < owners.length; i++) {
            vm.deal(owners[i], 500 ether);
        }
        walletOwner = wallet.i_owner();
        vm.deal(walletOwner, 500 ether);
        vm.deal(address(0x22), 500 ether);
    }

    function testConstructorRevertsWhenNoOwners() external {
        address[] memory _owners;
        vm.expectRevert(
            MultiSignatureWallet
                .MultiSignatureWallet__AtleastOneOwnerRequired
                .selector
        );
        new MultiSignatureWallet(_owners, 1);
    }

    function testConstructorRevertsWhenInvalidApprovals() external {
        vm.expectRevert(
            MultiSignatureWallet
                .MultiSignatureWallet__InvalidApprovalCount
                .selector
        );
        new MultiSignatureWallet(owners, 0);
        vm.expectRevert(
            MultiSignatureWallet
                .MultiSignatureWallet__InvalidApprovalCount
                .selector
        );
        new MultiSignatureWallet(owners, 100);
    }

    function testConsturctorRevertsWhenOwnerHasInvalidAddress() external {
        address[] memory _owners = new address[](2);
        _owners[0] = address(0x1234e);
        _owners[1] = address(0);
        vm.expectRevert(
            MultiSignatureWallet.MultiSignatureWallet__InvalidOwner.selector
        );
        new MultiSignatureWallet(_owners, 1);
    }

    function testConstructorRevertsWhenOwnerIsDuplicated() external {
        address[] memory _owners = new address[](2);
        _owners[0] = address(0x1234e);
        _owners[1] = address(0x1234e);
        vm.expectRevert(
            MultiSignatureWallet
                .MultiSignatureWallet__OwnerAlreadyExists
                .selector
        );
        new MultiSignatureWallet(_owners, 1);
    }

    function testOwner() external {
        assertEq(msg.sender, wallet.i_owner());
        assertEq(owners.length, 4);
    }

    function testSubmitTx() external {
        submitTx(owners[0], address(0x22), 2 ether);

        (
            address to,
            uint256 value,
            bytes memory data,
            bool executed,
            uint256 approvals
        ) = wallet.getTransaction(0);

        assertEq(wallet.getNumberOfTransactions(), 1);
        assertEq(to, address(0x22));
        assertEq(value, 2 ether);
        assertEq(data, "");
        assertEq(executed, false);
        assertEq(approvals, 0);
    }

    function testSubmitTxEmitsEvent() external {
        vm.startPrank(owners[0]);
        vm.expectEmit(true, false, false, true);
        emit events.TxSubmitted(0, address(0x22), 2 ether, "");
        wallet.submitTransaction{value: 2 ether}(address(0x22), "");
        vm.stopPrank();
    }

    function testSubmitTxRevertsOnlyOwner() external {
        vm.expectRevert(
            MultiSignatureWallet.MultiSignatureWallet__OnlyOwner.selector
        );
        wallet.submitTransaction{value: 2 ether}(address(0x22), "");
    }

    function testApproveTx() external {
        submitTx(owners[0], address(0x22), 2 ether);
        vm.startPrank(owners[2]);
        vm.expectEmit(true, false, false, true);
        emit events.TxApproved(0, owners[2]);
        wallet.approveTranscation(0);
        vm.stopPrank();

        (, , , bool executed, uint256 approvals) = wallet.getTransaction(0);

        assertEq(approvals, 1);
        assertEq(executed, false);
        assert(wallet.isTransactionApproved(0, owners[2]));
    }

    function testApproveTxReverts() external {
        submitTx(owners[0], address(0x22), 2 ether);

        // Reverts when not called by owner
        vm.expectRevert(
            MultiSignatureWallet.MultiSignatureWallet__OnlyOwner.selector
        );
        wallet.approveTranscation(0);

        // Reverts when invalid id passed by owner
        vm.startPrank(owners[2]);
        uint256 id = wallet.getNumberOfTransactions();
        vm.expectRevert(
            MultiSignatureWallet.MultiSignatureWallet__InvalidTxId.selector
        );
        wallet.approveTranscation(id);

        // Reverts when owner tries to reapprove
        wallet.approveTranscation(0);
        vm.expectRevert(
            MultiSignatureWallet
                .MultiSignatureWallet__TxAlreadyApproved
                .selector
        );
        wallet.approveTranscation(0);
        vm.stopPrank();
    }

    function testApproveTxRevertsWhenTxExecuted() external {
        submitTx(owners[0], address(0x22), 2 ether);
        for (uint8 i = 0; i < 3; i++) {
            vm.startPrank(owners[i]);
            wallet.approveTranscation(0);
            vm.stopPrank();
        }
        vm.startPrank(owners[0]);
        wallet.executeTransaction(0);
        vm.expectRevert(
            MultiSignatureWallet
                .MultiSignatureWallet__TxAlreadyExecuted
                .selector
        );
        wallet.approveTranscation(0);
        vm.stopPrank();
    }

    function testExecuteReverts() external {
        submitTx(owners[0], address(0x22), 2 ether);

        // Reverts when not called by owner
        vm.expectRevert(
            MultiSignatureWallet.MultiSignatureWallet__OnlyOwner.selector
        );
        wallet.executeTransaction(0);

        vm.startPrank(walletOwner);
        // Reverts when invalid id passed by owner
        uint256 id = wallet.getNumberOfTransactions();
        vm.expectRevert(
            MultiSignatureWallet.MultiSignatureWallet__InvalidTxId.selector
        );
        wallet.executeTransaction(id);

        // Reverts when txn doesnt have required approvals
        vm.expectRevert(
            MultiSignatureWallet.MultiSignatureWallet__TxNotApproved.selector
        );
        wallet.executeTransaction(0);
        vm.stopPrank();
    }

    function testExecute() external {
        submitTx(owners[0], address(0x22), 2 ether);
        approveTx();
        vm.startPrank(walletOwner);
        vm.expectEmit(true, false, false, true);
        emit events.TxExecuted(0, walletOwner);
        wallet.executeTransaction(0);
        vm.stopPrank();
    }

    function testExecuteRevertsWhenAlreadyExecuted() external {
        executeTx();
        vm.startPrank(walletOwner);
        vm.expectRevert(
            MultiSignatureWallet
                .MultiSignatureWallet__TxAlreadyExecuted
                .selector
        );
        wallet.executeTransaction(0);
        vm.stopPrank();
    }

    function testCancelTx() external {
        submitTx(owners[0], address(0x22), 2 ether);
        approveTx();
        vm.startPrank(owners[0]);
        vm.expectEmit(true, false, false, true);
        emit events.TxCancelled(0, owners[0]);
        wallet.cancelTransaction(0);
        vm.stopPrank();
        assertEq(wallet.isTransactionApproved(0, owners[0]), false);
    }

    function testCancelTxReverts() external {
        submitTx(owners[0], address(0x22), 2 ether);
        approveTx();
        // Reverts when not owner
        vm.expectRevert(
            MultiSignatureWallet.MultiSignatureWallet__OnlyOwner.selector
        );
        wallet.cancelTransaction(0);

        vm.startPrank(owners[0]);
        // Reverts when not valid txId
        uint256 id = wallet.getNumberOfTransactions();
        vm.expectRevert(
            MultiSignatureWallet.MultiSignatureWallet__InvalidTxId.selector
        );
        wallet.cancelTransaction(id);

        // Reverts when txn not approved
        // remove contract approval for owners[0]
        wallet.cancelTransaction(0);
        vm.expectRevert(
            MultiSignatureWallet.MultiSignatureWallet__TxNotApproved.selector
        );
        wallet.cancelTransaction(0);
        vm.stopPrank();
    }

    function testCancelTxRevertsWhenTxAlreadyExecuted() external {
        executeTx();
        vm.startPrank(walletOwner);
        vm.expectRevert(
            MultiSignatureWallet
                .MultiSignatureWallet__TxAlreadyExecuted
                .selector
        );
        wallet.cancelTransaction(0);
        vm.stopPrank();
    }

    function testTxAllCancellations() external {
        submitTx(owners[0], address(0x22), 2 ether);
        assertEq(address(wallet).balance, 2 ether);
        assertEq(wallet.getNumberOfTransactions(), 1);
        approveTx();
        for (uint8 i = 0; i < owners.length; i++) {
            vm.startPrank(owners[i]);
            wallet.cancelTransaction(0);
            vm.stopPrank();
        }

        assertEq(address(wallet).balance, 0);
        assertEq(wallet.getNumberOfTransactions(), 0);
        assertEq(wallet.s_transactionSubmittedBy(0), address(0));
    }

    function submitTx(address sender, address to, uint256 value) private {
        vm.startPrank(sender);
        wallet.submitTransaction{value: value}(to, "");
        vm.stopPrank();
    }

    function approveTx() private {
        for (uint8 i = 0; i < owners.length; i++) {
            vm.startPrank(owners[i]);
            wallet.approveTranscation(0);
            vm.stopPrank();
        }
    }

    function executeTx() private {
        submitTx(owners[0], address(0x22), 2 ether);
        approveTx();
        vm.startPrank(walletOwner);
        wallet.executeTransaction(0);
        vm.stopPrank();
    }
}
