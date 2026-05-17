// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { Test } from "forge-std/Test.sol";
import { IHooks } from "@uniswap/v4-core/src/interfaces/IHooks.sol";
import { Hooks } from "@uniswap/v4-core/src/libraries/Hooks.sol";
import { PoolKey } from "@uniswap/v4-core/src/types/PoolKey.sol";
import { Currency } from "@uniswap/v4-core/src/types/Currency.sol";
import { BalanceDelta, BalanceDeltaLibrary } from "@uniswap/v4-core/src/types/BalanceDelta.sol";
import { BaseV4HookProbe } from "../../../contracts/hooks/base/BaseV4HookProbe.sol";
import { ModifyLiquidityParams, SwapParams } from "@uniswap/v4-core/src/types/PoolOperation.sol";

contract BaseV4HookProbeTest is Test {
    address internal poolManager = makeAddr("poolManager");
    address internal alice = makeAddr("alice");

    BaseV4HookProbe internal probe;

    function setUp() public {
        probe = new BaseV4HookProbe(poolManager);
    }

    function testExpectedHookMaskMatchesSunAndMoonProbeCallbacks() public {
        uint160 expectedMask = Hooks.BEFORE_ADD_LIQUIDITY_FLAG | Hooks.AFTER_SWAP_FLAG;

        assertEq(probe.expectedHookMask(), expectedMask);
    }

    function testBeforeAddLiquidityReturnsV4Selector() public {
        PoolKey memory key = _poolKey();
        ModifyLiquidityParams memory params = ModifyLiquidityParams({
            tickLower: -120, tickUpper: 120, liquidityDelta: 1, salt: bytes32(0)
        });

        vm.prank(poolManager);
        bytes4 selector = probe.beforeAddLiquidity(alice, key, params, "");

        assertEq(selector, IHooks.beforeAddLiquidity.selector);
    }

    function testAfterSwapReturnsV4SelectorAndNoDelta() public {
        PoolKey memory key = _poolKey();
        SwapParams memory params =
            SwapParams({ zeroForOne: true, amountSpecified: -1e18, sqrtPriceLimitX96: 0 });

        vm.prank(poolManager);
        (bytes4 selector, int128 hookDelta) =
            probe.afterSwap(alice, key, params, BalanceDeltaLibrary.ZERO_DELTA, "");

        assertEq(selector, IHooks.afterSwap.selector);
        assertEq(hookDelta, 0);
    }

    function testRejectsNonPoolManagerCallbacks() public {
        PoolKey memory key = _poolKey();
        ModifyLiquidityParams memory params = ModifyLiquidityParams({
            tickLower: -120, tickUpper: 120, liquidityDelta: 1, salt: bytes32(0)
        });

        vm.prank(alice);
        vm.expectRevert(BaseV4HookProbe.NotPoolManager.selector);
        probe.beforeAddLiquidity(alice, key, params, "");
    }

    function testRejectsZeroPoolManager() public {
        vm.expectRevert(BaseV4HookProbe.InvalidAddress.selector);
        new BaseV4HookProbe(address(0));
    }

    function _poolKey() internal view returns (PoolKey memory) {
        return PoolKey({
            currency0: Currency.wrap(address(0x1000)),
            currency1: Currency.wrap(address(0x2000)),
            fee: 3000,
            tickSpacing: 60,
            hooks: IHooks(address(probe))
        });
    }
}
