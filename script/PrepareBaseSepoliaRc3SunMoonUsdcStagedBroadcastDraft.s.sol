// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { Script, console2 } from "forge-std/Script.sol";
import { BaseV4Addresses } from "../contracts/hooks/base/BaseV4Addresses.sol";
import {
    PrepareBaseSepoliaRc3SunMoonUsdcBroadcastDraft
} from "./PrepareBaseSepoliaRc3SunMoonUsdcBroadcastDraft.s.sol";
import {
    PrepareBaseSepoliaRc3SunMoonUsdcDryRun
} from "./PrepareBaseSepoliaRc3SunMoonUsdcDryRun.s.sol";

contract PrepareBaseSepoliaRc3SunMoonUsdcStagedBroadcastDraft is Script {
    uint24 internal constant EXPECTED_POOL_FEE = 3000;
    int24 internal constant EXPECTED_TICK_SPACING = 60;
    uint256 internal constant LOCAL_SIMULATION_CHAIN_ID = 31_337;
    uint256 internal constant TOKEN_ONE = 1e18;
    uint256 internal constant DEFAULT_SUN_USDC_PRICE = 1e6;
    uint256 internal constant DEFAULT_MOON_USDC_PRICE = 240_000;

    address internal constant DEFAULT_SEPOLIA_DEPLOYER = 0x2F6E887c6058deE520f9468a1022E3480A6334D3;
    address internal constant DEFAULT_SEPOLIA_ADMIN = 0x6E22b2e6fFAA30Fe75B71d53d1eC469b4e97A986;
    address internal constant DEFAULT_SEPOLIA_PROTOCOL_BUDGET =
        0x277ba3Cf597CdAaF958C301db3cF6a631F793039;

    struct StagedBroadcastConfig {
        PrepareBaseSepoliaRc3SunMoonUsdcBroadcastDraft.Rc3BroadcastDraftConfig draftConfig;
        bool stagedDraftConfirmed;
        uint8 selectedStage;
        bool executeRequested;
        bool privateKeyPresent;
    }

    struct StagedBroadcastPlan {
        uint256 chainId;
        bool stagedDraftConfirmed;
        uint8 selectedStage;
        bool executeRequested;
        bool privateKeyPresent;
        bool broadcastAllowed;
        bool executionBlocked;
        bool simulationOnly;
        address stage1CoreDeployer;
        address stage2HookDeployer;
        address stage2AdminWallet;
        address stage3RenounceOwner;
        uint256 stage1CoreDeploymentTxs;
        uint256 stage2HookAndPoolTxs;
        uint256 stage3RenounceTxs;
        uint256 selectedStageTxs;
        uint256 totalTransactionsPlanned;
        address predictedSunToken;
        address predictedSunCurve;
        address predictedMoonToken;
        address predictedMoonCurve;
        address predictedCreate2HookDeployer;
        bytes32 hookSalt;
        address predictedHook;
        bytes32 sunUsdcPoolId;
        bytes32 moonUsdcPoolId;
        bool predictedSunTokenHasCode;
        bool predictedSunCurveHasCode;
        bool predictedMoonTokenHasCode;
        bool predictedMoonCurveHasCode;
        bool predictedCreate2HookDeployerHasCode;
        bool predictedHookHasCode;
        bool stage1AddressCollision;
        bool stage2HookCollision;
    }

    error BaseMainnetNotAllowed(uint256 chainId);
    error BaseSepoliaStagedBroadcastDraftNotConfirmed(uint256 chainId);
    error BroadcastExecutionNotAllowed();
    error InvalidStage(uint8 selectedStage);
    error PrivateKeyEnvNotAllowed();
    error UnsupportedChain(uint256 chainId);

    function run() external returns (StagedBroadcastPlan memory plan) {
        plan = prepare(_loadConfig());
    }

    function prepare(StagedBroadcastConfig memory config)
        public
        returns (StagedBroadcastPlan memory plan)
    {
        _validateConfig(config);

        PrepareBaseSepoliaRc3SunMoonUsdcBroadcastDraft draftScript =
            new PrepareBaseSepoliaRc3SunMoonUsdcBroadcastDraft();
        PrepareBaseSepoliaRc3SunMoonUsdcBroadcastDraft.Rc3BroadcastDraftPlan memory draftPlan =
            draftScript.prepare(config.draftConfig);

        plan = _buildPlan(config, draftPlan);
        _logPlan(plan);
    }

    function _loadConfig() private view returns (StagedBroadcastConfig memory config) {
        bool localSimulation = block.chainid == LOCAL_SIMULATION_CHAIN_ID;
        bool stagedDraftConfirmed =
            vm.envOr("CONFIRM_BASE_SEPOLIA_RC3_STAGED_BROADCAST_DRAFT", uint256(0)) == 1;

        config = StagedBroadcastConfig({
            draftConfig: PrepareBaseSepoliaRc3SunMoonUsdcBroadcastDraft.Rc3BroadcastDraftConfig({
                dryRunConfig: PrepareBaseSepoliaRc3SunMoonUsdcDryRun.Rc3DryRunConfig({
                    sepoliaDeployer: vm.envOr("SEPOLIA_DEPLOYER", DEFAULT_SEPOLIA_DEPLOYER),
                    sepoliaAdminWallet: vm.envOr("SEPOLIA_ADMIN_WALLET", DEFAULT_SEPOLIA_ADMIN),
                    sepoliaProtocolBudgetWallet: vm.envOr(
                        "SEPOLIA_PROTOCOL_BUDGET_WALLET", DEFAULT_SEPOLIA_PROTOCOL_BUDGET
                    ),
                    sepoliaCreate2DeployerOwner: vm.envOr(
                        "SEPOLIA_CREATE2_DEPLOYER_OWNER", DEFAULT_SEPOLIA_ADMIN
                    ),
                    poolManager: vm.envOr(
                        "POOL_MANAGER",
                        localSimulation ? address(0) : BaseV4Addresses.BASE_SEPOLIA_POOL_MANAGER
                    ),
                    stateView: vm.envOr(
                        "STATE_VIEW",
                        localSimulation ? address(0) : BaseV4Addresses.BASE_SEPOLIA_STATE_VIEW
                    ),
                    usdcToken: vm.envOr(
                        "USDC_TOKEN",
                        localSimulation ? address(0) : BaseV4Addresses.BASE_SEPOLIA_USDC
                    ),
                    moonLaunchDelay: vm.envOr("MOON_LAUNCH_DELAY", uint256(0)),
                    sunUsdcFee: uint24(vm.envOr("SUN_USDC_POOL_FEE", uint256(EXPECTED_POOL_FEE))),
                    sunUsdcTickSpacing: int24(
                        vm.envOr("SUN_USDC_POOL_TICK_SPACING", int256(EXPECTED_TICK_SPACING))
                    ),
                    sunUsdcInitialTokenAmount: vm.envOr("SUN_USDC_INITIAL_TOKEN_AMOUNT", TOKEN_ONE),
                    sunUsdcInitialUsdcAmount: vm.envOr(
                        "SUN_USDC_INITIAL_USDC_AMOUNT", DEFAULT_SUN_USDC_PRICE
                    ),
                    expectedSunUsdcPoolId: vm.envOr("SUN_USDC_POOL_ID", bytes32(0)),
                    moonUsdcFee: uint24(vm.envOr("MOON_USDC_POOL_FEE", uint256(EXPECTED_POOL_FEE))),
                    moonUsdcTickSpacing: int24(
                        vm.envOr("MOON_USDC_POOL_TICK_SPACING", int256(EXPECTED_TICK_SPACING))
                    ),
                    moonUsdcInitialTokenAmount: vm.envOr(
                        "MOON_USDC_INITIAL_TOKEN_AMOUNT", TOKEN_ONE
                    ),
                    moonUsdcInitialUsdcAmount: vm.envOr(
                        "MOON_USDC_INITIAL_USDC_AMOUNT", DEFAULT_MOON_USDC_PRICE
                    ),
                    expectedMoonUsdcPoolId: vm.envOr("MOON_USDC_POOL_ID", bytes32(0)),
                    hookSaltStart: vm.envOr("HOOK_SALT_START", uint256(0)),
                    hookMaxSaltSearch: vm.envOr("HOOK_MAX_SALT_SEARCH", uint256(300_000)),
                    baseSepoliaConfirmed: stagedDraftConfirmed,
                    broadcastRequested: false
                }),
                baseSepoliaDraftConfirmed: stagedDraftConfirmed,
                executeRequested: false,
                privateKeyPresent: false
            }),
            stagedDraftConfirmed: stagedDraftConfirmed,
            selectedStage: uint8(vm.envOr("BASE_SEPOLIA_RC3_BROADCAST_STAGE", uint256(0))),
            executeRequested: vm.envOr("EXECUTE_BASE_SEPOLIA_RC3_STAGE", uint256(0)) == 1,
            privateKeyPresent: bytes(vm.envOr("PRIVATE_KEY", string(""))).length != 0
        });
    }

    function _validateConfig(StagedBroadcastConfig memory config) private view {
        if (config.selectedStage > 3) revert InvalidStage(config.selectedStage);
        if (config.executeRequested) revert BroadcastExecutionNotAllowed();
        if (config.privateKeyPresent) revert PrivateKeyEnvNotAllowed();
        if (block.chainid == BaseV4Addresses.BASE_MAINNET_CHAIN_ID) {
            revert BaseMainnetNotAllowed(block.chainid);
        }
        if (block.chainid == BaseV4Addresses.BASE_SEPOLIA_CHAIN_ID && !config.stagedDraftConfirmed)
        {
            revert BaseSepoliaStagedBroadcastDraftNotConfirmed(block.chainid);
        }
        if (
            block.chainid != LOCAL_SIMULATION_CHAIN_ID
                && block.chainid != BaseV4Addresses.BASE_SEPOLIA_CHAIN_ID
        ) {
            revert UnsupportedChain(block.chainid);
        }
    }

    function _buildPlan(
        StagedBroadcastConfig memory config,
        PrepareBaseSepoliaRc3SunMoonUsdcBroadcastDraft.Rc3BroadcastDraftPlan memory draftPlan
    ) private view returns (StagedBroadcastPlan memory plan) {
        plan.chainId = draftPlan.chainId;
        plan.stagedDraftConfirmed = config.stagedDraftConfirmed;
        plan.selectedStage = config.selectedStage;
        plan.executeRequested = config.executeRequested;
        plan.privateKeyPresent = config.privateKeyPresent;
        plan.broadcastAllowed = false;
        plan.executionBlocked = true;
        plan.simulationOnly = true;
        plan.stage1CoreDeployer = draftPlan.stage1CoreDeployer;
        plan.stage2HookDeployer = draftPlan.stage2HookDeployer;
        plan.stage2AdminWallet = draftPlan.stage2AdminWallet;
        plan.stage3RenounceOwner = draftPlan.stage3RenounceOwner;
        plan.stage1CoreDeploymentTxs = draftPlan.stage1CoreDeploymentTxs;
        plan.stage2HookAndPoolTxs = draftPlan.stage2HookAndPoolTxs;
        plan.stage3RenounceTxs = draftPlan.stage3RenounceTxs;
        plan.totalTransactionsPlanned = draftPlan.totalTransactionsPlanned;
        plan.selectedStageTxs = _selectedStageTxs(config.selectedStage, draftPlan);
        plan.predictedSunToken = draftPlan.predictedSunToken;
        plan.predictedSunCurve = draftPlan.predictedSunCurve;
        plan.predictedMoonToken = draftPlan.predictedMoonToken;
        plan.predictedMoonCurve = draftPlan.predictedMoonCurve;
        plan.predictedCreate2HookDeployer = draftPlan.predictedCreate2HookDeployer;
        plan.hookSalt = draftPlan.hookSalt;
        plan.predictedHook = draftPlan.predictedHook;
        plan.sunUsdcPoolId = draftPlan.sunUsdcPoolId;
        plan.moonUsdcPoolId = draftPlan.moonUsdcPoolId;
        plan.predictedSunTokenHasCode = draftPlan.predictedSunToken.code.length != 0;
        plan.predictedSunCurveHasCode = draftPlan.predictedSunCurve.code.length != 0;
        plan.predictedMoonTokenHasCode = draftPlan.predictedMoonToken.code.length != 0;
        plan.predictedMoonCurveHasCode = draftPlan.predictedMoonCurve.code.length != 0;
        plan.predictedCreate2HookDeployerHasCode =
            draftPlan.predictedCreate2HookDeployer.code.length != 0;
        plan.predictedHookHasCode = false;
        plan.stage1AddressCollision = plan.predictedSunTokenHasCode || plan.predictedSunCurveHasCode
            || plan.predictedMoonTokenHasCode || plan.predictedMoonCurveHasCode
            || plan.predictedCreate2HookDeployerHasCode;
        plan.stage2HookCollision = false;
    }

    function _selectedStageTxs(
        uint8 selectedStage,
        PrepareBaseSepoliaRc3SunMoonUsdcBroadcastDraft.Rc3BroadcastDraftPlan memory draftPlan
    ) private pure returns (uint256 txs) {
        if (selectedStage == 0) return draftPlan.totalTransactionsPlanned;
        if (selectedStage == 1) return draftPlan.stage1CoreDeploymentTxs;
        if (selectedStage == 2) return draftPlan.stage2HookAndPoolTxs;
        return draftPlan.stage3RenounceTxs;
    }

    function _logPlan(StagedBroadcastPlan memory plan) private pure {
        console2.log("Base Sepolia rc3 staged broadcast draft");
        console2.log("broadcastAllowed:", plan.broadcastAllowed);
        console2.log("executionBlocked:", plan.executionBlocked);
        console2.log("simulationOnly:", plan.simulationOnly);
        console2.log("chainId:", plan.chainId);
        console2.log("stagedDraftConfirmed:", plan.stagedDraftConfirmed);
        console2.log("selectedStage:", plan.selectedStage);
        console2.log("selectedStageTxs:", plan.selectedStageTxs);
        console2.log("executeRequested:", plan.executeRequested);
        console2.log("privateKeyPresent:", plan.privateKeyPresent);
        console2.log("stage1CoreDeployer:", plan.stage1CoreDeployer);
        console2.log("stage2HookDeployer:", plan.stage2HookDeployer);
        console2.log("stage2AdminWallet:", plan.stage2AdminWallet);
        console2.log("stage3RenounceOwner:", plan.stage3RenounceOwner);
        console2.log("stage1CoreDeploymentTxs:", plan.stage1CoreDeploymentTxs);
        console2.log("stage2HookAndPoolTxs:", plan.stage2HookAndPoolTxs);
        console2.log("stage3RenounceTxs:", plan.stage3RenounceTxs);
        console2.log("totalTransactionsPlanned:", plan.totalTransactionsPlanned);
        console2.log("PREDICTED_SUN_TOKEN:", plan.predictedSunToken);
        console2.log("PREDICTED_SUN_CURVE:", plan.predictedSunCurve);
        console2.log("PREDICTED_MOON_TOKEN:", plan.predictedMoonToken);
        console2.log("PREDICTED_MOON_CURVE:", plan.predictedMoonCurve);
        console2.log("PREDICTED_CREATE2_HOOK_DEPLOYER:", plan.predictedCreate2HookDeployer);
        console2.log("HOOK_SALT:");
        console2.logBytes32(plan.hookSalt);
        console2.log("PREDICTED_HOOK:", plan.predictedHook);
        console2.log("SUN/USDC poolId:");
        console2.logBytes32(plan.sunUsdcPoolId);
        console2.log("MOON/USDC poolId:");
        console2.logBytes32(plan.moonUsdcPoolId);
        console2.log("stage1AddressCollision:", plan.stage1AddressCollision);
        console2.log("stage2HookCollision:", plan.stage2HookCollision);
        console2.log("Next step:", "manual review only; execution remains blocked");
    }
}
