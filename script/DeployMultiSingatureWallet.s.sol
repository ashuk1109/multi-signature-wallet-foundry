// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Script} from "forge-std/Script.sol";
import {MultiSignatureWallet as Wallet} from "../src/MultiSignatureWallet.sol";
import {HelperConfig} from "./HelperConfig.s.sol";

contract DeployMultiSignatureWallet is Script, HelperConfig {
    function run() external returns (Wallet) {
        (
            address[] memory owners,
            uint256 approvalsRequired
        ) = getConstructorConfig();
        vm.startBroadcast();
        Wallet wallet = new Wallet(owners, approvalsRequired);
        vm.stopBroadcast();
        return wallet;
    }
}
