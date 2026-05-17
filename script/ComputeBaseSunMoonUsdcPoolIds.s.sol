// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { Script, console2 } from "forge-std/Script.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { IHooks } from "@uniswap/v4-core/src/interfaces/IHooks.sol";
import { TickMath } from "@uniswap/v4-core/src/libraries/TickMath.sol";
import { Currency } from "@uniswap/v4-core/src/types/Currency.sol";
import { PoolId, PoolIdLibrary } from "@uniswap/v4-core/src/types/PoolId.sol";
import { PoolKey } from "@uniswap/v4-core/src/types/PoolKey.sol";
import { BaseV4HookAddressMiner } from "../contracts/hooks/base/BaseV4HookAddressMiner.sol";

contract ComputeBaseSunMoonUsdcPoolIds is Script {
    using PoolIdLibrary for PoolKey;

    bytes32 internal constant LABEL_HOOK = "HOOK_ADDRESS";
    bytes32 internal constant LABEL_SUN_TOKEN = "SUN_TOKEN";
    bytes32 internal constant LABEL_MOON_TOKEN = "MOON_TOKEN";
    bytes32 internal constant LABEL_USDC_TOKEN = "USDC_TOKEN";
    bytes32 internal constant LABEL_SUN_POOL = "SUN_USDC_POOL";
    bytes32 internal constant LABEL_MOON_POOL = "MOON_USDC_POOL";
    bytes32 internal constant LABEL_SUN_PRICE = "SUN_USDC_INITIAL_PRICE";
    bytes32 internal constant LABEL_MOON_PRICE = "MOON_USDC_INITIAL_PRICE";

    uint256 internal constant Q192 = uint256(1) << 192;
    uint256 internal constant DEFAULT_TOKEN_UNIT = 1e18;
    uint256 internal constant DEFAULT_SUN_USDC_PRICE = 1e6;
    uint256 internal constant DEFAULT_MOON_USDC_PRICE = 240_000;

    struct PoolIdConfig {
        address hook;
        address sunToken;
        address moonToken;
        address usdcToken;
        uint24 sunUsdcFee;
        int24 sunUsdcTickSpacing;
        uint256 sunUsdcInitialTokenAmount;
        uint256 sunUsdcInitialUsdcAmount;
        uint24 moonUsdcFee;
        int24 moonUsdcTickSpacing;
        uint256 moonUsdcInitialTokenAmount;
        uint256 moonUsdcInitialUsdcAmount;
    }

    struct PoolIdPlan {
        uint256 chainId;
        address hook;
        address sunToken;
        address moonToken;
        address usdcToken;
        uint160 expectedHookMask;
        uint160 actualHookMask;
        uint24 sunUsdcFee;
        int24 sunUsdcTickSpacing;
        PoolKey sunUsdcPoolKey;
        bytes32 sunUsdcPoolId;
        uint256 sunUsdcInitialTokenAmount;
        uint256 sunUsdcInitialUsdcAmount;
        int24 sunUsdcInitialTick;
        uint160 sunUsdcSqrtPriceX96;
        uint24 moonUsdcFee;
        int24 moonUsdcTickSpacing;
        PoolKey moonUsdcPoolKey;
        bytes32 moonUsdcPoolId;
        uint256 moonUsdcInitialTokenAmount;
        uint256 moonUsdcInitialUsdcAmount;
        int24 moonUsdcInitialTick;
        uint160 moonUsdcSqrtPriceX96;
    }

    error DuplicatePoolId(bytes32 poolId);
    error DuplicateTokenAddress(bytes32 leftLabel, bytes32 rightLabel, address token);
    error InvalidAddress(bytes32 label);
    error InvalidPoolConfig(bytes32 label, uint24 fee, int24 tickSpacing);
    error InvalidInitialPrice(bytes32 label, uint256 tokenAmount, uint256 usdcAmount);
    error UnexpectedHookMask(uint160 expectedMask, uint160 actualMask);

    function run() external view returns (PoolIdPlan memory plan) {
        plan = _prepare(_loadConfig());
    }

    function prepare(PoolIdConfig memory config) external view returns (PoolIdPlan memory plan) {
        plan = _prepare(config);
    }

    function _loadConfig() private view returns (PoolIdConfig memory config) {
        config = PoolIdConfig({
            hook: vm.envOr("HOOK_ADDRESS", _defaultPermissionedHookAddress()),
            sunToken: vm.envOr("SUN_TOKEN", address(0x1002)),
            moonToken: vm.envOr("MOON_TOKEN", address(0x1003)),
            usdcToken: vm.envOr("USDC_TOKEN", address(0x1004)),
            sunUsdcFee: uint24(vm.envOr("SUN_USDC_POOL_FEE", uint256(3000))),
            sunUsdcTickSpacing: int24(vm.envOr("SUN_USDC_POOL_TICK_SPACING", int256(60))),
            sunUsdcInitialTokenAmount: vm.envOr(
                "SUN_USDC_INITIAL_TOKEN_AMOUNT", DEFAULT_TOKEN_UNIT
            ),
            sunUsdcInitialUsdcAmount: vm.envOr(
                "SUN_USDC_INITIAL_USDC_AMOUNT", DEFAULT_SUN_USDC_PRICE
            ),
            moonUsdcFee: uint24(vm.envOr("MOON_USDC_POOL_FEE", uint256(3000))),
            moonUsdcTickSpacing: int24(vm.envOr("MOON_USDC_POOL_TICK_SPACING", int256(60))),
            moonUsdcInitialTokenAmount: vm.envOr(
                "MOON_USDC_INITIAL_TOKEN_AMOUNT", DEFAULT_TOKEN_UNIT
            ),
            moonUsdcInitialUsdcAmount: vm.envOr(
                "MOON_USDC_INITIAL_USDC_AMOUNT", DEFAULT_MOON_USDC_PRICE
            )
        });
    }

    function _prepare(PoolIdConfig memory config) private view returns (PoolIdPlan memory plan) {
        _validateConfig(config);

        plan.chainId = block.chainid;
        plan.hook = config.hook;
        plan.sunToken = config.sunToken;
        plan.moonToken = config.moonToken;
        plan.usdcToken = config.usdcToken;
        plan.expectedHookMask = BaseV4HookAddressMiner.BASE_SUN_MOON_USDC_FEE_V4_HOOK_MASK;
        plan.actualHookMask = uint160(config.hook) & BaseV4HookAddressMiner.V4_ALL_HOOK_MASK;
        plan.sunUsdcFee = config.sunUsdcFee;
        plan.sunUsdcTickSpacing = config.sunUsdcTickSpacing;
        plan.sunUsdcPoolKey = _poolKey(
            config.sunToken,
            config.usdcToken,
            IHooks(config.hook),
            config.sunUsdcFee,
            config.sunUsdcTickSpacing
        );
        plan.sunUsdcPoolId = PoolId.unwrap(plan.sunUsdcPoolKey.toId());
        plan.sunUsdcInitialTokenAmount = config.sunUsdcInitialTokenAmount;
        plan.sunUsdcInitialUsdcAmount = config.sunUsdcInitialUsdcAmount;
        plan.sunUsdcSqrtPriceX96 = _initialSqrtPriceX96(
            plan.sunUsdcPoolKey,
            config.sunToken,
            config.usdcToken,
            config.sunUsdcInitialTokenAmount,
            config.sunUsdcInitialUsdcAmount
        );
        plan.sunUsdcInitialTick = TickMath.getTickAtSqrtPrice(plan.sunUsdcSqrtPriceX96);
        plan.moonUsdcFee = config.moonUsdcFee;
        plan.moonUsdcTickSpacing = config.moonUsdcTickSpacing;
        plan.moonUsdcPoolKey = _poolKey(
            config.moonToken,
            config.usdcToken,
            IHooks(config.hook),
            config.moonUsdcFee,
            config.moonUsdcTickSpacing
        );
        plan.moonUsdcPoolId = PoolId.unwrap(plan.moonUsdcPoolKey.toId());
        plan.moonUsdcInitialTokenAmount = config.moonUsdcInitialTokenAmount;
        plan.moonUsdcInitialUsdcAmount = config.moonUsdcInitialUsdcAmount;
        plan.moonUsdcSqrtPriceX96 = _initialSqrtPriceX96(
            plan.moonUsdcPoolKey,
            config.moonToken,
            config.usdcToken,
            config.moonUsdcInitialTokenAmount,
            config.moonUsdcInitialUsdcAmount
        );
        plan.moonUsdcInitialTick = TickMath.getTickAtSqrtPrice(plan.moonUsdcSqrtPriceX96);

        if (plan.sunUsdcPoolId == plan.moonUsdcPoolId) revert DuplicatePoolId(plan.sunUsdcPoolId);

        _logPlan(plan);
    }

    function _validateConfig(PoolIdConfig memory config) private pure {
        _requireAddress(config.hook, LABEL_HOOK);
        _requireAddress(config.sunToken, LABEL_SUN_TOKEN);
        _requireAddress(config.moonToken, LABEL_MOON_TOKEN);
        _requireAddress(config.usdcToken, LABEL_USDC_TOKEN);

        _requireDistinct(config.sunToken, LABEL_SUN_TOKEN, config.moonToken, LABEL_MOON_TOKEN);
        _requireDistinct(config.sunToken, LABEL_SUN_TOKEN, config.usdcToken, LABEL_USDC_TOKEN);
        _requireDistinct(config.moonToken, LABEL_MOON_TOKEN, config.usdcToken, LABEL_USDC_TOKEN);

        _requirePoolConfig(LABEL_SUN_POOL, config.sunUsdcFee, config.sunUsdcTickSpacing);
        _requirePoolConfig(LABEL_MOON_POOL, config.moonUsdcFee, config.moonUsdcTickSpacing);
        _requireInitialPrice(
            LABEL_SUN_PRICE, config.sunUsdcInitialTokenAmount, config.sunUsdcInitialUsdcAmount
        );
        _requireInitialPrice(
            LABEL_MOON_PRICE, config.moonUsdcInitialTokenAmount, config.moonUsdcInitialUsdcAmount
        );

        uint160 expectedMask = BaseV4HookAddressMiner.BASE_SUN_MOON_USDC_FEE_V4_HOOK_MASK;
        uint160 actualMask = uint160(config.hook) & BaseV4HookAddressMiner.V4_ALL_HOOK_MASK;
        if (actualMask != expectedMask) revert UnexpectedHookMask(expectedMask, actualMask);
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

    function _initialSqrtPriceX96(
        PoolKey memory key,
        address token,
        address usdc,
        uint256 tokenAmount,
        uint256 usdcAmount
    ) private pure returns (uint160 sqrtPriceX96) {
        uint256 ratioNumerator;
        uint256 ratioDenominator;

        if (Currency.unwrap(key.currency0) == usdc && Currency.unwrap(key.currency1) == token) {
            ratioNumerator = tokenAmount;
            ratioDenominator = usdcAmount;
        } else if (
            Currency.unwrap(key.currency0) == token && Currency.unwrap(key.currency1) == usdc
        ) {
            ratioNumerator = usdcAmount;
            ratioDenominator = tokenAmount;
        } else {
            revert InvalidAddress("POOL_PRICE_TOKEN_ORDER");
        }

        sqrtPriceX96 = uint160(Math.sqrt(Math.mulDiv(ratioNumerator, Q192, ratioDenominator)));
    }

    function _defaultPermissionedHookAddress() private pure returns (address) {
        return address(
            uint160(BaseV4HookAddressMiner.BASE_SUN_MOON_USDC_FEE_V4_HOOK_MASK) | (uint160(1) << 14)
        );
    }

    function _requireAddress(address value, bytes32 label) private pure {
        if (value == address(0)) revert InvalidAddress(label);
    }

    function _requireDistinct(address left, bytes32 leftLabel, address right, bytes32 rightLabel)
        private
        pure
    {
        if (left == right) revert DuplicateTokenAddress(leftLabel, rightLabel, left);
    }

    function _requirePoolConfig(bytes32 label, uint24 fee, int24 tickSpacing) private pure {
        if (fee == 0 || tickSpacing <= 0) revert InvalidPoolConfig(label, fee, tickSpacing);
    }

    function _requireInitialPrice(bytes32 label, uint256 tokenAmount, uint256 usdcAmount)
        private
        pure
    {
        if (tokenAmount == 0 || usdcAmount == 0) {
            revert InvalidInitialPrice(label, tokenAmount, usdcAmount);
        }
    }

    function _logPlan(PoolIdPlan memory plan) private pure {
        console2.log("Base SUN/MOON USDC v4 Hook poolId calculation");
        console2.log("simulationOnly:", "no broadcast, no approvals, no private key required");
        console2.log("chainId:", plan.chainId);
        console2.log("HOOK_ADDRESS:", plan.hook);
        console2.log("expectedHookMask:", plan.expectedHookMask);
        console2.log("actualLow14Bits:", plan.actualHookMask);
        console2.log("SUN_TOKEN:", plan.sunToken);
        console2.log("MOON_TOKEN:", plan.moonToken);
        console2.log("USDC_TOKEN:", plan.usdcToken);
        console2.log("SUN/USDC currency0:", Currency.unwrap(plan.sunUsdcPoolKey.currency0));
        console2.log("SUN/USDC currency1:", Currency.unwrap(plan.sunUsdcPoolKey.currency1));
        console2.log("SUN/USDC fee:", plan.sunUsdcFee);
        console2.log("SUN/USDC tickSpacing:", plan.sunUsdcTickSpacing);
        console2.log("SUN/USDC initial token amount:", plan.sunUsdcInitialTokenAmount);
        console2.log("SUN/USDC initial USDC amount:", plan.sunUsdcInitialUsdcAmount);
        console2.log("SUN/USDC initialTick:", plan.sunUsdcInitialTick);
        console2.log("SUN/USDC sqrtPriceX96:", plan.sunUsdcSqrtPriceX96);
        console2.log("SUN/USDC poolId:");
        console2.logBytes32(plan.sunUsdcPoolId);
        console2.log("MOON/USDC currency0:", Currency.unwrap(plan.moonUsdcPoolKey.currency0));
        console2.log("MOON/USDC currency1:", Currency.unwrap(plan.moonUsdcPoolKey.currency1));
        console2.log("MOON/USDC fee:", plan.moonUsdcFee);
        console2.log("MOON/USDC tickSpacing:", plan.moonUsdcTickSpacing);
        console2.log("MOON/USDC initial token amount:", plan.moonUsdcInitialTokenAmount);
        console2.log("MOON/USDC initial USDC amount:", plan.moonUsdcInitialUsdcAmount);
        console2.log("MOON/USDC initialTick:", plan.moonUsdcInitialTick);
        console2.log("MOON/USDC sqrtPriceX96:", plan.moonUsdcSqrtPriceX96);
        console2.log("MOON/USDC poolId:");
        console2.logBytes32(plan.moonUsdcPoolId);
    }
}
