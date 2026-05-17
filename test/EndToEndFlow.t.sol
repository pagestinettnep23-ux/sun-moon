// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { Test } from "forge-std/Test.sol";
import { MoonCurve } from "../contracts/MoonCurve.sol";
import { MoonToken } from "../contracts/MoonToken.sol";
import { SunCurve } from "../contracts/SunCurve.sol";
import { SunToken } from "../contracts/SunToken.sol";
import { MockUSDT } from "../contracts/mocks/MockUSDT.sol";

contract EndToEndFlowTest is Test {
    uint256 internal constant TOKEN_ONE = 1e18;
    uint256 internal constant USDT_ONE = 1e6;
    uint256 internal constant SUN_MAX_MINT_USDT = 10_000 * USDT_ONE;
    uint256 internal constant MOON_MAX_MINT_USDT_EQUIV = 10_000 * USDT_ONE;
    uint256 internal constant K = 5_000_000 * TOKEN_ONE;
    uint256 internal constant S = 1_200_000 * TOKEN_ONE;

    address internal owner = makeAddr("owner");
    address internal user = makeAddr("user");
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
    }

    function testCompleteUserFlowMatchesFrontendPath() public {
        usdt.mint(user, 2000 * USDT_ONE);

        vm.startPrank(user);
        usdt.approve(address(sunCurve), 2000 * USDT_ONE);

        uint256 sunOut = sunCurve.mint(1000 * USDT_ONE);
        assertEq(sunOut, 980 * TOKEN_ONE);
        assertEq(usdt.balanceOf(user), 1000 * USDT_ONE);
        assertEq(sun.balanceOf(user), 980 * TOKEN_ONE);
        assertEq(sunCurve.curveReserve(), 995 * USDT_ONE);

        uint256 sunPriceAfterSunMint = sunCurve.getSunPrice();
        assertEq(sunPriceAfterSunMint, 1_015_306);

        sun.approve(address(moonCurve), 500 * TOKEN_ONE);

        uint256 moonOut = moonCurve.mint(500 * TOKEN_ONE);
        assertEq(moon.balanceOf(user), moonOut);
        assertEq(sun.balanceOf(user), 480 * TOKEN_ONE);
        assertEq(moonCurve.sunReserve(), 475 * TOKEN_ONE);
        assertGt(sunCurve.getSunPrice(), sunPriceAfterSunMint);

        vm.roll(block.number + 1);

        uint256 halfMoon = moonOut / 2;
        uint256 sunBeforeMoonBurn = sun.balanceOf(user);
        uint256 sunOutFromMoonBurn = moonCurve.burn(halfMoon);
        assertEq(moon.balanceOf(user), moonOut - halfMoon);
        assertEq(sun.balanceOf(user), sunBeforeMoonBurn + sunOutFromMoonBurn);
        assertGt(sunOutFromMoonBurn, 0);

        vm.roll(block.number + 1);

        uint256 sunBeforeSunBurn = sun.balanceOf(user);
        uint256 usdtBeforeSunBurn = usdt.balanceOf(user);
        uint256 sunPriceBeforeSunBurn = sunCurve.getSunPrice();

        sun.approve(address(sunCurve), 100 * TOKEN_ONE);
        uint256 usdtOut = sunCurve.burn(100 * TOKEN_ONE);

        assertEq(sun.balanceOf(user), sunBeforeSunBurn - 100 * TOKEN_ONE);
        assertEq(usdt.balanceOf(user), usdtBeforeSunBurn + usdtOut);
        assertGt(usdtOut, 0);
        assertGe(sunCurve.getSunPrice(), sunPriceBeforeSunBurn);

        vm.stopPrank();

        assertGt(usdt.balanceOf(protocolBudget), 0);
        assertGt(sun.balanceOf(protocolBudget), 0);
        assertEq(sun.balanceOf(address(moonCurve)), moonCurve.sunReserve());
    }

    function testCompleteFlowCannotSkipSunPathIntoMoon() public {
        usdt.mint(user, 2000 * USDT_ONE);

        vm.startPrank(user);
        usdt.approve(address(sunCurve), 2000 * USDT_ONE);

        vm.expectRevert();
        moonCurve.mint(500 * TOKEN_ONE);

        sunCurve.mint(1000 * USDT_ONE);
        sun.approve(address(moonCurve), 500 * TOKEN_ONE);
        uint256 moonOut = moonCurve.mint(500 * TOKEN_ONE);

        assertGt(moonOut, 0);
        vm.stopPrank();
    }
}
