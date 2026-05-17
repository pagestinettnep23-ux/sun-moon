// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { Test } from "forge-std/Test.sol";
import { IHooks } from "@uniswap/v4-core/src/interfaces/IHooks.sol";
import { Hooks } from "@uniswap/v4-core/src/libraries/Hooks.sol";
import { Currency } from "@uniswap/v4-core/src/types/Currency.sol";
import { PoolId, PoolIdLibrary } from "@uniswap/v4-core/src/types/PoolId.sol";
import { PoolKey } from "@uniswap/v4-core/src/types/PoolKey.sol";
import { ModifyLiquidityParams } from "@uniswap/v4-core/src/types/PoolOperation.sol";
import { BaseSunAmmGuardV4Hook } from "../../../contracts/hooks/base/BaseSunAmmGuardV4Hook.sol";
import { SunAmmGuardHook } from "../../../contracts/hooks/SunAmmGuardHook.sol";

contract BaseSunAmmGuardV4HookTest is Test {
    using PoolIdLibrary for PoolKey;

    address internal owner = makeAddr("owner");
    address internal poolManager = makeAddr("basePoolManager");
    address internal firstLiquidityProvider = makeAddr("firstLiquidityProvider");
    address internal alice = makeAddr("alice");
    address internal sun = address(0x1000);
    address internal usdt = address(0x2000);
    address internal wbnb = address(0x3000);
    address internal otherToken0 = address(0x4000);
    address internal otherToken1 = address(0x5000);

    address internal permissionedHook = address(uint160(Hooks.BEFORE_ADD_LIQUIDITY_FLAG));

    SunAmmGuardHook internal guard;
    BaseSunAmmGuardV4Hook internal adapter;
    PoolKey internal sunUsdtKey;
    bytes32 internal sunUsdtPoolId;

    event SunAmmUnlocked(bytes32 indexed poolId, address indexed liquidityProvider);

    function setUp() public {
        guard = new SunAmmGuardHook(sun, firstLiquidityProvider, owner, owner);

        BaseSunAmmGuardV4Hook implementation = new BaseSunAmmGuardV4Hook(poolManager, guard);
        vm.etch(permissionedHook, address(implementation).code);
        adapter = BaseSunAmmGuardV4Hook(permissionedHook);

        sunUsdtKey = _poolKey(sun, usdt, IHooks(permissionedHook));
        sunUsdtPoolId = PoolId.unwrap(sunUsdtKey.toId());

        vm.startPrank(owner);
        guard.setHookCaller(permissionedHook);
        guard.setAllowedSunPool(sunUsdtPoolId, true);
        vm.stopPrank();
    }

    function testExpectedHookMaskMatchesBeforeAddLiquidityOnly() public view {
        assertEq(adapter.expectedHookMask(), Hooks.BEFORE_ADD_LIQUIDITY_FLAG);
        assertEq(
            uint160(permissionedHook) & Hooks.BEFORE_ADD_LIQUIDITY_FLAG,
            Hooks.BEFORE_ADD_LIQUIDITY_FLAG
        );
    }

    function testNonSunV4PoolIsUnaffected() public {
        PoolKey memory nonSunKey = _poolKey(otherToken0, otherToken1, IHooks(permissionedHook));

        vm.prank(poolManager);
        bytes4 selector =
            adapter.beforeAddLiquidity(alice, nonSunKey, _addLiquidityParams(), bytes(""));

        assertEq(selector, guard.beforeAddLiquidity.selector);
        assertFalse(guard.sunAmmUnlocked());
    }

    function testNormalUserCannotAddFirstSunLiquidityThroughV4Adapter() public {
        vm.prank(poolManager);
        vm.expectRevert(abi.encodeWithSelector(SunAmmGuardHook.SunAmmLocked.selector, alice));
        adapter.beforeAddLiquidity(alice, sunUsdtKey, _addLiquidityParams(), bytes(""));

        assertFalse(guard.sunAmmUnlocked());
    }

    function testFirstLiquidityProviderUnlocksSunPoolThroughV4Adapter() public {
        vm.prank(poolManager);
        vm.expectEmit(true, true, false, true, address(guard));
        emit SunAmmUnlocked(sunUsdtPoolId, firstLiquidityProvider);
        bytes4 selector = adapter.beforeAddLiquidity(
            firstLiquidityProvider, sunUsdtKey, _addLiquidityParams(), bytes("")
        );

        assertEq(selector, guard.beforeAddLiquidity.selector);
        assertTrue(guard.sunAmmUnlocked());
    }

    function testAnyUserCanAddSunLiquidityAfterV4Unlock() public {
        vm.prank(poolManager);
        adapter.beforeAddLiquidity(
            firstLiquidityProvider, sunUsdtKey, _addLiquidityParams(), bytes("")
        );

        vm.prank(poolManager);
        bytes4 selector =
            adapter.beforeAddLiquidity(alice, sunUsdtKey, _addLiquidityParams(), bytes(""));

        assertEq(selector, guard.beforeAddLiquidity.selector);
        assertTrue(guard.sunAmmUnlocked());
    }

    function testUnallowedSunPoolRevertsThroughV4Adapter() public {
        PoolKey memory sunWbnbKey = _poolKey(sun, wbnb, IHooks(permissionedHook));
        bytes32 sunWbnbPoolId = PoolId.unwrap(sunWbnbKey.toId());

        vm.prank(poolManager);
        vm.expectRevert(
            abi.encodeWithSelector(SunAmmGuardHook.SunPoolNotAllowed.selector, sunWbnbPoolId)
        );
        adapter.beforeAddLiquidity(
            firstLiquidityProvider, sunWbnbKey, _addLiquidityParams(), bytes("")
        );
    }

    function testOnlyPoolManagerCanCallV4Adapter() public {
        vm.prank(alice);
        vm.expectRevert(BaseSunAmmGuardV4Hook.NotPoolManager.selector);
        adapter.beforeAddLiquidity(alice, sunUsdtKey, _addLiquidityParams(), bytes(""));
    }

    function testRejectsInvalidConstructorConfig() public {
        vm.expectRevert(BaseSunAmmGuardV4Hook.InvalidAddress.selector);
        new BaseSunAmmGuardV4Hook(address(0), guard);

        vm.expectRevert(BaseSunAmmGuardV4Hook.InvalidAddress.selector);
        new BaseSunAmmGuardV4Hook(poolManager, SunAmmGuardHook(address(0)));
    }

    function _poolKey(address tokenA, address tokenB, IHooks hooks)
        internal
        pure
        returns (PoolKey memory key)
    {
        (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);

        key = PoolKey({
            currency0: Currency.wrap(token0),
            currency1: Currency.wrap(token1),
            fee: 3000,
            tickSpacing: 60,
            hooks: hooks
        });
    }

    function _addLiquidityParams() internal pure returns (ModifyLiquidityParams memory params) {
        params = ModifyLiquidityParams({
            tickLower: -60, tickUpper: 60, liquidityDelta: 1, salt: bytes32(0)
        });
    }
}
