// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { Test } from "forge-std/Test.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { SunCurve } from "../contracts/SunCurve.sol";
import { SunToken } from "../contracts/SunToken.sol";
import { MockUSDT } from "../contracts/mocks/MockUSDT.sol";

contract SunCurveTest is Test {
    uint256 internal constant SUN_ONE = 1e18;
    uint256 internal constant USDT_ONE = 1e6;
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

        usdt.mint(alice, 100_000 * USDT_ONE);
        usdt.mint(bob, 100_000 * USDT_ONE);

        vm.prank(alice);
        usdt.approve(address(curve), type(uint256).max);

        vm.prank(bob);
        usdt.approve(address(curve), type(uint256).max);
    }

    function testSunTokenMinterCanOnlyBeLockedOnce() public {
        assertEq(sun.minter(), address(curve));
        assertTrue(sun.minterLocked());

        vm.prank(owner);
        vm.expectRevert(SunToken.MinterAlreadyLocked.selector);
        sun.setMinter(makeAddr("otherMinter"));

        vm.expectRevert(SunToken.NotMinter.selector);
        sun.mint(alice, 1);
    }

    function testSunTokenRejectsZeroMinter() public {
        SunToken freshSun = new SunToken("Fresh SUN", "FSUN", owner);

        vm.prank(owner);
        vm.expectRevert(SunToken.InvalidAddress.selector);
        freshSun.setMinter(address(0));
    }

    function testSunCurveRejectsInvalidConstructorArgs() public {
        vm.expectRevert(SunCurve.InvalidAddress.selector);
        new SunCurve(SunToken(address(0)), usdt, protocolBudget, MAX_MINT_USDT, owner);

        vm.expectRevert(SunCurve.InvalidAddress.selector);
        new SunCurve(sun, MockUSDT(address(0)), protocolBudget, MAX_MINT_USDT, owner);

        vm.expectRevert(SunCurve.InvalidAddress.selector);
        new SunCurve(sun, usdt, address(0), MAX_MINT_USDT, owner);

        vm.expectRevert(SunCurve.InvalidAmount.selector);
        new SunCurve(sun, usdt, protocolBudget, 0, owner);

        MockUSDT invalidDecimalsUsdt = new MockUSDT("Bad USDT", "BUSDT", 19);

        vm.expectRevert(SunCurve.InvalidUSDTDecimals.selector);
        new SunCurve(sun, invalidDecimalsUsdt, protocolBudget, MAX_MINT_USDT, owner);
    }

    function testSunOwnerSettersRejectZeroAddress() public {
        vm.startPrank(owner);

        vm.expectRevert(SunCurve.InvalidAddress.selector);
        curve.setMoonCurve(address(0));

        vm.expectRevert(SunCurve.InvalidAddress.selector);
        curve.setMoonAMM(address(0));

        vm.stopPrank();
    }

    function testFirstSunMintMatchesMathBook() public {
        vm.prank(alice);
        uint256 sunOut = curve.mint(100 * USDT_ONE);

        assertEq(sunOut, 98 * SUN_ONE);
        assertEq(sun.balanceOf(alice), 98 * SUN_ONE);
        assertEq(curve.curveReserve(), 99_500_000);
        assertEq(curve.getSunPrice(), 1_015_306);
        assertEq(usdt.balanceOf(address(curve)), 99_500_000);
        assertEq(usdt.balanceOf(protocolBudget), 500_000);
    }

    function testSecondSunMintUsesPreviousCurvePriceAndRaisesPrice() public {
        vm.prank(alice);
        curve.mint(100 * USDT_ONE);
        uint256 priceBefore = curve.getSunPrice();

        vm.prank(alice);
        uint256 secondSunOut = curve.mint(100 * USDT_ONE);

        uint256 expectedSunOut = Math.mulDiv(98 * SUN_ONE, 98 * USDT_ONE, 99_500_000);

        assertEq(secondSunOut, expectedSunOut);
        assertEq(curve.curveReserve(), 199_000_000);
        assertEq(sun.totalSupply(), 98 * SUN_ONE + expectedSunOut);
        assertEq(usdt.balanceOf(protocolBudget), 1_000_000);
        assertGt(curve.getSunPrice(), priceBefore);
    }

    function testSunMintRejectsMoreThanTenThousandUsdt() public {
        vm.prank(alice);
        vm.expectRevert(SunCurve.MaxMintExceeded.selector);
        curve.mint(MAX_MINT_USDT + 1);
    }

    function testSunMintRejectsZeroAmount() public {
        vm.prank(alice);
        vm.expectRevert(SunCurve.InvalidAmount.selector);
        curve.mint(0);
    }

    function testSunMintForRejectsZeroReceiver() public {
        vm.prank(alice);
        vm.expectRevert(SunCurve.InvalidAddress.selector);
        curve.mintFor(address(0), 100 * USDT_ONE);
    }

    function testSunMintForTracksLastMintBlockForPayerAndReceiver() public {
        uint256 currentBlock = block.number;

        vm.prank(alice);
        uint256 minted = curve.mintFor(bob, 100 * USDT_ONE);

        assertEq(curve.lastMintBlock(alice), currentBlock);
        assertEq(curve.lastMintBlock(bob), currentBlock);

        vm.prank(bob);
        sun.approve(address(curve), minted);

        vm.prank(bob);
        vm.expectRevert(SunCurve.SameBlockMintBurn.selector);
        curve.burn(minted / 2);
    }

    function testSunMintAllowsExactlyTenThousandUsdt() public {
        vm.prank(alice);
        uint256 sunOut = curve.mint(MAX_MINT_USDT);

        assertEq(sunOut, 9800 * SUN_ONE);
        assertEq(curve.curveReserve(), 9950 * USDT_ONE);
        assertEq(sun.totalSupply(), 9800 * SUN_ONE);
        assertEq(usdt.balanceOf(protocolBudget), 50 * USDT_ONE);
    }

    function testSunBurnReturnsNetUsdtAndKeepsCurveFee() public {
        vm.prank(alice);
        uint256 minted = curve.mint(1000 * USDT_ONE);
        uint256 priceBefore = curve.getSunPrice();
        vm.roll(block.number + 1);

        vm.prank(alice);
        sun.approve(address(curve), minted / 2);

        uint256 aliceUsdtBefore = usdt.balanceOf(alice);

        vm.prank(alice);
        uint256 usdtOut = curve.burn(minted / 2);

        assertEq(usdtOut, 487_550_000);
        assertEq(usdt.balanceOf(alice) - aliceUsdtBefore, 487_550_000);
        assertEq(curve.curveReserve(), 504_962_500);
        assertEq(sun.totalSupply(), 490 * SUN_ONE);
        assertEq(usdt.balanceOf(protocolBudget), 7_487_500);
        assertEq(usdt.balanceOf(address(curve)), 504_962_500);
        assertGt(curve.getSunPrice(), priceBefore);
    }

    function testSunBurnAllSupplyLeavesRetainedCurveFee() public {
        vm.prank(alice);
        uint256 minted = curve.mint(1000 * USDT_ONE);
        vm.roll(block.number + 1);

        vm.prank(alice);
        sun.approve(address(curve), minted);

        vm.prank(alice);
        uint256 usdtOut = curve.burn(minted);

        assertEq(usdtOut, 975_100_000);
        assertEq(curve.curveReserve(), 14_925_000);
        assertEq(sun.totalSupply(), 0);
        assertEq(usdt.balanceOf(protocolBudget), 9_975_000);
        assertEq(usdt.balanceOf(address(curve)), 14_925_000);
        assertEq(curve.getSunPrice(), 0);
    }

    function testSunBurnRejectsMoreThanTotalSupply() public {
        vm.prank(alice);
        curve.mint(100 * USDT_ONE);
        vm.roll(block.number + 1);

        uint256 amountOverSupply = sun.totalSupply() + 1;

        vm.prank(alice);
        vm.expectRevert(SunCurve.BurnAmountExceedsSupply.selector);
        curve.burn(amountOverSupply);
    }

    function testSunBurnRejectsZeroAmount() public {
        vm.prank(alice);
        vm.expectRevert(SunCurve.InvalidAmount.selector);
        curve.burn(0);
    }

    function testSunBurnToRejectsZeroReceiver() public {
        vm.prank(alice);
        uint256 minted = curve.mint(100 * USDT_ONE);
        vm.roll(block.number + 1);

        vm.prank(alice);
        sun.approve(address(curve), minted);

        vm.prank(alice);
        vm.expectRevert(SunCurve.InvalidAddress.selector);
        curve.burnTo(address(0), minted);
    }

    function testSunBurnRejectsSameBlockAfterMint() public {
        vm.prank(alice);
        uint256 minted = curve.mint(100 * USDT_ONE);

        vm.prank(alice);
        sun.approve(address(curve), minted);

        vm.prank(alice);
        vm.expectRevert(SunCurve.SameBlockMintBurn.selector);
        curve.burn(minted / 2);

        vm.roll(block.number + 1);

        vm.prank(alice);
        uint256 usdtOut = curve.burn(minted / 2);

        assertGt(usdtOut, 0);
    }

    function testSunBurnAllowsDifferentPayerWhenAnotherUserMintedSameBlock() public {
        vm.prank(bob);
        uint256 bobMinted = curve.mint(100 * USDT_ONE);

        vm.roll(block.number + 1);

        vm.prank(bob);
        sun.approve(address(curve), bobMinted);

        vm.prank(alice);
        curve.mint(100 * USDT_ONE);

        vm.prank(bob);
        uint256 usdtOut = curve.burn(bobMinted / 2);

        assertGt(usdtOut, 0);
    }

    function testR04SunMintForVictimSameBlockBlocksVictimBurn() public {
        vm.prank(alice);
        uint256 victimSun = curve.mint(1000 * USDT_ONE);

        vm.roll(block.number + 1);

        vm.prank(alice);
        sun.approve(address(curve), victimSun);

        vm.prank(bob);
        uint256 dustSun = curve.mintFor(alice, 1);

        assertGt(dustSun, 0);
        assertEq(curve.lastMintBlock(alice), block.number);

        vm.prank(alice);
        vm.expectRevert(SunCurve.SameBlockMintBurn.selector);
        curve.burn(victimSun / 2);
    }

    function testR04SunMintForVictimSameBlockBlocksVictimBurnTo() public {
        vm.prank(alice);
        uint256 victimSun = curve.mint(1000 * USDT_ONE);

        vm.roll(block.number + 1);

        vm.prank(alice);
        sun.approve(address(curve), victimSun);

        vm.prank(bob);
        uint256 dustSun = curve.mintFor(alice, 1);

        assertGt(dustSun, 0);
        assertEq(curve.lastMintBlock(alice), block.number);

        vm.prank(alice);
        vm.expectRevert(SunCurve.SameBlockMintBurn.selector);
        curve.burnTo(bob, victimSun / 2);
    }

    function testSunBurnRejectsWithoutApproval() public {
        vm.prank(alice);
        uint256 minted = curve.mint(100 * USDT_ONE);
        vm.roll(block.number + 1);

        vm.prank(alice);
        vm.expectRevert();
        curve.burn(minted);
    }

    function testInjectUsdtRaisesPriceWithoutChangingSupply() public {
        vm.prank(alice);
        curve.mint(1000 * USDT_ONE);

        uint256 supplyBefore = sun.totalSupply();
        uint256 priceBefore = curve.getSunPrice();

        usdt.mint(moonAMM, 100 * USDT_ONE);

        vm.startPrank(moonAMM);
        usdt.approve(address(curve), 100 * USDT_ONE);
        curve.injectUSDT(100 * USDT_ONE);
        vm.stopPrank();

        assertEq(curve.curveReserve(), 1095 * USDT_ONE);
        assertEq(sun.totalSupply(), supplyBefore);
        assertEq(usdt.balanceOf(address(curve)), 1095 * USDT_ONE);
        assertGt(curve.getSunPrice(), priceBefore);
    }

    function testInjectUsdtRejectsUnauthorizedCaller() public {
        vm.prank(alice);
        vm.expectRevert(SunCurve.NotMoonAMM.selector);
        curve.injectUSDT(100 * USDT_ONE);
    }

    function testInjectUsdtRejectsZeroAmountFromAuthorizedCaller() public {
        vm.prank(moonAMM);
        vm.expectRevert(SunCurve.InvalidAmount.selector);
        curve.injectUSDT(0);
    }

    function testInjectUsdtRejectsWithoutAllowance() public {
        usdt.mint(moonAMM, 100 * USDT_ONE);

        vm.prank(moonAMM);
        vm.expectRevert();
        curve.injectUSDT(100 * USDT_ONE);
    }

    function testBurnAndRetainRaisesPriceByReducingSupply() public {
        vm.prank(alice);
        curve.mint(1000 * USDT_ONE);

        uint256 reserveBefore = curve.curveReserve();
        uint256 priceBefore = curve.getSunPrice();

        vm.prank(alice);
        sun.transfer(address(curve), 10 * SUN_ONE);

        vm.prank(moonCurve);
        curve.burnAndRetain(10 * SUN_ONE);

        assertEq(curve.curveReserve(), reserveBefore);
        assertEq(sun.totalSupply(), 970 * SUN_ONE);
        assertEq(sun.balanceOf(address(curve)), 0);
        assertGt(curve.getSunPrice(), priceBefore);
    }

    function testBurnAndRetainRejectsUnauthorizedCaller() public {
        vm.prank(alice);
        curve.mint(100 * USDT_ONE);

        vm.prank(alice);
        sun.transfer(address(curve), 1 * SUN_ONE);

        vm.prank(alice);
        vm.expectRevert(SunCurve.NotMoonCurve.selector);
        curve.burnAndRetain(1 * SUN_ONE);
    }

    function testBurnAndRetainRejectsZeroAmountFromAuthorizedCaller() public {
        vm.prank(moonCurve);
        vm.expectRevert(SunCurve.InvalidAmount.selector);
        curve.burnAndRetain(0);
    }
}
