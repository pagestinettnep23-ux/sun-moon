// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { Test } from "forge-std/Test.sol";
import { MoonCurve } from "../contracts/MoonCurve.sol";
import { MoonToken } from "../contracts/MoonToken.sol";
import { SunCurve } from "../contracts/SunCurve.sol";
import { SunToken } from "../contracts/SunToken.sol";
import { MoonCurveMath } from "../contracts/libraries/MoonCurveMath.sol";
import { MockUSDT } from "../contracts/mocks/MockUSDT.sol";

contract MoonCurveTest is Test {
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

        usdt.mint(alice, 100_000 * USDT_ONE);
        usdt.mint(bob, 100_000 * USDT_ONE);

        vm.startPrank(alice);
        usdt.approve(address(sunCurve), type(uint256).max);
        sun.approve(address(moonCurve), type(uint256).max);
        vm.stopPrank();

        vm.startPrank(bob);
        usdt.approve(address(sunCurve), type(uint256).max);
        sun.approve(address(moonCurve), type(uint256).max);
        vm.stopPrank();
    }

    function testMoonTokenMinterCanOnlyBeLockedOnce() public {
        assertEq(moon.minter(), address(moonCurve));
        assertTrue(moon.minterLocked());

        vm.prank(owner);
        vm.expectRevert(MoonToken.MinterAlreadyLocked.selector);
        moon.setMinter(makeAddr("otherMinter"));

        vm.expectRevert(MoonToken.NotMinter.selector);
        moon.mint(alice, 1);
    }

    function testMoonTokenRejectsZeroMinter() public {
        MoonToken freshMoon = new MoonToken("Fresh MOON", "FMOON", owner);

        vm.prank(owner);
        vm.expectRevert(MoonToken.InvalidAddress.selector);
        freshMoon.setMinter(address(0));
    }

    function testMoonCurveRejectsInvalidConstructorArgs() public {
        vm.expectRevert(MoonCurve.InvalidAddress.selector);
        new MoonCurve(
            MoonToken(address(0)),
            sun,
            sunCurve,
            protocolBudget,
            K,
            S,
            0,
            MOON_MAX_MINT_USDT_EQUIV,
            owner
        );

        vm.expectRevert(MoonCurve.InvalidAddress.selector);
        new MoonCurve(
            moon,
            SunToken(address(0)),
            sunCurve,
            protocolBudget,
            K,
            S,
            0,
            MOON_MAX_MINT_USDT_EQUIV,
            owner
        );

        vm.expectRevert(MoonCurve.InvalidAddress.selector);
        new MoonCurve(
            moon,
            sun,
            SunCurve(address(0)),
            protocolBudget,
            K,
            S,
            0,
            MOON_MAX_MINT_USDT_EQUIV,
            owner
        );

        vm.expectRevert(MoonCurve.InvalidAddress.selector);
        new MoonCurve(moon, sun, sunCurve, address(0), K, S, 0, MOON_MAX_MINT_USDT_EQUIV, owner);

        vm.expectRevert(MoonCurve.InvalidCurveParameter.selector);
        new MoonCurve(moon, sun, sunCurve, protocolBudget, 0, S, 0, MOON_MAX_MINT_USDT_EQUIV, owner);

        vm.expectRevert(MoonCurve.InvalidCurveParameter.selector);
        new MoonCurve(moon, sun, sunCurve, protocolBudget, K, 0, 0, MOON_MAX_MINT_USDT_EQUIV, owner);

        vm.expectRevert(MoonCurve.InvalidAmount.selector);
        new MoonCurve(moon, sun, sunCurve, protocolBudget, K, S, 0, 0, owner);
    }

    function testMoonMintRejectsBeforeLaunch() public {
        MoonToken delayedMoon = new MoonToken("Delayed MOON", "DMOON", owner);
        MoonCurve delayedCurve = new MoonCurve(
            delayedMoon,
            sun,
            sunCurve,
            protocolBudget,
            K,
            S,
            block.timestamp + 1 days,
            MOON_MAX_MINT_USDT_EQUIV,
            owner
        );

        vm.startPrank(owner);
        delayedMoon.setMinter(address(delayedCurve));
        sunCurve.setMoonCurve(address(delayedCurve));
        vm.stopPrank();

        _mintSunTo(alice, 1000 * USDT_ONE);

        vm.prank(alice);
        vm.expectRevert(MoonCurve.MintNotLaunched.selector);
        delayedCurve.mint(100 * TOKEN_ONE);
    }

    function testMoonMintMatchesMathAndTransfersFees() public {
        _mintSunTo(alice, 2000 * USDT_ONE);
        uint256 sunIn = 1000 * TOKEN_ONE;
        uint256 sunSupplyBefore = sun.totalSupply();
        uint256 sunPriceBefore = sunCurve.getSunPrice();
        MoonCurveMath.MintQuote memory quote = MoonCurveMath.mintQuote(K, S, 0, sunIn);

        vm.prank(alice);
        uint256 moonOut = moonCurve.mint(sunIn);

        assertEq(moonOut, quote.moonOut);
        assertEq(moon.balanceOf(alice), quote.moonOut);
        assertEq(moonCurve.sunReserve(), quote.sunNet);
        assertEq(sun.balanceOf(address(moonCurve)), quote.sunNet);
        assertEq(sun.balanceOf(protocolBudget), quote.feeToProtocol);
        assertEq(sun.balanceOf(address(sunCurve)), 0);
        assertEq(sun.totalSupply(), sunSupplyBefore - quote.feeToSunCurve);
        assertGt(sunCurve.getSunPrice(), sunPriceBefore);
    }

    function testMoonMintRejectsZeroAmount() public {
        vm.prank(alice);
        vm.expectRevert(MoonCurveMath.InvalidAmount.selector);
        moonCurve.mint(0);
    }

    function testMoonMintForRejectsZeroReceiver() public {
        vm.prank(alice);
        vm.expectRevert(MoonCurve.InvalidAddress.selector);
        moonCurve.mintFor(address(0), 1 * TOKEN_ONE);
    }

    function testMoonMintForTracksLastMintBlockForPayerOnly() public {
        _mintSunTo(alice, 2000 * USDT_ONE);
        uint256 currentBlock = block.number;

        vm.prank(alice);
        uint256 moonOut = moonCurve.mintFor(bob, 1000 * TOKEN_ONE);

        assertEq(moonCurve.lastMintBlock(alice), currentBlock);
        assertEq(moonCurve.lastMintBlock(bob), 0);

        vm.prank(bob);
        uint256 sunOut = moonCurve.burn(moonOut / 2);

        assertGt(sunOut, 0);
    }

    function testMoonMintRejectsWithoutSunApproval() public {
        address charlie = makeAddr("charlie");
        usdt.mint(charlie, 1000 * USDT_ONE);

        vm.startPrank(charlie);
        usdt.approve(address(sunCurve), type(uint256).max);
        sunCurve.mint(1000 * USDT_ONE);
        vm.expectRevert();
        moonCurve.mint(100 * TOKEN_ONE);
        vm.stopPrank();
    }

    function testSameSunInputMintsLessMoonAtHigherReserve() public {
        _mintSunTo(alice, 4000 * USDT_ONE);
        _mintSunTo(bob, 4000 * USDT_ONE);

        vm.prank(alice);
        uint256 firstMoonOut = moonCurve.mint(1000 * TOKEN_ONE);

        vm.prank(bob);
        uint256 secondMoonOut = moonCurve.mint(1000 * TOKEN_ONE);

        assertLt(secondMoonOut, firstMoonOut);
        assertEq(moonCurve.sunReserve(), 1900 * TOKEN_ONE);
    }

    function testMoonMintLimitUsesFullSunInputBeforeFees() public {
        MoonToken lowLimitMoon = new MoonToken("Low Limit MOON", "LMOON", owner);
        MoonCurve lowLimitCurve = new MoonCurve(
            lowLimitMoon, sun, sunCurve, protocolBudget, K, S, 0, 50 * USDT_ONE, owner
        );

        vm.startPrank(owner);
        lowLimitMoon.setMinter(address(lowLimitCurve));
        sunCurve.setMoonCurve(address(lowLimitCurve));
        vm.stopPrank();

        _mintSunTo(alice, 1000 * USDT_ONE);

        vm.startPrank(alice);
        sun.approve(address(lowLimitCurve), type(uint256).max);
        vm.expectRevert(MoonCurve.MaxMintExceeded.selector);
        lowLimitCurve.mint(50 * TOKEN_ONE);
        vm.stopPrank();
    }

    function testMoonBurnReturnsSunAndDeductsFullGrossReserve() public {
        _mintSunTo(alice, 2000 * USDT_ONE);
        uint256 sunIn = 1000 * TOKEN_ONE;

        vm.prank(alice);
        uint256 moonOut = moonCurve.mint(sunIn);
        vm.roll(block.number + 1);

        uint256 burnAmount = moonOut / 2;
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
        assertEq(moon.balanceOf(alice), moonOut - burnAmount);
        assertGt(sunCurve.getSunPrice(), sunPriceBefore);
    }

    function testMoonFullBurnLeavesOnlyTinyRoundingReserve() public {
        _mintSunTo(alice, 2000 * USDT_ONE);

        vm.prank(alice);
        uint256 moonOut = moonCurve.mint(1000 * TOKEN_ONE);
        vm.roll(block.number + 1);

        vm.prank(alice);
        moonCurve.burn(moonOut);

        assertApproxEqAbs(moonCurve.sunReserve(), 0, 1e10);
        assertApproxEqAbs(sun.balanceOf(address(moonCurve)), 0, 1e10);
        assertEq(moon.balanceOf(alice), 0);
    }

    function testMoonBurnRejectsMoreThanFairSupply() public {
        _mintSunTo(alice, 2000 * USDT_ONE);

        vm.prank(alice);
        moonCurve.mint(1000 * TOKEN_ONE);
        vm.roll(block.number + 1);

        uint256 fairSupply = moonCurve.currentFairSupply();

        vm.prank(alice);
        vm.expectRevert(MoonCurveMath.BurnAmountExceedsFairSupply.selector);
        moonCurve.burn(fairSupply + 1);
    }

    function testMoonBurnRejectsZeroAmount() public {
        vm.prank(alice);
        vm.expectRevert(MoonCurveMath.InvalidAmount.selector);
        moonCurve.burn(0);
    }

    function testMoonBurnToRejectsZeroReceiver() public {
        vm.prank(alice);
        vm.expectRevert(MoonCurve.InvalidAddress.selector);
        moonCurve.burnTo(address(0), 1);
    }

    function testMoonBurnRejectsSameBlockAfterMint() public {
        _mintSunTo(alice, 2000 * USDT_ONE);

        vm.prank(alice);
        uint256 moonOut = moonCurve.mint(1000 * TOKEN_ONE);

        vm.prank(alice);
        vm.expectRevert(MoonCurve.SameBlockMintBurn.selector);
        moonCurve.burn(moonOut / 2);

        vm.roll(block.number + 1);

        vm.prank(alice);
        uint256 sunOut = moonCurve.burn(moonOut / 2);

        assertGt(sunOut, 0);
    }

    function testMoonBurnToRejectsSameBlockAfterMint() public {
        _mintSunTo(alice, 2000 * USDT_ONE);

        vm.prank(alice);
        uint256 moonOut = moonCurve.mint(1000 * TOKEN_ONE);

        vm.prank(alice);
        vm.expectRevert(MoonCurve.SameBlockMintBurn.selector);
        moonCurve.burnTo(bob, moonOut / 2);
    }

    function testMoonBurnAllowsDifferentPayerWhenAnotherUserMintedSameBlock() public {
        _mintSunTo(bob, 2000 * USDT_ONE);

        vm.prank(bob);
        uint256 bobMoonOut = moonCurve.mint(1000 * TOKEN_ONE);

        vm.roll(block.number + 1);

        _mintSunTo(alice, 2000 * USDT_ONE);

        vm.prank(alice);
        moonCurve.mint(1000 * TOKEN_ONE);

        vm.prank(bob);
        uint256 sunOut = moonCurve.burn(bobMoonOut / 2);

        assertGt(sunOut, 0);
    }

    function testR04MoonMintForVictimSameBlockAllowsVictimBurn() public {
        _mintSunTo(alice, 2000 * USDT_ONE);
        _mintSunTo(bob, 2000 * USDT_ONE);

        vm.prank(alice);
        uint256 victimMoon = moonCurve.mint(1000 * TOKEN_ONE);

        vm.roll(block.number + 1);

        vm.prank(bob);
        uint256 dustMoon = moonCurve.mintFor(alice, 1e12);

        assertGt(dustMoon, 0);
        assertLt(moonCurve.lastMintBlock(alice), block.number);
        assertEq(moonCurve.lastMintBlock(bob), block.number);

        vm.prank(alice);
        uint256 sunOut = moonCurve.burn(victimMoon / 2);

        assertGt(sunOut, 0);
    }

    function testR04MoonMintForVictimSameBlockAllowsVictimBurnTo() public {
        _mintSunTo(alice, 2000 * USDT_ONE);
        _mintSunTo(bob, 2000 * USDT_ONE);

        vm.prank(alice);
        uint256 victimMoon = moonCurve.mint(1000 * TOKEN_ONE);

        vm.roll(block.number + 1);

        vm.prank(bob);
        uint256 dustMoon = moonCurve.mintFor(alice, 1e12);

        assertGt(dustMoon, 0);
        assertLt(moonCurve.lastMintBlock(alice), block.number);
        assertEq(moonCurve.lastMintBlock(bob), block.number);

        vm.prank(alice);
        uint256 sunOut = moonCurve.burnTo(bob, victimMoon / 2);

        assertGt(sunOut, 0);
    }

    function testMoonBurnRejectsWhenUserHasNoMoon() public {
        _mintSunTo(alice, 2000 * USDT_ONE);

        vm.prank(alice);
        uint256 moonOut = moonCurve.mint(1000 * TOKEN_ONE);
        vm.roll(block.number + 1);

        vm.prank(bob);
        vm.expectRevert();
        moonCurve.burn(moonOut / 2);
    }

    function testMoonMintPriceInUsdtFollowsSunPrice() public {
        _mintSunTo(alice, 2000 * USDT_ONE);
        uint256 priceBefore = moonCurve.getMintPriceInUSDT();

        usdt.mint(moonAMM, 1000 * USDT_ONE);

        vm.startPrank(moonAMM);
        usdt.approve(address(sunCurve), 1000 * USDT_ONE);
        sunCurve.injectUSDT(1000 * USDT_ONE);
        vm.stopPrank();

        assertGt(moonCurve.getMintPriceInUSDT(), priceBefore);
    }

    function _mintSunTo(address user, uint256 usdtIn) internal returns (uint256 sunOut) {
        vm.prank(user);
        return sunCurve.mint(usdtIn);
    }
}
