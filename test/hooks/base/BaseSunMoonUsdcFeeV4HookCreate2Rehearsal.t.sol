// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { Test } from "forge-std/Test.sol";
import {
    BaseSunMoonUsdcFeeV4Hook
} from "../../../contracts/hooks/base/BaseSunMoonUsdcFeeV4Hook.sol";
import { BaseV4HookAddressMiner } from "../../../contracts/hooks/base/BaseV4HookAddressMiner.sol";
import {
    RehearseBaseSunMoonUsdcFeeV4Hook
} from "../../../script/RehearseBaseSunMoonUsdcFeeV4Hook.s.sol";

contract BaseSunMoonUsdcFeeV4HookCreate2RehearsalTest is Test {
    address internal create2Owner = makeAddr("create2Owner");
    address internal hookOwner = makeAddr("hookOwner");
    address internal poolManager = address(0x1001);
    address internal sunToken = address(0x1002);
    address internal moonToken = address(0x1003);
    address internal usdc = address(0x1004);
    address internal sunCurve = address(0x1005);
    address internal protocolBudget = address(0x1006);

    function testLocalScriptRehearsalDeploysBaseSunMoonUsdcHookAtPredictedAddress() public {
        _setRehearsalEnv();

        RehearseBaseSunMoonUsdcFeeV4Hook script = new RehearseBaseSunMoonUsdcFeeV4Hook();
        RehearseBaseSunMoonUsdcFeeV4Hook.Rehearsal memory rehearsal = script.run();
        BaseSunMoonUsdcFeeV4Hook hook = rehearsal.hook;

        assertEq(rehearsal.create2Deployer.owner(), create2Owner);
        assertEq(address(hook), rehearsal.predictedHook);
        assertEq(rehearsal.predictedHook.code.length > 0, true);
        assertEq(
            rehearsal.expectedHookMask, BaseV4HookAddressMiner.BASE_SUN_MOON_USDC_FEE_V4_HOOK_MASK
        );
        assertEq(rehearsal.actualHookMask, rehearsal.expectedHookMask);
        assertEq(
            uint160(rehearsal.predictedHook) & BaseV4HookAddressMiner.V4_ALL_HOOK_MASK,
            rehearsal.expectedHookMask
        );
        assertEq(hook.expectedHookMask(), rehearsal.expectedHookMask);

        assertEq(address(hook.poolManager()), poolManager);
        assertEq(hook.sunToken(), sunToken);
        assertEq(hook.moonToken(), moonToken);
        assertEq(address(hook.usdc()), usdc);
        assertEq(address(hook.sunCurve()), sunCurve);
        assertEq(hook.protocolBudget(), protocolBudget);
        assertEq(hook.owner(), hookOwner);
    }

    function _setRehearsalEnv() private {
        vm.setEnv("CREATE2_DEPLOYER_OWNER", vm.toString(create2Owner));
        vm.setEnv("HOOK_OWNER", vm.toString(hookOwner));
        vm.setEnv("POOL_MANAGER", vm.toString(poolManager));
        vm.setEnv("SUN_TOKEN", vm.toString(sunToken));
        vm.setEnv("MOON_TOKEN", vm.toString(moonToken));
        vm.setEnv("USDC_TOKEN", vm.toString(usdc));
        vm.setEnv("SUN_CURVE", vm.toString(sunCurve));
        vm.setEnv("PROTOCOL_BUDGET_ADDRESS", vm.toString(protocolBudget));
        vm.setEnv("HOOK_SALT_START", "0");
        vm.setEnv("HOOK_MAX_SALT_SEARCH", "200000");
    }
}
