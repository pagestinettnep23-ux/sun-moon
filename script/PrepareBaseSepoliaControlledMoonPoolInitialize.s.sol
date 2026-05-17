// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { Script, console2 } from "forge-std/Script.sol";
import { IHooks } from "@uniswap/v4-core/src/interfaces/IHooks.sol";
import { IPoolManager } from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import { TickMath } from "@uniswap/v4-core/src/libraries/TickMath.sol";
import { Currency } from "@uniswap/v4-core/src/types/Currency.sol";
import { PoolId, PoolIdLibrary } from "@uniswap/v4-core/src/types/PoolId.sol";
import { PoolKey } from "@uniswap/v4-core/src/types/PoolKey.sol";
import { IStateView } from "@uniswap/v4-periphery/src/interfaces/IStateView.sol";
import { BaseMoonAmmFeeV4Hook } from "../contracts/hooks/base/BaseMoonAmmFeeV4Hook.sol";
import { BaseV4Addresses } from "../contracts/hooks/base/BaseV4Addresses.sol";
import { BaseV4HookAddressMiner } from "../contracts/hooks/base/BaseV4HookAddressMiner.sol";

contract PrepareBaseSepoliaControlledMoonPoolInitialize is Script {
    using PoolIdLibrary for PoolKey;

    int24 internal constant DEFAULT_INITIAL_TICK = 276_300;

    bytes32 internal constant LABEL_POOL_INITIALIZER = "POOL_INITIALIZER";
    bytes32 internal constant LABEL_POOL_MANAGER = "POOL_MANAGER";
    bytes32 internal constant LABEL_STATE_VIEW = "STATE_VIEW";
    bytes32 internal constant LABEL_HOOK = "HOOK";
    bytes32 internal constant LABEL_MOON_TOKEN = "MOON_TOKEN";
    bytes32 internal constant LABEL_USDC_TOKEN = "USDC_TOKEN";

    struct PoolInitialization {
        uint256 chainId;
        bool baseSepoliaConfirmed;
        address poolInitializer;
        IPoolManager poolManager;
        IStateView stateView;
        BaseMoonAmmFeeV4Hook hook;
        address moonToken;
        address usdcToken;
        uint24 fee;
        int24 tickSpacing;
        int24 initialTick;
        uint160 sqrtPriceX96;
        PoolKey poolKey;
        bytes32 poolId;
        bool allowedMoonPool;
        uint160 sqrtPriceBefore;
        int24 tickBefore;
        bool alreadyInitialized;
        uint256 transactionsPlanned;
        uint160 sqrtPriceAfter;
        int24 tickAfter;
    }

    error BaseMainnetNotAllowed(uint256 chainId);
    error BaseSepoliaRunNotConfirmed(uint256 chainId);
    error DependencyCodeMissing(bytes32 label, address target);
    error InvalidAddress(bytes32 label);
    error InvalidPoolConfig(uint24 fee, int24 tickSpacing);
    error InvalidInitialTick(int24 tick, int24 tickSpacing);
    error MoonPoolNotAllowed(bytes32 poolId);
    error PoolNotInitialized(bytes32 poolId);
    error UnexpectedHookMask(uint160 expectedMask, uint160 actualMask);
    error UnexpectedInitializedPool(
        bytes32 poolId, uint160 expectedSqrtPriceX96, uint160 actualSqrtPriceX96
    );
    error UnexpectedParameter(bytes32 label, address expected, address actual);

    function run() external returns (PoolInitialization memory pool) {
        pool = _loadPool();
        _validateRun(pool);
        _loadSlot0Before(pool);

        pool.alreadyInitialized = pool.sqrtPriceBefore != 0;
        pool.transactionsPlanned = pool.alreadyInitialized ? 0 : 1;

        if (pool.alreadyInitialized) {
            _requireExpectedInitializedPool(pool);
        } else {
            vm.startBroadcast(pool.poolInitializer);
            pool.tickAfter = pool.poolManager.initialize(pool.poolKey, pool.sqrtPriceX96);
            vm.stopBroadcast();
        }

        _loadSlot0After(pool);
        _requireInitialized(pool);
        _logPool(pool);
    }

    function _loadPool() private view returns (PoolInitialization memory pool) {
        pool.chainId = block.chainid;
        pool.baseSepoliaConfirmed =
            vm.envOr("CONFIRM_BASE_SEPOLIA_POOL_INITIALIZE_RUN", uint256(0)) == 1;
        pool.poolInitializer =
            _envAddressOr("POOL_INITIALIZER", "HOOK_OWNER", LABEL_POOL_INITIALIZER);
        pool.poolManager = IPoolManager(
            _envAddressOrDefault(
                "POOL_MANAGER", BaseV4Addresses.BASE_SEPOLIA_POOL_MANAGER, LABEL_POOL_MANAGER
            )
        );
        pool.stateView = IStateView(
            _envAddressOrDefault(
                "STATE_VIEW", BaseV4Addresses.BASE_SEPOLIA_STATE_VIEW, LABEL_STATE_VIEW
            )
        );
        pool.hook = BaseMoonAmmFeeV4Hook(_requiredEnvAddress("HOOK_ADDRESS", LABEL_HOOK));
        pool.moonToken = _envAddressOr("CONTROLLED_POOL_MOON_TOKEN", "MOON_TOKEN", LABEL_MOON_TOKEN);
        pool.usdcToken = _envAddressOrDefault(
            "CONTROLLED_POOL_USDC_TOKEN", BaseV4Addresses.BASE_SEPOLIA_USDC, LABEL_USDC_TOKEN
        );
        pool.fee = uint24(vm.envOr("MOON_USDC_POOL_FEE", uint256(3000)));
        pool.tickSpacing = int24(vm.envOr("MOON_USDC_POOL_TICK_SPACING", int256(60)));
        pool.initialTick =
            _initialTick(vm.envOr("MOON_USDC_INITIAL_TICK", int256(DEFAULT_INITIAL_TICK)));
        pool.sqrtPriceX96 = TickMath.getSqrtPriceAtTick(pool.initialTick);
        pool.poolKey = _poolKey(
            pool.moonToken, pool.usdcToken, IHooks(address(pool.hook)), pool.fee, pool.tickSpacing
        );
        pool.poolId = PoolId.unwrap(pool.poolKey.toId());
    }

    function _requiredEnvAddress(string memory key, bytes32 label)
        private
        view
        returns (address value)
    {
        value = _parseRequiredAddress(vm.envOr(key, string("")), label);
    }

    function _envAddressOr(string memory primaryKey, string memory fallbackKey, bytes32 label)
        private
        view
        returns (address value)
    {
        string memory rawValue = vm.envOr(primaryKey, string(""));
        if (bytes(rawValue).length == 0) {
            rawValue = vm.envOr(fallbackKey, string(""));
        }

        value = _parseRequiredAddress(rawValue, label);
    }

    function _envAddressOrDefault(string memory key, address defaultValue, bytes32 label)
        private
        view
        returns (address value)
    {
        string memory rawValue = vm.envOr(key, string(""));
        if (bytes(rawValue).length == 0) {
            value = defaultValue;
        } else {
            value = vm.parseAddress(rawValue);
        }
        if (value == address(0)) revert InvalidAddress(label);
    }

    function _parseRequiredAddress(string memory rawValue, bytes32 label)
        private
        pure
        returns (address value)
    {
        if (bytes(rawValue).length == 0) revert InvalidAddress(label);

        value = vm.parseAddress(rawValue);
        if (value == address(0)) revert InvalidAddress(label);
    }

    function _initialTick(int256 rawTick) private pure returns (int24 tick) {
        if (rawTick < TickMath.MIN_TICK || rawTick > TickMath.MAX_TICK) {
            revert InvalidInitialTick(int24(0), int24(0));
        }

        tick = int24(rawTick);
    }

    function _validateRun(PoolInitialization memory pool) private view {
        if (pool.chainId == BaseV4Addresses.BASE_MAINNET_CHAIN_ID) {
            revert BaseMainnetNotAllowed(pool.chainId);
        }
        if (pool.chainId == BaseV4Addresses.BASE_SEPOLIA_CHAIN_ID && !pool.baseSepoliaConfirmed) {
            revert BaseSepoliaRunNotConfirmed(pool.chainId);
        }
        if (pool.fee == 0 || pool.tickSpacing <= 0) {
            revert InvalidPoolConfig(pool.fee, pool.tickSpacing);
        }
        if (pool.initialTick % pool.tickSpacing != 0) {
            revert InvalidInitialTick(pool.initialTick, pool.tickSpacing);
        }

        _requireCode(LABEL_POOL_MANAGER, address(pool.poolManager));
        _requireCode(LABEL_STATE_VIEW, address(pool.stateView));
        _requireCode(LABEL_HOOK, address(pool.hook));
        _requireCode(LABEL_MOON_TOKEN, pool.moonToken);
        _requireCode(LABEL_USDC_TOKEN, pool.usdcToken);
        _requireParameter(
            LABEL_POOL_MANAGER, address(pool.poolManager), address(pool.hook.poolManager())
        );
        _requireParameter(LABEL_MOON_TOKEN, pool.moonToken, pool.hook.moonToken());
        _requireParameter(LABEL_USDC_TOKEN, pool.usdcToken, address(pool.hook.usdt()));

        if (
            pool.chainId == BaseV4Addresses.BASE_SEPOLIA_CHAIN_ID
                && pool.usdcToken != BaseV4Addresses.BASE_SEPOLIA_USDC
        ) {
            revert UnexpectedParameter(
                LABEL_USDC_TOKEN, BaseV4Addresses.BASE_SEPOLIA_USDC, pool.usdcToken
            );
        }

        uint160 expectedMask = BaseV4HookAddressMiner.BASE_MOON_AMM_FEE_V4_HOOK_MASK;
        uint160 actualMask = uint160(address(pool.hook)) & BaseV4HookAddressMiner.V4_ALL_HOOK_MASK;
        if (actualMask != expectedMask) revert UnexpectedHookMask(expectedMask, actualMask);
        if (pool.hook.expectedHookMask() != expectedMask) {
            revert UnexpectedHookMask(expectedMask, pool.hook.expectedHookMask());
        }
        if (pool.poolId == bytes32(0)) revert InvalidAddress("POOL_ID");

        pool.allowedMoonPool = pool.hook.allowedMoonPools(pool.poolId);
        if (!pool.allowedMoonPool) revert MoonPoolNotAllowed(pool.poolId);
    }

    function _loadSlot0Before(PoolInitialization memory pool) private view {
        (pool.sqrtPriceBefore, pool.tickBefore,,) =
            pool.stateView.getSlot0(PoolId.wrap(pool.poolId));
    }

    function _loadSlot0After(PoolInitialization memory pool) private view {
        (pool.sqrtPriceAfter, pool.tickAfter,,) = pool.stateView.getSlot0(PoolId.wrap(pool.poolId));
    }

    function _requireInitialized(PoolInitialization memory pool) private pure {
        if (pool.sqrtPriceAfter == 0) revert PoolNotInitialized(pool.poolId);
        if (pool.sqrtPriceAfter != pool.sqrtPriceX96) {
            revert UnexpectedInitializedPool(pool.poolId, pool.sqrtPriceX96, pool.sqrtPriceAfter);
        }
    }

    function _requireExpectedInitializedPool(PoolInitialization memory pool) private pure {
        if (pool.sqrtPriceBefore != pool.sqrtPriceX96) {
            revert UnexpectedInitializedPool(pool.poolId, pool.sqrtPriceX96, pool.sqrtPriceBefore);
        }
    }

    function _poolKey(address tokenA, address tokenB, IHooks hooks, uint24 fee, int24 tickSpacing)
        private
        pure
        returns (PoolKey memory key)
    {
        if (tokenA == tokenB || tokenA == address(0) || tokenB == address(0)) {
            revert InvalidAddress("POOL_TOKEN");
        }
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

    function _requireCode(bytes32 label, address target) private view {
        if (target.code.length == 0) revert DependencyCodeMissing(label, target);
    }

    function _requireParameter(bytes32 label, address expected, address actual) private pure {
        if (actual != expected) revert UnexpectedParameter(label, expected, actual);
    }

    function _logPool(PoolInitialization memory pool) private pure {
        console2.log("Base Sepolia controlled MOON/USDC pool initialization preparation");
        console2.log("simulationOnly:", "do not add --broadcast without explicit approval");
        console2.log("chainId:", pool.chainId);
        console2.log("baseSepoliaConfirmed:", pool.baseSepoliaConfirmed);
        console2.log("POOL_INITIALIZER / tx sender:", pool.poolInitializer);
        console2.log("POOL_MANAGER:", address(pool.poolManager));
        console2.log("STATE_VIEW:", address(pool.stateView));
        console2.log("HOOK_ADDRESS:", address(pool.hook));
        console2.log("MOON_TOKEN:", pool.moonToken);
        console2.log("USDC_TOKEN:", pool.usdcToken);
        console2.log("pool.currency0:", Currency.unwrap(pool.poolKey.currency0));
        console2.log("pool.currency1:", Currency.unwrap(pool.poolKey.currency1));
        console2.log("pool.fee:", pool.fee);
        console2.log("pool.tickSpacing:", pool.tickSpacing);
        console2.log("initialTick:", pool.initialTick);
        console2.log("sqrtPriceX96:", pool.sqrtPriceX96);
        console2.logBytes32(pool.poolId);
        console2.log("allowedMoonPool:", pool.allowedMoonPool);
        console2.log("sqrtPriceBefore:", pool.sqrtPriceBefore);
        console2.log("alreadyInitialized:", pool.alreadyInitialized);
        console2.log("transactionsPlanned:", pool.transactionsPlanned);
        console2.log("sqrtPriceAfter:", pool.sqrtPriceAfter);
        console2.log("tickAfter:", pool.tickAfter);
        console2.log("Next step after real Base Sepolia pool initialization broadcast:");
        console2.log(
            "prepare tiny controlled liquidity/swap rehearsal only after explicit approval"
        );
    }
}
