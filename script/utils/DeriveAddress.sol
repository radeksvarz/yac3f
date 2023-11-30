// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {CREATE_PROXY_BYTECODE_HASH} from "./YAC3F.g.sol";

/// @notice To be used in Deploy scripts. Not optimised for onchain usage.
library DeriveAddress {
    /// @notice Determines the address of the contract deployed using YAC3F Create3 factory
    /// @param salt A unique value to differentiate deployed contracts. Salt is combined with creator to prevent
    /// front-running, creating namespace for each caller.
    /// @param creator The address of the creator deploying the contract using YAC3F.
    /// @param create3Factory The address of the YAC3F (Create3 factory) contract.
    /// @return The address of the newly created contract.
    function fromYAC3F(bytes32 salt, address creator, address create3Factory) public pure returns (address) {
        address createProxyAddress = ofCreateProxy(salt, creator, create3Factory);

        return fromCreate(createProxyAddress, 1);
    }

    /// @notice Determines the address of the YAC3F Create3 factory
    /// @param creator To be msg.sender deploying the YAC3F factory
    /// @param nonce To be nonce of the msg.sender deploying the YAC3F factory
    function ofFactory(address creator, uint256 nonce) public pure returns (address) {
        return fromCreate(creator, nonce);
    }

    /// @notice Determines the address of the YAC3F Create3 factory
    /// @param salt A unique value to differentiate deployed contracts. Salt is combined with creator to prevent
    /// front-running, creating namespace for each caller.
    /// @param creator To be msg.sender deploying the YAC3F factory
    /// @param create3Factory Address of the YAC3F Create3 factory
    function ofCreateProxy(bytes32 salt, address creator, address create3Factory) public pure returns (address) {
        // YAC3F hashes provided salt with msg.sender to prevent front-running, creating namespace for each caller.
        bytes32 _salt = keccak256(abi.encodePacked(salt, uint256(uint160(creator))));

        return fromCreate2(_salt, create3Factory, CREATE_PROXY_BYTECODE_HASH);
    }

    /// @notice Determines the address of the contract to be deployed using CREATE2
    /// @param salt A unique value to differentiate deployed contracts.
    /// @param creator To be msg.sender deploying the contract
    /// @param initCodeHash Bytecode (initialization_code) of the deployed contract
    /// @dev address = keccak256(0xff + sender_address + salt + keccak256(initialisation_code))[12:]
    function fromCreate2(bytes32 salt, address creator, bytes32 initCodeHash) public pure returns (address) {
        return address(uint160(uint256(keccak256(abi.encodePacked(bytes1(0xFF), creator, salt, initCodeHash)))));
    }

    /// @notice Determines the address of the contract to be deployed using CREATE
    /// @param creator To be msg.sender deploying the contract
    /// @param nonce To be nonce of the msg.sender deploying the contract
    function fromCreate(address creator, uint256 nonce) public pure returns (address) {
        require(nonce < 0x100000000, "Nonce too high (2^32+), not realistic");

        if (nonce == 0x00) {
            return address(
                uint160(uint256(keccak256(abi.encodePacked(bytes1(0xd6), bytes1(0x94), creator, bytes1(0x80)))))
            );
        }
        if (nonce <= 0x7f) {
            return address(
                uint160(uint256(keccak256(abi.encodePacked(bytes1(0xd6), bytes1(0x94), creator, uint8(nonce)))))
            );
        }
        if (nonce <= 0xff) {
            return address(
                uint160(
                    uint256(
                        keccak256(abi.encodePacked(bytes1(0xd7), bytes1(0x94), creator, bytes1(0x81), uint8(nonce)))
                    )
                )
            );
        }
        if (nonce <= 0xffff) {
            return address(
                uint160(
                    uint256(
                        keccak256(abi.encodePacked(bytes1(0xd8), bytes1(0x94), creator, bytes1(0x82), uint16(nonce)))
                    )
                )
            );
        }
        if (nonce <= 0xffffff) {
            return address(
                uint160(
                    uint256(
                        keccak256(abi.encodePacked(bytes1(0xd9), bytes1(0x94), creator, bytes1(0x83), uint24(nonce)))
                    )
                )
            );
        }
        return address(
            uint160(
                uint256(keccak256(abi.encodePacked(bytes1(0xda), bytes1(0x94), creator, bytes1(0x84), uint32(nonce))))
            )
        ); // more than 2^32 nonces not realistic
    }
}
