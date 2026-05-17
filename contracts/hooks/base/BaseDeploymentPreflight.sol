// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { BaseV4Addresses } from "./BaseV4Addresses.sol";
import { BaseV4HookAddressMiner } from "./BaseV4HookAddressMiner.sol";

library BaseDeploymentPreflight {
    bytes32 internal constant LABEL_POOL_MANAGER = "POOL_MANAGER";
    bytes32 internal constant LABEL_POSITION_MANAGER = "POSITION_MANAGER";
    bytes32 internal constant LABEL_UNIVERSAL_ROUTER = "UNIVERSAL_ROUTER";
    bytes32 internal constant LABEL_USDC = "USDC_TOKEN";
    bytes32 internal constant LABEL_MOON_TOKEN = "MOON_TOKEN";
    bytes32 internal constant LABEL_SUN_CURVE = "SUN_CURVE";
    bytes32 internal constant LABEL_PROTOCOL_BUDGET = "PROTOCOL_BUDGET";
    bytes32 internal constant LABEL_SWAP_ADAPTER = "SWAP_ADAPTER";
    bytes32 internal constant LABEL_HOOK_OWNER = "HOOK_OWNER";
    bytes32 internal constant LABEL_PREDICTED_HOOK = "PREDICTED_HOOK";

    struct BaseMoonV2DeploymentParams {
        uint256 chainId;
        address poolManager;
        address positionManager;
        address universalRouter;
        address usdc;
        address moonToken;
        address sunCurve;
        address protocolBudget;
        address swapAdapter;
        address hookOwner;
        address predictedHook;
    }

    error BadHookPermissionBits(address hookAddress, uint160 actualMask, uint160 expectedMask);
    error SameAddress(bytes32 leftLabel, bytes32 rightLabel, address sharedAddress);
    error UnexpectedAddress(bytes32 label, address actual, address expected);
    error UnsupportedChainId(uint256 chainId);
    error ZeroAddress(bytes32 label);

    function expectedMoonV2HookMask() internal pure returns (uint160) {
        return BaseV4HookAddressMiner.BASE_MOON_AMM_FEE_V4_HOOK_MASK;
    }

    function actualHookMask(address hookAddress) internal pure returns (uint160) {
        return uint160(hookAddress) & BaseV4HookAddressMiner.V4_ALL_HOOK_MASK;
    }

    function validateBaseSepoliaMoonV2Params(BaseMoonV2DeploymentParams memory params)
        internal
        pure
    {
        if (params.chainId != BaseV4Addresses.BASE_SEPOLIA_CHAIN_ID) {
            revert UnsupportedChainId(params.chainId);
        }

        _requireExpectedAddress(
            LABEL_POOL_MANAGER, params.poolManager, BaseV4Addresses.BASE_SEPOLIA_POOL_MANAGER
        );
        _requireExpectedAddress(
            LABEL_POSITION_MANAGER,
            params.positionManager,
            BaseV4Addresses.BASE_SEPOLIA_POSITION_MANAGER
        );
        _requireExpectedAddress(
            LABEL_UNIVERSAL_ROUTER,
            params.universalRouter,
            BaseV4Addresses.BASE_SEPOLIA_UNIVERSAL_ROUTER
        );
        _requireExpectedAddress(LABEL_USDC, params.usdc, BaseV4Addresses.BASE_SEPOLIA_USDC);

        _requireNonZero(LABEL_MOON_TOKEN, params.moonToken);
        _requireNonZero(LABEL_SUN_CURVE, params.sunCurve);
        _requireNonZero(LABEL_PROTOCOL_BUDGET, params.protocolBudget);
        _requireNonZero(LABEL_SWAP_ADAPTER, params.swapAdapter);
        _requireNonZero(LABEL_HOOK_OWNER, params.hookOwner);
        _requireNonZero(LABEL_PREDICTED_HOOK, params.predictedHook);

        _requireDistinct(LABEL_MOON_TOKEN, params.moonToken, LABEL_USDC, params.usdc);
        _requireDistinct(LABEL_MOON_TOKEN, params.moonToken, LABEL_SUN_CURVE, params.sunCurve);
        _requireDistinct(LABEL_USDC, params.usdc, LABEL_SUN_CURVE, params.sunCurve);
        _requireDistinct(
            LABEL_PROTOCOL_BUDGET, params.protocolBudget, LABEL_SWAP_ADAPTER, params.swapAdapter
        );

        uint160 expectedMask = expectedMoonV2HookMask();
        uint160 actualMask = actualHookMask(params.predictedHook);
        if (actualMask != expectedMask) {
            revert BadHookPermissionBits(params.predictedHook, actualMask, expectedMask);
        }
    }

    function _requireExpectedAddress(bytes32 label, address actual, address expected) private pure {
        if (actual != expected) revert UnexpectedAddress(label, actual, expected);
    }

    function _requireNonZero(bytes32 label, address value) private pure {
        if (value == address(0)) revert ZeroAddress(label);
    }

    function _requireDistinct(bytes32 leftLabel, address left, bytes32 rightLabel, address right)
        private
        pure
    {
        if (left == right) revert SameAddress(leftLabel, rightLabel, left);
    }
}
