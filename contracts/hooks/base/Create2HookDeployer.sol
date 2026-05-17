// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { BaseV4HookAddressMiner } from "./BaseV4HookAddressMiner.sol";

contract Create2HookDeployer {
    address public immutable owner;

    error BadHookPermissionBits(address hookAddress, uint160 actualMask, uint160 expectedMask);
    error Create2DeployFailed(bytes32 salt, bytes32 initCodeHash);
    error EmptyInitCode();
    error InvalidOwner();
    error NotOwner();

    event Deployed(address indexed deployed, bytes32 indexed salt, bytes32 initCodeHash);

    constructor(address owner_) {
        if (owner_ == address(0)) revert InvalidOwner();

        owner = owner_;
    }

    function deploy(bytes32 salt, bytes memory initCode)
        external
        onlyOwner
        returns (address deployed)
    {
        bytes32 initCodeHash = _initCodeHash(initCode);

        deployed = _deploy(salt, initCode, initCodeHash);
    }

    function deployHook(bytes32 salt, bytes memory initCode, uint160 expectedMask)
        external
        onlyOwner
        returns (address deployed)
    {
        bytes32 initCodeHash = _initCodeHash(initCode);
        address predicted = computeAddress(salt, initCodeHash);
        uint160 actualMask = hookMask(predicted);
        if (actualMask != expectedMask) {
            revert BadHookPermissionBits(predicted, actualMask, expectedMask);
        }

        deployed = _deploy(salt, initCode, initCodeHash);
    }

    function computeAddress(bytes32 salt, bytes32 initCodeHash)
        public
        view
        returns (address predicted)
    {
        predicted = computeAddressFor(address(this), salt, initCodeHash);
    }

    function computeAddressFor(address deployer, bytes32 salt, bytes32 initCodeHash)
        public
        pure
        returns (address predicted)
    {
        predicted = BaseV4HookAddressMiner.computeCreate2Address(deployer, salt, initCodeHash);
    }

    function hookMask(address hookAddress) public pure returns (uint160 mask) {
        mask = uint160(hookAddress) & BaseV4HookAddressMiner.V4_ALL_HOOK_MASK;
    }

    function _initCodeHash(bytes memory initCode) private pure returns (bytes32 initCodeHash) {
        if (initCode.length == 0) revert EmptyInitCode();

        initCodeHash = keccak256(initCode);
    }

    function _deploy(bytes32 salt, bytes memory initCode, bytes32 initCodeHash)
        private
        returns (address deployed)
    {
        assembly ("memory-safe") {
            deployed := create2(0, add(initCode, 0x20), mload(initCode), salt)
        }

        if (deployed == address(0)) revert Create2DeployFailed(salt, initCodeHash);

        emit Deployed(deployed, salt, initCodeHash);
    }

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }
}
