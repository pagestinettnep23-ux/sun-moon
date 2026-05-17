// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { Test } from "forge-std/Test.sol";
import { SunAmmGuardHook } from "../../contracts/hooks/SunAmmGuardHook.sol";

contract MockPoolManager {
    SunAmmGuardHook public immutable hook;

    constructor(SunAmmGuardHook hook_) {
        hook = hook_;
    }

    function addLiquidity(address liquidityProvider, bytes32 poolId, address token0, address token1)
        external
        returns (bytes4)
    {
        return hook.beforeAddLiquidity(liquidityProvider, poolId, token0, token1);
    }
}

contract SunAmmGuardHookTest is Test {
    address internal owner = makeAddr("owner");
    address internal firstLiquidityProvider = makeAddr("firstLiquidityProvider");
    address internal newFirstLiquidityProvider = makeAddr("newFirstLiquidityProvider");
    address internal alice = makeAddr("alice");
    address internal sun = makeAddr("SUN");
    address internal usdt = makeAddr("USDT");
    address internal wbnb = makeAddr("WBNB");
    address internal otherToken0 = makeAddr("OTHER0");
    address internal otherToken1 = makeAddr("OTHER1");

    bytes32 internal sunUsdtPool = keccak256("SUN_USDT_POOL");
    bytes32 internal sunWbnbPool = keccak256("SUN_WBNB_POOL");
    bytes32 internal nonSunPool = keccak256("NON_SUN_POOL");

    SunAmmGuardHook internal hook;
    MockPoolManager internal poolManager;

    event SunAmmUnlocked(bytes32 indexed poolId, address indexed liquidityProvider);
    event FirstLiquidityProviderSet(address indexed firstLiquidityProvider);
    event SunPoolAllowedSet(bytes32 indexed poolId, bool allowed);
    event PausedSet(bool paused);

    function setUp() public {
        hook = new SunAmmGuardHook(sun, firstLiquidityProvider, owner, owner);
        poolManager = new MockPoolManager(hook);

        vm.startPrank(owner);
        hook.setHookCaller(address(poolManager));
        hook.setAllowedSunPool(sunUsdtPool, true);
        vm.stopPrank();
    }

    function testNonSunPoolIsUnaffectedBeforeUnlock() public {
        vm.prank(alice);
        bytes4 selector = poolManager.addLiquidity(alice, nonSunPool, otherToken0, otherToken1);

        assertEq(selector, hook.beforeAddLiquidity.selector);
        assertFalse(hook.sunAmmUnlocked());
    }

    function testNormalUserCannotAddSunLiquidityBeforeUnlock() public {
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(SunAmmGuardHook.SunAmmLocked.selector, alice));
        poolManager.addLiquidity(alice, sunUsdtPool, sun, usdt);

        assertFalse(hook.sunAmmUnlocked());
    }

    function testDesignatedWalletCanAddFirstSunLiquidityAndUnlock() public {
        vm.prank(firstLiquidityProvider);
        vm.expectEmit(true, true, false, true, address(hook));
        emit SunAmmUnlocked(sunUsdtPool, firstLiquidityProvider);
        bytes4 selector = poolManager.addLiquidity(firstLiquidityProvider, sunUsdtPool, sun, usdt);

        assertEq(selector, hook.beforeAddLiquidity.selector);
        assertTrue(hook.sunAmmUnlocked());
    }

    function testAnyUserCanAddAllowedSunLiquidityAfterUnlock() public {
        vm.prank(firstLiquidityProvider);
        poolManager.addLiquidity(firstLiquidityProvider, sunUsdtPool, sun, usdt);

        vm.prank(alice);
        bytes4 selector = poolManager.addLiquidity(alice, sunUsdtPool, sun, usdt);

        assertEq(selector, hook.beforeAddLiquidity.selector);
        assertTrue(hook.sunAmmUnlocked());
    }

    function testUnallowedSunPoolStillFailsAfterUnlock() public {
        vm.prank(firstLiquidityProvider);
        poolManager.addLiquidity(firstLiquidityProvider, sunUsdtPool, sun, usdt);

        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(SunAmmGuardHook.SunPoolNotAllowed.selector, sunWbnbPool)
        );
        poolManager.addLiquidity(alice, sunWbnbPool, sun, wbnb);
    }

    function testFirstLiquidityProviderCannotUnlockUnallowedSunPool() public {
        vm.prank(firstLiquidityProvider);
        vm.expectRevert(
            abi.encodeWithSelector(SunAmmGuardHook.SunPoolNotAllowed.selector, sunWbnbPool)
        );
        poolManager.addLiquidity(firstLiquidityProvider, sunWbnbPool, sun, wbnb);

        assertFalse(hook.sunAmmUnlocked());
    }

    function testOwnerCanAllowAnotherSunPoolAfterUnlock() public {
        vm.prank(firstLiquidityProvider);
        poolManager.addLiquidity(firstLiquidityProvider, sunUsdtPool, sun, usdt);

        vm.prank(owner);
        vm.expectEmit(true, false, false, true, address(hook));
        emit SunPoolAllowedSet(sunWbnbPool, true);
        hook.setAllowedSunPool(sunWbnbPool, true);

        vm.prank(alice);
        bytes4 selector = poolManager.addLiquidity(alice, sunWbnbPool, sun, wbnb);

        assertEq(selector, hook.beforeAddLiquidity.selector);
    }

    function testOnlyConfiguredHookCallerCanTriggerGuard() public {
        vm.prank(alice);
        vm.expectRevert(SunAmmGuardHook.NotHookCaller.selector);
        hook.beforeAddLiquidity(alice, sunUsdtPool, sun, usdt);
    }

    function testOwnerCanChangeFirstLiquidityProviderBeforeUnlock() public {
        vm.prank(owner);
        vm.expectEmit(true, false, false, true, address(hook));
        emit FirstLiquidityProviderSet(newFirstLiquidityProvider);
        hook.setFirstLiquidityProvider(newFirstLiquidityProvider);

        vm.prank(firstLiquidityProvider);
        vm.expectRevert(
            abi.encodeWithSelector(SunAmmGuardHook.SunAmmLocked.selector, firstLiquidityProvider)
        );
        poolManager.addLiquidity(firstLiquidityProvider, sunUsdtPool, sun, usdt);

        vm.prank(newFirstLiquidityProvider);
        poolManager.addLiquidity(newFirstLiquidityProvider, sunUsdtPool, sun, usdt);

        assertTrue(hook.sunAmmUnlocked());
    }

    function testPauseBlocksSunLiquidityGuardPath() public {
        vm.prank(owner);
        vm.expectEmit(false, false, false, true, address(hook));
        emit PausedSet(true);
        hook.setPaused(true);

        vm.prank(firstLiquidityProvider);
        vm.expectRevert(SunAmmGuardHook.HookPaused.selector);
        poolManager.addLiquidity(firstLiquidityProvider, sunUsdtPool, sun, usdt);
    }

    function testNonOwnerCannotChangeConfig() public {
        vm.startPrank(alice);

        vm.expectRevert();
        hook.setFirstLiquidityProvider(alice);

        vm.expectRevert();
        hook.setAllowedSunPool(sunWbnbPool, true);

        vm.expectRevert();
        hook.setPaused(true);

        vm.expectRevert();
        hook.setHookCaller(alice);

        vm.stopPrank();
    }

    function testRejectsInvalidConfig() public {
        vm.expectRevert(SunAmmGuardHook.InvalidAddress.selector);
        new SunAmmGuardHook(address(0), firstLiquidityProvider, owner, owner);

        vm.expectRevert(SunAmmGuardHook.InvalidAddress.selector);
        new SunAmmGuardHook(sun, address(0), owner, owner);

        vm.expectRevert(SunAmmGuardHook.InvalidAddress.selector);
        new SunAmmGuardHook(sun, firstLiquidityProvider, address(0), owner);

        vm.prank(owner);
        vm.expectRevert(SunAmmGuardHook.InvalidAddress.selector);
        hook.setHookCaller(address(0));

        vm.prank(owner);
        vm.expectRevert(SunAmmGuardHook.InvalidAddress.selector);
        hook.setFirstLiquidityProvider(address(0));

        vm.prank(owner);
        vm.expectRevert(SunAmmGuardHook.InvalidPoolId.selector);
        hook.setAllowedSunPool(bytes32(0), true);
    }
}
