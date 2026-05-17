// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Script, console2 } from "forge-std/Script.sol";
import { IPoolManager } from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import { IMoonAmmSwapAdapter } from "../contracts/hooks/MoonAmmFeeHook.sol";
import { BaseDeploymentPreflight } from "../contracts/hooks/base/BaseDeploymentPreflight.sol";
import { BaseMoonAmmFeeV4Hook } from "../contracts/hooks/base/BaseMoonAmmFeeV4Hook.sol";
import { BaseV4Addresses } from "../contracts/hooks/base/BaseV4Addresses.sol";
import { BaseV4HookAddressMiner } from "../contracts/hooks/base/BaseV4HookAddressMiner.sol";
import { Create2HookDeployer } from "../contracts/hooks/base/Create2HookDeployer.sol";
import { SunCurve } from "../contracts/SunCurve.sol";

contract PrepareBaseSepoliaHookDeploy is Script {
    bytes32 internal constant LABEL_CREATE2_DEPLOYER = "CREATE2_DEPLOYER";
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

    struct Deployment {
        uint256 chainId;
        bool baseSepoliaConfirmed;
        Create2HookDeployer create2Deployer;
        address hookOwner;
        address poolManager;
        address positionManager;
        address universalRouter;
        address usdc;
        address moonToken;
        address sunCurve;
        address protocolBudget;
        address swapAdapter;
        bytes32 hookSalt;
        bytes32 initCodeHash;
        uint160 expectedHookMask;
        uint160 actualHookMask;
        address predictedHook;
        address deployedHook;
    }

    error BaseMainnetNotAllowed(uint256 chainId);
    error BaseSepoliaRunNotConfirmed(uint256 chainId);
    error Create2DeployerOwnerMismatch(address expectedOwner, address actualOwner);
    error DependencyCodeMissing(bytes32 label, address target);
    error DeployedHookMismatch(address expected, address actual);
    error HookCodeMissing(address hook);
    error InvalidAddress(bytes32 label);
    error InvalidHookSalt();
    error PredictedHookAlreadyDeployed(address predictedHook);
    error UnexpectedHookMask(uint160 expectedMask, uint160 actualMask);
    error UnexpectedHookParameter(bytes32 label, address expected, address actual);
    error UnexpectedPredictedHook(address expected, address actual);

    function run() external returns (Deployment memory deployment) {
        deployment = _loadDeployment();
        _validateRun(deployment);

        bytes memory initCode = _baseMoonHookInitCode(deployment);
        deployment.initCodeHash = keccak256(initCode);
        deployment.expectedHookMask = BaseV4HookAddressMiner.BASE_MOON_AMM_FEE_V4_HOOK_MASK;
        deployment.actualHookMask =
            uint160(deployment.predictedHook) & BaseV4HookAddressMiner.V4_ALL_HOOK_MASK;

        _validateCreate2Precheck(deployment);

        vm.startBroadcast(deployment.hookOwner);
        deployment.deployedHook = deployment.create2Deployer
            .deployHook(deployment.hookSalt, initCode, deployment.expectedHookMask);
        vm.stopBroadcast();

        _validateHookDeployment(deployment);
        _logDeployment(deployment);
    }

    function _loadDeployment() private view returns (Deployment memory deployment) {
        deployment.chainId = block.chainid;
        deployment.baseSepoliaConfirmed =
            vm.envOr("CONFIRM_BASE_SEPOLIA_HOOK_DEPLOY_RUN", uint256(0)) == 1;
        deployment.create2Deployer =
            Create2HookDeployer(_requiredEnvAddress("CREATE2_DEPLOYER", LABEL_CREATE2_DEPLOYER));
        deployment.hookOwner = _requiredEnvAddress("HOOK_OWNER", LABEL_HOOK_OWNER);
        deployment.poolManager = vm.envOr("POOL_MANAGER", BaseV4Addresses.BASE_SEPOLIA_POOL_MANAGER);
        deployment.positionManager =
            vm.envOr("POSITION_MANAGER", BaseV4Addresses.BASE_SEPOLIA_POSITION_MANAGER);
        deployment.universalRouter =
            vm.envOr("UNIVERSAL_ROUTER", BaseV4Addresses.BASE_SEPOLIA_UNIVERSAL_ROUTER);
        deployment.usdc = vm.envOr("USDC_TOKEN", BaseV4Addresses.BASE_SEPOLIA_USDC);
        deployment.moonToken = _requiredEnvAddress("MOON_TOKEN", LABEL_MOON_TOKEN);
        deployment.sunCurve = _requiredEnvAddress("SUN_CURVE", LABEL_SUN_CURVE);
        deployment.protocolBudget =
            _requiredEnvAddress("PROTOCOL_BUDGET_ADDRESS", LABEL_PROTOCOL_BUDGET);
        deployment.swapAdapter = _requiredEnvAddress("SWAP_ADAPTER", LABEL_SWAP_ADAPTER);
        deployment.hookSalt = vm.envOr("HOOK_SALT", bytes32(0));
        deployment.predictedHook = _requiredEnvAddress("PREDICTED_HOOK", LABEL_PREDICTED_HOOK);
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

    function _validateRun(Deployment memory deployment) private view {
        if (deployment.hookSalt == bytes32(0)) revert InvalidHookSalt();
        if (deployment.chainId == BaseV4Addresses.BASE_MAINNET_CHAIN_ID) {
            revert BaseMainnetNotAllowed(deployment.chainId);
        }
        if (deployment.chainId == BaseV4Addresses.BASE_SEPOLIA_CHAIN_ID) {
            if (!deployment.baseSepoliaConfirmed) {
                revert BaseSepoliaRunNotConfirmed(deployment.chainId);
            }
            BaseDeploymentPreflight.validateBaseSepoliaMoonV2Params(
                BaseDeploymentPreflight.BaseMoonV2DeploymentParams({
                    chainId: deployment.chainId,
                    poolManager: deployment.poolManager,
                    positionManager: deployment.positionManager,
                    universalRouter: deployment.universalRouter,
                    usdc: deployment.usdc,
                    moonToken: deployment.moonToken,
                    sunCurve: deployment.sunCurve,
                    protocolBudget: deployment.protocolBudget,
                    swapAdapter: deployment.swapAdapter,
                    hookOwner: deployment.hookOwner,
                    predictedHook: deployment.predictedHook
                })
            );
        }

        _requireCode(LABEL_CREATE2_DEPLOYER, address(deployment.create2Deployer));
        _requireCode(LABEL_POOL_MANAGER, deployment.poolManager);
        _requireCode(LABEL_USDC, deployment.usdc);
        _requireCode(LABEL_MOON_TOKEN, deployment.moonToken);
        _requireCode(LABEL_SUN_CURVE, deployment.sunCurve);
        _requireCode(LABEL_SWAP_ADAPTER, deployment.swapAdapter);

        if (deployment.chainId == BaseV4Addresses.BASE_SEPOLIA_CHAIN_ID) {
            _requireCode(LABEL_POSITION_MANAGER, deployment.positionManager);
            _requireCode(LABEL_UNIVERSAL_ROUTER, deployment.universalRouter);
        }

        address actualOwner = deployment.create2Deployer.owner();
        if (actualOwner != deployment.hookOwner) {
            revert Create2DeployerOwnerMismatch(deployment.hookOwner, actualOwner);
        }
    }

    function _requireCode(bytes32 label, address target) private view {
        if (target.code.length == 0) revert DependencyCodeMissing(label, target);
    }

    function _validateCreate2Precheck(Deployment memory deployment) private view {
        address computedHook = BaseV4HookAddressMiner.computeCreate2Address(
            address(deployment.create2Deployer), deployment.hookSalt, deployment.initCodeHash
        );
        if (computedHook != deployment.predictedHook) {
            revert UnexpectedPredictedHook(deployment.predictedHook, computedHook);
        }
        if (deployment.actualHookMask != deployment.expectedHookMask) {
            revert UnexpectedHookMask(deployment.expectedHookMask, deployment.actualHookMask);
        }
        if (deployment.predictedHook.code.length != 0) {
            revert PredictedHookAlreadyDeployed(deployment.predictedHook);
        }
    }

    function _baseMoonHookInitCode(Deployment memory deployment)
        private
        pure
        returns (bytes memory)
    {
        return abi.encodePacked(
            type(BaseMoonAmmFeeV4Hook).creationCode,
            abi.encode(
                IPoolManager(deployment.poolManager),
                deployment.moonToken,
                IERC20(deployment.usdc),
                SunCurve(deployment.sunCurve),
                deployment.protocolBudget,
                IMoonAmmSwapAdapter(deployment.swapAdapter),
                deployment.hookOwner
            )
        );
    }

    function _validateHookDeployment(Deployment memory deployment) private view {
        if (deployment.deployedHook != deployment.predictedHook) {
            revert DeployedHookMismatch(deployment.predictedHook, deployment.deployedHook);
        }
        if (deployment.deployedHook.code.length == 0) {
            revert HookCodeMissing(deployment.deployedHook);
        }

        BaseMoonAmmFeeV4Hook hook = BaseMoonAmmFeeV4Hook(deployment.deployedHook);
        _requireHookAddress(LABEL_POOL_MANAGER, deployment.poolManager, address(hook.poolManager()));
        _requireHookAddress(LABEL_MOON_TOKEN, deployment.moonToken, hook.moonToken());
        _requireHookAddress(LABEL_USDC, deployment.usdc, address(hook.usdt()));
        _requireHookAddress(LABEL_SUN_CURVE, deployment.sunCurve, address(hook.sunCurve()));
        _requireHookAddress(LABEL_PROTOCOL_BUDGET, deployment.protocolBudget, hook.protocolBudget());
        _requireHookAddress(LABEL_SWAP_ADAPTER, deployment.swapAdapter, address(hook.swapAdapter()));
        _requireHookAddress(LABEL_HOOK_OWNER, deployment.hookOwner, hook.owner());
        if (hook.expectedHookMask() != deployment.expectedHookMask) {
            revert UnexpectedHookMask(deployment.expectedHookMask, hook.expectedHookMask());
        }
    }

    function _requireHookAddress(bytes32 label, address expected, address actual) private pure {
        if (expected != actual) revert UnexpectedHookParameter(label, expected, actual);
    }

    function _logDeployment(Deployment memory deployment) private view {
        console2.log("Base Sepolia Hook deployment preparation");
        console2.log("simulationOnly:", "do not add --broadcast without explicit approval");
        console2.log("chainId:", deployment.chainId);
        console2.log("baseSepoliaConfirmed:", deployment.baseSepoliaConfirmed);
        console2.log("CREATE2_DEPLOYER:", address(deployment.create2Deployer));
        console2.log("Create2Deployer.owner:", deployment.create2Deployer.owner());
        console2.log("HOOK_OWNER / tx sender:", deployment.hookOwner);
        console2.log("POOL_MANAGER:", deployment.poolManager);
        console2.log("USDC_TOKEN:", deployment.usdc);
        console2.log("MOON_TOKEN:", deployment.moonToken);
        console2.log("SUN_CURVE:", deployment.sunCurve);
        console2.log("PROTOCOL_BUDGET_ADDRESS:", deployment.protocolBudget);
        console2.log("SWAP_ADAPTER:", deployment.swapAdapter);
        console2.log("HOOK_SALT:");
        console2.logBytes32(deployment.hookSalt);
        console2.log("initCodeHash:");
        console2.logBytes32(deployment.initCodeHash);
        console2.log("PREDICTED_HOOK:", deployment.predictedHook);
        console2.log("DEPLOYED_HOOK:", deployment.deployedHook);
        console2.log("expectedHookMask:", deployment.expectedHookMask);
        console2.log("actualLow14Bits:", deployment.actualHookMask);
        console2.log("Next step after real Base Sepolia Hook broadcast:");
        console2.log("set adapter authorizedHook and SunCurve moonAMM to DEPLOYED_HOOK");
    }
}
