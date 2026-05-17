// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Test } from "forge-std/Test.sol";
import { IPoolManager } from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import { IMoonAmmSwapAdapter } from "../../../contracts/hooks/MoonAmmFeeHook.sol";
import { BaseMoonAmmFeeV4Hook } from "../../../contracts/hooks/base/BaseMoonAmmFeeV4Hook.sol";
import { BaseV4HookAddressMiner } from "../../../contracts/hooks/base/BaseV4HookAddressMiner.sol";
import { Create2HookDeployer } from "../../../contracts/hooks/base/Create2HookDeployer.sol";
import { SunCurve } from "../../../contracts/SunCurve.sol";

contract Create2HookDeployerRehearsalTest is Test {
    address internal create2Owner = makeAddr("create2Owner");
    address internal poolManager = address(0x1001);
    address internal moonToken = address(0x1002);
    address internal usdc = address(0x1003);
    address internal sunCurve = address(0x1004);
    address internal protocolBudget = address(0x1005);
    address internal swapAdapter = address(0x1006);
    address internal hookOwner = address(0x1007);

    function testLocalCreate2HookDeployerRehearsalDeploysBaseMoonHookAtPredictedAddress() public {
        Create2HookDeployer deployer = new Create2HookDeployer(create2Owner);
        bytes memory initCode = _baseMoonHookInitCode();
        bytes32 initCodeHash = keccak256(initCode);

        (bytes32 salt, address predictedHook, bool found) = BaseV4HookAddressMiner.mineSalt(
            address(deployer),
            initCodeHash,
            BaseV4HookAddressMiner.BASE_MOON_AMM_FEE_V4_HOOK_MASK,
            0,
            200_000
        );

        assertTrue(found);
        assertEq(deployer.computeAddress(salt, initCodeHash), predictedHook);

        vm.prank(create2Owner);
        address deployedHook = deployer.deployHook(
            salt, initCode, BaseV4HookAddressMiner.BASE_MOON_AMM_FEE_V4_HOOK_MASK
        );

        assertEq(deployedHook, predictedHook);
        assertGt(deployedHook.code.length, 0);
        assertEq(BaseMoonAmmFeeV4Hook(deployedHook).owner(), hookOwner);
        assertEq(address(BaseMoonAmmFeeV4Hook(deployedHook).poolManager()), poolManager);
        assertEq(BaseMoonAmmFeeV4Hook(deployedHook).moonToken(), moonToken);
        assertEq(address(BaseMoonAmmFeeV4Hook(deployedHook).usdt()), usdc);
        assertEq(address(BaseMoonAmmFeeV4Hook(deployedHook).sunCurve()), sunCurve);
        assertEq(BaseMoonAmmFeeV4Hook(deployedHook).protocolBudget(), protocolBudget);
        assertEq(address(BaseMoonAmmFeeV4Hook(deployedHook).swapAdapter()), swapAdapter);
        assertEq(
            BaseMoonAmmFeeV4Hook(deployedHook).expectedHookMask(),
            BaseV4HookAddressMiner.BASE_MOON_AMM_FEE_V4_HOOK_MASK
        );
    }

    function _baseMoonHookInitCode() private view returns (bytes memory) {
        return abi.encodePacked(
            type(BaseMoonAmmFeeV4Hook).creationCode,
            abi.encode(
                IPoolManager(poolManager),
                moonToken,
                IERC20(usdc),
                SunCurve(sunCurve),
                protocolBudget,
                IMoonAmmSwapAdapter(swapAdapter),
                hookOwner
            )
        );
    }
}
