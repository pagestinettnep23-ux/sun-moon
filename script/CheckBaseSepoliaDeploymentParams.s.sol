// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { Script, console2 } from "forge-std/Script.sol";
import { BaseDeploymentPreflight } from "../contracts/hooks/base/BaseDeploymentPreflight.sol";
import { BaseV4Addresses } from "../contracts/hooks/base/BaseV4Addresses.sol";

// DEPRECATED / LEGACY BaseMoonAmmFeeV4Hook path.
// Old Base Sepolia-only parameter checker; do not use for rc4 or Base mainnet.
// Current rc4/mainnet path uses BaseSunMoonUsdcFeeV4Hook.
contract CheckBaseSepoliaDeploymentParams is Script {
    function run() external view {
        console2.log("DEPRECATED LEGACY SCRIPT: old BaseMoonAmmFeeV4Hook path; not for rc4/mainnet");

        BaseDeploymentPreflight.BaseMoonV2DeploymentParams memory params =
            BaseDeploymentPreflight.BaseMoonV2DeploymentParams({
                chainId: vm.envOr("BASE_CHAIN_ID", BaseV4Addresses.BASE_SEPOLIA_CHAIN_ID),
                poolManager: vm.envOr("POOL_MANAGER", BaseV4Addresses.BASE_SEPOLIA_POOL_MANAGER),
                positionManager: vm.envOr(
                    "POSITION_MANAGER", BaseV4Addresses.BASE_SEPOLIA_POSITION_MANAGER
                ),
                universalRouter: vm.envOr(
                    "UNIVERSAL_ROUTER", BaseV4Addresses.BASE_SEPOLIA_UNIVERSAL_ROUTER
                ),
                usdc: vm.envOr("USDC_TOKEN", BaseV4Addresses.BASE_SEPOLIA_USDC),
                moonToken: vm.envOr("MOON_TOKEN", address(0)),
                sunCurve: vm.envOr("SUN_CURVE", address(0)),
                protocolBudget: vm.envOr("PROTOCOL_BUDGET_ADDRESS", address(0)),
                swapAdapter: vm.envOr("SWAP_ADAPTER", address(0)),
                hookOwner: vm.envOr("HOOK_OWNER", address(0)),
                predictedHook: vm.envOr("PREDICTED_HOOK", address(0))
            });

        BaseDeploymentPreflight.validateBaseSepoliaMoonV2Params(params);

        console2.log("Base Sepolia deployment preflight passed");
        console2.log("chainId:", params.chainId);
        console2.log("poolManager:", params.poolManager);
        console2.log("positionManager:", params.positionManager);
        console2.log("universalRouter:", params.universalRouter);
        console2.log("usdc:", params.usdc);
        console2.log("moonToken:", params.moonToken);
        console2.log("sunCurve:", params.sunCurve);
        console2.log("protocolBudget:", params.protocolBudget);
        console2.log("swapAdapter:", params.swapAdapter);
        console2.log("hookOwner:", params.hookOwner);
        console2.log("predictedHook:", params.predictedHook);
        console2.log("expectedHookMask:", BaseDeploymentPreflight.expectedMoonV2HookMask());
        console2.log(
            "actualHookMask:", BaseDeploymentPreflight.actualHookMask(params.predictedHook)
        );
    }
}
