// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.15;

/// @notice Deploy the bytecode with the CREATE instruction
function deployBytecode(bytes memory bytecode) returns (address) {
    address deployedAddress;
    assembly {
        deployedAddress := create(0, add(bytecode, 0x20), mload(bytecode))
    }

    // Check that the deployment was successful
    require(deployedAddress != address(0), "Could not deploy contract");

    return deployedAddress;
}
