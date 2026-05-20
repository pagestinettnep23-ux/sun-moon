// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { Script, console2 } from "forge-std/Script.sol";
import { IHooks } from "@uniswap/v4-core/src/interfaces/IHooks.sol";
import { Currency } from "@uniswap/v4-core/src/types/Currency.sol";
import { PoolId, PoolIdLibrary } from "@uniswap/v4-core/src/types/PoolId.sol";
import { PoolKey } from "@uniswap/v4-core/src/types/PoolKey.sol";
import { BaseMoonAmmFeeV4Hook } from "../contracts/hooks/base/BaseMoonAmmFeeV4Hook.sol";
import { BaseV4Addresses } from "../contracts/hooks/base/BaseV4Addresses.sol";
import { BaseV4HookAddressMiner } from "../contracts/hooks/base/BaseV4HookAddressMiner.sol";

// DEPRECATED / LEGACY BaseMoonAmmFeeV4Hook path.
// Old Base Sepolia-only MOON/USDC pool helper; do not use for rc4 or Base mainnet.
// Current rc4/mainnet path uses BaseSunMoonUsdcFeeV4Hook.
contract PrepareBaseSepoliaControlledMoonPool is Script {
    using PoolIdLibrary for PoolKey;

    bytes32 internal constant LABEL_HOOK_OWNER = "HOOK_OWNER";
    bytes32 internal constant LABEL_HOOK = "HOOK";
    bytes32 internal constant LABEL_MOON_TOKEN = "MOON_TOKEN";
    bytes32 internal constant LABEL_USDC_TOKEN = "USDC_TOKEN";

    struct ControlledPool {
        uint256 chainId;
        bool baseSepoliaConfirmed;
        address hookOwner;
        BaseMoonAmmFeeV4Hook hook;
        address moonToken;
        address usdcToken;
        uint24 fee;
        int24 tickSpacing;
        PoolKey poolKey;
        bytes32 poolId;
        bool alreadyAllowed;
        uint256 transactionsPlanned;
    }

    struct ControlledPoolConfig {
        bool baseSepoliaConfirmed;
        address hookOwner;
        address hook;
        address moonToken;
        address usdcToken;
        uint24 fee;
        int24 tickSpacing;
    }

    error BaseMainnetNotAllowed(uint256 chainId);
    error BaseSepoliaRunNotConfirmed(uint256 chainId);
    error DependencyCodeMissing(bytes32 label, address target);
    error InvalidAddress(bytes32 label);
    error InvalidPoolConfig(uint24 fee, int24 tickSpacing);
    error UnexpectedHookMask(uint160 expectedMask, uint160 actualMask);
    error UnexpectedOwner(bytes32 label, address expected, address actual);
    error UnexpectedParameter(bytes32 label, address expected, address actual);

    function run() external returns (ControlledPool memory pool) {
        console2.log("DEPRECATED LEGACY SCRIPT: old BaseMoonAmmFeeV4Hook path; not for rc4/mainnet");

        pool = _loadPool();
        pool = _prepare(pool);
    }

    function prepare(ControlledPoolConfig memory config)
        external
        returns (ControlledPool memory pool)
    {
        pool = _loadPool(config);
        pool = _prepare(pool);
    }

    function _prepare(ControlledPool memory pool) private returns (ControlledPool memory) {
        _validateRun(pool);

        pool.alreadyAllowed = pool.hook.allowedMoonPools(pool.poolId);
        pool.transactionsPlanned = pool.alreadyAllowed ? 0 : 1;

        if (pool.transactionsPlanned != 0) {
            vm.startBroadcast(pool.hookOwner);
            pool.hook.setAllowedMoonPool(pool.poolId, true);
            vm.stopBroadcast();
        }

        _requireAllowed(pool);
        _logPool(pool);
        return pool;
    }

    function _loadPool() private view returns (ControlledPool memory pool) {
        pool.chainId = block.chainid;
        pool.baseSepoliaConfirmed =
            vm.envOr("CONFIRM_BASE_SEPOLIA_CONTROLLED_POOL_RUN", uint256(0)) == 1;
        pool.hookOwner = _requiredEnvAddress("HOOK_OWNER", LABEL_HOOK_OWNER);
        pool.hook = BaseMoonAmmFeeV4Hook(_requiredEnvAddress("HOOK_ADDRESS", LABEL_HOOK));
        pool.moonToken = _envAddressOr("CONTROLLED_POOL_MOON_TOKEN", "MOON_TOKEN", LABEL_MOON_TOKEN);
        pool.usdcToken = _envAddressOrDefault(
            "CONTROLLED_POOL_USDC_TOKEN", BaseV4Addresses.BASE_SEPOLIA_USDC, LABEL_USDC_TOKEN
        );

        pool.fee = uint24(vm.envOr("MOON_USDC_POOL_FEE", uint256(3000)));
        pool.tickSpacing = int24(vm.envOr("MOON_USDC_POOL_TICK_SPACING", int256(60)));
        pool.poolKey = _poolKey(
            pool.moonToken, pool.usdcToken, IHooks(address(pool.hook)), pool.fee, pool.tickSpacing
        );
        pool.poolId = PoolId.unwrap(pool.poolKey.toId());
    }

    function _loadPool(ControlledPoolConfig memory config)
        private
        view
        returns (ControlledPool memory pool)
    {
        pool.chainId = block.chainid;
        pool.baseSepoliaConfirmed = config.baseSepoliaConfirmed;
        pool.hookOwner = _requiredConfigAddress(config.hookOwner, LABEL_HOOK_OWNER);
        pool.hook = BaseMoonAmmFeeV4Hook(_requiredConfigAddress(config.hook, LABEL_HOOK));
        pool.moonToken = _requiredConfigAddress(config.moonToken, LABEL_MOON_TOKEN);
        pool.usdcToken = _requiredConfigAddress(config.usdcToken, LABEL_USDC_TOKEN);
        pool.fee = config.fee;
        pool.tickSpacing = config.tickSpacing;
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
        string memory rawValue = vm.envOr(key, string(""));
        value = _parseRequiredAddress(rawValue, label);
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

    function _requiredConfigAddress(address value, bytes32 label) private pure returns (address) {
        if (value == address(0)) revert InvalidAddress(label);
        return value;
    }

    function _validateRun(ControlledPool memory pool) private view {
        if (pool.chainId == BaseV4Addresses.BASE_MAINNET_CHAIN_ID) {
            revert BaseMainnetNotAllowed(pool.chainId);
        }
        if (pool.chainId == BaseV4Addresses.BASE_SEPOLIA_CHAIN_ID && !pool.baseSepoliaConfirmed) {
            revert BaseSepoliaRunNotConfirmed(pool.chainId);
        }
        if (pool.fee == 0 || pool.tickSpacing <= 0) {
            revert InvalidPoolConfig(pool.fee, pool.tickSpacing);
        }

        _requireCode(LABEL_HOOK, address(pool.hook));
        _requireCode(LABEL_MOON_TOKEN, pool.moonToken);
        _requireCode(LABEL_USDC_TOKEN, pool.usdcToken);
        _requireOwner(LABEL_HOOK, pool.hookOwner, pool.hook.owner());
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

    function _requireOwner(bytes32 label, address expected, address actual) private pure {
        if (actual != expected) revert UnexpectedOwner(label, expected, actual);
    }

    function _requireParameter(bytes32 label, address expected, address actual) private pure {
        if (actual != expected) revert UnexpectedParameter(label, expected, actual);
    }

    function _requireAllowed(ControlledPool memory pool) private view {
        if (!pool.hook.allowedMoonPools(pool.poolId)) {
            revert UnexpectedParameter("POOL_ALLOWED", address(1), address(0));
        }
    }

    function _logPool(ControlledPool memory pool) private view {
        console2.log("Base Sepolia controlled MOON/USDC pool preparation");
        console2.log("simulationOnly:", "do not add --broadcast without explicit approval");
        console2.log("chainId:", pool.chainId);
        console2.log("baseSepoliaConfirmed:", pool.baseSepoliaConfirmed);
        console2.log("HOOK_OWNER / tx sender:", pool.hookOwner);
        console2.log("HOOK_ADDRESS:", address(pool.hook));
        console2.log("MOON_TOKEN:", pool.moonToken);
        console2.log("USDC_TOKEN:", pool.usdcToken);
        console2.log("pool.currency0:", Currency.unwrap(pool.poolKey.currency0));
        console2.log("pool.currency1:", Currency.unwrap(pool.poolKey.currency1));
        console2.log("pool.fee:", pool.fee);
        console2.log("pool.tickSpacing:", pool.tickSpacing);
        console2.logBytes32(pool.poolId);
        console2.log("allowedMoonPoolBefore:", pool.alreadyAllowed);
        console2.log("allowedMoonPoolAfter:", pool.hook.allowedMoonPools(pool.poolId));
        console2.log("transactionsPlanned:", pool.transactionsPlanned);
        console2.log("Next step after real Base Sepolia pool allowlist broadcast:");
        console2.log(
            "create or initialize only the controlled MOON/USDC test pool with this PoolKey"
        );
    }
}
