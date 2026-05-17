// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { Script, console2 } from "forge-std/Script.sol";
import { TestnetUsdcAdapter } from "../contracts/hooks/TestnetUsdcAdapter.sol";
import { BaseMoonAmmFeeV4Hook } from "../contracts/hooks/base/BaseMoonAmmFeeV4Hook.sol";
import { BaseV4Addresses } from "../contracts/hooks/base/BaseV4Addresses.sol";
import { BaseV4HookAddressMiner } from "../contracts/hooks/base/BaseV4HookAddressMiner.sol";
import { SunCurve } from "../contracts/SunCurve.sol";

contract PrepareBaseSepoliaHookBinding is Script {
    bytes32 internal constant LABEL_HOOK_OWNER = "HOOK_OWNER";
    bytes32 internal constant LABEL_HOOK = "HOOK";
    bytes32 internal constant LABEL_SWAP_ADAPTER = "SWAP_ADAPTER";
    bytes32 internal constant LABEL_SUN_CURVE = "SUN_CURVE";

    struct Binding {
        uint256 chainId;
        bool baseSepoliaConfirmed;
        address hookOwner;
        BaseMoonAmmFeeV4Hook hook;
        TestnetUsdcAdapter adapter;
        SunCurve sunCurve;
        address adapterAuthorizedHookBefore;
        address sunCurveMoonAMMBefore;
        bool adapterAlreadyBound;
        bool sunCurveAlreadyBound;
        uint256 transactionsPlanned;
    }

    error BaseMainnetNotAllowed(uint256 chainId);
    error BaseSepoliaRunNotConfirmed(uint256 chainId);
    error DependencyCodeMissing(bytes32 label, address target);
    error InvalidAddress(bytes32 label);
    error UnexpectedHookMask(uint160 expectedMask, uint160 actualMask);
    error UnexpectedOwner(bytes32 label, address expected, address actual);
    error UnexpectedParameter(bytes32 label, address expected, address actual);

    function run() external returns (Binding memory binding) {
        binding = _loadBinding();
        _validateRun(binding);

        binding.adapterAuthorizedHookBefore = binding.adapter.authorizedHook();
        binding.sunCurveMoonAMMBefore = binding.sunCurve.moonAMM();
        binding.adapterAlreadyBound = binding.adapterAuthorizedHookBefore == address(binding.hook);
        binding.sunCurveAlreadyBound = binding.sunCurveMoonAMMBefore == address(binding.hook);

        if (!binding.adapterAlreadyBound) binding.transactionsPlanned++;
        if (!binding.sunCurveAlreadyBound) binding.transactionsPlanned++;

        if (binding.transactionsPlanned != 0) {
            vm.startBroadcast(binding.hookOwner);
            if (!binding.adapterAlreadyBound) {
                binding.adapter.setAuthorizedHook(address(binding.hook));
            }
            if (!binding.sunCurveAlreadyBound) {
                binding.sunCurve.setMoonAMM(address(binding.hook));
            }
            vm.stopBroadcast();
        }

        _validateBinding(binding);
        _logBinding(binding);
    }

    function _loadBinding() private view returns (Binding memory binding) {
        binding.chainId = block.chainid;
        binding.baseSepoliaConfirmed =
            vm.envOr("CONFIRM_BASE_SEPOLIA_HOOK_BINDING_RUN", uint256(0)) == 1;
        binding.hookOwner = _requiredEnvAddress("HOOK_OWNER", LABEL_HOOK_OWNER);
        binding.hook = BaseMoonAmmFeeV4Hook(_requiredEnvAddress("HOOK_ADDRESS", LABEL_HOOK));
        binding.adapter =
            TestnetUsdcAdapter(_requiredEnvAddress("SWAP_ADAPTER", LABEL_SWAP_ADAPTER));
        binding.sunCurve = SunCurve(_requiredEnvAddress("SUN_CURVE", LABEL_SUN_CURVE));
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

    function _validateRun(Binding memory binding) private view {
        if (binding.chainId == BaseV4Addresses.BASE_MAINNET_CHAIN_ID) {
            revert BaseMainnetNotAllowed(binding.chainId);
        }
        if (
            binding.chainId == BaseV4Addresses.BASE_SEPOLIA_CHAIN_ID
                && !binding.baseSepoliaConfirmed
        ) {
            revert BaseSepoliaRunNotConfirmed(binding.chainId);
        }

        _requireCode(LABEL_HOOK, address(binding.hook));
        _requireCode(LABEL_SWAP_ADAPTER, address(binding.adapter));
        _requireCode(LABEL_SUN_CURVE, address(binding.sunCurve));

        _requireOwner(LABEL_HOOK, binding.hookOwner, binding.hook.owner());
        _requireOwner(LABEL_SWAP_ADAPTER, binding.hookOwner, binding.adapter.owner());
        _requireOwner(LABEL_SUN_CURVE, binding.hookOwner, binding.sunCurve.owner());
        _requireParameter(
            LABEL_SWAP_ADAPTER, address(binding.adapter), address(binding.hook.swapAdapter())
        );
        _requireParameter(
            LABEL_SUN_CURVE, address(binding.sunCurve), address(binding.hook.sunCurve())
        );

        uint160 expectedMask = BaseV4HookAddressMiner.BASE_MOON_AMM_FEE_V4_HOOK_MASK;
        uint160 actualMask =
            uint160(address(binding.hook)) & BaseV4HookAddressMiner.V4_ALL_HOOK_MASK;
        if (actualMask != expectedMask) revert UnexpectedHookMask(expectedMask, actualMask);
        if (binding.hook.expectedHookMask() != expectedMask) {
            revert UnexpectedHookMask(expectedMask, binding.hook.expectedHookMask());
        }
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

    function _validateBinding(Binding memory binding) private view {
        _requireParameter(LABEL_HOOK, address(binding.hook), binding.adapter.authorizedHook());
        _requireParameter(LABEL_HOOK, address(binding.hook), binding.sunCurve.moonAMM());
    }

    function _logBinding(Binding memory binding) private view {
        console2.log("Base Sepolia Hook binding preparation");
        console2.log("simulationOnly:", "do not add --broadcast without explicit approval");
        console2.log("chainId:", binding.chainId);
        console2.log("baseSepoliaConfirmed:", binding.baseSepoliaConfirmed);
        console2.log("HOOK_OWNER / tx sender:", binding.hookOwner);
        console2.log("HOOK_ADDRESS:", address(binding.hook));
        console2.log("SWAP_ADAPTER:", address(binding.adapter));
        console2.log("SUN_CURVE:", address(binding.sunCurve));
        console2.log("adapterAuthorizedHookBefore:", binding.adapterAuthorizedHookBefore);
        console2.log("sunCurveMoonAMMBefore:", binding.sunCurveMoonAMMBefore);
        console2.log("adapterAuthorizedHookAfter:", binding.adapter.authorizedHook());
        console2.log("sunCurveMoonAMMAfter:", binding.sunCurve.moonAMM());
        console2.log("transactionsPlanned:", binding.transactionsPlanned);
        console2.log("Next step after real Base Sepolia binding broadcast:");
        console2.log("verify adapter authorizedHook and SunCurve moonAMM are HOOK_ADDRESS");
    }
}
