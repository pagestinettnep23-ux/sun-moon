// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { Test } from "forge-std/Test.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { MoonCurve } from "../../contracts/MoonCurve.sol";
import { MoonToken } from "../../contracts/MoonToken.sol";
import { SunCurve } from "../../contracts/SunCurve.sol";
import { SunToken } from "../../contracts/SunToken.sol";
import { MoonCurveMath } from "../../contracts/libraries/MoonCurveMath.sol";
import { MockUSDT } from "../../contracts/mocks/MockUSDT.sol";

contract SunCurveFuzzTest is Test {
    uint256 internal constant SUN_ONE = 1e18;
    uint256 internal constant USDT_ONE = 1e6;
    uint256 internal constant BPS = 10_000;
    uint256 internal constant FEE_TO_CURVE_BPS = 150;
    uint256 internal constant FEE_TO_PROTOCOL_BPS = 50;
    uint256 internal constant MAX_MINT_USDT = 10_000 * USDT_ONE;

    address internal owner = makeAddr("owner");
    address internal alice = makeAddr("alice");
    address internal bob = makeAddr("bob");
    address internal protocolBudget = makeAddr("protocolBudget");
    address internal moonCurve = makeAddr("moonCurve");
    address internal moonAMM = makeAddr("moonAMM");

    MockUSDT internal usdt;
    SunToken internal sun;
    SunCurve internal curve;

    function setUp() public {
        usdt = new MockUSDT("Mock USDT", "USDT", 6);
        sun = new SunToken("SUN", "SUN", owner);
        curve = new SunCurve(sun, usdt, protocolBudget, MAX_MINT_USDT, owner);

        vm.startPrank(owner);
        sun.setMinter(address(curve));
        curve.setMoonCurve(moonCurve);
        curve.setMoonAMM(moonAMM);
        vm.stopPrank();

        usdt.mint(alice, 1_000_000 * USDT_ONE);

        vm.prank(alice);
        usdt.approve(address(curve), type(uint256).max);
    }

    function testFuzzSunMintBurnAccounting(uint256 mintUsdtSeed, uint256 burnSeed) public {
        uint256 usdtIn = bound(mintUsdtSeed, 1, MAX_MINT_USDT);
        uint256 mintFeeToCurve = usdtIn * FEE_TO_CURVE_BPS / BPS;
        uint256 mintFeeToProtocol = usdtIn * FEE_TO_PROTOCOL_BPS / BPS;
        uint256 usdtNet = usdtIn - mintFeeToCurve - mintFeeToProtocol;

        vm.prank(alice);
        uint256 sunOut = curve.mint(usdtIn);

        assertEq(sunOut, usdtNet * 10 ** 12);
        assertEq(curve.curveReserve(), usdtIn - mintFeeToProtocol);
        assertEq(usdt.balanceOf(address(curve)), curve.curveReserve());
        assertEq(usdt.balanceOf(protocolBudget), mintFeeToProtocol);

        vm.roll(block.number + 1);

        uint256 burnAmount = bound(burnSeed, 1, sunOut);
        uint256 reserveBefore = curve.curveReserve();
        uint256 supplyBefore = sun.totalSupply();
        uint256 protocolBefore = usdt.balanceOf(protocolBudget);
        uint256 aliceUsdtBefore = usdt.balanceOf(alice);

        uint256 usdtGross = Math.mulDiv(reserveBefore, burnAmount, supplyBefore);
        uint256 burnFeeToCurve = usdtGross * FEE_TO_CURVE_BPS / BPS;
        uint256 burnFeeToProtocol = usdtGross * FEE_TO_PROTOCOL_BPS / BPS;
        uint256 expectedUsdtOut = usdtGross - burnFeeToCurve - burnFeeToProtocol;

        vm.startPrank(alice);
        sun.approve(address(curve), burnAmount);
        uint256 actualUsdtOut = curve.burn(burnAmount);
        vm.stopPrank();

        assertEq(actualUsdtOut, expectedUsdtOut);
        assertEq(usdt.balanceOf(alice) - aliceUsdtBefore, expectedUsdtOut);
        assertEq(usdt.balanceOf(protocolBudget) - protocolBefore, burnFeeToProtocol);
        assertEq(curve.curveReserve(), reserveBefore - expectedUsdtOut - burnFeeToProtocol);
        assertEq(usdt.balanceOf(address(curve)), curve.curveReserve());
        assertEq(sun.totalSupply(), supplyBefore - burnAmount);
    }

    function testFuzzSunPriceDoesNotDecreaseAcrossMints(uint256 firstSeed, uint256 secondSeed)
        public
    {
        uint256 firstUsdtIn = bound(firstSeed, 1, MAX_MINT_USDT);
        uint256 secondUsdtIn = bound(secondSeed, 1, MAX_MINT_USDT);

        vm.prank(alice);
        curve.mint(firstUsdtIn);
        uint256 priceAfterFirstMint = curve.getSunPrice();

        vm.prank(alice);
        curve.mint(secondUsdtIn);

        assertGe(curve.getSunPrice(), priceAfterFirstMint);
        assertEq(usdt.balanceOf(address(curve)), curve.curveReserve());
    }

    function testFuzzSunFreeTransferDoesNotChangeCurveState(
        uint256 mintUsdtSeed,
        uint256 transferSeed
    ) public {
        uint256 usdtIn = bound(mintUsdtSeed, 1, MAX_MINT_USDT);

        vm.prank(alice);
        curve.mint(usdtIn);

        uint256 reserveBefore = curve.curveReserve();
        uint256 supplyBefore = sun.totalSupply();
        uint256 priceBefore = curve.getSunPrice();
        uint256 transferAmount = bound(transferSeed, 0, sun.balanceOf(alice));

        vm.prank(alice);
        sun.transfer(bob, transferAmount);

        assertEq(curve.curveReserve(), reserveBefore);
        assertEq(usdt.balanceOf(address(curve)), reserveBefore);
        assertEq(sun.totalSupply(), supplyBefore);
        assertEq(curve.getSunPrice(), priceBefore);
        assertEq(sun.balanceOf(bob), transferAmount);
    }

    function testFuzzSunInjectUsdtAccounting(uint256 mintUsdtSeed, uint256 injectSeed) public {
        uint256 usdtIn = bound(mintUsdtSeed, 1, MAX_MINT_USDT);
        uint256 injectAmount = bound(injectSeed, 1, MAX_MINT_USDT);

        vm.prank(alice);
        curve.mint(usdtIn);

        uint256 reserveBefore = curve.curveReserve();
        uint256 supplyBefore = sun.totalSupply();
        uint256 priceBefore = curve.getSunPrice();

        usdt.mint(moonAMM, injectAmount);
        vm.startPrank(moonAMM);
        usdt.approve(address(curve), injectAmount);
        curve.injectUSDT(injectAmount);
        vm.stopPrank();

        assertEq(curve.curveReserve(), reserveBefore + injectAmount);
        assertEq(usdt.balanceOf(address(curve)), curve.curveReserve());
        assertEq(sun.totalSupply(), supplyBefore);
        assertGe(curve.getSunPrice(), priceBefore);
    }
}

contract MoonCurveFuzzTest is Test {
    uint256 internal constant TOKEN_ONE = 1e18;
    uint256 internal constant USDT_ONE = 1e6;
    uint256 internal constant SUN_MAX_MINT_USDT = 10_000 * USDT_ONE;
    uint256 internal constant MOON_MAX_MINT_USDT_EQUIV = 10_000 * USDT_ONE;
    uint256 internal constant K = 5_000_000 * TOKEN_ONE;
    uint256 internal constant S = 1_200_000 * TOKEN_ONE;

    address internal owner = makeAddr("owner");
    address internal alice = makeAddr("alice");
    address internal bob = makeAddr("bob");
    address internal protocolBudget = makeAddr("protocolBudget");
    address internal moonAMM = makeAddr("moonAMM");

    MockUSDT internal usdt;
    SunToken internal sun;
    SunCurve internal sunCurve;
    MoonToken internal moon;
    MoonCurve internal moonCurve;

    function setUp() public {
        usdt = new MockUSDT("Mock USDT", "USDT", 6);
        sun = new SunToken("SUN", "SUN", owner);
        sunCurve = new SunCurve(sun, usdt, protocolBudget, SUN_MAX_MINT_USDT, owner);
        moon = new MoonToken("MOON", "MOON", owner);
        moonCurve = new MoonCurve(
            moon, sun, sunCurve, protocolBudget, K, S, 0, MOON_MAX_MINT_USDT_EQUIV, owner
        );

        vm.startPrank(owner);
        sun.setMinter(address(sunCurve));
        sunCurve.setMoonCurve(address(moonCurve));
        sunCurve.setMoonAMM(moonAMM);
        moon.setMinter(address(moonCurve));
        vm.stopPrank();

        usdt.mint(alice, 1_000_000 * USDT_ONE);

        vm.startPrank(alice);
        usdt.approve(address(sunCurve), type(uint256).max);
        sun.approve(address(moonCurve), type(uint256).max);
        vm.stopPrank();
    }

    function testFuzzMoonMintAccounting(uint256 seedUsdtSeed, uint256 sunInSeed) public {
        _seedSun(seedUsdtSeed);

        uint256 sunIn = _boundSunIn(sunInSeed);
        uint256 sunSupplyBefore = sun.totalSupply();
        uint256 sunPriceBefore = sunCurve.getSunPrice();
        MoonCurveMath.MintQuote memory quote = MoonCurveMath.mintQuote(K, S, 0, sunIn);

        vm.prank(alice);
        uint256 moonOut = moonCurve.mint(sunIn);

        assertEq(moonOut, quote.moonOut);
        assertEq(moon.balanceOf(alice), quote.moonOut);
        assertEq(moon.totalSupply(), quote.moonOut);
        assertEq(moonCurve.sunReserve(), quote.sunNet);
        assertEq(sun.balanceOf(address(moonCurve)), quote.sunNet);
        assertEq(sun.balanceOf(protocolBudget), quote.feeToProtocol);
        assertEq(sun.totalSupply(), sunSupplyBefore - quote.feeToSunCurve);
        assertGe(sunCurve.getSunPrice(), sunPriceBefore);
    }

    function testFuzzMoonMintBurnAccounting(
        uint256 seedUsdtSeed,
        uint256 sunInSeed,
        uint256 burnSeed
    ) public {
        _seedSun(seedUsdtSeed);
        uint256 sunIn = _boundSunIn(sunInSeed);

        vm.prank(alice);
        uint256 moonOut = moonCurve.mint(sunIn);
        vm.roll(block.number + 1);

        uint256 burnAmount = bound(burnSeed, 1e15, moonOut);
        MoonCurveMath.BurnQuote memory quote =
            MoonCurveMath.burnQuote(K, S, moonCurve.sunReserve(), burnAmount);
        uint256 aliceSunBefore = sun.balanceOf(alice);
        uint256 protocolSunBefore = sun.balanceOf(protocolBudget);
        uint256 sunSupplyBefore = sun.totalSupply();
        uint256 sunPriceBefore = sunCurve.getSunPrice();

        vm.prank(alice);
        uint256 sunOut = moonCurve.burn(burnAmount);

        assertEq(sunOut, quote.sunOut);
        assertEq(sun.balanceOf(alice) - aliceSunBefore, quote.sunOut);
        assertEq(sun.balanceOf(protocolBudget) - protocolSunBefore, quote.feeToProtocol);
        assertEq(moonCurve.sunReserve(), quote.nextSunReserve);
        assertEq(sun.balanceOf(address(moonCurve)), quote.nextSunReserve);
        assertEq(sun.totalSupply(), sunSupplyBefore - quote.feeToSunCurve);
        assertEq(moon.totalSupply(), moonOut - burnAmount);
        assertGe(sunCurve.getSunPrice(), sunPriceBefore);
    }

    function testFuzzMoonFreeTransferDoesNotChangeCurveState(
        uint256 seedUsdtSeed,
        uint256 sunInSeed,
        uint256 transferSeed
    ) public {
        _seedSun(seedUsdtSeed);
        uint256 sunIn = _boundSunIn(sunInSeed);

        vm.prank(alice);
        uint256 moonOut = moonCurve.mint(sunIn);

        uint256 reserveBefore = moonCurve.sunReserve();
        uint256 fairSupplyBefore = moonCurve.currentFairSupply();
        uint256 transferAmount = bound(transferSeed, 0, moonOut);

        vm.prank(alice);
        moon.transfer(bob, transferAmount);

        assertEq(moonCurve.sunReserve(), reserveBefore);
        assertEq(moonCurve.currentFairSupply(), fairSupplyBefore);
        assertEq(moon.totalSupply(), moonOut);
        assertEq(moon.balanceOf(bob), transferAmount);
    }

    function _seedSun(uint256 seedUsdtSeed) private {
        uint256 seedUsdtIn = bound(seedUsdtSeed, 2000 * USDT_ONE, SUN_MAX_MINT_USDT);

        vm.prank(alice);
        sunCurve.mint(seedUsdtIn);
    }

    function _boundSunIn(uint256 sunInSeed) private view returns (uint256) {
        uint256 maxSunIn = sun.balanceOf(alice);
        if (maxSunIn > 1000 * TOKEN_ONE) {
            maxSunIn = 1000 * TOKEN_ONE;
        }

        return bound(sunInSeed, 1 * TOKEN_ONE, maxSunIn);
    }
}
