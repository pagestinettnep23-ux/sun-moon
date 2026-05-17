// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { Test } from "forge-std/Test.sol";
import { BaseV4HookAddressMiner } from "../../../contracts/hooks/base/BaseV4HookAddressMiner.sol";
import { Create2HookDeployer } from "../../../contracts/hooks/base/Create2HookDeployer.sol";

contract Create2HookTarget {
    uint256 public immutable value;
    address public immutable creator;

    constructor(uint256 value_) {
        value = value_;
        creator = msg.sender;
    }
}

contract Create2HookDeployerTest is Test {
    address internal owner = address(0xCAFE);
    address internal stranger = address(0xBEEF);

    function testOwnerCanPredictAndDeployWithCreate2() public {
        Create2HookDeployer deployer = new Create2HookDeployer(owner);
        bytes memory initCode = _targetInitCode(42);
        bytes32 salt = bytes32(uint256(123));

        address predicted = deployer.computeAddress(salt, keccak256(initCode));

        vm.prank(owner);
        address deployed = deployer.deploy(salt, initCode);

        assertEq(deployed, predicted);
        assertEq(
            deployer.computeAddressFor(address(deployer), salt, keccak256(initCode)), predicted
        );
        assertGt(deployed.code.length, 0);
        assertEq(Create2HookTarget(deployed).value(), 42);
        assertEq(Create2HookTarget(deployed).creator(), address(deployer));
    }

    function testDeployHookAllowsOnlyExactExpectedPermissionBits() public {
        Create2HookDeployer deployer = new Create2HookDeployer(owner);
        bytes memory initCode = _targetInitCode(7);
        bytes32 salt = bytes32(uint256(456));
        address predicted = deployer.computeAddress(salt, keccak256(initCode));
        uint160 actualMask = deployer.hookMask(predicted);

        vm.prank(owner);
        address deployed = deployer.deployHook(salt, initCode, actualMask);

        assertEq(deployed, predicted);
        assertEq(deployer.hookMask(deployed), actualMask);
    }

    function testRejectsHookDeploymentWhenPermissionBitsDoNotMatch() public {
        Create2HookDeployer deployer = new Create2HookDeployer(owner);
        bytes memory initCode = _targetInitCode(1);
        bytes32 salt = bytes32(uint256(789));
        address predicted = deployer.computeAddress(salt, keccak256(initCode));
        uint160 actualMask = deployer.hookMask(predicted);
        uint160 wrongMask = actualMask ^ uint160(1);

        vm.expectRevert(
            abi.encodeWithSelector(
                Create2HookDeployer.BadHookPermissionBits.selector, predicted, actualMask, wrongMask
            )
        );
        vm.prank(owner);
        deployer.deployHook(salt, initCode, wrongMask);
    }

    function testRejectsNonOwnerDeployment() public {
        Create2HookDeployer deployer = new Create2HookDeployer(owner);

        vm.expectRevert(Create2HookDeployer.NotOwner.selector);
        vm.prank(stranger);
        deployer.deploy(bytes32(0), _targetInitCode(1));
    }

    function testRejectsZeroOwner() public {
        vm.expectRevert(Create2HookDeployer.InvalidOwner.selector);
        new Create2HookDeployer(address(0));
    }

    function testRejectsEmptyInitCode() public {
        Create2HookDeployer deployer = new Create2HookDeployer(owner);

        vm.expectRevert(Create2HookDeployer.EmptyInitCode.selector);
        vm.prank(owner);
        deployer.deploy(bytes32(0), "");
    }

    function testComputeAddressForMatchesMinerLibrary() public {
        Create2HookDeployer deployerContract = new Create2HookDeployer(owner);
        address deployer = address(0x1234);
        bytes32 salt = bytes32(uint256(55));
        bytes32 initCodeHash = keccak256("init code");

        assertEq(
            deployerContract.computeAddressFor(deployer, salt, initCodeHash),
            BaseV4HookAddressMiner.computeCreate2Address(deployer, salt, initCodeHash)
        );
    }

    function _targetInitCode(uint256 value) private pure returns (bytes memory) {
        return abi.encodePacked(type(Create2HookTarget).creationCode, abi.encode(value));
    }
}
