// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Deployers } from "@uniswap/v4-core/test/utils/Deployers.sol";
import { IHooks } from "@uniswap/v4-core/src/interfaces/IHooks.sol";
import { CustomRevert } from "@uniswap/v4-core/src/libraries/CustomRevert.sol";
import { Hooks } from "@uniswap/v4-core/src/libraries/Hooks.sol";
import { PoolSwapTest } from "@uniswap/v4-core/src/test/PoolSwapTest.sol";
import { BalanceDelta } from "@uniswap/v4-core/src/types/BalanceDelta.sol";
import { Currency } from "@uniswap/v4-core/src/types/Currency.sol";
import { PoolId, PoolIdLibrary } from "@uniswap/v4-core/src/types/PoolId.sol";
import { PoolKey } from "@uniswap/v4-core/src/types/PoolKey.sol";
import { SwapParams } from "@uniswap/v4-core/src/types/PoolOperation.sol";
import {
    BaseSunMoonUsdcFeeV4Hook
} from "../../../contracts/hooks/base/BaseSunMoonUsdcFeeV4Hook.sol";
import { BaseV4HookAddressMiner } from "../../../contracts/hooks/base/BaseV4HookAddressMiner.sol";
import { MockUSDT } from "../../../contracts/mocks/MockUSDT.sol";
import { MoonCurve } from "../../../contracts/MoonCurve.sol";
import { MoonToken } from "../../../contracts/MoonToken.sol";
import { SunCurve } from "../../../contracts/SunCurve.sol";
import { SunToken } from "../../../contracts/SunToken.sol";

contract BaseSunMoonUsdcFeeV4HookTest is Deployers {
    using PoolIdLibrary for PoolKey;

    uint256 internal constant USDC_ONE = 1e6;
    uint256 internal constant TOKEN_ONE = 1e18;
    uint256 internal constant SWAP_USDC_AMOUNT = 10_000;
    uint256 internal constant BPS = 10_000;
    uint256 internal constant SUN_FEE_TO_CURVE_BPS = 150;
    uint256 internal constant SUN_FEE_TO_PROTOCOL_BPS = 50;
    uint256 internal constant MOON_FEE_TO_CURVE_BPS = 300;
    uint256 internal constant MOON_FEE_TO_PROTOCOL_BPS = 200;
    uint256 internal constant MOON_CURVE_K = 5_000_000 * TOKEN_ONE;
    uint256 internal constant MOON_CURVE_S = 1_200_000 * TOKEN_ONE;
    uint256 internal constant EXPECTED_SUN_FEE_TO_CURVE =
        SWAP_USDC_AMOUNT * SUN_FEE_TO_CURVE_BPS / BPS;
    uint256 internal constant EXPECTED_SUN_FEE_TO_PROTOCOL =
        SWAP_USDC_AMOUNT * SUN_FEE_TO_PROTOCOL_BPS / BPS;
    uint256 internal constant EXPECTED_MOON_FEE_TO_CURVE =
        SWAP_USDC_AMOUNT * MOON_FEE_TO_CURVE_BPS / BPS;
    uint256 internal constant EXPECTED_MOON_FEE_TO_PROTOCOL =
        SWAP_USDC_AMOUNT * MOON_FEE_TO_PROTOCOL_BPS / BPS;

    address internal owner = makeAddr("owner");
    address internal newOwner = makeAddr("newOwner");
    address internal alice = makeAddr("alice");
    address internal bob = makeAddr("bob");
    address internal protocolBudget = makeAddr("protocolBudget");

    MockUSDT internal usdc;
    SunToken internal sun;
    MoonToken internal moon;
    SunCurve internal sunCurve;
    MoonCurve internal moonCurve;
    BaseSunMoonUsdcFeeV4Hook internal hook;

    PoolKey internal sunUsdcKey;
    PoolKey internal moonUsdcKey;

    event FeeRouted(
        bytes32 indexed poolId,
        BaseSunMoonUsdcFeeV4Hook.PoolKind indexed kind,
        uint256 feeBaseAmount,
        uint256 feeToSunCurve,
        uint256 feeToProtocol,
        uint256 usdcInjected
    );

    function setUp() public {
        deployFreshManagerAndRouters();

        usdc = new MockUSDT("Mock USDC", "USDC", 6);
        sun = new SunToken("SUN", "SUN", owner);
        moon = new MoonToken("MOON", "MOON", owner);
        sunCurve = new SunCurve(sun, usdc, protocolBudget, type(uint128).max, owner);
        moonCurve = new MoonCurve(
            moon,
            sun,
            sunCurve,
            protocolBudget,
            MOON_CURVE_K,
            MOON_CURVE_S,
            0,
            type(uint128).max,
            owner
        );

        vm.startPrank(owner);
        sun.setMinter(address(sunCurve));
        sunCurve.setMoonCurve(address(moonCurve));
        moon.setMinter(address(moonCurve));
        vm.stopPrank();

        usdc.mint(address(this), type(uint128).max);
        usdc.approve(address(sunCurve), type(uint256).max);
        sunCurve.mint(1_000_000 * USDC_ONE);
        sun.approve(address(moonCurve), type(uint256).max);
        moonCurve.mint(10_000 * TOKEN_ONE);

        hook = _deployHook();

        vm.prank(owner);
        sunCurve.setMoonAMM(address(hook));

        _approveRouters(IERC20(address(usdc)));
        _approveRouters(IERC20(address(sun)));
        _approveRouters(IERC20(address(moon)));

        (Currency sunCurrency0, Currency sunCurrency1) =
            _sortedCurrencies(address(usdc), address(sun));
        (sunUsdcKey,) = initPoolAndAddLiquidity(
            sunCurrency0, sunCurrency1, IHooks(address(hook)), 3000, SQRT_PRICE_1_1
        );

        (Currency moonCurrency0, Currency moonCurrency1) =
            _sortedCurrencies(address(usdc), address(moon));
        (moonUsdcKey,) = initPoolAndAddLiquidity(
            moonCurrency0, moonCurrency1, IHooks(address(hook)), 3000, SQRT_PRICE_1_1
        );

        vm.startPrank(owner);
        hook.setAllowedSunUsdcPool(PoolId.unwrap(sunUsdcKey.toId()), true);
        hook.setAllowedMoonUsdcPool(PoolId.unwrap(moonUsdcKey.toId()), true);
        vm.stopPrank();
    }

    function testExpectedHookMaskMatchesReturnDeltaSwapPermissions() public view {
        uint160 expectedMask = Hooks.BEFORE_SWAP_FLAG | Hooks.AFTER_SWAP_FLAG
            | Hooks.BEFORE_SWAP_RETURNS_DELTA_FLAG | Hooks.AFTER_SWAP_RETURNS_DELTA_FLAG;

        assertEq(hook.expectedHookMask(), expectedMask);
        assertEq(uint160(address(hook)) & expectedMask, expectedMask);
    }

    function testSunAndMoonRemainFreelyTransferable() public {
        sun.transfer(alice, 10 * TOKEN_ONE);
        moon.transfer(alice, 10 * TOKEN_ONE);

        vm.startPrank(alice);
        sun.transfer(bob, 4 * TOKEN_ONE);
        moon.transfer(bob, 4 * TOKEN_ONE);
        vm.stopPrank();

        assertEq(sun.balanceOf(bob), 4 * TOKEN_ONE);
        assertEq(moon.balanceOf(bob), 4 * TOKEN_ONE);
        assertEq(sun.balanceOf(alice), 6 * TOKEN_ONE);
        assertEq(moon.balanceOf(alice), 6 * TOKEN_ONE);
    }

    function testCurveMintBurnStillWorksWithFreelyTransferredSun() public {
        sun.transfer(alice, 2000 * TOKEN_ONE);
        vm.roll(block.number + 1);

        vm.startPrank(alice);
        sun.approve(address(sunCurve), type(uint256).max);
        uint256 usdcOut = sunCurve.burn(100 * TOKEN_ONE);
        assertGt(usdcOut, 0);

        sun.approve(address(moonCurve), type(uint256).max);
        uint256 moonOut = moonCurve.mint(100 * TOKEN_ONE);
        assertGt(moonOut, 0);

        vm.roll(block.number + 1);
        uint256 sunBeforeMoonBurn = sun.balanceOf(alice);
        uint256 moonBurnIn = moonOut / 2;
        uint256 sunOut = moonCurve.burn(moonBurnIn);
        vm.stopPrank();

        assertGt(sunOut, 0);
        assertEq(moon.balanceOf(alice), moonOut - moonBurnIn);
        assertEq(sun.balanceOf(alice), sunBeforeMoonBurn + sunOut);
    }

    function testSunUsdcPoolCollectsTwoPercentWhenUsdcIsSpecified() public {
        uint256 reserveBefore = sunCurve.curveReserve();
        uint256 budgetBefore = usdc.balanceOf(protocolBudget);

        vm.expectEmit(true, true, false, true, address(hook));
        emit FeeRouted(
            PoolId.unwrap(sunUsdcKey.toId()),
            BaseSunMoonUsdcFeeV4Hook.PoolKind.SunUsdc,
            SWAP_USDC_AMOUNT,
            EXPECTED_SUN_FEE_TO_CURVE,
            EXPECTED_SUN_FEE_TO_PROTOCOL,
            EXPECTED_SUN_FEE_TO_CURVE
        );

        _swapExactUsdcInput(sunUsdcKey, SWAP_USDC_AMOUNT, EXPECTED_SUN_FEE_TO_CURVE);

        assertEq(sunCurve.curveReserve() - reserveBefore, EXPECTED_SUN_FEE_TO_CURVE);
        assertEq(usdc.balanceOf(protocolBudget) - budgetBefore, EXPECTED_SUN_FEE_TO_PROTOCOL);
        assertEq(usdc.balanceOf(address(hook)), 0);
    }

    function testMoonUsdcPoolCollectsFivePercentWhenUsdcIsSpecified() public {
        uint256 reserveBefore = sunCurve.curveReserve();
        uint256 budgetBefore = usdc.balanceOf(protocolBudget);

        vm.expectEmit(true, true, false, true, address(hook));
        emit FeeRouted(
            PoolId.unwrap(moonUsdcKey.toId()),
            BaseSunMoonUsdcFeeV4Hook.PoolKind.MoonUsdc,
            SWAP_USDC_AMOUNT,
            EXPECTED_MOON_FEE_TO_CURVE,
            EXPECTED_MOON_FEE_TO_PROTOCOL,
            EXPECTED_MOON_FEE_TO_CURVE
        );

        _swapExactUsdcInput(moonUsdcKey, SWAP_USDC_AMOUNT, EXPECTED_MOON_FEE_TO_CURVE);

        assertEq(sunCurve.curveReserve() - reserveBefore, EXPECTED_MOON_FEE_TO_CURVE);
        assertEq(usdc.balanceOf(protocolBudget) - budgetBefore, EXPECTED_MOON_FEE_TO_PROTOCOL);
        assertEq(usdc.balanceOf(address(hook)), 0);
    }

    function testExactOutputBuySunWithUsdcInputChargesAfterSwapFeeOnce() public {
        uint256 exactSunOut = 10_000;
        uint256 reserveBefore = sunCurve.curveReserve();
        uint256 budgetBefore = usdc.balanceOf(protocolBudget);
        uint256 userUsdcBefore = usdc.balanceOf(address(this));
        uint256 userSunBefore = sun.balanceOf(address(this));

        BalanceDelta swapDelta = _swapExactUsdcInputForTokenOutput(sunUsdcKey, exactSunOut, 1);

        uint256 reserveDelta = sunCurve.curveReserve() - reserveBefore;
        uint256 budgetDelta = usdc.balanceOf(protocolBudget) - budgetBefore;
        uint256 userUsdcSpent = userUsdcBefore - usdc.balanceOf(address(this));

        assertEq(sun.balanceOf(address(this)) - userSunBefore, exactSunOut);
        assertGt(reserveDelta, 0);
        assertGt(budgetDelta, 0);
        _assertExactOutputUsdcInputFeeSplit(
            sunUsdcKey,
            swapDelta,
            userUsdcSpent,
            reserveDelta,
            budgetDelta,
            SUN_FEE_TO_CURVE_BPS,
            SUN_FEE_TO_PROTOCOL_BPS
        );
    }

    function testExactOutputBuyMoonWithUsdcInputChargesAfterSwapFeeOnce() public {
        uint256 exactMoonOut = 10_000;
        uint256 reserveBefore = sunCurve.curveReserve();
        uint256 budgetBefore = usdc.balanceOf(protocolBudget);
        uint256 userUsdcBefore = usdc.balanceOf(address(this));
        uint256 userMoonBefore = moon.balanceOf(address(this));

        BalanceDelta swapDelta = _swapExactUsdcInputForTokenOutput(moonUsdcKey, exactMoonOut, 1);

        uint256 reserveDelta = sunCurve.curveReserve() - reserveBefore;
        uint256 budgetDelta = usdc.balanceOf(protocolBudget) - budgetBefore;
        uint256 userUsdcSpent = userUsdcBefore - usdc.balanceOf(address(this));

        assertEq(moon.balanceOf(address(this)) - userMoonBefore, exactMoonOut);
        assertGt(reserveDelta, 0);
        assertGt(budgetDelta, 0);
        _assertExactOutputUsdcInputFeeSplit(
            moonUsdcKey,
            swapDelta,
            userUsdcSpent,
            reserveDelta,
            budgetDelta,
            MOON_FEE_TO_CURVE_BPS,
            MOON_FEE_TO_PROTOCOL_BPS
        );
    }

    function testEmptyHookDataDefaultsMinUsdcToOneAndSwapSucceeds() public {
        uint256 reserveBefore = sunCurve.curveReserve();
        uint256 budgetBefore = usdc.balanceOf(protocolBudget);

        vm.expectEmit(true, true, false, true, address(hook));
        emit FeeRouted(
            PoolId.unwrap(sunUsdcKey.toId()),
            BaseSunMoonUsdcFeeV4Hook.PoolKind.SunUsdc,
            SWAP_USDC_AMOUNT,
            EXPECTED_SUN_FEE_TO_CURVE,
            EXPECTED_SUN_FEE_TO_PROTOCOL,
            EXPECTED_SUN_FEE_TO_CURVE
        );

        _swapExactUsdcInputWithHookData(sunUsdcKey, SWAP_USDC_AMOUNT, bytes(""));

        assertEq(sunCurve.curveReserve() - reserveBefore, EXPECTED_SUN_FEE_TO_CURVE);
        assertEq(usdc.balanceOf(protocolBudget) - budgetBefore, EXPECTED_SUN_FEE_TO_PROTOCOL);
        assertEq(usdc.balanceOf(address(hook)), 0);
    }

    function testNonEmptyHookDataWithZeroMinUsdcToSunCurveStillReverts() public {
        _expectBeforeSwapHookRevert(
            abi.encodeWithSelector(BaseSunMoonUsdcFeeV4Hook.InvalidMinUSDCToSunCurve.selector)
        );

        _swapExactUsdcInputWithHookData(sunUsdcKey, SWAP_USDC_AMOUNT, _hookData(0));
    }

    function testShortNonEmptyHookDataRevertsInvalidHookData() public {
        _expectBeforeSwapHookRevert(
            abi.encodeWithSelector(BaseSunMoonUsdcFeeV4Hook.InvalidHookData.selector)
        );

        _swapExactUsdcInputWithHookData(sunUsdcKey, SWAP_USDC_AMOUNT, hex"01");
    }

    function testMinUsdcToSunCurveAboveInjectedAmountReverts() public {
        uint256 minUSDCToSunCurve = EXPECTED_SUN_FEE_TO_CURVE + 1;

        _expectBeforeSwapHookRevert(
            abi.encodeWithSelector(
                BaseSunMoonUsdcFeeV4Hook.InsufficientUSDCToSunCurve.selector,
                EXPECTED_SUN_FEE_TO_CURVE,
                minUSDCToSunCurve
            )
        );

        _swapExactUsdcInputWithHookData(sunUsdcKey, SWAP_USDC_AMOUNT, _hookData(minUSDCToSunCurve));
    }

    function testTinySwapWithZeroFeeStillRevertsWithEmptyHookData() public {
        _expectBeforeSwapHookRevert(
            abi.encodeWithSelector(BaseSunMoonUsdcFeeV4Hook.InvalidAmount.selector)
        );

        _swapExactUsdcInputWithHookData(sunUsdcKey, 1, bytes(""));
    }

    function testFuzzSpecifiedUsdcInputFeeSplits(uint256 sunUsdcSeed, uint256 moonUsdcSeed) public {
        uint256 sunUsdcIn = bound(sunUsdcSeed, 10_000, 1_000_000);
        uint256 moonUsdcIn = bound(moonUsdcSeed, 10_000, 1_000_000);

        uint256 reserveBefore = sunCurve.curveReserve();
        uint256 budgetBefore = usdc.balanceOf(protocolBudget);
        uint256 expectedSunFeeToCurve = sunUsdcIn * SUN_FEE_TO_CURVE_BPS / BPS;
        uint256 expectedSunFeeToProtocol = sunUsdcIn * SUN_FEE_TO_PROTOCOL_BPS / BPS;

        _swapExactUsdcInput(sunUsdcKey, sunUsdcIn, expectedSunFeeToCurve);

        assertEq(sunCurve.curveReserve() - reserveBefore, expectedSunFeeToCurve);
        assertEq(usdc.balanceOf(protocolBudget) - budgetBefore, expectedSunFeeToProtocol);
        assertEq(usdc.balanceOf(address(hook)), 0);

        reserveBefore = sunCurve.curveReserve();
        budgetBefore = usdc.balanceOf(protocolBudget);
        uint256 expectedMoonFeeToCurve = moonUsdcIn * MOON_FEE_TO_CURVE_BPS / BPS;
        uint256 expectedMoonFeeToProtocol = moonUsdcIn * MOON_FEE_TO_PROTOCOL_BPS / BPS;

        _swapExactUsdcInput(moonUsdcKey, moonUsdcIn, expectedMoonFeeToCurve);

        assertEq(sunCurve.curveReserve() - reserveBefore, expectedMoonFeeToCurve);
        assertEq(usdc.balanceOf(protocolBudget) - budgetBefore, expectedMoonFeeToProtocol);
        assertEq(usdc.balanceOf(address(hook)), 0);
    }

    function testSunUsdcPoolCollectsTwoPercentWhenUsdcIsUnspecifiedOutput() public {
        uint256 reserveBefore = sunCurve.curveReserve();
        uint256 budgetBefore = usdc.balanceOf(protocolBudget);

        BalanceDelta swapDelta =
            _swapExactTokenInputForUsdcOutput(sunUsdcKey, address(sun), 10_000, 1);

        uint256 reserveDelta = sunCurve.curveReserve() - reserveBefore;
        uint256 budgetDelta = usdc.balanceOf(protocolBudget) - budgetBefore;

        assertGt(reserveDelta, 0);
        assertGt(budgetDelta, 0);
        _assertUsdcOutputFeeSplit(
            sunUsdcKey,
            swapDelta,
            reserveDelta,
            budgetDelta,
            SUN_FEE_TO_CURVE_BPS,
            SUN_FEE_TO_PROTOCOL_BPS
        );
    }

    function testMoonUsdcPoolCollectsFivePercentWhenUsdcIsUnspecifiedOutput() public {
        uint256 reserveBefore = sunCurve.curveReserve();
        uint256 budgetBefore = usdc.balanceOf(protocolBudget);

        BalanceDelta swapDelta =
            _swapExactTokenInputForUsdcOutput(moonUsdcKey, address(moon), 10_000, 1);

        uint256 reserveDelta = sunCurve.curveReserve() - reserveBefore;
        uint256 budgetDelta = usdc.balanceOf(protocolBudget) - budgetBefore;

        assertGt(reserveDelta, 0);
        assertGt(budgetDelta, 0);
        _assertUsdcOutputFeeSplit(
            moonUsdcKey,
            swapDelta,
            reserveDelta,
            budgetDelta,
            MOON_FEE_TO_CURVE_BPS,
            MOON_FEE_TO_PROTOCOL_BPS
        );
    }

    function testUnallowedSupportedPoolReverts() public {
        vm.prank(owner);
        hook.setAllowedSunUsdcPool(PoolId.unwrap(sunUsdcKey.toId()), false);

        vm.prank(address(manager));
        vm.expectRevert(
            abi.encodeWithSelector(
                BaseSunMoonUsdcFeeV4Hook.FeePoolNotAllowed.selector,
                PoolId.unwrap(sunUsdcKey.toId()),
                BaseSunMoonUsdcFeeV4Hook.PoolKind.SunUsdc
            )
        );
        hook.beforeSwap(address(this), sunUsdcKey, _swapParams(true, -1), _hookData(1));
    }

    function testUnsupportedThirdPartyPoolUsingHookIsUnaffected() public {
        PoolKey memory sunMoonKey = _poolKey(address(sun), address(moon), IHooks(address(hook)));

        vm.prank(address(manager));
        (bytes4 beforeSelector,,) =
            hook.beforeSwap(address(this), sunMoonKey, _swapParams(true, -1), bytes(""));

        vm.prank(address(manager));
        (bytes4 afterSelector, int128 hookDelta) = hook.afterSwap(
            address(this), sunMoonKey, _swapParams(true, -1), BalanceDelta.wrap(0), bytes("")
        );

        assertEq(beforeSelector, hook.beforeSwap.selector);
        assertEq(afterSelector, hook.afterSwap.selector);
        assertEq(hookDelta, 0);
    }

    function testFuzzRenouncePermanentlyBlocksConfiguration(
        bytes32 sunPoolSeed,
        bytes32 moonPoolSeed,
        address callerSeed
    ) public {
        bytes32 sunPoolId = sunPoolSeed == bytes32(0)
            ? keccak256("fuzzSunPoolAfterRenounce")
            : sunPoolSeed;
        bytes32 moonPoolId =
            moonPoolSeed == bytes32(0) ? keccak256("fuzzMoonPoolAfterRenounce") : moonPoolSeed;
        address caller = callerSeed == address(0) ? alice : callerSeed;

        vm.prank(owner);
        hook.renounceOwnership();
        assertEq(hook.owner(), address(0));

        vm.startPrank(caller);

        vm.expectRevert(BaseSunMoonUsdcFeeV4Hook.NotOwner.selector);
        hook.setAllowedSunUsdcPool(sunPoolId, true);

        vm.expectRevert(BaseSunMoonUsdcFeeV4Hook.NotOwner.selector);
        hook.setAllowedMoonUsdcPool(moonPoolId, true);

        vm.expectRevert(BaseSunMoonUsdcFeeV4Hook.NotOwner.selector);
        hook.setProtocolBudget(makeAddr("fuzzBudgetAfterRenounce"));

        vm.expectRevert(BaseSunMoonUsdcFeeV4Hook.NotOwner.selector);
        hook.setPaused(true);

        vm.expectRevert(BaseSunMoonUsdcFeeV4Hook.NotOwner.selector);
        hook.transferOwnership(makeAddr("fuzzOwnerAfterRenounce"));

        vm.stopPrank();
    }

    function testTransferAndRenounceOwnershipLocksConfiguration() public {
        bytes32 extraPoolId = keccak256("extraPool");

        vm.prank(owner);
        hook.transferOwnership(newOwner);

        vm.prank(owner);
        vm.expectRevert(BaseSunMoonUsdcFeeV4Hook.NotOwner.selector);
        hook.setAllowedSunUsdcPool(extraPoolId, true);

        vm.prank(newOwner);
        hook.setAllowedSunUsdcPool(extraPoolId, true);
        assertTrue(hook.allowedSunUsdcPools(extraPoolId));

        vm.prank(newOwner);
        hook.renounceOwnership();
        assertEq(hook.owner(), address(0));

        vm.startPrank(newOwner);

        vm.expectRevert(BaseSunMoonUsdcFeeV4Hook.NotOwner.selector);
        hook.setAllowedSunUsdcPool(keccak256("afterRenounceSun"), true);

        vm.expectRevert(BaseSunMoonUsdcFeeV4Hook.NotOwner.selector);
        hook.setAllowedMoonUsdcPool(keccak256("afterRenounceMoon"), true);

        vm.expectRevert(BaseSunMoonUsdcFeeV4Hook.NotOwner.selector);
        hook.setProtocolBudget(makeAddr("newBudget"));

        vm.expectRevert(BaseSunMoonUsdcFeeV4Hook.NotOwner.selector);
        hook.setPaused(true);

        vm.expectRevert(BaseSunMoonUsdcFeeV4Hook.NotOwner.selector);
        hook.transferOwnership(owner);

        vm.stopPrank();

        uint256 reserveBefore = sunCurve.curveReserve();
        _swapExactUsdcInput(sunUsdcKey, SWAP_USDC_AMOUNT, EXPECTED_SUN_FEE_TO_CURVE);
        assertEq(sunCurve.curveReserve() - reserveBefore, EXPECTED_SUN_FEE_TO_CURVE);
    }

    function testRejectsInvalidConfig() public {
        vm.expectRevert(BaseSunMoonUsdcFeeV4Hook.InvalidAddress.selector);
        new BaseSunMoonUsdcFeeV4Hook(
            manager,
            address(0),
            address(moon),
            IERC20(address(usdc)),
            sunCurve,
            protocolBudget,
            owner
        );

        vm.expectRevert(BaseSunMoonUsdcFeeV4Hook.InvalidAddress.selector);
        new BaseSunMoonUsdcFeeV4Hook(
            manager,
            address(sun),
            address(sun),
            IERC20(address(usdc)),
            sunCurve,
            protocolBudget,
            owner
        );

        vm.prank(owner);
        vm.expectRevert(BaseSunMoonUsdcFeeV4Hook.InvalidAddress.selector);
        hook.setProtocolBudget(address(0));

        vm.prank(owner);
        vm.expectRevert(BaseSunMoonUsdcFeeV4Hook.InvalidPoolId.selector);
        hook.setAllowedSunUsdcPool(bytes32(0), true);
    }

    function _deployHook() private returns (BaseSunMoonUsdcFeeV4Hook deployed) {
        bytes memory initCode = abi.encodePacked(
            type(BaseSunMoonUsdcFeeV4Hook).creationCode,
            abi.encode(
                manager,
                address(sun),
                address(moon),
                IERC20(address(usdc)),
                sunCurve,
                protocolBudget,
                owner
            )
        );

        (bytes32 salt, address predicted, bool found) = BaseV4HookAddressMiner.mineSalt(
            address(this),
            keccak256(initCode),
            BaseV4HookAddressMiner.BASE_MOON_AMM_FEE_V4_HOOK_MASK,
            0,
            100_000
        );

        assertTrue(found);
        deployed = new BaseSunMoonUsdcFeeV4Hook{ salt: salt }(
            manager,
            address(sun),
            address(moon),
            IERC20(address(usdc)),
            sunCurve,
            protocolBudget,
            owner
        );
        assertEq(address(deployed), predicted);
    }

    function _approveRouters(IERC20 token) private {
        token.approve(address(swapRouter), type(uint256).max);
        token.approve(address(modifyLiquidityRouter), type(uint256).max);
    }

    function _swapExactUsdcInput(PoolKey memory poolKey, uint256 usdcIn, uint256 minUSDCToSunCurve)
        private
        returns (BalanceDelta)
    {
        return _swap(
            poolKey,
            Currency.unwrap(poolKey.currency0) == address(usdc),
            -int256(usdcIn),
            minUSDCToSunCurve
        );
    }

    function _swapExactTokenInputForUsdcOutput(
        PoolKey memory poolKey,
        address tokenIn,
        uint256 amountIn,
        uint256 minUSDCToSunCurve
    ) private returns (BalanceDelta) {
        return _swap(
            poolKey,
            Currency.unwrap(poolKey.currency0) == tokenIn,
            -int256(amountIn),
            minUSDCToSunCurve
        );
    }

    function _swapExactUsdcInputForTokenOutput(
        PoolKey memory poolKey,
        uint256 tokenOut,
        uint256 minUSDCToSunCurve
    ) private returns (BalanceDelta) {
        return _swap(
            poolKey,
            Currency.unwrap(poolKey.currency0) == address(usdc),
            int256(tokenOut),
            minUSDCToSunCurve
        );
    }

    function _swap(
        PoolKey memory poolKey,
        bool zeroForOne,
        int256 amountSpecified,
        uint256 minUSDCToSunCurve
    ) private returns (BalanceDelta) {
        return _swapWithHookData(poolKey, zeroForOne, amountSpecified, _hookData(minUSDCToSunCurve));
    }

    function _swapExactUsdcInputWithHookData(
        PoolKey memory poolKey,
        uint256 usdcIn,
        bytes memory hookData
    ) private returns (BalanceDelta) {
        return _swapWithHookData(
            poolKey, Currency.unwrap(poolKey.currency0) == address(usdc), -int256(usdcIn), hookData
        );
    }

    function _swapWithHookData(
        PoolKey memory poolKey,
        bool zeroForOne,
        int256 amountSpecified,
        bytes memory hookData
    ) private returns (BalanceDelta) {
        return swapRouter.swap(
            poolKey,
            _swapParams(zeroForOne, amountSpecified),
            PoolSwapTest.TestSettings({ takeClaims: false, settleUsingBurn: false }),
            hookData
        );
    }

    function _assertUsdcOutputFeeSplit(
        PoolKey memory poolKey,
        BalanceDelta swapDelta,
        uint256 reserveDelta,
        uint256 budgetDelta,
        uint256 curveBps,
        uint256 protocolBps
    ) private view {
        uint256 totalFee = reserveDelta + budgetDelta;
        uint256 feeBaseAmount = _positiveUsdcDelta(poolKey, swapDelta) + totalFee;

        assertEq(reserveDelta, feeBaseAmount * curveBps / BPS);
        assertEq(budgetDelta, feeBaseAmount * protocolBps / BPS);
        assertEq(usdc.balanceOf(address(hook)), 0);
    }

    function _assertExactOutputUsdcInputFeeSplit(
        PoolKey memory poolKey,
        BalanceDelta swapDelta,
        uint256 userUsdcSpent,
        uint256 reserveDelta,
        uint256 budgetDelta,
        uint256 curveBps,
        uint256 protocolBps
    ) private view {
        uint256 totalFee = reserveDelta + budgetDelta;
        uint256 returnedUsdcInput = _negativeUsdcDelta(poolKey, swapDelta);
        uint256 baseUsdcInput = userUsdcSpent - totalFee;

        assertEq(reserveDelta, baseUsdcInput * curveBps / BPS);
        assertEq(budgetDelta, baseUsdcInput * protocolBps / BPS);
        assertEq(returnedUsdcInput, userUsdcSpent);
        assertEq(userUsdcSpent, baseUsdcInput + totalFee);
        assertEq(usdc.balanceOf(address(hook)), 0);
    }

    function _positiveUsdcDelta(PoolKey memory poolKey, BalanceDelta swapDelta)
        private
        view
        returns (uint256)
    {
        int128 signedUsdcDelta = Currency.unwrap(poolKey.currency0) == address(usdc)
            ? swapDelta.amount0()
            : swapDelta.amount1();

        assertTrue(signedUsdcDelta > 0);
        return uint256(uint128(signedUsdcDelta));
    }

    function _negativeUsdcDelta(PoolKey memory poolKey, BalanceDelta swapDelta)
        private
        view
        returns (uint256)
    {
        int128 signedUsdcDelta = Currency.unwrap(poolKey.currency0) == address(usdc)
            ? swapDelta.amount0()
            : swapDelta.amount1();

        assertTrue(signedUsdcDelta < 0);
        return uint256(uint128(-signedUsdcDelta));
    }

    function _hookData(uint256 minUSDCToSunCurve) private pure returns (bytes memory) {
        return abi.encode(
            BaseSunMoonUsdcFeeV4Hook.UsdcFeeHookData({ minUSDCToSunCurve: minUSDCToSunCurve })
        );
    }

    function _expectBeforeSwapHookRevert(bytes memory reason) private {
        vm.expectRevert(
            abi.encodeWithSelector(
                CustomRevert.WrappedError.selector,
                address(hook),
                IHooks.beforeSwap.selector,
                reason,
                abi.encodeWithSelector(Hooks.HookCallFailed.selector)
            )
        );
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

    function _swapParams(bool zeroForOne, int256 amountSpecified)
        internal
        pure
        returns (SwapParams memory params)
    {
        params = SwapParams({
            zeroForOne: zeroForOne,
            amountSpecified: amountSpecified,
            sqrtPriceLimitX96: zeroForOne ? MIN_PRICE_LIMIT : MAX_PRICE_LIMIT
        });
    }

    function _sortedCurrencies(address tokenA, address tokenB)
        private
        pure
        returns (Currency currencyA, Currency currencyB)
    {
        (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        return (Currency.wrap(token0), Currency.wrap(token1));
    }
}
