// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { StdInvariant } from "forge-std/StdInvariant.sol";
import { Test } from "forge-std/Test.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { MoonCurve } from "../../contracts/MoonCurve.sol";
import { MoonToken } from "../../contracts/MoonToken.sol";
import { SunCurve } from "../../contracts/SunCurve.sol";
import { SunToken } from "../../contracts/SunToken.sol";
import { MockUSDT } from "../../contracts/mocks/MockUSDT.sol";

contract SunCurveInvariantHandler is Test {
    uint256 internal constant USDT_ONE = 1e6;
    uint256 internal constant MAX_MINT_USDT = 10_000 * USDT_ONE;

    MockUSDT internal immutable usdt;
    SunToken internal immutable sun;
    SunCurve internal immutable curve;
    address internal immutable moonAMM;
    address[3] internal actors;

    constructor(MockUSDT usdt_, SunToken sun_, SunCurve curve_, address moonAMM_) {
        usdt = usdt_;
        sun = sun_;
        curve = curve_;
        moonAMM = moonAMM_;
        actors = [
            makeAddr("sunInvariantAlice"),
            makeAddr("sunInvariantBob"),
            makeAddr("sunInvariantCarol")
        ];
    }

    function mint(uint256 actorSeed, uint256 usdtSeed) external {
        address actor = _actor(actorSeed);
        uint256 usdtIn = bound(usdtSeed, 1, MAX_MINT_USDT);

        usdt.mint(actor, usdtIn);
        vm.startPrank(actor);
        usdt.approve(address(curve), usdtIn);
        curve.mint(usdtIn);
        vm.stopPrank();
    }

    function burn(uint256 actorSeed, uint256 burnSeed) external {
        address actor = _actor(actorSeed);
        uint256 balance = sun.balanceOf(actor);
        if (balance == 0) return;

        uint256 burnAmount = bound(burnSeed, 1, balance);
        vm.roll(block.number + 1);

        vm.startPrank(actor);
        sun.approve(address(curve), burnAmount);
        curve.burn(burnAmount);
        vm.stopPrank();
    }

    function inject(uint256 usdtSeed) external {
        uint256 amount = bound(usdtSeed, 1, MAX_MINT_USDT);

        usdt.mint(moonAMM, amount);
        vm.startPrank(moonAMM);
        usdt.approve(address(curve), amount);
        curve.injectUSDT(amount);
        vm.stopPrank();
    }

    function transferSun(uint256 fromSeed, uint256 toSeed, uint256 amountSeed) external {
        address from = _actor(fromSeed);
        address to = _actor(toSeed);
        if (from == to) return;

        uint256 balance = sun.balanceOf(from);
        if (balance == 0) return;

        uint256 amount = bound(amountSeed, 1, balance);
        vm.prank(from);
        sun.transfer(to, amount);
    }

    function _actor(uint256 seed) private view returns (address) {
        return actors[seed % actors.length];
    }
}

contract SunCurveInvariantTest is StdInvariant, Test {
    uint256 internal constant USDT_ONE = 1e6;
    uint256 internal constant MAX_MINT_USDT = 10_000 * USDT_ONE;

    address internal owner = makeAddr("owner");
    address internal protocolBudget = makeAddr("protocolBudget");
    address internal moonCurve = makeAddr("moonCurve");
    address internal moonAMM = makeAddr("moonAMM");

    MockUSDT internal usdt;
    SunToken internal sun;
    SunCurve internal curve;
    SunCurveInvariantHandler internal handler;

    function setUp() public {
        usdt = new MockUSDT("Mock USDT", "USDT", 6);
        sun = new SunToken("SUN", "SUN", owner);
        curve = new SunCurve(sun, usdt, protocolBudget, MAX_MINT_USDT, owner);

        vm.startPrank(owner);
        sun.setMinter(address(curve));
        curve.setMoonCurve(moonCurve);
        curve.setMoonAMM(moonAMM);
        vm.stopPrank();

        handler = new SunCurveInvariantHandler(usdt, sun, curve, moonAMM);
        targetContract(address(handler));
    }

    function invariant_SunCurveAccounting() public view {
        assertEq(curve.curveReserve(), usdt.balanceOf(address(curve)));

        uint256 totalSupply = sun.totalSupply();
        if (totalSupply == 0) {
            assertEq(curve.getSunPrice(), 0);
        } else {
            assertEq(curve.getSunPrice(), Math.mulDiv(curve.curveReserve(), 1e18, totalSupply));
        }
    }
}

contract MoonCurveInvariantHandler is Test {
    uint256 internal constant TOKEN_ONE = 1e18;
    uint256 internal constant USDT_ONE = 1e6;
    uint256 internal constant SUN_MAX_MINT_USDT = 10_000 * USDT_ONE;

    MockUSDT internal immutable usdt;
    SunToken internal immutable sun;
    MoonToken internal immutable moon;
    SunCurve internal immutable sunCurve;
    MoonCurve internal immutable moonCurve;
    address[3] internal actors;

    constructor(
        MockUSDT usdt_,
        SunToken sun_,
        MoonToken moon_,
        SunCurve sunCurve_,
        MoonCurve moonCurve_
    ) {
        usdt = usdt_;
        sun = sun_;
        moon = moon_;
        sunCurve = sunCurve_;
        moonCurve = moonCurve_;
        actors = [
            makeAddr("moonInvariantAlice"),
            makeAddr("moonInvariantBob"),
            makeAddr("moonInvariantCarol")
        ];
    }

    function mintSun(uint256 actorSeed, uint256 usdtSeed) external {
        address actor = _actor(actorSeed);
        uint256 usdtIn = bound(usdtSeed, 1 * USDT_ONE, SUN_MAX_MINT_USDT);

        usdt.mint(actor, usdtIn);
        vm.startPrank(actor);
        usdt.approve(address(sunCurve), usdtIn);
        sunCurve.mint(usdtIn);
        vm.stopPrank();
    }

    function mintMoon(uint256 actorSeed, uint256 sunSeed) external {
        address actor = _actor(actorSeed);
        uint256 balance = sun.balanceOf(actor);
        if (balance < TOKEN_ONE) return;

        uint256 maxSunIn = balance;
        if (maxSunIn > 1000 * TOKEN_ONE) {
            maxSunIn = 1000 * TOKEN_ONE;
        }

        uint256 sunIn = bound(sunSeed, TOKEN_ONE, maxSunIn);
        vm.startPrank(actor);
        sun.approve(address(moonCurve), sunIn);
        try moonCurve.mint(sunIn) { } catch { }
        vm.stopPrank();
    }

    function burnMoon(uint256 actorSeed, uint256 moonSeed) external {
        address actor = _actor(actorSeed);
        uint256 maxBurn = moon.balanceOf(actor);
        uint256 fairSupply = moonCurve.currentFairSupply();
        if (fairSupply < maxBurn) {
            maxBurn = fairSupply;
        }
        if (maxBurn == 0) return;

        uint256 moonIn = bound(moonSeed, 1, maxBurn);
        vm.roll(block.number + 1);

        vm.prank(actor);
        try moonCurve.burn(moonIn) { } catch { }
    }

    function transferSun(uint256 fromSeed, uint256 toSeed, uint256 amountSeed) external {
        address from = _actor(fromSeed);
        address to = _actor(toSeed);
        if (from == to) return;

        uint256 balance = sun.balanceOf(from);
        if (balance == 0) return;

        uint256 amount = bound(amountSeed, 1, balance);
        vm.prank(from);
        sun.transfer(to, amount);
    }

    function transferMoon(uint256 fromSeed, uint256 toSeed, uint256 amountSeed) external {
        address from = _actor(fromSeed);
        address to = _actor(toSeed);
        if (from == to) return;

        uint256 balance = moon.balanceOf(from);
        if (balance == 0) return;

        uint256 amount = bound(amountSeed, 1, balance);
        vm.prank(from);
        moon.transfer(to, amount);
    }

    function _actor(uint256 seed) private view returns (address) {
        return actors[seed % actors.length];
    }
}

contract MoonCurveInvariantTest is StdInvariant, Test {
    uint256 internal constant TOKEN_ONE = 1e18;
    uint256 internal constant USDT_ONE = 1e6;
    uint256 internal constant SUN_MAX_MINT_USDT = 10_000 * USDT_ONE;
    uint256 internal constant MOON_MAX_MINT_USDT_EQUIV = 10_000 * USDT_ONE;
    uint256 internal constant K = 5_000_000 * TOKEN_ONE;
    uint256 internal constant S = 1_200_000 * TOKEN_ONE;

    address internal owner = makeAddr("owner");
    address internal protocolBudget = makeAddr("protocolBudget");
    address internal moonAMM = makeAddr("moonAMM");

    MockUSDT internal usdt;
    SunToken internal sun;
    SunCurve internal sunCurve;
    MoonToken internal moon;
    MoonCurve internal moonCurve;
    MoonCurveInvariantHandler internal handler;

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

        handler = new MoonCurveInvariantHandler(usdt, sun, moon, sunCurve, moonCurve);
        targetContract(address(handler));
    }

    function invariant_MoonAndSunCurveAccounting() public view {
        assertEq(sunCurve.curveReserve(), usdt.balanceOf(address(sunCurve)));
        assertEq(moonCurve.sunReserve(), sun.balanceOf(address(moonCurve)));
        assertApproxEqAbs(moon.totalSupply(), moonCurve.currentFairSupply(), 1e12);

        uint256 totalSupply = sun.totalSupply();
        if (totalSupply == 0) {
            assertEq(sunCurve.getSunPrice(), 0);
        } else {
            assertEq(
                sunCurve.getSunPrice(), Math.mulDiv(sunCurve.curveReserve(), 1e18, totalSupply)
            );
        }
    }
}
