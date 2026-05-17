// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import { Script, console2 } from "forge-std/Script.sol";
import { DirectUsdcOnlyAdapter } from "../contracts/hooks/DirectUsdcOnlyAdapter.sol";
import { BaseV4Addresses } from "../contracts/hooks/base/BaseV4Addresses.sol";

contract PrepareBaseMainnetDirectUsdcOnlyAdapter is Script {
    bytes32 internal constant LABEL_USDC = "USDC_TOKEN";
    bytes32 internal constant LABEL_OWNER = "MAINNET_ADMIN_WALLET";
    bytes32 internal constant LABEL_TEMP_AUTHORIZED_HOOK = "TEMP_AUTHORIZED_HOOK";
    bytes32 internal constant LABEL_POOL_MANAGER = "POOL_MANAGER";
    bytes32 internal constant LABEL_POSITION_MANAGER = "POSITION_MANAGER";
    bytes32 internal constant LABEL_STATE_VIEW = "STATE_VIEW";
    bytes32 internal constant LABEL_UNIVERSAL_ROUTER = "UNIVERSAL_ROUTER";

    struct AdapterPlan {
        uint256 chainId;
        bool baseMainnetConfirmed;
        bool broadcastRequested;
        address deployer;
        address owner;
        address temporaryAuthorizedHook;
        address usdc;
        uint8 usdcDecimals;
        DirectUsdcOnlyAdapter adapter;
    }

    struct AdapterConfig {
        address deployer;
        address owner;
        address temporaryAuthorizedHook;
        address usdc;
        bool baseMainnetConfirmed;
        bool broadcastRequested;
    }

    error BaseMainnetDryRunNotConfirmed(uint256 chainId);
    error BaseMainnetUnexpectedUsdc(address expected, address actual);
    error BroadcastNotAllowed();
    error DependencyCodeMissing(bytes32 label, address target);
    error InvalidAddress(bytes32 label);
    error UnsupportedChain(uint256 chainId);
    error UsdcDecimalsMismatch(uint8 expected, uint8 actual);

    function run() external returns (AdapterPlan memory plan) {
        plan.chainId = block.chainid;
        plan.baseMainnetConfirmed =
            vm.envOr("CONFIRM_BASE_MAINNET_DIRECT_ADAPTER_DRY_RUN", uint256(0)) == 1;
        plan.broadcastRequested =
            vm.envOr("EXECUTE_BASE_MAINNET_DIRECT_ADAPTER_BROADCAST", uint256(0)) == 1;
        plan.deployer = vm.envOr("DEPLOYER_ADDRESS", msg.sender);
        plan.owner = _requiredEnvAddress("MAINNET_ADMIN_WALLET", LABEL_OWNER);
        plan.temporaryAuthorizedHook = vm.envOr("TEMP_AUTHORIZED_HOOK", plan.owner);
        plan.usdc = vm.envOr("USDC_TOKEN", BaseV4Addresses.BASE_MAINNET_USDC);

        plan = _simulateDeploy(plan);
    }

    function deploy(AdapterConfig memory config) external returns (AdapterPlan memory plan) {
        plan.chainId = block.chainid;
        plan.baseMainnetConfirmed = config.baseMainnetConfirmed;
        plan.broadcastRequested = config.broadcastRequested;
        plan.deployer = config.deployer == address(0) ? msg.sender : config.deployer;
        plan.owner = config.owner;
        plan.temporaryAuthorizedHook = config.temporaryAuthorizedHook;
        plan.usdc = config.usdc;

        plan = _simulateDeploy(plan);
    }

    function _simulateDeploy(AdapterPlan memory plan) private returns (AdapterPlan memory) {
        _validatePlan(plan);

        plan.usdcDecimals = IERC20Metadata(plan.usdc).decimals();
        if (plan.usdcDecimals != 6) {
            revert UsdcDecimalsMismatch(6, plan.usdcDecimals);
        }

        bytes32 dryRunSalt = keccak256(
            abi.encode(
                "SUN_MOON_DIRECT_USDC_ONLY_ADAPTER_DRY_RUN",
                plan.chainId,
                plan.owner,
                plan.temporaryAuthorizedHook,
                plan.usdc
            )
        );
        plan.adapter = new DirectUsdcOnlyAdapter{ salt: dryRunSalt }(
            IERC20(plan.usdc), plan.temporaryAuthorizedHook, plan.owner
        );

        _validateAdapter(plan);
        _logPlan(plan);
        return plan;
    }

    function _validatePlan(AdapterPlan memory plan) private view {
        if (plan.broadcastRequested) revert BroadcastNotAllowed();
        if (plan.owner == address(0)) revert InvalidAddress(LABEL_OWNER);
        if (plan.temporaryAuthorizedHook == address(0)) {
            revert InvalidAddress(LABEL_TEMP_AUTHORIZED_HOOK);
        }
        if (plan.usdc == address(0)) revert InvalidAddress(LABEL_USDC);

        if (plan.chainId == BaseV4Addresses.BASE_MAINNET_CHAIN_ID) {
            if (!plan.baseMainnetConfirmed) {
                revert BaseMainnetDryRunNotConfirmed(plan.chainId);
            }
            if (plan.usdc != BaseV4Addresses.BASE_MAINNET_USDC) {
                revert BaseMainnetUnexpectedUsdc(BaseV4Addresses.BASE_MAINNET_USDC, plan.usdc);
            }

            _requireCode(LABEL_POOL_MANAGER, BaseV4Addresses.BASE_MAINNET_POOL_MANAGER);
            _requireCode(LABEL_POSITION_MANAGER, BaseV4Addresses.BASE_MAINNET_POSITION_MANAGER);
            _requireCode(LABEL_STATE_VIEW, BaseV4Addresses.BASE_MAINNET_STATE_VIEW);
            _requireCode(LABEL_UNIVERSAL_ROUTER, BaseV4Addresses.BASE_MAINNET_UNIVERSAL_ROUTER);
        } else if (plan.chainId != 31_337) {
            revert UnsupportedChain(plan.chainId);
        }

        _requireCode(LABEL_USDC, plan.usdc);
    }

    function _validateAdapter(AdapterPlan memory plan) private view {
        require(address(plan.adapter.usdc()) == plan.usdc, "adapter USDC mismatch");
        require(plan.adapter.authorizedHook() == plan.temporaryAuthorizedHook, "temp hook mismatch");
        require(plan.adapter.owner() == plan.owner, "adapter owner mismatch");
        require(!plan.adapter.paused(), "adapter unexpectedly paused");
    }

    function _requiredEnvAddress(string memory key, bytes32 label)
        private
        view
        returns (address value)
    {
        string memory rawValue = vm.envOr(key, string(""));
        if (bytes(rawValue).length == 0) revert InvalidAddress(label);

        value = vm.parseAddress(rawValue);
        if (value == address(0)) revert InvalidAddress(label);
    }

    function _requireCode(bytes32 label, address target) private view {
        if (target.code.length == 0) revert DependencyCodeMissing(label, target);
    }

    function _logPlan(AdapterPlan memory plan) private pure {
        console2.log("Base mainnet Direct-USDC-only adapter preparation");
        console2.log("simulationOnly:", "this script does not startBroadcast");
        console2.log("chainId:", plan.chainId);
        console2.log("baseMainnetConfirmed:", plan.baseMainnetConfirmed);
        console2.log("broadcastRequested:", plan.broadcastRequested);
        console2.log("deployer label:", plan.deployer);
        console2.log("owner / MAINNET_ADMIN_WALLET:", plan.owner);
        console2.log("temporaryAuthorizedHook:", plan.temporaryAuthorizedHook);
        console2.log("USDC:", plan.usdc);
        console2.log("USDC decimals:", plan.usdcDecimals);
        console2.log("DirectUsdcOnlyAdapter simulation:", address(plan.adapter));
        console2.log("Next step:", "review params; do not broadcast mainnet deployment yet");
    }
}
