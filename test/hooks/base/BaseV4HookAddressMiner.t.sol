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

contract BaseV4HookAddressMinerTest is Test {
    address internal poolManager = address(0x1001);
    address internal moonToken = address(0x1002);
    address internal usdc = address(0x1003);
    address internal sunCurve = address(0x1004);
    address internal protocolBudget = address(0x1005);
    address internal swapAdapter = address(0x1006);
    address internal owner = address(0x1007);

    function testMinesAndDeploysBaseMoonV4HookAddressWithExactPermissionBits() public {
        Create2HookDeployer deployer = new Create2HookDeployer(address(this));
        bytes memory initCode = _baseMoonHookInitCode();

        (bytes32 salt, address predicted, bool found) = BaseV4HookAddressMiner.mineSalt(
            address(deployer),
            keccak256(initCode),
            BaseV4HookAddressMiner.BASE_MOON_AMM_FEE_V4_HOOK_MASK,
            0,
            100_000
        );

        assertTrue(found);
        assertTrue(
            BaseV4HookAddressMiner.matchesHookMask(
                predicted, BaseV4HookAddressMiner.BASE_MOON_AMM_FEE_V4_HOOK_MASK
            )
        );

        address deployed = deployer.deploy(salt, initCode);

        assertEq(deployed, predicted);
        assertGt(deployed.code.length, 0);
        assertEq(
            BaseMoonAmmFeeV4Hook(deployed).expectedHookMask(),
            BaseV4HookAddressMiner.BASE_MOON_AMM_FEE_V4_HOOK_MASK
        );
    }

    function testMinedSaltCanDeployThroughHookPermissionGuard() public {
        Create2HookDeployer deployer = new Create2HookDeployer(address(this));
        bytes memory initCode = _baseMoonHookInitCode();

        (bytes32 salt, address predicted, bool found) = BaseV4HookAddressMiner.mineSalt(
            address(deployer),
            keccak256(initCode),
            BaseV4HookAddressMiner.BASE_MOON_AMM_FEE_V4_HOOK_MASK,
            0,
            100_000
        );

        assertTrue(found);

        address deployed = deployer.deployHook(
            salt, initCode, BaseV4HookAddressMiner.BASE_MOON_AMM_FEE_V4_HOOK_MASK
        );

        assertEq(deployed, predicted);
        assertGt(deployed.code.length, 0);
    }

    function testRejectsAddressesWithExtraHookPermissionBits() public pure {
        address withExtraBeforeInitializeBit = address(
            uint160(BaseV4HookAddressMiner.BASE_MOON_AMM_FEE_V4_HOOK_MASK | uint160(1 << 13))
        );

        assertFalse(
            BaseV4HookAddressMiner.matchesHookMask(
                withExtraBeforeInitializeBit, BaseV4HookAddressMiner.BASE_MOON_AMM_FEE_V4_HOOK_MASK
            )
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
                owner
            )
        );
    }
}
