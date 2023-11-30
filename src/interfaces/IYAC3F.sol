// SPDX-License-Identifier: MIT
pragma solidity >=0.8.4;

// For testing purposes due to expectRevert behaviour
bytes constant DEPLOYMENT_FAILED_ERROR = abi.encodeWithSelector(0x30116425);

interface IYAC3F {
    /// @notice Reverts with this error when bytecode was not deployed
    error DeploymentFailed(); // 0x30116425
}
