// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.15;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";

import {DeriveAddress} from "../script/utils/DeriveAddress.sol";

import {IYAC3F, DEPLOYMENT_FAILED_ERROR} from "../src/interfaces/IYAC3F.sol";

import {YAC3F_BYTECODE} from "../script/utils/YAC3F.g.sol";
import {deployBytecode} from "../script/utils/DeployBytecode.sol";

function bytesToAddress(bytes memory _data) pure returns (address) {
    require(_data.length == 32);
    return address(uint160(uint256(bytes32(_data))));
}

contract YAC3FTest is Test {
    // Address of the YAC3F factory contract.
    IYAC3F public create3Factory;

    // Precalculated address of the deployed contract based on Foundry basic testing address
    address public targetAddress;

    // Testing salt (impacts `targetAddress`)
    bytes32 constant SALTALLFF = bytes32(type(uint256).max);

    /// @notice Different ways to call the factory
    /// Returning data are either address of the deployed contract or error
    function callFactory(bytes32 _salt, bytes memory _bytecode) internal returns (bool status, bytes memory data) {
        return address(create3Factory).call(abi.encodePacked(_salt, _bytecode));
    }

    function callFactory(bytes32 _salt, bytes memory _bytecode, uint256 _value)
        internal
        returns (bool status, bytes memory data)
    {
        return address(create3Factory).call{value: _value}(abi.encodePacked(_salt, _bytecode));
    }

    function callFactory(bytes32 _salt, bytes memory _bytecode, uint256 _value, uint256 _gaslimit)
        internal
        returns (bool status, bytes memory data)
    {
        return address(create3Factory).call{value: _value, gas: _gaslimit}(abi.encodePacked(_salt, _bytecode));
    }

    function setUp() public {
        uint256 nonce = vm.getNonce(address(this));

        address expectedFactoryAddress = DeriveAddress.ofFactory(address(this), nonce);

        create3Factory = IYAC3F(deployBytecode(YAC3F_BYTECODE));

        vm.label(address(create3Factory), "YAC3F");

        assertEq(expectedFactoryAddress, address(create3Factory));

        targetAddress = DeriveAddress.fromYAC3F(SALTALLFF, address(this), address(create3Factory));
    }

    // Impact of REVERT in init code:
    // no deployed code, nonce = 0
    // returns address = 0, but returns reason data towards CREATE proxy, which is omitted
    function test_InitCodeHavingRevertWithData() public {
        // 602a PUSH1 42
        // 6000 PUSH1 0
        // 53   MSTORE8
        // 6001 PUSH1 1
        // 6000 PUSH1 0
        // FD   REVERT
        bytes memory bytecode = hex"602a60005360016000FD";

        (bool status, bytes memory data) = callFactory(SALTALLFF, bytecode);

        assertFalse(status);
        assertEq(data, DEPLOYMENT_FAILED_ERROR);
        assertEq(vm.getNonce(targetAddress), 0);
        assertEq(targetAddress.code.length, 0);
    }

    // Impact of REVERT(0,0) in init code:
    // no deployed code, nonce = 0
    // returns address = 0, no reason data towards CREATE proxy
    // ala INVALID, but unused gas is not spent
    // YAC3F reverts, target account remains empty
    function test_InitCodeHavingRevertWithoutData() public {
        // 602a PUSH1 42
        // 6000 PUSH1 0
        // 53   MSTORE8
        // 6000 PUSH1 0
        // 6000 PUSH1 0
        // FD   REVERT
        bytes memory bytecode = hex"602a60005360006000FD";

        (bool status, bytes memory data) = callFactory(SALTALLFF, bytecode);

        assertFalse(status);
        assertEq(data, DEPLOYMENT_FAILED_ERROR);
        assertEq(vm.getNonce(targetAddress), 0);
        assertEq(targetAddress.code.length, 0);
    }

    // Impact of INVALID in init code:
    // no deployed code, nonce = 0
    // returns address = 0, no return data towards CREATE proxy
    // ala revert(0,0), but with all gas spent
    // YAC3F reverts, target account remains empty
    function test_InitCodeHavingInvalidOpcode() public {
        bytes memory bytecode = hex"FE";

        (bool status, bytes memory data) = callFactory(SALTALLFF, bytecode);

        assertFalse(status);
        assertEq(data, DEPLOYMENT_FAILED_ERROR);
        assertEq(vm.getNonce(targetAddress), 0);
        assertEq(targetAddress.code.length, 0);
    }

    // Impact of STOP in init code:
    // no deployed code, but nonce = 1
    // returns address in stack, no return data towards CREATE proxy
    // YAC3F reverts, rollbacks that nonce, target account remains empty
    function test_InitCodeHavingStop() public {
        // 00 STOP
        bytes memory bytecode = hex"00";

        (bool status, bytes memory data) = callFactory(SALTALLFF, bytecode);

        assertFalse(status);
        assertEq(data, DEPLOYMENT_FAILED_ERROR);
        assertEq(vm.getNonce(targetAddress), 0);
        assertEq(targetAddress.code.length, 0);
    }

    // No contract bytecode provided
    // Since there is no code at the target address, init code executes STOP op.
    // Impact of no init code:
    // no deployed code, but nonce = 1
    // returns address in stack, no return data towards CREATE proxy
    // ala STOP case
    // YAC3F reverts, rollbacks that nonce, target account remains empty
    function test_InitCodeEmpty() public {
        bytes memory bytecode = hex"";

        (bool status, bytes memory data) = callFactory(SALTALLFF, bytecode);

        assertFalse(status);
        assertEq(data, DEPLOYMENT_FAILED_ERROR);
        assertEq(vm.getNonce(targetAddress), 0);
        assertEq(targetAddress.code.length, 0);
    }

    // Impact of RETURN(0,0) in init code:
    // no deployed code, but nonce = 1
    // returns address in stack, no return data towards CREATE proxy
    // YAC3F reverts, rollbacks that nonce, target account remains empty
    function test_InitCodeHavingEmptyReturn() public {
        // 6000 PUSH1 0
        // 6000 PUSH1 0
        // F3   RETURN
        bytes memory bytecode = hex"60006000F3";

        (bool status, bytes memory data) = callFactory(SALTALLFF, bytecode);

        assertFalse(status);
        assertEq(data, DEPLOYMENT_FAILED_ERROR);
        assertEq(vm.getNonce(targetAddress), 0);
        assertEq(targetAddress.code.length, 0);
    }

    // Impact of RETURN(x,y) in init code:
    // deployed code, nonce = 1
    // returns address in stack, no return data towards CREATE proxy
    // YAC3F returns address
    function test_InitCodeHavingReturn() public {
        // Runtime code
        // 602a PUSH1 42
        // 6000 PUSH1 0
        // 53   MSTORE8
        // 6001 PUSH1 1
        // 6000 PUSH1 0
        // F3   RETURN
        // 602a60005360016000F3
        //
        // Init code
        // 69xx PUSH10 0x602a60005360016000F3
        // 6000 PUSH1 0
        // 52 MSTORE
        // 600a PUSH1 10
        // 6016 PUSH1 22
        // F3   RETURN
        bytes memory bytecode = hex"69602a60005360016000f3600052600a6016f3";

        address proxy = DeriveAddress.ofCreateProxy(SALTALLFF, address(this), address(create3Factory));
        console.log(proxy);

        targetAddress = DeriveAddress.fromYAC3F(SALTALLFF, address(this), address(create3Factory));
        console.log(targetAddress);

        (bool status, bytes memory data) = callFactory(SALTALLFF, bytecode);

        assertTrue(status);
        assertEq(data.length, 32);
        assertEq(bytesToAddress(data), targetAddress);
        assertEq(vm.getNonce(targetAddress), 1);
        assertEq(targetAddress.code.length, 10);
    }

    function test_RevertIf_DeployingSameBytecodeTwice() public {
        // Runtime code
        // 602a PUSH1 42
        // 6000 PUSH1 0
        // 53   MSTORE8
        // 6001 PUSH1 1
        // 6000 PUSH1 0
        // F3   RETURN
        // 602a60005360016000F3
        //
        // Init code
        // 69xx PUSH10 0x602a60005360016000F3
        // 6000 PUSH1 0
        // 52 MSTORE
        // 600a PUSH1 10
        // 6016 PUSH1 22
        // F3   RETURN
        bytes memory bytecode = hex"69602a60005360016000f3600052600a6016f3";

        (bool status, bytes memory data) = callFactory(SALTALLFF, bytecode);

        assertTrue(status);
        assertEq(bytesToAddress(data), targetAddress);
        assertEq(targetAddress.code.length, 10);

        (bool status2, bytes memory data2) = callFactory(SALTALLFF, bytecode);

        assertFalse(status2);
        assertEq(data2, DEPLOYMENT_FAILED_ERROR);
    }

    function test_RevertIf_DeployingDifferentBytecodeToTheSameAddress() public {
        // Runtime code
        // 602a PUSH1 42
        // 6000 PUSH1 0
        // 53   MSTORE8
        // 6001 PUSH1 1
        // 6000 PUSH1 0
        // F3   RETURN
        // 602a60005360016000F3
        //
        // Init code
        // 69xx PUSH10 0x602a60005360016000F3
        // 6000 PUSH1 0
        // 52 MSTORE
        // 600a PUSH1 10
        // 6016 PUSH1 22
        // F3   RETURN
        bytes memory bytecode = hex"69602a60005360016000f3600052600a6016f3";

        // Runtime code
        // 6040 PUSH1 64
        // 6000 PUSH1 0
        // ...
        bytes memory bytecode2 = hex"69604060005360016000f3600052600a6016f3";

        (bool status, bytes memory data) = callFactory(SALTALLFF, bytecode);

        assertTrue(status);
        assertEq(bytesToAddress(data), targetAddress);
        assertEq(targetAddress.code.length, 10);

        (bool status2, bytes memory data2) = callFactory(SALTALLFF, bytecode2);

        assertFalse(status2);
        assertEq(data2, DEPLOYMENT_FAILED_ERROR);
    }

    // TODO example Mock ERC20

    // TODO example Mock UUPS proxy + ERC20

    // TODO example Mock some AA registry
    // TODO contract with ETH value used in constructor

    // TODO not enough gas tests
    // - at factory code - phase pre CALL
    // - at factory code - phase post CALL
    // - at create proxy code - phase pre CREATE
    // - at create proxy code - phase POST CREATE
    // - at contract's initcode

    // TODO fuzzy tests - salt, bytecode (init part, runtime part) vs predetermined address
}
