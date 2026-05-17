// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { Script, console2 } from "forge-std/Script.sol";
import { BaseV4Addresses } from "../contracts/hooks/base/BaseV4Addresses.sol";
import {
    PrepareBaseSepoliaRc3SunMoonUsdcDryRun
} from "./PrepareBaseSepoliaRc3SunMoonUsdcDryRun.s.sol";

contract PrepareBaseSepoliaRc3SunMoonUsdcBroadcastDraft is Script {
    uint24 internal constant EXPECTED_POOL_FEE = 3000;
    int24 internal constant EXPECTED_TICK_SPACING = 60;
    uint256 internal constant LOCAL_SIMULATION_CHAIN_ID = 31_337;
    uint256 internal constant USDC_ONE = 1e6;
    uint256 internal constant TOKEN_ONE = 1e18;
    uint256 internal constant DEFAULT_SUN_USDC_PRICE = 1e6;
    uint256 internal constant DEFAULT_MOON_USDC_PRICE = 240_000;

    uint256 internal constant CORE_DEPLOY_TXS = 5;
    uint256 internal constant CORE_CONFIG_TXS = 3;
    uint256 internal constant CORE_OWNERSHIP_TRANSFER_TXS = 4;
    uint256 internal constant HOOK_DEPLOY_TXS = 1;
    uint256 internal constant HOOK_BIND_TXS = 1;
    uint256 internal constant HOOK_ALLOWLIST_TXS = 2;
    uint256 internal constant POOL_INITIALIZE_TXS = 2;
    uint256 internal constant HOOK_RENOUNCE_TXS = 1;

    address internal constant DEFAULT_SEPOLIA_DEPLOYER = 0x2F6E887c6058deE520f9468a1022E3480A6334D3;
    address internal constant DEFAULT_SEPOLIA_ADMIN = 0x6E22b2e6fFAA30Fe75B71d53d1eC469b4e97A986;
    address internal constant DEFAULT_SEPOLIA_PROTOCOL_BUDGET =
        0x277ba3Cf597CdAaF958C301db3cF6a631F793039;

    struct Rc3BroadcastDraftConfig {
        PrepareBaseSepoliaRc3SunMoonUsdcDryRun.Rc3DryRunConfig dryRunConfig;
        bool baseSepoliaDraftConfirmed;
        bool executeRequested;
        bool privateKeyPresent;
    }

    struct Rc3BroadcastDraftPlan {
        uint256 chainId;
        bool baseSepoliaDraftConfirmed;
        bool executeRequested;
        bool privateKeyPresent;
        bool broadcastAllowed;
        bool simulationOnly;
        address stage1CoreDeployer;
        address stage2HookDeployer;
        address stage2AdminWallet;
        address stage3RenounceOwner;
        bool requiresSeparateCoreAndAdminRuns;
        bool requiresSeparateHookOwnerAndAdminRuns;
        uint256 stage1CoreDeploymentTxs;
        uint256 stage2HookAndPoolTxs;
        uint256 stage3RenounceTxs;
        uint256 totalTransactionsPlanned;
        address predictedSunToken;
        address predictedSunCurve;
        address predictedMoonToken;
        address predictedMoonCurve;
        address predictedCreate2HookDeployer;
        bytes32 hookSalt;
        address predictedHook;
        bytes32 sunUsdcPoolId;
        int24 sunUsdcInitialTick;
        uint160 sunUsdcSqrtPriceX96;
        bytes32 moonUsdcPoolId;
        int24 moonUsdcInitialTick;
        uint160 moonUsdcSqrtPriceX96;
        bool sunUsdcAllowedAfterDryRun;
        bool moonUsdcAllowedAfterDryRun;
        bool renounceBlocksSunAllowlist;
        bool renounceBlocksMoonAllowlist;
        bool renounceBlocksProtocolBudget;
    }

    error BaseMainnetNotAllowed(uint256 chainId);
    error BaseSepoliaRc3BroadcastDraftNotConfirmed(uint256 chainId);
    error BroadcastExecutionNotAllowed();
    error PrivateKeyEnvNotAllowed();
    error UnsupportedChain(uint256 chainId);

    function run() external returns (Rc3BroadcastDraftPlan memory plan) {
        plan = prepare(_loadConfig());
    }

    function prepare(Rc3BroadcastDraftConfig memory config)
        public
        returns (Rc3BroadcastDraftPlan memory plan)
    {
        _validateDraft(config);

        PrepareBaseSepoliaRc3SunMoonUsdcDryRun dryRunScript =
            new PrepareBaseSepoliaRc3SunMoonUsdcDryRun();
        PrepareBaseSepoliaRc3SunMoonUsdcDryRun.Rc3DryRunPlan memory dryRunPlan =
            dryRunScript.prepare(config.dryRunConfig);

        plan = _buildPlan(config, dryRunPlan);
        _logPlan(plan);
    }

    function _loadConfig() private view returns (Rc3BroadcastDraftConfig memory config) {
        bool localSimulation = block.chainid == LOCAL_SIMULATION_CHAIN_ID;
        bool draftConfirmed = vm.envOr("CONFIRM_BASE_SEPOLIA_RC3_BROADCAST_DRAFT", uint256(0)) == 1;

        config = Rc3BroadcastDraftConfig({
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
                    "USDC_TOKEN", localSimulation ? address(0) : BaseV4Addresses.BASE_SEPOLIA_USDC
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
                moonUsdcInitialTokenAmount: vm.envOr("MOON_USDC_INITIAL_TOKEN_AMOUNT", TOKEN_ONE),
                moonUsdcInitialUsdcAmount: vm.envOr(
                    "MOON_USDC_INITIAL_USDC_AMOUNT", DEFAULT_MOON_USDC_PRICE
                ),
                expectedMoonUsdcPoolId: vm.envOr("MOON_USDC_POOL_ID", bytes32(0)),
                hookSaltStart: vm.envOr("HOOK_SALT_START", uint256(0)),
                hookMaxSaltSearch: vm.envOr("HOOK_MAX_SALT_SEARCH", uint256(300_000)),
                baseSepoliaConfirmed: draftConfirmed,
                broadcastRequested: false
            }),
            baseSepoliaDraftConfirmed: draftConfirmed,
            executeRequested: vm.envOr("EXECUTE_BASE_SEPOLIA_RC3_BROADCAST", uint256(0)) == 1,
            privateKeyPresent: bytes(vm.envOr("PRIVATE_KEY", string(""))).length != 0
        });
    }

    function _validateDraft(Rc3BroadcastDraftConfig memory config) private view {
        if (config.executeRequested) revert BroadcastExecutionNotAllowed();
        if (config.privateKeyPresent) revert PrivateKeyEnvNotAllowed();
        if (block.chainid == BaseV4Addresses.BASE_MAINNET_CHAIN_ID) {
            revert BaseMainnetNotAllowed(block.chainid);
        }
        if (
            block.chainid == BaseV4Addresses.BASE_SEPOLIA_CHAIN_ID
                && !config.baseSepoliaDraftConfirmed
        ) {
            revert BaseSepoliaRc3BroadcastDraftNotConfirmed(block.chainid);
        }
        if (
            block.chainid != LOCAL_SIMULATION_CHAIN_ID
                && block.chainid != BaseV4Addresses.BASE_SEPOLIA_CHAIN_ID
        ) {
            revert UnsupportedChain(block.chainid);
        }
    }

    function _buildPlan(
        Rc3BroadcastDraftConfig memory config,
        PrepareBaseSepoliaRc3SunMoonUsdcDryRun.Rc3DryRunPlan memory dryRunPlan
    ) private pure returns (Rc3BroadcastDraftPlan memory plan) {
        uint256 ownershipTransferTxs = dryRunPlan.sepoliaDeployer == dryRunPlan.sepoliaAdminWallet
            ? 0
            : CORE_OWNERSHIP_TRANSFER_TXS;

        plan.chainId = dryRunPlan.chainId;
        plan.baseSepoliaDraftConfirmed = config.baseSepoliaDraftConfirmed;
        plan.executeRequested = config.executeRequested;
        plan.privateKeyPresent = config.privateKeyPresent;
        plan.broadcastAllowed = false;
        plan.simulationOnly = true;
        plan.stage1CoreDeployer = dryRunPlan.sepoliaDeployer;
        plan.stage2HookDeployer = dryRunPlan.sepoliaCreate2DeployerOwner;
        plan.stage2AdminWallet = dryRunPlan.sepoliaAdminWallet;
        plan.stage3RenounceOwner = dryRunPlan.sepoliaAdminWallet;
        plan.requiresSeparateCoreAndAdminRuns =
            dryRunPlan.sepoliaDeployer != dryRunPlan.sepoliaAdminWallet;
        plan.requiresSeparateHookOwnerAndAdminRuns =
            dryRunPlan.sepoliaCreate2DeployerOwner != dryRunPlan.sepoliaAdminWallet;
        plan.stage1CoreDeploymentTxs = CORE_DEPLOY_TXS + CORE_CONFIG_TXS + ownershipTransferTxs;
        plan.stage2HookAndPoolTxs =
            HOOK_DEPLOY_TXS + HOOK_BIND_TXS + HOOK_ALLOWLIST_TXS + POOL_INITIALIZE_TXS;
        plan.stage3RenounceTxs = HOOK_RENOUNCE_TXS;
        plan.totalTransactionsPlanned =
            plan.stage1CoreDeploymentTxs + plan.stage2HookAndPoolTxs + plan.stage3RenounceTxs;
        plan.predictedSunToken = dryRunPlan.predictedSunToken;
        plan.predictedSunCurve = dryRunPlan.predictedSunCurve;
        plan.predictedMoonToken = dryRunPlan.predictedMoonToken;
        plan.predictedMoonCurve = dryRunPlan.predictedMoonCurve;
        plan.predictedCreate2HookDeployer = dryRunPlan.predictedCreate2HookDeployer;
        plan.hookSalt = dryRunPlan.hookSalt;
        plan.predictedHook = dryRunPlan.predictedHook;
        plan.sunUsdcPoolId = dryRunPlan.sunUsdcPoolId;
        plan.sunUsdcInitialTick = dryRunPlan.sunUsdcInitialTick;
        plan.sunUsdcSqrtPriceX96 = dryRunPlan.sunUsdcSqrtPriceX96;
        plan.moonUsdcPoolId = dryRunPlan.moonUsdcPoolId;
        plan.moonUsdcInitialTick = dryRunPlan.moonUsdcInitialTick;
        plan.moonUsdcSqrtPriceX96 = dryRunPlan.moonUsdcSqrtPriceX96;
        plan.sunUsdcAllowedAfterDryRun = dryRunPlan.sunUsdcAllowedAfter;
        plan.moonUsdcAllowedAfterDryRun = dryRunPlan.moonUsdcAllowedAfter;
        plan.renounceBlocksSunAllowlist = dryRunPlan.renounceBlocksSunAllowlist;
        plan.renounceBlocksMoonAllowlist = dryRunPlan.renounceBlocksMoonAllowlist;
        plan.renounceBlocksProtocolBudget = dryRunPlan.renounceBlocksProtocolBudget;
    }

    function _logPlan(Rc3BroadcastDraftPlan memory plan) private pure {
        console2.log("Base Sepolia rc3 SUN/MOON USDC broadcast draft");
        console2.log("broadcastAllowed:", plan.broadcastAllowed);
        console2.log("simulationOnly:", plan.simulationOnly);
        console2.log("chainId:", plan.chainId);
        console2.log("baseSepoliaDraftConfirmed:", plan.baseSepoliaDraftConfirmed);
        console2.log("executeRequested:", plan.executeRequested);
        console2.log("privateKeyPresent:", plan.privateKeyPresent);
        console2.log("stage1CoreDeployer:", plan.stage1CoreDeployer);
        console2.log("stage2HookDeployer:", plan.stage2HookDeployer);
        console2.log("stage2AdminWallet:", plan.stage2AdminWallet);
        console2.log("stage3RenounceOwner:", plan.stage3RenounceOwner);
        console2.log("requiresSeparateCoreAndAdminRuns:", plan.requiresSeparateCoreAndAdminRuns);
        console2.log(
            "requiresSeparateHookOwnerAndAdminRuns:", plan.requiresSeparateHookOwnerAndAdminRuns
        );
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
        console2.log("SUN/USDC initialTick:", plan.sunUsdcInitialTick);
        console2.log("SUN/USDC sqrtPriceX96:", plan.sunUsdcSqrtPriceX96);
        console2.log("MOON/USDC poolId:");
        console2.logBytes32(plan.moonUsdcPoolId);
        console2.log("MOON/USDC initialTick:", plan.moonUsdcInitialTick);
        console2.log("MOON/USDC sqrtPriceX96:", plan.moonUsdcSqrtPriceX96);
        console2.log("sunUsdcAllowedAfterDryRun:", plan.sunUsdcAllowedAfterDryRun);
        console2.log("moonUsdcAllowedAfterDryRun:", plan.moonUsdcAllowedAfterDryRun);
        console2.log("renounceBlocksSunAllowlist:", plan.renounceBlocksSunAllowlist);
        console2.log("renounceBlocksMoonAllowlist:", plan.renounceBlocksMoonAllowlist);
        console2.log("renounceBlocksProtocolBudget:", plan.renounceBlocksProtocolBudget);
        console2.log("Next step:", "review draft only; do not broadcast Base Sepolia yet");
    }
}
