// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import { Script, console2 } from "forge-std/Script.sol";
import { BaseV4Addresses } from "../contracts/hooks/base/BaseV4Addresses.sol";
import { Create2HookDeployer } from "../contracts/hooks/base/Create2HookDeployer.sol";
import { MoonCurve } from "../contracts/MoonCurve.sol";
import { MoonToken } from "../contracts/MoonToken.sol";
import { SunCurve } from "../contracts/SunCurve.sol";
import { SunToken } from "../contracts/SunToken.sol";

contract PrepareBaseSepoliaRc3Stage1RecoveryDraft is Script {
    bytes32 internal constant LABEL_SEPOLIA_DEPLOYER = "SEPOLIA_DEPLOYER";
    bytes32 internal constant LABEL_SEPOLIA_ADMIN_WALLET = "SEPOLIA_ADMIN_WALLET";
    bytes32 internal constant LABEL_SEPOLIA_PROTOCOL_BUDGET_WALLET =
        "SEPOLIA_PROTOCOL_BUDGET_WALLET";
    bytes32 internal constant LABEL_SEPOLIA_CREATE2_DEPLOYER_OWNER =
        "SEPOLIA_CREATE2_DEPLOYER_OWNER";
    bytes32 internal constant LABEL_USDC_TOKEN = "USDC_TOKEN";
    bytes32 internal constant LABEL_PARTIAL_SUN_TOKEN = "PARTIAL_SUN_TOKEN";
    bytes32 internal constant LABEL_PARTIAL_SUN_CURVE = "PARTIAL_SUN_CURVE";
    bytes32 internal constant LABEL_PREDICTED_MOON_TOKEN = "PREDICTED_MOON_TOKEN";
    bytes32 internal constant LABEL_PREDICTED_MOON_CURVE = "PREDICTED_MOON_CURVE";
    bytes32 internal constant LABEL_PREDICTED_CREATE2_HOOK_DEPLOYER =
        "PREDICTED_CREATE2_HOOK_DEPLOYER";

    uint256 internal constant LOCAL_SIMULATION_CHAIN_ID = 31_337;
    uint256 internal constant USDC_ONE = 1e6;
    uint256 internal constant TOKEN_ONE = 1e18;
    uint256 internal constant MOON_MAX_MINT_USDC_EQUIV = 10_000 * USDC_ONE;
    uint256 internal constant MOON_K = 5_000_000 * TOKEN_ONE;
    uint256 internal constant MOON_S = 1_200_000 * TOKEN_ONE;
    uint256 internal constant STAGE1_RECOVERY_TRANSACTIONS_PLANNED = 10;
    uint256 internal constant DEFAULT_EXPECTED_RECOVERY_NONCE = 18;

    address internal constant DEFAULT_SEPOLIA_DEPLOYER = 0x2F6E887c6058deE520f9468a1022E3480A6334D3;
    address internal constant DEFAULT_SEPOLIA_ADMIN = 0x6E22b2e6fFAA30Fe75B71d53d1eC469b4e97A986;
    address internal constant DEFAULT_SEPOLIA_PROTOCOL_BUDGET =
        0x277ba3Cf597CdAaF958C301db3cF6a631F793039;
    address internal constant DEFAULT_PARTIAL_SUN_TOKEN =
        0xb5287fBbAD0e25B12f18497209fDac7e0ACf7293;
    address internal constant DEFAULT_PARTIAL_SUN_CURVE =
        0xe8D048aB83727419b00F4e30F4898C6B3bB91aD4;

    struct Stage1RecoveryConfig {
        address sepoliaDeployer;
        address sepoliaAdminWallet;
        address sepoliaProtocolBudgetWallet;
        address sepoliaCreate2DeployerOwner;
        address usdcToken;
        address partialSunToken;
        address partialSunCurve;
        uint256 expectedRecoveryNonce;
        uint256 moonLaunchDelay;
        bool recoveryConfirmed;
        bool executeRequested;
        bool privateKeyPresent;
    }

    struct Stage1RecoveryPlan {
        uint256 chainId;
        bool recoveryConfirmed;
        bool executeRequested;
        bool privateKeyPresent;
        bool broadcastAllowed;
        bool executionBlocked;
        bool simulationOnly;
        uint256 remainingTransactionsPlanned;
        address stage1CoreDeployer;
        uint64 stage1CoreDeployerNonce;
        uint256 expectedRecoveryNonce;
        bool recoveryNonceMatches;
        address stage1AdminWallet;
        address stage1ProtocolBudgetWallet;
        address stage1Create2DeployerOwner;
        address usdcToken;
        uint8 usdcDecimals;
        address partialSunToken;
        address partialSunCurve;
        address partialSunTokenOwner;
        address partialSunCurveOwner;
        address partialSunTokenMinter;
        address partialSunCurveMoonCurve;
        bool partialStateReady;
        uint256 moonLaunchTime;
        address predictedMoonToken;
        address predictedMoonCurve;
        address predictedCreate2HookDeployer;
        bool predictedMoonTokenHasCode;
        bool predictedMoonCurveHasCode;
        bool predictedCreate2HookDeployerHasCode;
        bool remainingAddressCollision;
        address deployedMoonToken;
        address deployedMoonCurve;
        address deployedCreate2HookDeployer;
    }

    error BaseMainnetNotAllowed(uint256 chainId);
    error BaseSepoliaStage1RecoveryNotConfirmed(uint256 chainId);
    error DependencyCodeMissing(bytes32 label, address target);
    error ExistingStage1StateMismatch(bytes32 label, address expected, address actual);
    error InvalidAddress(bytes32 label);
    error PrivateKeyEnvNotAllowed();
    error RecoveryNonceMismatch(uint256 expected, uint256 actual);
    error RemainingAddressCollision(bytes32 label, address predicted);
    error Stage1RecoveryNotConfirmed();
    error UnsupportedChain(uint256 chainId);
    error UsdcDecimalsMismatch(uint8 expected, uint8 actual);

    function run() external returns (Stage1RecoveryPlan memory plan) {
        plan = prepare(_loadConfig());
    }

    function prepare(Stage1RecoveryConfig memory config)
        public
        returns (Stage1RecoveryPlan memory plan)
    {
        _validateConfig(config);

        plan = _buildPlan(config);
        _validateRecoveryState(plan);

        if (config.executeRequested) {
            _executeRecovery(config, plan);
            _validateExecutedRecovery(config, plan);
        }

        _logPlan(plan);
    }

    function _loadConfig() private view returns (Stage1RecoveryConfig memory config) {
        bool localSimulation = block.chainid == LOCAL_SIMULATION_CHAIN_ID;

        config = Stage1RecoveryConfig({
            sepoliaDeployer: vm.envOr("SEPOLIA_DEPLOYER", DEFAULT_SEPOLIA_DEPLOYER),
            sepoliaAdminWallet: vm.envOr("SEPOLIA_ADMIN_WALLET", DEFAULT_SEPOLIA_ADMIN),
            sepoliaProtocolBudgetWallet: vm.envOr(
                "SEPOLIA_PROTOCOL_BUDGET_WALLET", DEFAULT_SEPOLIA_PROTOCOL_BUDGET
            ),
            sepoliaCreate2DeployerOwner: vm.envOr(
                "SEPOLIA_CREATE2_DEPLOYER_OWNER", DEFAULT_SEPOLIA_ADMIN
            ),
            usdcToken: vm.envOr(
                "USDC_TOKEN", localSimulation ? address(0) : BaseV4Addresses.BASE_SEPOLIA_USDC
            ),
            partialSunToken: vm.envOr("PARTIAL_SUN_TOKEN", DEFAULT_PARTIAL_SUN_TOKEN),
            partialSunCurve: vm.envOr("PARTIAL_SUN_CURVE", DEFAULT_PARTIAL_SUN_CURVE),
            expectedRecoveryNonce: vm.envOr(
                "BASE_SEPOLIA_RC3_STAGE1_RECOVERY_EXPECTED_NONCE", DEFAULT_EXPECTED_RECOVERY_NONCE
            ),
            moonLaunchDelay: vm.envOr("MOON_LAUNCH_DELAY", uint256(0)),
            recoveryConfirmed: vm.envOr(
                    "CONFIRM_BASE_SEPOLIA_RC3_STAGE1_RECOVERY_DRAFT", uint256(0)
                ) == 1,
            executeRequested: vm.envOr("EXECUTE_BASE_SEPOLIA_RC3_STAGE1_RECOVERY", uint256(0)) == 1,
            privateKeyPresent: bytes(vm.envOr("PRIVATE_KEY", string(""))).length != 0
        });
    }

    function _validateConfig(Stage1RecoveryConfig memory config) private view {
        if (config.privateKeyPresent) revert PrivateKeyEnvNotAllowed();
        if (block.chainid == BaseV4Addresses.BASE_MAINNET_CHAIN_ID) {
            revert BaseMainnetNotAllowed(block.chainid);
        }
        if (
            block.chainid != LOCAL_SIMULATION_CHAIN_ID
                && block.chainid != BaseV4Addresses.BASE_SEPOLIA_CHAIN_ID
        ) {
            revert UnsupportedChain(block.chainid);
        }
        if (block.chainid == BaseV4Addresses.BASE_SEPOLIA_CHAIN_ID) {
            if (!config.recoveryConfirmed) {
                revert BaseSepoliaStage1RecoveryNotConfirmed(block.chainid);
            }
            if (config.usdcToken != BaseV4Addresses.BASE_SEPOLIA_USDC) {
                revert InvalidAddress(LABEL_USDC_TOKEN);
            }
        }
        if (config.executeRequested && !config.recoveryConfirmed) {
            revert Stage1RecoveryNotConfirmed();
        }

        _requireAddress(config.sepoliaDeployer, LABEL_SEPOLIA_DEPLOYER);
        _requireAddress(config.sepoliaAdminWallet, LABEL_SEPOLIA_ADMIN_WALLET);
        _requireAddress(config.sepoliaProtocolBudgetWallet, LABEL_SEPOLIA_PROTOCOL_BUDGET_WALLET);
        _requireAddress(config.sepoliaCreate2DeployerOwner, LABEL_SEPOLIA_CREATE2_DEPLOYER_OWNER);
        _requireAddress(config.usdcToken, LABEL_USDC_TOKEN);
        _requireAddress(config.partialSunToken, LABEL_PARTIAL_SUN_TOKEN);
        _requireAddress(config.partialSunCurve, LABEL_PARTIAL_SUN_CURVE);
        _requireCode(config.usdcToken, LABEL_USDC_TOKEN);
        _requireCode(config.partialSunToken, LABEL_PARTIAL_SUN_TOKEN);
        _requireCode(config.partialSunCurve, LABEL_PARTIAL_SUN_CURVE);
    }

    function _buildPlan(Stage1RecoveryConfig memory config)
        private
        view
        returns (Stage1RecoveryPlan memory plan)
    {
        plan.chainId = block.chainid;
        plan.recoveryConfirmed = config.recoveryConfirmed;
        plan.executeRequested = config.executeRequested;
        plan.privateKeyPresent = config.privateKeyPresent;
        plan.broadcastAllowed = config.executeRequested && config.recoveryConfirmed;
        plan.executionBlocked = !plan.broadcastAllowed;
        plan.simulationOnly = !plan.broadcastAllowed;
        plan.remainingTransactionsPlanned = STAGE1_RECOVERY_TRANSACTIONS_PLANNED;
        plan.stage1CoreDeployer = config.sepoliaDeployer;
        plan.stage1CoreDeployerNonce = vm.getNonce(config.sepoliaDeployer);
        plan.expectedRecoveryNonce = config.expectedRecoveryNonce;
        plan.recoveryNonceMatches = plan.stage1CoreDeployerNonce == config.expectedRecoveryNonce;
        plan.stage1AdminWallet = config.sepoliaAdminWallet;
        plan.stage1ProtocolBudgetWallet = config.sepoliaProtocolBudgetWallet;
        plan.stage1Create2DeployerOwner = config.sepoliaCreate2DeployerOwner;
        plan.usdcToken = config.usdcToken;
        plan.usdcDecimals = IERC20Metadata(config.usdcToken).decimals();
        if (plan.usdcDecimals != 6) revert UsdcDecimalsMismatch(6, plan.usdcDecimals);
        plan.partialSunToken = config.partialSunToken;
        plan.partialSunCurve = config.partialSunCurve;
        plan.partialSunTokenOwner = SunToken(config.partialSunToken).owner();
        plan.partialSunCurveOwner = SunCurve(config.partialSunCurve).owner();
        plan.partialSunTokenMinter = SunToken(config.partialSunToken).minter();
        plan.partialSunCurveMoonCurve = SunCurve(config.partialSunCurve).moonCurve();
        plan.partialStateReady = plan.partialSunTokenOwner == config.sepoliaDeployer
            && plan.partialSunCurveOwner == config.sepoliaDeployer
            && plan.partialSunTokenMinter == address(0)
            && plan.partialSunCurveMoonCurve == address(0);
        plan.moonLaunchTime = block.timestamp + config.moonLaunchDelay;

        uint64 nonce = plan.stage1CoreDeployerNonce;
        plan.predictedMoonToken = vm.computeCreateAddress(config.sepoliaDeployer, nonce);
        plan.predictedMoonCurve = vm.computeCreateAddress(config.sepoliaDeployer, nonce + 1);
        plan.predictedCreate2HookDeployer =
            vm.computeCreateAddress(config.sepoliaDeployer, nonce + 2);
        plan.predictedMoonTokenHasCode = plan.predictedMoonToken.code.length != 0;
        plan.predictedMoonCurveHasCode = plan.predictedMoonCurve.code.length != 0;
        plan.predictedCreate2HookDeployerHasCode =
            plan.predictedCreate2HookDeployer.code.length != 0;
        plan.remainingAddressCollision = plan.predictedMoonTokenHasCode
            || plan.predictedMoonCurveHasCode || plan.predictedCreate2HookDeployerHasCode;
    }

    function _executeRecovery(Stage1RecoveryConfig memory config, Stage1RecoveryPlan memory plan)
        private
    {
        address temporaryOwner = config.sepoliaDeployer;
        SunToken sunToken = SunToken(config.partialSunToken);
        SunCurve sunCurve = SunCurve(config.partialSunCurve);

        vm.startBroadcast(config.sepoliaDeployer);

        MoonToken moonToken = new MoonToken("MOON", "MOON", temporaryOwner);
        MoonCurve moonCurve = new MoonCurve(
            moonToken,
            sunToken,
            sunCurve,
            config.sepoliaProtocolBudgetWallet,
            MOON_K,
            MOON_S,
            plan.moonLaunchTime,
            MOON_MAX_MINT_USDC_EQUIV,
            temporaryOwner
        );
        Create2HookDeployer create2Deployer =
            new Create2HookDeployer(config.sepoliaCreate2DeployerOwner);

        sunToken.setMinter(address(sunCurve));
        sunCurve.setMoonCurve(address(moonCurve));
        moonToken.setMinter(address(moonCurve));
        sunToken.transferOwnership(config.sepoliaAdminWallet);
        sunCurve.transferOwnership(config.sepoliaAdminWallet);
        moonToken.transferOwnership(config.sepoliaAdminWallet);
        moonCurve.transferOwnership(config.sepoliaAdminWallet);

        vm.stopBroadcast();

        plan.deployedMoonToken = address(moonToken);
        plan.deployedMoonCurve = address(moonCurve);
        plan.deployedCreate2HookDeployer = address(create2Deployer);
    }

    function _validateRecoveryState(Stage1RecoveryPlan memory plan) private pure {
        if (!plan.recoveryNonceMatches) {
            revert RecoveryNonceMismatch(plan.expectedRecoveryNonce, plan.stage1CoreDeployerNonce);
        }
        if (plan.partialSunTokenOwner != plan.stage1CoreDeployer) {
            revert ExistingStage1StateMismatch(
                LABEL_PARTIAL_SUN_TOKEN, plan.stage1CoreDeployer, plan.partialSunTokenOwner
            );
        }
        if (plan.partialSunCurveOwner != plan.stage1CoreDeployer) {
            revert ExistingStage1StateMismatch(
                LABEL_PARTIAL_SUN_CURVE, plan.stage1CoreDeployer, plan.partialSunCurveOwner
            );
        }
        if (plan.partialSunTokenMinter != address(0)) {
            revert ExistingStage1StateMismatch(
                LABEL_PARTIAL_SUN_TOKEN, address(0), plan.partialSunTokenMinter
            );
        }
        if (plan.partialSunCurveMoonCurve != address(0)) {
            revert ExistingStage1StateMismatch(
                LABEL_PARTIAL_SUN_CURVE, address(0), plan.partialSunCurveMoonCurve
            );
        }
        if (plan.predictedMoonTokenHasCode) {
            revert RemainingAddressCollision(LABEL_PREDICTED_MOON_TOKEN, plan.predictedMoonToken);
        }
        if (plan.predictedMoonCurveHasCode) {
            revert RemainingAddressCollision(LABEL_PREDICTED_MOON_CURVE, plan.predictedMoonCurve);
        }
        if (plan.predictedCreate2HookDeployerHasCode) {
            revert RemainingAddressCollision(
                LABEL_PREDICTED_CREATE2_HOOK_DEPLOYER, plan.predictedCreate2HookDeployer
            );
        }
    }

    function _validateExecutedRecovery(
        Stage1RecoveryConfig memory config,
        Stage1RecoveryPlan memory plan
    ) private view {
        require(plan.deployedMoonToken == plan.predictedMoonToken, "MOON prediction mismatch");
        require(plan.deployedMoonCurve == plan.predictedMoonCurve, "MoonCurve prediction mismatch");
        require(
            plan.deployedCreate2HookDeployer == plan.predictedCreate2HookDeployer,
            "Create2 deployer prediction mismatch"
        );

        SunToken sunToken = SunToken(config.partialSunToken);
        SunCurve sunCurve = SunCurve(config.partialSunCurve);
        MoonToken moonToken = MoonToken(plan.deployedMoonToken);
        MoonCurve moonCurve = MoonCurve(plan.deployedMoonCurve);
        Create2HookDeployer create2Deployer = Create2HookDeployer(plan.deployedCreate2HookDeployer);

        require(sunToken.minter() == config.partialSunCurve, "SUN minter mismatch");
        require(sunCurve.moonCurve() == plan.deployedMoonCurve, "SunCurve moonCurve mismatch");
        require(moonToken.minter() == plan.deployedMoonCurve, "MOON minter mismatch");
        require(sunToken.owner() == config.sepoliaAdminWallet, "SUN owner mismatch");
        require(sunCurve.owner() == config.sepoliaAdminWallet, "SunCurve owner mismatch");
        require(moonToken.owner() == config.sepoliaAdminWallet, "MOON owner mismatch");
        require(moonCurve.owner() == config.sepoliaAdminWallet, "MoonCurve owner mismatch");
        require(
            create2Deployer.owner() == config.sepoliaCreate2DeployerOwner, "Create2 owner mismatch"
        );
    }

    function _requireAddress(address value, bytes32 label) private pure {
        if (value == address(0)) revert InvalidAddress(label);
    }

    function _requireCode(address target, bytes32 label) private view {
        if (target.code.length == 0) revert DependencyCodeMissing(label, target);
    }

    function _logPlan(Stage1RecoveryPlan memory plan) private pure {
        console2.log("Base Sepolia rc3 Stage 1 recovery draft");
        console2.log("chainId:", plan.chainId);
        console2.log("recoveryConfirmed:", plan.recoveryConfirmed);
        console2.log("executeRequested:", plan.executeRequested);
        console2.log("privateKeyPresent:", plan.privateKeyPresent);
        console2.log("broadcastAllowed:", plan.broadcastAllowed);
        console2.log("executionBlocked:", plan.executionBlocked);
        console2.log("simulationOnly:", plan.simulationOnly);
        console2.log("remainingTransactionsPlanned:", plan.remainingTransactionsPlanned);
        console2.log("stage1CoreDeployer:", plan.stage1CoreDeployer);
        console2.log("stage1CoreDeployerNonce:", plan.stage1CoreDeployerNonce);
        console2.log("expectedRecoveryNonce:", plan.expectedRecoveryNonce);
        console2.log("recoveryNonceMatches:", plan.recoveryNonceMatches);
        console2.log("stage1AdminWallet:", plan.stage1AdminWallet);
        console2.log("stage1ProtocolBudgetWallet:", plan.stage1ProtocolBudgetWallet);
        console2.log("stage1Create2DeployerOwner:", plan.stage1Create2DeployerOwner);
        console2.log("usdcToken:", plan.usdcToken);
        console2.log("usdcDecimals:", plan.usdcDecimals);
        console2.log("PARTIAL_SUN_TOKEN:", plan.partialSunToken);
        console2.log("PARTIAL_SUN_CURVE:", plan.partialSunCurve);
        console2.log("partialSunTokenOwner:", plan.partialSunTokenOwner);
        console2.log("partialSunCurveOwner:", plan.partialSunCurveOwner);
        console2.log("partialSunTokenMinter:", plan.partialSunTokenMinter);
        console2.log("partialSunCurveMoonCurve:", plan.partialSunCurveMoonCurve);
        console2.log("partialStateReady:", plan.partialStateReady);
        console2.log("moonLaunchTime:", plan.moonLaunchTime);
        console2.log("PREDICTED_MOON_TOKEN:", plan.predictedMoonToken);
        console2.log("PREDICTED_MOON_CURVE:", plan.predictedMoonCurve);
        console2.log("PREDICTED_CREATE2_HOOK_DEPLOYER:", plan.predictedCreate2HookDeployer);
        console2.log("remainingAddressCollision:", plan.remainingAddressCollision);
        console2.log("DEPLOYED_MOON_TOKEN:", plan.deployedMoonToken);
        console2.log("DEPLOYED_MOON_CURVE:", plan.deployedMoonCurve);
        console2.log("DEPLOYED_CREATE2_HOOK_DEPLOYER:", plan.deployedCreate2HookDeployer);
        console2.log("Next step:", "manual review only unless owner separately approves recovery");
    }
}
