// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

contract HelperConfig {
    function getConstructorConfig()
        internal
        pure
        returns (address[] memory, uint256)
    {
        address[] memory owners = new address[](4);
        uint256 approvalsRequired = 3;
        owners[0] = address(0x100);
        owners[1] = address(0x200);
        owners[2] = address(0x300);
        owners[3] = address(0x400);

        return (owners, approvalsRequired);
    }
}
