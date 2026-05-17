// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { Test } from "forge-std/Test.sol";
import { AmmSwapAdapter } from "../../contracts/hooks/AmmSwapAdapter.sol";
import { MoonAmmFeeHook } from "../../contracts/hooks/MoonAmmFeeHook.sol";
import { SunAmmGuardHook } from "../../contracts/hooks/SunAmmGuardHook.sol";
import { MoonCurve } from "../../contracts/MoonCurve.sol";
import { MoonToken } from "../../contracts/MoonToken.sol";
import { SunCurve } from "../../contracts/SunCurve.sol";
import { SunToken } from "../../contracts/SunToken.sol";
import { MockUSDT } from "../../contracts/mocks/MockUSDT.sol";

contract IntegrationSunPoolManager {
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

contract IntegrationMoonPoolManager {
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

contract HookIntegrationTest is Test {
    uint256 internal constant TOKEN_ONE = 1e18;
    uint256 internal constant USDT_ONE = 1e6;
    uint256 internal constant SUN_MAX_MINT_USDT = 10_000 * USDT_ONE;
    uint256 internal constant MOON_MAX_MINT_USDT_EQUIV = 10_000 * USDT_ONE;
    uint256 internal constant K = 5_000_000 * TOKEN_ONE;
    uint256 internal constant S = 1_200_000 * TOKEN_ONE;

    address internal owner = makeAddr("owner");
    address internal firstLiquidityProvider = makeAddr("firstLiquidityProvider");
    address internal trader = makeAddr("trader");
    address internal user = makeAddr("user");
    address internal protocolBudget = makeAddr("protocolBudget");
    address internal otherToken0 = makeAddr("OTHER0");
    address internal otherToken1 = makeAddr("OTHER1");

    bytes32 internal sunUsdtPool = keccak256("SUN_USDT_POOL");
    bytes32 internal moonUsdtPool = keccak256("MOON_USDT_POOL");
    bytes32 internal moonFeePool = keccak256("MOON_FEE_POOL");
    bytes32 internal nonSunPool = keccak256("NON_SUN_POOL");
    bytes32 internal nonMoonPool = keccak256("NON_MOON_POOL");

    MockUSDT internal usdt;
    MockUSDT internal feeAsset;
    SunToken internal sun;
    SunCurve internal sunCurve;
    MoonToken internal moon;
    MoonCurve internal moonCurve;
    SunAmmGuardHook internal sunHook;
    MoonAmmFeeHook internal moonHook;
    AmmSwapAdapter internal adapter;
    IntegrationSunPoolManager internal sunPoolManager;
    IntegrationMoonPoolManager internal moonPoolManager;

    function setUp() public {
        usdt = new MockUSDT("Mock USDT", "USDT", 6);
        feeAsset = new MockUSDT("Mock Fee Asset", "MFEE", 18);
        sun = new SunToken("SUN", "SUN", owner);
        sunCurve = new SunCurve(sun, usdt, protocolBudget, SUN_MAX_MINT_USDT, owner);
        moon = new MoonToken("MOON", "MOON", owner);
        moonCurve = new MoonCurve(
            moon, sun, sunCurve, protocolBudget, K, S, 0, MOON_MAX_MINT_USDT_EQUIV, owner
        );
        sunHook = new SunAmmGuardHook(address(sun), firstLiquidityProvider, owner, owner);
        moonHook = new MoonAmmFeeHook(address(moon), usdt, sunCurve, protocolBudget, owner, owner);
        adapter = new AmmSwapAdapter(usdt, address(moonHook), owner);
        sunPoolManager = new IntegrationSunPoolManager(sunHook);
        moonPoolManager = new IntegrationMoonPoolManager(moonHook);

        vm.startPrank(owner);
        sun.setMinter(address(sunCurve));
        sunCurve.setMoonCurve(address(moonCurve));
        sunCurve.setMoonAMM(address(moonHook));
        moon.setMinter(address(moonCurve));
        sunHook.setHookCaller(address(sunPoolManager));
        sunHook.setAllowedSunPool(sunUsdtPool, true);
        moonHook.setHookCaller(address(moonPoolManager));
        moonHook.setSwapAdapter(address(adapter));
        moonHook.setAllowedMoonPool(moonUsdtPool, true);
        moonHook.setAllowedMoonPool(moonFeePool, true);
        vm.stopPrank();

        usdt.mint(user, 20_000 * USDT_ONE);
        usdt.mint(trader, 10_000 * USDT_ONE);
        feeAsset.mint(trader, 10_000 * TOKEN_ONE);

        vm.startPrank(user);
        usdt.approve(address(sunCurve), type(uint256).max);
        sun.approve(address(moonCurve), type(uint256).max);
        vm.stopPrank();

        vm.prank(trader);
        usdt.approve(address(moonHook), type(uint256).max);

        vm.prank(trader);
        feeAsset.approve(address(moonHook), type(uint256).max);
    }

    function testMoonAmmFeeInjectionRaisesSunPriceAndMoonUsdtMintPrice() public {
        _seedSunCurve();

        uint256 sunPriceBefore = sunCurve.getSunPrice();
        uint256 moonUsdtMintPriceBefore = moonCurve.getMintPriceInUSDT();
        uint256 feeBaseAmount = 1000 * USDT_ONE;
        uint256 feeToSunCurve = 30 * USDT_ONE;

        vm.prank(trader);
        bytes4 selector = moonPoolManager.swap(
            trader,
            moonUsdtPool,
            address(moon),
            address(usdt),
            address(usdt),
            feeBaseAmount,
            feeToSunCurve
        );

        assertEq(selector, moonHook.afterSwap.selector);
        assertEq(sunCurve.curveReserve(), 995 * USDT_ONE + feeToSunCurve);
        assertEq(usdt.balanceOf(address(sunCurve)), 995 * USDT_ONE + feeToSunCurve);
        assertEq(usdt.balanceOf(protocolBudget), 5 * USDT_ONE + 20 * USDT_ONE);
        assertGt(sunCurve.getSunPrice(), sunPriceBefore);
        assertGt(moonCurve.getMintPriceInUSDT(), moonUsdtMintPriceBefore);
    }

    function testHooksDoNotInterfereWithStationMintBurnFlow() public {
        usdt.mint(user, 2000 * USDT_ONE);

        vm.startPrank(user);
        uint256 sunOut = sunCurve.mint(1000 * USDT_ONE);

        uint256 sunPriceAfterSunMint = sunCurve.getSunPrice();
        uint256 moonOut = moonCurve.mint(500 * TOKEN_ONE);

        assertEq(sunOut, 980 * TOKEN_ONE);
        assertEq(moon.balanceOf(user), moonOut);
        assertEq(moonCurve.sunReserve(), 475 * TOKEN_ONE);
        assertGt(sunCurve.getSunPrice(), sunPriceAfterSunMint);

        vm.roll(block.number + 1);

        uint256 sunBeforeMoonBurn = sun.balanceOf(user);
        uint256 sunOutFromMoonBurn = moonCurve.burn(moonOut / 2);

        assertEq(sun.balanceOf(user), sunBeforeMoonBurn + sunOutFromMoonBurn);
        assertGt(sunOutFromMoonBurn, 0);

        vm.roll(block.number + 1);

        uint256 usdtBeforeSunBurn = usdt.balanceOf(user);
        sun.approve(address(sunCurve), 100 * TOKEN_ONE);
        sunCurve.burn(100 * TOKEN_ONE);

        assertGt(usdt.balanceOf(user), usdtBeforeSunBurn);
        vm.stopPrank();
    }

    function testMoonFeeAssetUsesAdapterThenInjectsSunCurve() public {
        _seedSunCurve();

        uint256 sunPriceBefore = sunCurve.getSunPrice();
        uint256 moonUsdtMintPriceBefore = moonCurve.getMintPriceInUSDT();
        uint256 feeBaseAmount = 1000 * TOKEN_ONE;
        uint256 feeToSunCurveAsset = 30 * TOKEN_ONE;
        uint256 feeToProtocolAsset = 20 * TOKEN_ONE;
        uint256 usdtOut = 45 * USDT_ONE;

        vm.prank(owner);
        adapter.setMockUSDTOut(usdtOut);

        vm.prank(trader);
        bytes4 selector = moonPoolManager.swap(
            trader,
            moonFeePool,
            address(moon),
            address(feeAsset),
            address(feeAsset),
            feeBaseAmount,
            40 * USDT_ONE
        );

        assertEq(selector, moonHook.afterSwap.selector);
        assertEq(feeAsset.balanceOf(address(adapter)), feeToSunCurveAsset);
        assertEq(feeAsset.balanceOf(protocolBudget), feeToProtocolAsset);
        assertEq(sunCurve.curveReserve(), 995 * USDT_ONE + usdtOut);
        assertEq(usdt.balanceOf(address(sunCurve)), 995 * USDT_ONE + usdtOut);
        assertGt(sunCurve.getSunPrice(), sunPriceBefore);
        assertGt(moonCurve.getMintPriceInUSDT(), moonUsdtMintPriceBefore);
    }

    function testSunAndMoonHookStateMachinesStaySeparate() public {
        _seedSunCurve();

        vm.prank(trader);
        moonPoolManager.swap(
            trader,
            moonUsdtPool,
            address(moon),
            address(usdt),
            address(usdt),
            1000 * USDT_ONE,
            30 * USDT_ONE
        );

        assertFalse(sunHook.sunAmmUnlocked());

        vm.prank(firstLiquidityProvider);
        bytes4 sunSelector = sunPoolManager.addLiquidity(
            firstLiquidityProvider, sunUsdtPool, address(sun), address(usdt)
        );

        assertEq(sunSelector, sunHook.beforeAddLiquidity.selector);
        assertTrue(sunHook.sunAmmUnlocked());
        assertTrue(moonHook.allowedMoonPools(moonUsdtPool));
    }

    function testNonSunAndNonMoonPoolsRemainUnaffected() public {
        uint256 traderUsdtBefore = usdt.balanceOf(trader);

        vm.prank(user);
        bytes4 sunSelector = sunPoolManager.addLiquidity(user, nonSunPool, otherToken0, otherToken1);

        vm.prank(trader);
        bytes4 moonSelector = moonPoolManager.swap(
            trader, nonMoonPool, otherToken0, otherToken1, address(usdt), 1000 * USDT_ONE, 1
        );

        assertEq(sunSelector, sunHook.beforeAddLiquidity.selector);
        assertEq(moonSelector, moonHook.afterSwap.selector);
        assertFalse(sunHook.sunAmmUnlocked());
        assertEq(usdt.balanceOf(trader), traderUsdtBefore);
        assertEq(usdt.balanceOf(address(moonHook)), 0);
    }

    function _seedSunCurve() internal {
        vm.prank(user);
        uint256 sunOut = sunCurve.mint(1000 * USDT_ONE);

        assertEq(sunOut, 980 * TOKEN_ONE);
        assertEq(sunCurve.curveReserve(), 995 * USDT_ONE);
        assertGt(sunCurve.getSunPrice(), 0);
    }
}
