// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import { Script, console2 } from "forge-std/Script.sol";
import { MoonCurve } from "../contracts/MoonCurve.sol";
import { MoonToken } from "../contracts/MoonToken.sol";
import { SunCurve } from "../contracts/SunCurve.sol";
import { SunToken } from "../contracts/SunToken.sol";
import { BaseV4Addresses } from "../contracts/hooks/base/BaseV4Addresses.sol";
import { Create2HookDeployer } from "../contracts/hooks/base/Create2HookDeployer.sol";
import { MockUSDT } from "../contracts/mocks/MockUSDT.sol";

contract PrepareBaseMainnetCoreDeployDryRun is Script {
    bytes32 internal constant LABEL_MAINNET_DEPLOYER = "MAINNET_DEPLOYER";
    bytes32 internal constant LABEL_MAINNET_ADMIN_WALLET = "MAINNET_ADMIN_WALLET";
    bytes32 internal constant LABEL_PROTOCOL_BUDGET_WALLET = "PROTOCOL_BUDGET_WALLET";
    bytes32 internal constant LABEL_CREATE2_DEPLOYER_OWNER = "CREATE2_DEPLOYER_OWNER";
    bytes32 internal constant LABEL_USDC_TOKEN = "USDC_TOKEN";
    bytes32 internal constant LABEL_PREDICTED_SUN_TOKEN = "PREDICTED_SUN_TOKEN";
    bytes32 internal constant LABEL_PREDICTED_SUN_CURVE = "PREDICTED_SUN_CURVE";
    bytes32 internal constant LABEL_PREDICTED_MOON_TOKEN = "PREDICTED_MOON_TOKEN";
    bytes32 internal constant LABEL_PREDICTED_MOON_CURVE = "PREDICTED_MOON_CURVE";
    bytes32 internal constant LABEL_PREDICTED_CREATE2_HOOK_DEPLOYER =
        "PREDICTED_CREATE2_HOOK_DEPLOYER";

    uint256 internal constant LOCAL_SIMULATION_CHAIN_ID = 31_337;
    uint256 internal constant USDC_ONE = 1e6;
    uint256 internal constant TOKEN_ONE = 1e18;
    uint256 internal constant SUN_MAX_MINT_USDC = 10_000 * USDC_ONE;
    uint256 internal constant MOON_MAX_MINT_USDC_EQUIV = 10_000 * USDC_ONE;
    uint256 internal constant MOON_K = 5_000_000 * TOKEN_ONE;
    uint256 internal constant MOON_S = 1_200_000 * TOKEN_ONE;
    uint256 internal constant CORE_DEPLOYMENT_TRANSACTIONS_PLANNED = 12;

    struct CoreDeployConfig {
        address mainnetDeployer;
        address mainnetAdminWallet;
        address protocolBudgetWallet;
        address create2DeployerOwner;
        address usdcToken;
        uint256 moonLaunchDelay;
        bool baseMainnetConfirmed;
        bool broadcastRequested;
    }

    struct CoreDeployPlan {
        uint256 chainId;
        bool baseMainnetConfirmed;
        bool broadcastRequested;
        bool simulationOnly;
        uint256 transactionsPlanned;
        address mainnetDeployer;
        uint64 mainnetDeployerNonce;
        address mainnetAdminWallet;
        address protocolBudgetWallet;
        address create2DeployerOwner;
        address usdcToken;
        uint8 usdcDecimals;
        uint256 moonLaunchTime;
        address predictedSunToken;
        address predictedSunCurve;
        address predictedMoonToken;
        address predictedMoonCurve;
        address predictedCreate2HookDeployer;
        MockUSDT mockUsdc;
        SunToken sunTokenSimulation;
        SunCurve sunCurveSimulation;
        MoonToken moonTokenSimulation;
        MoonCurve moonCurveSimulation;
        Create2HookDeployer create2HookDeployerSimulation;
    }

    error BaseMainnetCoreDryRunNotConfirmed(uint256 chainId);
    error BaseMainnetUnexpectedAddress(bytes32 label, address expected, address actual);
    error BroadcastNotAllowed();
    error DependencyCodeMissing(bytes32 label, address target);
    error DuplicateAddress(bytes32 leftLabel, bytes32 rightLabel, address value);
    error InvalidAddress(bytes32 label);
    error PredictedAddressAlreadyUsed(bytes32 label, address predicted);
    error UnsupportedChain(uint256 chainId);
    error UsdcDecimalsMismatch(uint8 expected, uint8 actual);

    function run() external returns (CoreDeployPlan memory plan) {
        plan = _prepare(_loadConfig());
    }

    function prepare(CoreDeployConfig memory config) external returns (CoreDeployPlan memory plan) {
        plan = _prepare(config);
    }

    function _loadConfig() private view returns (CoreDeployConfig memory config) {
        config = CoreDeployConfig({
            mainnetDeployer: _requiredEnvAddress("MAINNET_DEPLOYER", LABEL_MAINNET_DEPLOYER),
            mainnetAdminWallet: _requiredEnvAddress(
                "MAINNET_ADMIN_WALLET", LABEL_MAINNET_ADMIN_WALLET
            ),
            protocolBudgetWallet: _requiredEnvAddress(
                "PROTOCOL_BUDGET_WALLET", LABEL_PROTOCOL_BUDGET_WALLET
            ),
            create2DeployerOwner: _requiredEnvAddress(
                "CREATE2_DEPLOYER_OWNER", LABEL_CREATE2_DEPLOYER_OWNER
            ),
            usdcToken: _envAddressOrZero("USDC_TOKEN"),
            moonLaunchDelay: vm.envOr("MOON_LAUNCH_DELAY", uint256(0)),
            baseMainnetConfirmed: vm.envOr("CONFIRM_BASE_MAINNET_CORE_DRY_RUN", uint256(0)) == 1,
            broadcastRequested: vm.envOr("EXECUTE_BASE_MAINNET_BROADCAST", uint256(0)) == 1
        });
    }

    function _prepare(CoreDeployConfig memory config) private returns (CoreDeployPlan memory plan) {
        _validateConfig(config);

        plan.chainId = block.chainid;
        plan.baseMainnetConfirmed = config.baseMainnetConfirmed;
        plan.broadcastRequested = config.broadcastRequested;
        plan.simulationOnly = true;
        plan.transactionsPlanned = CORE_DEPLOYMENT_TRANSACTIONS_PLANNED;
        plan.mainnetDeployer = config.mainnetDeployer;
        plan.mainnetDeployerNonce = vm.getNonce(config.mainnetDeployer);
        plan.mainnetAdminWallet = config.mainnetAdminWallet;
        plan.protocolBudgetWallet = config.protocolBudgetWallet;
        plan.create2DeployerOwner = config.create2DeployerOwner;
        plan.moonLaunchTime = block.timestamp + config.moonLaunchDelay;

        _prepareUsdc(config, plan);
        _preparePredictedAddresses(config, plan);
        _deploySimulation(config, plan);
        _validateSimulation(config, plan);
        _logPlan(plan);
    }

    function _validateConfig(CoreDeployConfig memory config) private view {
        if (config.broadcastRequested) revert BroadcastNotAllowed();

        _requireAddress(config.mainnetDeployer, LABEL_MAINNET_DEPLOYER);
        _requireAddress(config.mainnetAdminWallet, LABEL_MAINNET_ADMIN_WALLET);
        _requireAddress(config.protocolBudgetWallet, LABEL_PROTOCOL_BUDGET_WALLET);
        _requireAddress(config.create2DeployerOwner, LABEL_CREATE2_DEPLOYER_OWNER);

        _requireDistinct(
            config.mainnetDeployer,
            LABEL_MAINNET_DEPLOYER,
            config.mainnetAdminWallet,
            LABEL_MAINNET_ADMIN_WALLET
        );
        _requireDistinct(
            config.mainnetDeployer,
            LABEL_MAINNET_DEPLOYER,
            config.protocolBudgetWallet,
            LABEL_PROTOCOL_BUDGET_WALLET
        );
        _requireDistinct(
            config.mainnetDeployer,
            LABEL_MAINNET_DEPLOYER,
            config.create2DeployerOwner,
            LABEL_CREATE2_DEPLOYER_OWNER
        );
        _requireDistinct(
            config.mainnetAdminWallet,
            LABEL_MAINNET_ADMIN_WALLET,
            config.protocolBudgetWallet,
            LABEL_PROTOCOL_BUDGET_WALLET
        );
        _requireDistinct(
            config.mainnetAdminWallet,
            LABEL_MAINNET_ADMIN_WALLET,
            config.create2DeployerOwner,
            LABEL_CREATE2_DEPLOYER_OWNER
        );
        _requireDistinct(
            config.protocolBudgetWallet,
            LABEL_PROTOCOL_BUDGET_WALLET,
            config.create2DeployerOwner,
            LABEL_CREATE2_DEPLOYER_OWNER
        );

        if (block.chainid == BaseV4Addresses.BASE_MAINNET_CHAIN_ID) {
            if (!config.baseMainnetConfirmed) {
                revert BaseMainnetCoreDryRunNotConfirmed(block.chainid);
            }
            address usdcToken = _configuredOrOfficialUsdc(config.usdcToken);
            _requireOfficialMainnetAddress(
                LABEL_USDC_TOKEN, BaseV4Addresses.BASE_MAINNET_USDC, usdcToken
            );
            _requireCode(LABEL_USDC_TOKEN, usdcToken);
        } else if (block.chainid != LOCAL_SIMULATION_CHAIN_ID) {
            revert UnsupportedChain(block.chainid);
        } else if (config.usdcToken != address(0)) {
            _requireCode(LABEL_USDC_TOKEN, config.usdcToken);
        }
    }

    function _prepareUsdc(CoreDeployConfig memory config, CoreDeployPlan memory plan) private {
        if (block.chainid == BaseV4Addresses.BASE_MAINNET_CHAIN_ID) {
            plan.usdcToken = _configuredOrOfficialUsdc(config.usdcToken);
        } else if (config.usdcToken == address(0)) {
            plan.mockUsdc = new MockUSDT("Mock Base Mainnet USDC", "USDC", 6);
            plan.usdcToken = address(plan.mockUsdc);
        } else {
            plan.usdcToken = config.usdcToken;
        }

        plan.usdcDecimals = IERC20Metadata(plan.usdcToken).decimals();
        if (plan.usdcDecimals != 6) revert UsdcDecimalsMismatch(6, plan.usdcDecimals);
    }

    function _preparePredictedAddresses(CoreDeployConfig memory config, CoreDeployPlan memory plan)
        private
        view
    {
        uint64 nonce = plan.mainnetDeployerNonce;

        plan.predictedSunToken = vm.computeCreateAddress(config.mainnetDeployer, nonce);
        plan.predictedSunCurve = vm.computeCreateAddress(config.mainnetDeployer, nonce + 1);
        plan.predictedMoonToken = vm.computeCreateAddress(config.mainnetDeployer, nonce + 2);
        plan.predictedMoonCurve = vm.computeCreateAddress(config.mainnetDeployer, nonce + 3);
        plan.predictedCreate2HookDeployer =
            vm.computeCreateAddress(config.mainnetDeployer, nonce + 4);

        _requirePredictedAddressAvailable(LABEL_PREDICTED_SUN_TOKEN, plan.predictedSunToken);
        _requirePredictedAddressAvailable(LABEL_PREDICTED_SUN_CURVE, plan.predictedSunCurve);
        _requirePredictedAddressAvailable(LABEL_PREDICTED_MOON_TOKEN, plan.predictedMoonToken);
        _requirePredictedAddressAvailable(LABEL_PREDICTED_MOON_CURVE, plan.predictedMoonCurve);
        _requirePredictedAddressAvailable(
            LABEL_PREDICTED_CREATE2_HOOK_DEPLOYER, plan.predictedCreate2HookDeployer
        );

        _requireDistinct(
            plan.predictedSunToken,
            LABEL_PREDICTED_SUN_TOKEN,
            plan.predictedSunCurve,
            LABEL_PREDICTED_SUN_CURVE
        );
        _requireDistinct(
            plan.predictedSunToken,
            LABEL_PREDICTED_SUN_TOKEN,
            plan.predictedMoonToken,
            LABEL_PREDICTED_MOON_TOKEN
        );
        _requireDistinct(
            plan.predictedSunToken,
            LABEL_PREDICTED_SUN_TOKEN,
            plan.predictedMoonCurve,
            LABEL_PREDICTED_MOON_CURVE
        );
        _requireDistinct(
            plan.predictedSunToken,
            LABEL_PREDICTED_SUN_TOKEN,
            plan.predictedCreate2HookDeployer,
            LABEL_PREDICTED_CREATE2_HOOK_DEPLOYER
        );
        _requireDistinct(
            plan.predictedSunCurve,
            LABEL_PREDICTED_SUN_CURVE,
            plan.predictedMoonToken,
            LABEL_PREDICTED_MOON_TOKEN
        );
        _requireDistinct(
            plan.predictedSunCurve,
            LABEL_PREDICTED_SUN_CURVE,
            plan.predictedMoonCurve,
            LABEL_PREDICTED_MOON_CURVE
        );
        _requireDistinct(
            plan.predictedSunCurve,
            LABEL_PREDICTED_SUN_CURVE,
            plan.predictedCreate2HookDeployer,
            LABEL_PREDICTED_CREATE2_HOOK_DEPLOYER
        );
        _requireDistinct(
            plan.predictedMoonToken,
            LABEL_PREDICTED_MOON_TOKEN,
            plan.predictedMoonCurve,
            LABEL_PREDICTED_MOON_CURVE
        );
        _requireDistinct(
            plan.predictedMoonToken,
            LABEL_PREDICTED_MOON_TOKEN,
            plan.predictedCreate2HookDeployer,
            LABEL_PREDICTED_CREATE2_HOOK_DEPLOYER
        );
        _requireDistinct(
            plan.predictedMoonCurve,
            LABEL_PREDICTED_MOON_CURVE,
            plan.predictedCreate2HookDeployer,
            LABEL_PREDICTED_CREATE2_HOOK_DEPLOYER
        );
    }

    function _deploySimulation(CoreDeployConfig memory config, CoreDeployPlan memory plan) private {
        address temporaryOwner = config.mainnetDeployer;
        bytes32 baseSalt = keccak256(
            abi.encode(
                "SUN_MOON_MAINNET_CORE_DRY_RUN",
                block.chainid,
                config.mainnetDeployer,
                plan.mainnetDeployerNonce,
                config.mainnetAdminWallet,
                plan.usdcToken,
                plan.moonLaunchTime
            )
        );

        plan.sunTokenSimulation = new SunToken{ salt: _simulationSalt(baseSalt, "SUN_TOKEN") }(
            "SUN", "SUN", temporaryOwner
        );
        plan.sunCurveSimulation = new SunCurve{ salt: _simulationSalt(baseSalt, "SUN_CURVE") }(
            plan.sunTokenSimulation,
            IERC20Metadata(plan.usdcToken),
            config.protocolBudgetWallet,
            SUN_MAX_MINT_USDC,
            temporaryOwner
        );
        plan.moonTokenSimulation = new MoonToken{ salt: _simulationSalt(baseSalt, "MOON_TOKEN") }(
            "MOON", "MOON", temporaryOwner
        );
        plan.moonCurveSimulation = new MoonCurve{ salt: _simulationSalt(baseSalt, "MOON_CURVE") }(
            plan.moonTokenSimulation,
            plan.sunTokenSimulation,
            plan.sunCurveSimulation,
            config.protocolBudgetWallet,
            MOON_K,
            MOON_S,
            plan.moonLaunchTime,
            MOON_MAX_MINT_USDC_EQUIV,
            temporaryOwner
        );
        plan.create2HookDeployerSimulation = new Create2HookDeployer{
            salt: _simulationSalt(baseSalt, "CREATE2_HOOK_DEPLOYER")
        }(
            config.create2DeployerOwner
        );

        vm.deal(temporaryOwner, 1 ether);
        vm.startPrank(temporaryOwner);
        plan.sunTokenSimulation.setMinter(address(plan.sunCurveSimulation));
        plan.sunCurveSimulation.setMoonCurve(address(plan.moonCurveSimulation));
        plan.moonTokenSimulation.setMinter(address(plan.moonCurveSimulation));
        plan.sunTokenSimulation.transferOwnership(config.mainnetAdminWallet);
        plan.sunCurveSimulation.transferOwnership(config.mainnetAdminWallet);
        plan.moonTokenSimulation.transferOwnership(config.mainnetAdminWallet);
        plan.moonCurveSimulation.transferOwnership(config.mainnetAdminWallet);
        vm.stopPrank();
    }

    function _simulationSalt(bytes32 baseSalt, string memory label)
        private
        pure
        returns (bytes32 salt)
    {
        salt = keccak256(abi.encode(baseSalt, label));
    }

    function _validateSimulation(CoreDeployConfig memory config, CoreDeployPlan memory plan)
        private
        view
    {
        require(plan.sunTokenSimulation.owner() == config.mainnetAdminWallet, "SUN owner mismatch");
        require(
            plan.sunCurveSimulation.owner() == config.mainnetAdminWallet, "SunCurve owner mismatch"
        );
        require(
            plan.moonTokenSimulation.owner() == config.mainnetAdminWallet, "MOON owner mismatch"
        );
        require(
            plan.moonCurveSimulation.owner() == config.mainnetAdminWallet,
            "MoonCurve owner mismatch"
        );
        require(
            plan.sunTokenSimulation.minter() == address(plan.sunCurveSimulation),
            "SUN minter mismatch"
        );
        require(plan.sunTokenSimulation.minterLocked(), "SUN minter unlocked");
        require(
            plan.moonTokenSimulation.minter() == address(plan.moonCurveSimulation),
            "MOON minter mismatch"
        );
        require(plan.moonTokenSimulation.minterLocked(), "MOON minter unlocked");
        require(
            plan.sunCurveSimulation.moonCurve() == address(plan.moonCurveSimulation),
            "MoonCurve link mismatch"
        );
        require(plan.sunCurveSimulation.moonAMM() == address(0), "MoonAMM should remain unset");
        require(address(plan.sunCurveSimulation.usdt()) == plan.usdcToken, "SunCurve USDC mismatch");
        require(
            plan.sunCurveSimulation.protocolBudget() == config.protocolBudgetWallet,
            "SunCurve budget mismatch"
        );
        require(
            plan.moonCurveSimulation.protocolBudget() == config.protocolBudgetWallet,
            "MoonCurve budget mismatch"
        );
        require(plan.sunCurveSimulation.maxMintUsdt() == SUN_MAX_MINT_USDC, "SUN max mint mismatch");
        require(plan.moonCurveSimulation.k() == MOON_K, "MOON k mismatch");
        require(plan.moonCurveSimulation.s() == MOON_S, "MOON s mismatch");
        require(
            plan.moonCurveSimulation.launchTime() == plan.moonLaunchTime, "MOON launch mismatch"
        );
        require(
            plan.moonCurveSimulation.maxMintUsdtEquiv() == MOON_MAX_MINT_USDC_EQUIV,
            "MOON max mint mismatch"
        );
        require(
            plan.create2HookDeployerSimulation.owner() == config.create2DeployerOwner,
            "CREATE2 owner mismatch"
        );
    }

    function _configuredOrOfficialUsdc(address configuredUsdc)
        private
        pure
        returns (address usdcToken)
    {
        usdcToken =
            configuredUsdc == address(0) ? BaseV4Addresses.BASE_MAINNET_USDC : configuredUsdc;
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

    function _envAddressOrZero(string memory key) private view returns (address value) {
        string memory rawValue = vm.envOr(key, string(""));
        if (bytes(rawValue).length == 0) return address(0);

        value = vm.parseAddress(rawValue);
    }

    function _requireAddress(address value, bytes32 label) private pure {
        if (value == address(0)) revert InvalidAddress(label);
    }

    function _requireDistinct(address left, bytes32 leftLabel, address right, bytes32 rightLabel)
        private
        pure
    {
        if (left == right) revert DuplicateAddress(leftLabel, rightLabel, left);
    }

    function _requireOfficialMainnetAddress(bytes32 label, address expected, address actual)
        private
        pure
    {
        if (actual != expected) {
            revert BaseMainnetUnexpectedAddress(label, expected, actual);
        }
    }

    function _requireCode(bytes32 label, address target) private view {
        if (target.code.length == 0) revert DependencyCodeMissing(label, target);
    }

    function _requirePredictedAddressAvailable(bytes32 label, address predicted) private view {
        if (predicted.code.length != 0) revert PredictedAddressAlreadyUsed(label, predicted);
    }

    function _logPlan(CoreDeployPlan memory plan) private pure {
        console2.log("Base mainnet core deploy dry-run preparation");
        console2.log("simulationOnly:", plan.simulationOnly);
        console2.log("transactionsPlanned:", plan.transactionsPlanned);
        console2.log("chainId:", plan.chainId);
        console2.log("baseMainnetConfirmed:", plan.baseMainnetConfirmed);
        console2.log("broadcastRequested:", plan.broadcastRequested);
        console2.log("MAINNET_DEPLOYER:", plan.mainnetDeployer);
        console2.log("MAINNET_DEPLOYER nonce:", plan.mainnetDeployerNonce);
        console2.log("MAINNET_ADMIN_WALLET:", plan.mainnetAdminWallet);
        console2.log("PROTOCOL_BUDGET_WALLET:", plan.protocolBudgetWallet);
        console2.log("CREATE2_DEPLOYER_OWNER:", plan.create2DeployerOwner);
        console2.log("USDC_TOKEN used in simulation:", plan.usdcToken);
        console2.log("USDC decimals:", plan.usdcDecimals);
        console2.log("moonLaunchTime:", plan.moonLaunchTime);
        console2.log("Predicted CREATE addresses if deployer nonce does not change:");
        console2.log("SUN_TOKEN:", plan.predictedSunToken);
        console2.log("SUN_CURVE:", plan.predictedSunCurve);
        console2.log("MOON_TOKEN:", plan.predictedMoonToken);
        console2.log("MOON_CURVE:", plan.predictedMoonCurve);
        console2.log("CREATE2_HOOK_DEPLOYER:", plan.predictedCreate2HookDeployer);
        console2.log("Local simulation addresses are not mainnet addresses:");
        console2.log("SunToken simulation:", address(plan.sunTokenSimulation));
        console2.log("SunCurve simulation:", address(plan.sunCurveSimulation));
        console2.log("MoonToken simulation:", address(plan.moonTokenSimulation));
        console2.log("MoonCurve simulation:", address(plan.moonCurveSimulation));
        console2.log("Create2HookDeployer simulation:", address(plan.create2HookDeployerSimulation));
        console2.log("Next step:", "review predicted addresses; still do not broadcast mainnet");
    }
}
