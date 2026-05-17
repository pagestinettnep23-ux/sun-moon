// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { Test } from "forge-std/Test.sol";
import { IHooks } from "@uniswap/v4-core/src/interfaces/IHooks.sol";
import { TickMath } from "@uniswap/v4-core/src/libraries/TickMath.sol";
import { Currency } from "@uniswap/v4-core/src/types/Currency.sol";
import { PoolId, PoolIdLibrary } from "@uniswap/v4-core/src/types/PoolId.sol";
import { PoolKey } from "@uniswap/v4-core/src/types/PoolKey.sol";
import { BaseV4HookAddressMiner } from "../../../contracts/hooks/base/BaseV4HookAddressMiner.sol";
import { ComputeBaseSunMoonUsdcPoolIds } from "../../../script/ComputeBaseSunMoonUsdcPoolIds.s.sol";

contract BaseSunMoonUsdcPoolIdsPreparationTest is Test {
    using PoolIdLibrary for PoolKey;

    address internal hook = _permissionedHookAddress(0xBEEF);
    address internal sunToken = address(0x1002);
    address internal moonToken = address(0x1003);
    address internal usdcToken = address(0x1004);
    uint256 internal constant Q192 = uint256(1) << 192;

    function testPrepareComputesSunAndMoonUsdcPoolIds() public {
        vm.chainId(31_337);

        ComputeBaseSunMoonUsdcPoolIds script = new ComputeBaseSunMoonUsdcPoolIds();
        ComputeBaseSunMoonUsdcPoolIds.PoolIdPlan memory plan = script.prepare(_config());

        PoolKey memory expectedSunKey = _poolKey(sunToken, usdcToken, IHooks(hook), 3000, 60);
        PoolKey memory expectedMoonKey = _poolKey(moonToken, usdcToken, IHooks(hook), 3000, 60);

        assertEq(plan.chainId, 31_337);
        assertEq(plan.hook, hook);
        assertEq(plan.sunToken, sunToken);
        assertEq(plan.moonToken, moonToken);
        assertEq(plan.usdcToken, usdcToken);
        assertEq(plan.expectedHookMask, BaseV4HookAddressMiner.BASE_SUN_MOON_USDC_FEE_V4_HOOK_MASK);
        assertEq(plan.actualHookMask, plan.expectedHookMask);

        _assertPoolKey(plan.sunUsdcPoolKey, expectedSunKey);
        assertEq(plan.sunUsdcPoolId, PoolId.unwrap(expectedSunKey.toId()));
        assertEq(plan.sunUsdcInitialTokenAmount, 1e18);
        assertEq(plan.sunUsdcInitialUsdcAmount, 1e6);
        assertEq(
            plan.sunUsdcSqrtPriceX96, _initialSqrtPriceX96(expectedSunKey, sunToken, 1e18, 1e6)
        );
        assertEq(plan.sunUsdcInitialTick, TickMath.getTickAtSqrtPrice(plan.sunUsdcSqrtPriceX96));
        _assertPoolKey(plan.moonUsdcPoolKey, expectedMoonKey);
        assertEq(plan.moonUsdcPoolId, PoolId.unwrap(expectedMoonKey.toId()));
        assertEq(plan.moonUsdcInitialTokenAmount, 1e18);
        assertEq(plan.moonUsdcInitialUsdcAmount, 240_000);
        assertEq(
            plan.moonUsdcSqrtPriceX96,
            _initialSqrtPriceX96(expectedMoonKey, moonToken, 1e18, 240_000)
        );
        assertEq(plan.moonUsdcInitialTick, TickMath.getTickAtSqrtPrice(plan.moonUsdcSqrtPriceX96));
        assertNotEq(plan.sunUsdcPoolId, plan.moonUsdcPoolId);
    }

    function testRunLoadsEnvironmentAndComputesPoolIds() public {
        vm.chainId(31_337);
        _setEnv();

        ComputeBaseSunMoonUsdcPoolIds script = new ComputeBaseSunMoonUsdcPoolIds();
        ComputeBaseSunMoonUsdcPoolIds.PoolIdPlan memory plan = script.run();

        PoolKey memory expectedSunKey = _poolKey(sunToken, usdcToken, IHooks(hook), 3000, 60);
        PoolKey memory expectedMoonKey = _poolKey(moonToken, usdcToken, IHooks(hook), 3000, 60);

        assertEq(plan.hook, hook);
        assertEq(plan.sunUsdcPoolId, PoolId.unwrap(expectedSunKey.toId()));
        assertEq(plan.moonUsdcPoolId, PoolId.unwrap(expectedMoonKey.toId()));
        assertEq(plan.sunUsdcInitialUsdcAmount, 1e6);
        assertEq(plan.moonUsdcInitialUsdcAmount, 240_000);
    }

    function testRejectsInvalidHookMask() public {
        ComputeBaseSunMoonUsdcPoolIds.PoolIdConfig memory config = _config();
        config.hook = address(0x1234);

        ComputeBaseSunMoonUsdcPoolIds script = new ComputeBaseSunMoonUsdcPoolIds();
        uint160 expectedMask = BaseV4HookAddressMiner.BASE_SUN_MOON_USDC_FEE_V4_HOOK_MASK;
        uint160 actualMask = uint160(config.hook) & BaseV4HookAddressMiner.V4_ALL_HOOK_MASK;

        vm.expectRevert(
            abi.encodeWithSelector(
                ComputeBaseSunMoonUsdcPoolIds.UnexpectedHookMask.selector, expectedMask, actualMask
            )
        );
        script.prepare(config);
    }

    function testRejectsDuplicateTokenAddress() public {
        ComputeBaseSunMoonUsdcPoolIds.PoolIdConfig memory config = _config();
        config.moonToken = config.sunToken;

        ComputeBaseSunMoonUsdcPoolIds script = new ComputeBaseSunMoonUsdcPoolIds();

        vm.expectRevert(
            abi.encodeWithSelector(
                ComputeBaseSunMoonUsdcPoolIds.DuplicateTokenAddress.selector,
                bytes32("SUN_TOKEN"),
                bytes32("MOON_TOKEN"),
                config.sunToken
            )
        );
        script.prepare(config);
    }

    function testRejectsInvalidPoolConfig() public {
        ComputeBaseSunMoonUsdcPoolIds.PoolIdConfig memory config = _config();
        config.sunUsdcFee = 0;

        ComputeBaseSunMoonUsdcPoolIds script = new ComputeBaseSunMoonUsdcPoolIds();

        vm.expectRevert(
            abi.encodeWithSelector(
                ComputeBaseSunMoonUsdcPoolIds.InvalidPoolConfig.selector,
                bytes32("SUN_USDC_POOL"),
                uint24(0),
                int24(60)
            )
        );
        script.prepare(config);
    }

    function testRejectsInvalidInitialPrice() public {
        ComputeBaseSunMoonUsdcPoolIds.PoolIdConfig memory config = _config();
        config.moonUsdcInitialUsdcAmount = 0;

        ComputeBaseSunMoonUsdcPoolIds script = new ComputeBaseSunMoonUsdcPoolIds();

        vm.expectRevert(
            abi.encodeWithSelector(
                ComputeBaseSunMoonUsdcPoolIds.InvalidInitialPrice.selector,
                bytes32("MOON_USDC_INITIAL_PRICE"),
                uint256(1e18),
                uint256(0)
            )
        );
        script.prepare(config);
    }

    function testRejectsZeroTokenAddress() public {
        ComputeBaseSunMoonUsdcPoolIds.PoolIdConfig memory config = _config();
        config.usdcToken = address(0);

        ComputeBaseSunMoonUsdcPoolIds script = new ComputeBaseSunMoonUsdcPoolIds();

        vm.expectRevert(
            abi.encodeWithSelector(
                ComputeBaseSunMoonUsdcPoolIds.InvalidAddress.selector, bytes32("USDC_TOKEN")
            )
        );
        script.prepare(config);
    }

    function _config()
        private
        view
        returns (ComputeBaseSunMoonUsdcPoolIds.PoolIdConfig memory config)
    {
        config = ComputeBaseSunMoonUsdcPoolIds.PoolIdConfig({
            hook: hook,
            sunToken: sunToken,
            moonToken: moonToken,
            usdcToken: usdcToken,
            sunUsdcFee: 3000,
            sunUsdcTickSpacing: 60,
            sunUsdcInitialTokenAmount: 1e18,
            sunUsdcInitialUsdcAmount: 1e6,
            moonUsdcFee: 3000,
            moonUsdcTickSpacing: 60,
            moonUsdcInitialTokenAmount: 1e18,
            moonUsdcInitialUsdcAmount: 240_000
        });
    }

    function _poolKey(address tokenA, address tokenB, IHooks hooks, uint24 fee, int24 tickSpacing)
        private
        pure
        returns (PoolKey memory key)
    {
        (Currency currency0, Currency currency1) = tokenA < tokenB
            ? (Currency.wrap(tokenA), Currency.wrap(tokenB))
            : (Currency.wrap(tokenB), Currency.wrap(tokenA));

        key = PoolKey({
            currency0: currency0,
            currency1: currency1,
            fee: fee,
            tickSpacing: tickSpacing,
            hooks: hooks
        });
    }

    function _assertPoolKey(PoolKey memory actual, PoolKey memory expected) private pure {
        assert(Currency.unwrap(actual.currency0) == Currency.unwrap(expected.currency0));
        assert(Currency.unwrap(actual.currency1) == Currency.unwrap(expected.currency1));
        assert(actual.fee == expected.fee);
        assert(actual.tickSpacing == expected.tickSpacing);
        assert(address(actual.hooks) == address(expected.hooks));
    }

    function _initialSqrtPriceX96(
        PoolKey memory key,
        address token,
        uint256 tokenAmount,
        uint256 usdcAmount
    ) private view returns (uint160 sqrtPriceX96) {
        uint256 ratioNumerator;
        uint256 ratioDenominator;

        if (Currency.unwrap(key.currency0) == usdcToken && Currency.unwrap(key.currency1) == token)
        {
            ratioNumerator = tokenAmount;
            ratioDenominator = usdcAmount;
        } else {
            ratioNumerator = usdcAmount;
            ratioDenominator = tokenAmount;
        }

        sqrtPriceX96 = uint160(Math.sqrt(Math.mulDiv(ratioNumerator, Q192, ratioDenominator)));
    }

    function _permissionedHookAddress(uint160 highBits) private pure returns (address) {
        return address(
            uint160(BaseV4HookAddressMiner.BASE_SUN_MOON_USDC_FEE_V4_HOOK_MASK) | (highBits << 14)
        );
    }

    function _setEnv() private {
        vm.setEnv("HOOK_ADDRESS", vm.toString(hook));
        vm.setEnv("SUN_TOKEN", vm.toString(sunToken));
        vm.setEnv("MOON_TOKEN", vm.toString(moonToken));
        vm.setEnv("USDC_TOKEN", vm.toString(usdcToken));
        vm.setEnv("SUN_USDC_POOL_FEE", "3000");
        vm.setEnv("SUN_USDC_POOL_TICK_SPACING", "60");
        vm.setEnv("SUN_USDC_INITIAL_TOKEN_AMOUNT", "1000000000000000000");
        vm.setEnv("SUN_USDC_INITIAL_USDC_AMOUNT", "1000000");
        vm.setEnv("MOON_USDC_POOL_FEE", "3000");
        vm.setEnv("MOON_USDC_POOL_TICK_SPACING", "60");
        vm.setEnv("MOON_USDC_INITIAL_TOKEN_AMOUNT", "1000000000000000000");
        vm.setEnv("MOON_USDC_INITIAL_USDC_AMOUNT", "240000");
    }
}
