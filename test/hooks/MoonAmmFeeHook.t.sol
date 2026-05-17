// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { Test } from "forge-std/Test.sol";
import { AmmSwapAdapter } from "../../contracts/hooks/AmmSwapAdapter.sol";
import { MoonAmmFeeHook } from "../../contracts/hooks/MoonAmmFeeHook.sol";
import { MoonToken } from "../../contracts/MoonToken.sol";
import { SunCurve } from "../../contracts/SunCurve.sol";
import { SunToken } from "../../contracts/SunToken.sol";
import { MockUSDT } from "../../contracts/mocks/MockUSDT.sol";

contract MockMoonPoolManager {
    MoonAmmFeeHook public immutable hook;

    constructor(MoonAmmFeeHook hook_) {
        hook = hook_;
    }

    function swap(
        address trader,
        bytes32 poolId,
        address token0,
        address token1,
        address feeToken,
        uint256 feeBaseAmount,
        uint256 minUSDTOut
    ) external returns (bytes4) {
        return hook.afterSwap(trader, poolId, token0, token1, feeToken, feeBaseAmount, minUSDTOut);
    }
}

contract MoonAmmFeeHookTest is Test {
    uint256 internal constant TOKEN_ONE = 1e18;
    uint256 internal constant USDT_ONE = 1e6;
    uint256 internal constant SUN_MAX_MINT_USDT = 10_000 * USDT_ONE;

    address internal owner = makeAddr("owner");
    address internal alice = makeAddr("alice");
    address internal bob = makeAddr("bob");
    address internal protocolBudget = makeAddr("protocolBudget");
    address internal newProtocolBudget = makeAddr("newProtocolBudget");
    address internal otherToken0 = makeAddr("OTHER0");
    address internal otherToken1 = makeAddr("OTHER1");

    bytes32 internal moonUsdtPool = keccak256("MOON_USDT_POOL");
    bytes32 internal moonFeePool = keccak256("MOON_FEE_POOL");
    bytes32 internal unallowedMoonPool = keccak256("UNALLOWED_MOON_POOL");
    bytes32 internal nonMoonPool = keccak256("NON_MOON_POOL");

    MockUSDT internal usdt;
    MockUSDT internal feeAsset;
    SunToken internal sun;
    SunCurve internal sunCurve;
    MoonToken internal moon;
    MoonAmmFeeHook internal hook;
    MockMoonPoolManager internal poolManager;
    AmmSwapAdapter internal adapter;

    event MoonAmmFeeRouted(
        bytes32 indexed poolId,
        address indexed trader,
        address indexed feeToken,
        uint256 feeBaseAmount,
        uint256 feeToSunCurve,
        uint256 feeToProtocol,
        uint256 usdtInjected
    );
    event MoonPoolAllowedSet(bytes32 indexed poolId, bool allowed);
    event ProtocolBudgetSet(address indexed protocolBudget);
    event PausedSet(bool paused);

    function setUp() public {
        usdt = new MockUSDT("Mock USDT", "USDT", 6);
        feeAsset = new MockUSDT("Mock Fee Asset", "MFEE", 18);
        sun = new SunToken("SUN", "SUN", owner);
        sunCurve = new SunCurve(sun, usdt, protocolBudget, SUN_MAX_MINT_USDT, owner);
        moon = new MoonToken("MOON", "MOON", owner);
        hook = new MoonAmmFeeHook(address(moon), usdt, sunCurve, protocolBudget, owner, owner);
        poolManager = new MockMoonPoolManager(hook);
        adapter = new AmmSwapAdapter(usdt, address(hook), owner);

        vm.startPrank(owner);
        sun.setMinter(address(sunCurve));
        sunCurve.setMoonAMM(address(hook));
        hook.setHookCaller(address(poolManager));
        hook.setSwapAdapter(address(adapter));
        hook.setAllowedMoonPool(moonUsdtPool, true);
        hook.setAllowedMoonPool(moonFeePool, true);
        vm.stopPrank();

        usdt.mint(alice, 10_000 * USDT_ONE);
        usdt.mint(bob, 10_000 * USDT_ONE);
        feeAsset.mint(alice, 10_000 * TOKEN_ONE);

        vm.startPrank(alice);
        usdt.approve(address(hook), type(uint256).max);
        feeAsset.approve(address(hook), type(uint256).max);
        vm.stopPrank();

        vm.prank(bob);
        usdt.approve(address(hook), type(uint256).max);
    }

    function testNonMoonPoolIsUnaffected() public {
        uint256 aliceUsdtBefore = usdt.balanceOf(alice);

        vm.prank(alice);
        bytes4 selector = poolManager.swap(
            alice, nonMoonPool, otherToken0, otherToken1, address(usdt), 1000 * USDT_ONE, 1
        );

        assertEq(selector, hook.afterSwap.selector);
        assertEq(usdt.balanceOf(alice), aliceUsdtBefore);
        assertEq(usdt.balanceOf(address(sunCurve)), 0);
        assertEq(usdt.balanceOf(protocolBudget), 0);
        assertEq(sunCurve.curveReserve(), 0);
    }

    function testMoonBuyAndSellDirectionsChargeFivePercentUsdtFee() public {
        uint256 feeBaseAmount = 1000 * USDT_ONE;
        uint256 feeToSunCurve = 30 * USDT_ONE;
        uint256 feeToProtocol = 20 * USDT_ONE;

        vm.prank(alice);
        poolManager.swap(
            alice,
            moonUsdtPool,
            address(usdt),
            address(moon),
            address(usdt),
            feeBaseAmount,
            feeToSunCurve
        );

        vm.prank(bob);
        poolManager.swap(
            bob,
            moonUsdtPool,
            address(moon),
            address(usdt),
            address(usdt),
            feeBaseAmount,
            feeToSunCurve
        );

        assertEq(sunCurve.curveReserve(), 2 * feeToSunCurve);
        assertEq(usdt.balanceOf(address(sunCurve)), 2 * feeToSunCurve);
        assertEq(usdt.balanceOf(protocolBudget), 2 * feeToProtocol);
        assertEq(usdt.balanceOf(alice), 10_000 * USDT_ONE - feeToSunCurve - feeToProtocol);
        assertEq(usdt.balanceOf(bob), 10_000 * USDT_ONE - feeToSunCurve - feeToProtocol);
        assertEq(usdt.balanceOf(address(hook)), 0);
    }

    function testMoonUsdtFeeInjectsThreePercentAndSendsTwoPercentToProtocol() public {
        uint256 feeBaseAmount = 1000 * USDT_ONE;
        uint256 feeToSunCurve = 30 * USDT_ONE;
        uint256 feeToProtocol = 20 * USDT_ONE;

        vm.prank(alice);
        vm.expectEmit(true, true, true, true, address(hook));
        emit MoonAmmFeeRouted(
            moonUsdtPool,
            alice,
            address(usdt),
            feeBaseAmount,
            feeToSunCurve,
            feeToProtocol,
            feeToSunCurve
        );
        bytes4 selector = poolManager.swap(
            alice,
            moonUsdtPool,
            address(moon),
            address(usdt),
            address(usdt),
            feeBaseAmount,
            feeToSunCurve
        );

        assertEq(selector, hook.afterSwap.selector);
        assertEq(sunCurve.curveReserve(), feeToSunCurve);
        assertEq(usdt.balanceOf(address(sunCurve)), feeToSunCurve);
        assertEq(usdt.balanceOf(protocolBudget), feeToProtocol);
        assertEq(usdt.balanceOf(alice), 10_000 * USDT_ONE - feeToSunCurve - feeToProtocol);
        assertEq(usdt.balanceOf(address(hook)), 0);
    }

    function testUnallowedMoonPoolCannotRouteFee() public {
        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(MoonAmmFeeHook.MoonPoolNotAllowed.selector, unallowedMoonPool)
        );
        poolManager.swap(
            alice,
            unallowedMoonPool,
            address(moon),
            address(usdt),
            address(usdt),
            1000 * USDT_ONE,
            30 * USDT_ONE
        );
    }

    function testMinUsdtOutMustBeNonZero() public {
        vm.prank(alice);
        vm.expectRevert(MoonAmmFeeHook.InvalidMinUSDTOut.selector);
        poolManager.swap(
            alice, moonUsdtPool, address(moon), address(usdt), address(usdt), 1000 * USDT_ONE, 0
        );
    }

    function testRevertsWhenUsdtFeeIsBelowMinUsdtOut() public {
        uint256 feeBaseAmount = 1000 * USDT_ONE;
        uint256 feeToSunCurve = 30 * USDT_ONE;
        uint256 minUSDTOut = feeToSunCurve + 1;

        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(
                MoonAmmFeeHook.InsufficientUSDTOut.selector, feeToSunCurve, minUSDTOut
            )
        );
        poolManager.swap(
            alice,
            moonUsdtPool,
            address(moon),
            address(usdt),
            address(usdt),
            feeBaseAmount,
            minUSDTOut
        );

        assertEq(usdt.balanceOf(alice), 10_000 * USDT_ONE);
        assertEq(sunCurve.curveReserve(), 0);
        assertEq(usdt.balanceOf(protocolBudget), 0);
    }

    function testMockAdapterCanReturnUsdtAndInjectSunCurve() public {
        uint256 feeBaseAmount = 1000 * TOKEN_ONE;
        uint256 feeToSunCurveAsset = 30 * TOKEN_ONE;
        uint256 feeToProtocolAsset = 20 * TOKEN_ONE;
        uint256 usdtOut = 45 * USDT_ONE;

        vm.prank(owner);
        adapter.setMockUSDTOut(usdtOut);

        vm.prank(alice);
        poolManager.swap(
            alice,
            moonFeePool,
            address(moon),
            address(feeAsset),
            address(feeAsset),
            feeBaseAmount,
            40 * USDT_ONE
        );

        assertEq(sunCurve.curveReserve(), usdtOut);
        assertEq(usdt.balanceOf(address(sunCurve)), usdtOut);
        assertEq(feeAsset.balanceOf(address(adapter)), feeToSunCurveAsset);
        assertEq(feeAsset.balanceOf(protocolBudget), feeToProtocolAsset);
        assertEq(feeAsset.balanceOf(alice), 10_000 * TOKEN_ONE - 50 * TOKEN_ONE);
        assertEq(usdt.balanceOf(address(hook)), 0);
        assertEq(feeAsset.balanceOf(address(hook)), 0);
    }

    function testProtocolBudgetKeepsOriginalFeeAssetWhenSunCurveFeeIsConverted() public {
        uint256 feeBaseAmount = 1000 * TOKEN_ONE;
        uint256 feeToSunCurveAsset = 30 * TOKEN_ONE;
        uint256 feeToProtocolAsset = 20 * TOKEN_ONE;
        uint256 usdtOut = 45 * USDT_ONE;

        vm.prank(owner);
        adapter.setMockUSDTOut(usdtOut);

        uint256 protocolFeeAssetBefore = feeAsset.balanceOf(protocolBudget);
        uint256 protocolUsdtBefore = usdt.balanceOf(protocolBudget);

        vm.prank(alice);
        poolManager.swap(
            alice,
            moonFeePool,
            address(moon),
            address(feeAsset),
            address(feeAsset),
            feeBaseAmount,
            40 * USDT_ONE
        );

        assertEq(sunCurve.curveReserve(), usdtOut);
        assertEq(usdt.balanceOf(address(sunCurve)), usdtOut);
        assertEq(feeAsset.balanceOf(address(adapter)), feeToSunCurveAsset);
        assertEq(feeAsset.balanceOf(protocolBudget) - protocolFeeAssetBefore, feeToProtocolAsset);
        assertEq(usdt.balanceOf(protocolBudget), protocolUsdtBefore);
        assertEq(feeAsset.balanceOf(address(hook)), 0);
        assertEq(usdt.balanceOf(address(hook)), 0);
    }

    function testMockAdapterFailureRollsBackWholeSwapFeeRoute() public {
        uint256 aliceFeeBefore = feeAsset.balanceOf(alice);

        vm.startPrank(owner);
        adapter.setMockUSDTOut(45 * USDT_ONE);
        adapter.setMockSwapShouldFail(true);
        vm.stopPrank();

        vm.prank(alice);
        vm.expectRevert(AmmSwapAdapter.MockSwapFailed.selector);
        poolManager.swap(
            alice,
            moonFeePool,
            address(moon),
            address(feeAsset),
            address(feeAsset),
            1000 * TOKEN_ONE,
            40 * USDT_ONE
        );

        assertEq(feeAsset.balanceOf(alice), aliceFeeBefore);
        assertEq(feeAsset.balanceOf(protocolBudget), 0);
        assertEq(feeAsset.balanceOf(address(adapter)), 0);
        assertEq(sunCurve.curveReserve(), 0);
    }

    function testFeeRoundingDoesNotOverCollectDust() public {
        uint256 feeBaseAmount = 101;
        uint256 feeToSunCurve = 3;
        uint256 feeToProtocol = 2;
        uint256 aliceUsdtBefore = usdt.balanceOf(alice);

        vm.prank(alice);
        poolManager.swap(
            alice,
            moonUsdtPool,
            address(moon),
            address(usdt),
            address(usdt),
            feeBaseAmount,
            feeToSunCurve
        );

        assertEq(aliceUsdtBefore - usdt.balanceOf(alice), feeToSunCurve + feeToProtocol);
        assertEq(sunCurve.curveReserve(), feeToSunCurve);
        assertEq(usdt.balanceOf(protocolBudget), feeToProtocol);
        assertEq(usdt.balanceOf(address(hook)), 0);
    }

    function testRejectsFeeAmountsThatRoundToZero() public {
        vm.prank(alice);
        vm.expectRevert(MoonAmmFeeHook.InvalidAmount.selector);
        poolManager.swap(alice, moonUsdtPool, address(moon), address(usdt), address(usdt), 10, 1);
    }

    function testOnlyConfiguredHookCallerCanTriggerFeeRoute() public {
        vm.prank(alice);
        vm.expectRevert(MoonAmmFeeHook.NotHookCaller.selector);
        hook.afterSwap(
            alice,
            moonUsdtPool,
            address(moon),
            address(usdt),
            address(usdt),
            1000 * USDT_ONE,
            30 * USDT_ONE
        );
    }

    function testOwnerCanChangeConfig() public {
        vm.startPrank(owner);

        vm.expectEmit(true, false, false, true, address(hook));
        emit ProtocolBudgetSet(newProtocolBudget);
        hook.setProtocolBudget(newProtocolBudget);

        vm.expectEmit(true, false, false, true, address(hook));
        emit MoonPoolAllowedSet(unallowedMoonPool, true);
        hook.setAllowedMoonPool(unallowedMoonPool, true);

        vm.expectEmit(false, false, false, true, address(hook));
        emit PausedSet(true);
        hook.setPaused(true);

        vm.stopPrank();

        assertEq(hook.protocolBudget(), newProtocolBudget);
        assertTrue(hook.allowedMoonPools(unallowedMoonPool));
        assertTrue(hook.paused());
    }

    function testPauseBlocksMoonFeeRoute() public {
        vm.prank(owner);
        hook.setPaused(true);

        vm.prank(alice);
        vm.expectRevert(MoonAmmFeeHook.HookPaused.selector);
        poolManager.swap(
            alice,
            moonUsdtPool,
            address(moon),
            address(usdt),
            address(usdt),
            1000 * USDT_ONE,
            30 * USDT_ONE
        );
    }

    function testNonOwnerCannotChangeConfig() public {
        vm.startPrank(alice);

        vm.expectRevert();
        hook.setHookCaller(alice);

        vm.expectRevert();
        hook.setProtocolBudget(alice);

        vm.expectRevert();
        hook.setSwapAdapter(alice);

        vm.expectRevert();
        hook.setAllowedMoonPool(unallowedMoonPool, true);

        vm.expectRevert();
        hook.setPaused(true);

        vm.stopPrank();
    }

    function testRejectsInvalidConfig() public {
        vm.expectRevert(MoonAmmFeeHook.InvalidAddress.selector);
        new MoonAmmFeeHook(address(0), usdt, sunCurve, protocolBudget, owner, owner);

        vm.expectRevert(MoonAmmFeeHook.InvalidAddress.selector);
        new MoonAmmFeeHook(
            address(moon), MockUSDT(address(0)), sunCurve, protocolBudget, owner, owner
        );

        vm.expectRevert(MoonAmmFeeHook.InvalidAddress.selector);
        new MoonAmmFeeHook(address(moon), usdt, SunCurve(address(0)), protocolBudget, owner, owner);

        vm.expectRevert(MoonAmmFeeHook.InvalidAddress.selector);
        new MoonAmmFeeHook(address(moon), usdt, sunCurve, address(0), owner, owner);

        vm.expectRevert(MoonAmmFeeHook.InvalidAddress.selector);
        new MoonAmmFeeHook(address(moon), usdt, sunCurve, protocolBudget, address(0), owner);

        vm.startPrank(owner);

        vm.expectRevert(MoonAmmFeeHook.InvalidAddress.selector);
        hook.setHookCaller(address(0));

        vm.expectRevert(MoonAmmFeeHook.InvalidAddress.selector);
        hook.setProtocolBudget(address(0));

        vm.expectRevert(MoonAmmFeeHook.InvalidAddress.selector);
        hook.setSwapAdapter(address(0));

        vm.expectRevert(MoonAmmFeeHook.InvalidPoolId.selector);
        hook.setAllowedMoonPool(bytes32(0), true);

        vm.stopPrank();
    }
}
