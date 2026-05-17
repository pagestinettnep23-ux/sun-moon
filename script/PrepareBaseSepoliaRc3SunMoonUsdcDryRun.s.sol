// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { Script, console2 } from "forge-std/Script.sol";
import { IHooks } from "@uniswap/v4-core/src/interfaces/IHooks.sol";
import { IPoolManager } from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import { TickMath } from "@uniswap/v4-core/src/libraries/TickMath.sol";
import { PoolManager } from "@uniswap/v4-core/src/PoolManager.sol";
import { Currency } from "@uniswap/v4-core/src/types/Currency.sol";
import { PoolId, PoolIdLibrary } from "@uniswap/v4-core/src/types/PoolId.sol";
import { PoolKey } from "@uniswap/v4-core/src/types/PoolKey.sol";
import { IStateView } from "@uniswap/v4-periphery/src/interfaces/IStateView.sol";
import { StateView } from "@uniswap/v4-periphery/src/lens/StateView.sol";
import { MoonCurve } from "../contracts/MoonCurve.sol";
import { MoonToken } from "../contracts/MoonToken.sol";
import { SunCurve } from "../contracts/SunCurve.sol";
import { SunToken } from "../contracts/SunToken.sol";
import { BaseSunMoonUsdcFeeV4Hook } from "../contracts/hooks/base/BaseSunMoonUsdcFeeV4Hook.sol";
import { BaseV4Addresses } from "../contracts/hooks/base/BaseV4Addresses.sol";
import { BaseV4HookAddressMiner } from "../contracts/hooks/base/BaseV4HookAddressMiner.sol";
import { Create2HookDeployer } from "../contracts/hooks/base/Create2HookDeployer.sol";
import { MockUSDT } from "../contracts/mocks/MockUSDT.sol";

contract PrepareBaseSepoliaRc3SunMoonUsdcDryRun is Script {
    using PoolIdLibrary for PoolKey;

    bytes32 internal constant LABEL_SEPOLIA_DEPLOYER = "SEPOLIA_DEPLOYER";
    bytes32 internal constant LABEL_SEPOLIA_ADMIN_WALLET = "SEPOLIA_ADMIN_WALLET";
    bytes32 internal constant LABEL_SEPOLIA_PROTOCOL_BUDGET_WALLET =
        "SEPOLIA_PROTOCOL_BUDGET_WALLET";
    bytes32 internal constant LABEL_SEPOLIA_CREATE2_DEPLOYER_OWNER =
        "SEPOLIA_CREATE2_DEPLOYER_OWNER";
    bytes32 internal constant LABEL_POOL_MANAGER = "POOL_MANAGER";
    bytes32 internal constant LABEL_STATE_VIEW = "STATE_VIEW";
    bytes32 internal constant LABEL_USDC_TOKEN = "USDC_TOKEN";
    bytes32 internal constant LABEL_SUN_POOL = "SUN_USDC_POOL";
    bytes32 internal constant LABEL_MOON_POOL = "MOON_USDC_POOL";
    bytes32 internal constant LABEL_SUN_POOL_ID = "SUN_USDC_POOL_ID";
    bytes32 internal constant LABEL_MOON_POOL_ID = "MOON_USDC_POOL_ID";
    bytes32 internal constant LABEL_SUN_PRICE = "SUN_USDC_INITIAL_PRICE";
    bytes32 internal constant LABEL_MOON_PRICE = "MOON_USDC_INITIAL_PRICE";

    uint24 internal constant EXPECTED_POOL_FEE = 3000;
    int24 internal constant EXPECTED_TICK_SPACING = 60;
    uint256 internal constant LOCAL_SIMULATION_CHAIN_ID = 31_337;
    uint256 internal constant Q192 = uint256(1) << 192;
    uint256 internal constant USDC_ONE = 1e6;
    uint256 internal constant TOKEN_ONE = 1e18;
    uint256 internal constant DEFAULT_SUN_USDC_PRICE = 1e6;
    uint256 internal constant DEFAULT_MOON_USDC_PRICE = 240_000;
    uint256 internal constant SUN_MAX_MINT_USDC = 10_000 * USDC_ONE;
    uint256 internal constant MOON_MAX_MINT_USDC_EQUIV = 10_000 * USDC_ONE;
    uint256 internal constant MOON_K = 5_000_000 * TOKEN_ONE;
    uint256 internal constant MOON_S = 1_200_000 * TOKEN_ONE;
    uint256 internal constant SIMULATED_ACTIONS_PLANNED = 19;

    address internal constant DEFAULT_SEPOLIA_DEPLOYER = 0x2F6E887c6058deE520f9468a1022E3480A6334D3;
    address internal constant DEFAULT_SEPOLIA_ADMIN = 0x6E22b2e6fFAA30Fe75B71d53d1eC469b4e97A986;
    address internal constant DEFAULT_SEPOLIA_PROTOCOL_BUDGET =
        0x277ba3Cf597CdAaF958C301db3cF6a631F793039;

    struct Rc3DryRunConfig {
        address sepoliaDeployer;
        address sepoliaAdminWallet;
        address sepoliaProtocolBudgetWallet;
        address sepoliaCreate2DeployerOwner;
        address poolManager;
        address stateView;
        address usdcToken;
        uint256 moonLaunchDelay;
        uint24 sunUsdcFee;
        int24 sunUsdcTickSpacing;
        uint256 sunUsdcInitialTokenAmount;
        uint256 sunUsdcInitialUsdcAmount;
        bytes32 expectedSunUsdcPoolId;
        uint24 moonUsdcFee;
        int24 moonUsdcTickSpacing;
        uint256 moonUsdcInitialTokenAmount;
        uint256 moonUsdcInitialUsdcAmount;
        bytes32 expectedMoonUsdcPoolId;
        uint256 hookSaltStart;
        uint256 hookMaxSaltSearch;
        bool baseSepoliaConfirmed;
        bool broadcastRequested;
    }

    struct Rc3DryRunPlan {
        uint256 chainId;
        bool baseSepoliaConfirmed;
        bool broadcastRequested;
        bool simulationOnly;
        uint256 simulatedActionsPlanned;
        address sepoliaDeployer;
        uint64 sepoliaDeployerNonce;
        address sepoliaAdminWallet;
        address sepoliaProtocolBudgetWallet;
        address sepoliaCreate2DeployerOwner;
        address poolManager;
        address stateView;
        address usdcToken;
        uint8 usdcDecimals;
        uint256 moonLaunchTime;
        address predictedSunToken;
        address predictedSunCurve;
        address predictedMoonToken;
        address predictedMoonCurve;
        address predictedCreate2HookDeployer;
        address sunTokenSimulation;
        address sunCurveSimulation;
        address moonTokenSimulation;
        address moonCurveSimulation;
        address create2HookDeployerSimulation;
        uint160 expectedHookMask;
        uint160 actualHookMask;
        bytes32 initCodeHash;
        bytes32 hookSalt;
        address predictedHook;
        address deployedHookSimulation;
        PoolKey sunUsdcPoolKey;
        bytes32 sunUsdcPoolId;
        bytes32 expectedSunUsdcPoolId;
        uint256 sunUsdcInitialTokenAmount;
        uint256 sunUsdcInitialUsdcAmount;
        int24 sunUsdcInitialTick;
        uint160 sunUsdcSqrtPriceX96;
        uint160 sunUsdcSqrtPriceBefore;
        uint160 sunUsdcSqrtPriceAfter;
        PoolKey moonUsdcPoolKey;
        bytes32 moonUsdcPoolId;
        bytes32 expectedMoonUsdcPoolId;
        uint256 moonUsdcInitialTokenAmount;
        uint256 moonUsdcInitialUsdcAmount;
        int24 moonUsdcInitialTick;
        uint160 moonUsdcSqrtPriceX96;
        uint160 moonUsdcSqrtPriceBefore;
        uint160 moonUsdcSqrtPriceAfter;
        bool sunUsdcAllowedAfter;
        bool moonUsdcAllowedAfter;
        address ownerBeforeRenounce;
        address ownerAfterRenounce;
        bool renounceBlocksSunAllowlist;
        bool renounceBlocksMoonAllowlist;
        bool renounceBlocksProtocolBudget;
    }

    error BaseMainnetNotAllowed(uint256 chainId);
    error BaseSepoliaRc3DryRunNotConfirmed(uint256 chainId);
    error BaseSepoliaUnexpectedAddress(bytes32 label, address expected, address actual);
    error BroadcastNotAllowed();
    error DependencyCodeMissing(bytes32 label, address target);
    error DuplicateAddress(bytes32 leftLabel, bytes32 rightLabel, address value);
    error HookDeploymentMismatch(address expected, address actual);
    error InvalidAddress(bytes32 label);
    error InvalidInitialPrice(bytes32 label, uint256 tokenAmount, uint256 usdcAmount);
    error InvalidPoolConfig(bytes32 label, uint24 fee, int24 tickSpacing);
    error RenounceGuardFailed(bytes32 label);
    error SaltNotFound(uint256 startSalt, uint256 maxIterations);
    error UnexpectedHookMask(uint160 expectedMask, uint160 actualMask);
    error UnexpectedPoolId(bytes32 label, bytes32 expected, bytes32 actual);
    error UnsupportedChain(uint256 chainId);
    error UsdcDecimalsMismatch(uint8 expected, uint8 actual);

    function run() external returns (Rc3DryRunPlan memory plan) {
        plan = _prepare(_loadConfig());
    }

    function prepare(Rc3DryRunConfig memory config) external returns (Rc3DryRunPlan memory plan) {
        plan = _prepare(config);
    }

    function _loadConfig() private view returns (Rc3DryRunConfig memory config) {
        bool localSimulation = block.chainid == LOCAL_SIMULATION_CHAIN_ID;
        config = Rc3DryRunConfig({
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
                "STATE_VIEW", localSimulation ? address(0) : BaseV4Addresses.BASE_SEPOLIA_STATE_VIEW
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
            baseSepoliaConfirmed: vm.envOr("CONFIRM_BASE_SEPOLIA_RC3_DRY_RUN", uint256(0)) == 1,
            broadcastRequested: vm.envOr("EXECUTE_BASE_SEPOLIA_RC3_BROADCAST", uint256(0)) == 1
        });
    }

    function _prepare(Rc3DryRunConfig memory config) private returns (Rc3DryRunPlan memory plan) {
        _validateConfig(config);
        _prepareInfrastructure(config);

        plan.chainId = block.chainid;
        plan.baseSepoliaConfirmed = config.baseSepoliaConfirmed;
        plan.broadcastRequested = config.broadcastRequested;
        plan.simulationOnly = true;
        plan.simulatedActionsPlanned = SIMULATED_ACTIONS_PLANNED;
        plan.sepoliaDeployer = config.sepoliaDeployer;
        plan.sepoliaDeployerNonce = vm.getNonce(config.sepoliaDeployer);
        plan.sepoliaAdminWallet = config.sepoliaAdminWallet;
        plan.sepoliaProtocolBudgetWallet = config.sepoliaProtocolBudgetWallet;
        plan.sepoliaCreate2DeployerOwner = config.sepoliaCreate2DeployerOwner;
        plan.poolManager = config.poolManager;
        plan.stateView = config.stateView;
        plan.usdcToken = config.usdcToken;
        plan.usdcDecimals = IERC20Metadata(config.usdcToken).decimals();
        if (plan.usdcDecimals != 6) revert UsdcDecimalsMismatch(6, plan.usdcDecimals);
        plan.moonLaunchTime = block.timestamp + config.moonLaunchDelay;

        _preparePredictedCreateAddresses(config, plan);
        _deployCoreSimulation(config, plan);
        _deployHookSimulation(config, plan);
        _preparePoolIds(config, plan);
        _simulateAllowlistAndInitialize(config, plan);
        _simulateRenounce(config, plan);
        _logPlan(plan);
    }

    function _validateConfig(Rc3DryRunConfig memory config) private view {
        if (config.broadcastRequested) revert BroadcastNotAllowed();
        if (block.chainid == BaseV4Addresses.BASE_MAINNET_CHAIN_ID) {
            revert BaseMainnetNotAllowed(block.chainid);
        }
        if (block.chainid == BaseV4Addresses.BASE_SEPOLIA_CHAIN_ID && !config.baseSepoliaConfirmed)
        {
            revert BaseSepoliaRc3DryRunNotConfirmed(block.chainid);
        }
        if (
            block.chainid != LOCAL_SIMULATION_CHAIN_ID
                && block.chainid != BaseV4Addresses.BASE_SEPOLIA_CHAIN_ID
        ) {
            revert UnsupportedChain(block.chainid);
        }

        _requireAddress(config.sepoliaDeployer, LABEL_SEPOLIA_DEPLOYER);
        _requireAddress(config.sepoliaAdminWallet, LABEL_SEPOLIA_ADMIN_WALLET);
        _requireAddress(config.sepoliaProtocolBudgetWallet, LABEL_SEPOLIA_PROTOCOL_BUDGET_WALLET);
        _requireAddress(config.sepoliaCreate2DeployerOwner, LABEL_SEPOLIA_CREATE2_DEPLOYER_OWNER);
        _requireDistinct(
            config.sepoliaAdminWallet,
            LABEL_SEPOLIA_ADMIN_WALLET,
            config.sepoliaProtocolBudgetWallet,
            LABEL_SEPOLIA_PROTOCOL_BUDGET_WALLET
        );
        _requireDistinct(
            config.sepoliaDeployer,
            LABEL_SEPOLIA_DEPLOYER,
            config.sepoliaProtocolBudgetWallet,
            LABEL_SEPOLIA_PROTOCOL_BUDGET_WALLET
        );
        _requirePoolConfig(LABEL_SUN_POOL, config.sunUsdcFee, config.sunUsdcTickSpacing);
        _requirePoolConfig(LABEL_MOON_POOL, config.moonUsdcFee, config.moonUsdcTickSpacing);
        _requireInitialPrice(
            LABEL_SUN_PRICE, config.sunUsdcInitialTokenAmount, config.sunUsdcInitialUsdcAmount
        );
        _requireInitialPrice(
            LABEL_MOON_PRICE, config.moonUsdcInitialTokenAmount, config.moonUsdcInitialUsdcAmount
        );
        if (config.hookMaxSaltSearch == 0) {
            revert SaltNotFound(config.hookSaltStart, config.hookMaxSaltSearch);
        }

        if (block.chainid == BaseV4Addresses.BASE_SEPOLIA_CHAIN_ID) {
            _requireOfficialSepoliaAddress(
                LABEL_POOL_MANAGER, BaseV4Addresses.BASE_SEPOLIA_POOL_MANAGER, config.poolManager
            );
            _requireOfficialSepoliaAddress(
                LABEL_STATE_VIEW, BaseV4Addresses.BASE_SEPOLIA_STATE_VIEW, config.stateView
            );
            _requireOfficialSepoliaAddress(
                LABEL_USDC_TOKEN, BaseV4Addresses.BASE_SEPOLIA_USDC, config.usdcToken
            );
        }
    }

    function _prepareInfrastructure(Rc3DryRunConfig memory config) private {
        if (block.chainid == LOCAL_SIMULATION_CHAIN_ID) {
            if (config.poolManager == address(0) || config.poolManager.code.length == 0) {
                PoolManager poolManager = new PoolManager(config.sepoliaAdminWallet);
                config.poolManager = address(poolManager);
            }
            if (config.stateView == address(0) || config.stateView.code.length == 0) {
                StateView stateView = new StateView(IPoolManager(config.poolManager));
                config.stateView = address(stateView);
            }
            if (config.usdcToken == address(0) || config.usdcToken.code.length == 0) {
                MockUSDT mockUsdc = new MockUSDT("Mock Base Sepolia USDC", "USDC", 6);
                config.usdcToken = address(mockUsdc);
            }
        }

        _requireCode(LABEL_POOL_MANAGER, config.poolManager);
        _requireCode(LABEL_STATE_VIEW, config.stateView);
        _requireCode(LABEL_USDC_TOKEN, config.usdcToken);
    }

    function _preparePredictedCreateAddresses(
        Rc3DryRunConfig memory config,
        Rc3DryRunPlan memory plan
    ) private pure {
        uint64 nonce = plan.sepoliaDeployerNonce;
        plan.predictedSunToken = vm.computeCreateAddress(config.sepoliaDeployer, nonce);
        plan.predictedSunCurve = vm.computeCreateAddress(config.sepoliaDeployer, nonce + 1);
        plan.predictedMoonToken = vm.computeCreateAddress(config.sepoliaDeployer, nonce + 2);
        plan.predictedMoonCurve = vm.computeCreateAddress(config.sepoliaDeployer, nonce + 3);
        plan.predictedCreate2HookDeployer =
            vm.computeCreateAddress(config.sepoliaDeployer, nonce + 4);
    }

    function _deployCoreSimulation(Rc3DryRunConfig memory config, Rc3DryRunPlan memory plan)
        private
    {
        address temporaryOwner = config.sepoliaDeployer;

        SunToken sunToken = new SunToken("SUN", "SUN", temporaryOwner);
        SunCurve sunCurve = new SunCurve(
            sunToken,
            IERC20Metadata(config.usdcToken),
            config.sepoliaProtocolBudgetWallet,
            SUN_MAX_MINT_USDC,
            temporaryOwner
        );
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

        vm.deal(temporaryOwner, 1 ether);
        vm.startPrank(temporaryOwner);
        sunToken.setMinter(address(sunCurve));
        sunCurve.setMoonCurve(address(moonCurve));
        moonToken.setMinter(address(moonCurve));
        sunToken.transferOwnership(config.sepoliaAdminWallet);
        sunCurve.transferOwnership(config.sepoliaAdminWallet);
        moonToken.transferOwnership(config.sepoliaAdminWallet);
        moonCurve.transferOwnership(config.sepoliaAdminWallet);
        vm.stopPrank();

        plan.sunTokenSimulation = address(sunToken);
        plan.sunCurveSimulation = address(sunCurve);
        plan.moonTokenSimulation = address(moonToken);
        plan.moonCurveSimulation = address(moonCurve);
        plan.create2HookDeployerSimulation = address(create2Deployer);
    }

    function _deployHookSimulation(Rc3DryRunConfig memory config, Rc3DryRunPlan memory plan)
        private
    {
        bytes memory initCode = _hookInitCode(config, plan);
        plan.initCodeHash = keccak256(initCode);
        plan.expectedHookMask = BaseV4HookAddressMiner.BASE_SUN_MOON_USDC_FEE_V4_HOOK_MASK;

        bool found;
        (plan.hookSalt, plan.predictedHook, found) = BaseV4HookAddressMiner.mineSalt(
            plan.create2HookDeployerSimulation,
            plan.initCodeHash,
            plan.expectedHookMask,
            config.hookSaltStart,
            config.hookMaxSaltSearch
        );
        if (!found) revert SaltNotFound(config.hookSaltStart, config.hookMaxSaltSearch);

        plan.actualHookMask = uint160(plan.predictedHook) & BaseV4HookAddressMiner.V4_ALL_HOOK_MASK;
        if (plan.actualHookMask != plan.expectedHookMask) {
            revert UnexpectedHookMask(plan.expectedHookMask, plan.actualHookMask);
        }

        vm.prank(config.sepoliaCreate2DeployerOwner);
        plan.deployedHookSimulation = Create2HookDeployer(plan.create2HookDeployerSimulation)
            .deployHook(plan.hookSalt, initCode, plan.expectedHookMask);
        if (plan.deployedHookSimulation != plan.predictedHook) {
            revert HookDeploymentMismatch(plan.predictedHook, plan.deployedHookSimulation);
        }

        BaseSunMoonUsdcFeeV4Hook hook = BaseSunMoonUsdcFeeV4Hook(plan.deployedHookSimulation);
        require(address(hook.poolManager()) == config.poolManager, "pool manager mismatch");
        require(hook.sunToken() == plan.sunTokenSimulation, "SUN token mismatch");
        require(hook.moonToken() == plan.moonTokenSimulation, "MOON token mismatch");
        require(address(hook.usdc()) == config.usdcToken, "USDC mismatch");
        require(address(hook.sunCurve()) == plan.sunCurveSimulation, "SunCurve mismatch");
        require(hook.protocolBudget() == config.sepoliaProtocolBudgetWallet, "budget mismatch");
        require(hook.owner() == config.sepoliaAdminWallet, "owner mismatch");

        vm.prank(config.sepoliaAdminWallet);
        SunCurve(plan.sunCurveSimulation).setMoonAMM(plan.deployedHookSimulation);
    }

    function _preparePoolIds(Rc3DryRunConfig memory config, Rc3DryRunPlan memory plan)
        private
        pure
    {
        plan.sunUsdcPoolKey = _poolKey(
            plan.sunTokenSimulation,
            config.usdcToken,
            IHooks(plan.predictedHook),
            config.sunUsdcFee,
            config.sunUsdcTickSpacing
        );
        plan.sunUsdcPoolId = PoolId.unwrap(plan.sunUsdcPoolKey.toId());
        plan.expectedSunUsdcPoolId = config.expectedSunUsdcPoolId;
        if (
            config.expectedSunUsdcPoolId != bytes32(0)
                && plan.sunUsdcPoolId != config.expectedSunUsdcPoolId
        ) {
            revert UnexpectedPoolId(
                LABEL_SUN_POOL_ID, config.expectedSunUsdcPoolId, plan.sunUsdcPoolId
            );
        }
        plan.sunUsdcInitialTokenAmount = config.sunUsdcInitialTokenAmount;
        plan.sunUsdcInitialUsdcAmount = config.sunUsdcInitialUsdcAmount;
        plan.sunUsdcSqrtPriceX96 = _initialSqrtPriceX96(
            plan.sunUsdcPoolKey,
            plan.sunTokenSimulation,
            config.usdcToken,
            config.sunUsdcInitialTokenAmount,
            config.sunUsdcInitialUsdcAmount
        );
        plan.sunUsdcInitialTick = TickMath.getTickAtSqrtPrice(plan.sunUsdcSqrtPriceX96);

        plan.moonUsdcPoolKey = _poolKey(
            plan.moonTokenSimulation,
            config.usdcToken,
            IHooks(plan.predictedHook),
            config.moonUsdcFee,
            config.moonUsdcTickSpacing
        );
        plan.moonUsdcPoolId = PoolId.unwrap(plan.moonUsdcPoolKey.toId());
        plan.expectedMoonUsdcPoolId = config.expectedMoonUsdcPoolId;
        if (
            config.expectedMoonUsdcPoolId != bytes32(0)
                && plan.moonUsdcPoolId != config.expectedMoonUsdcPoolId
        ) {
            revert UnexpectedPoolId(
                LABEL_MOON_POOL_ID, config.expectedMoonUsdcPoolId, plan.moonUsdcPoolId
            );
        }
        plan.moonUsdcInitialTokenAmount = config.moonUsdcInitialTokenAmount;
        plan.moonUsdcInitialUsdcAmount = config.moonUsdcInitialUsdcAmount;
        plan.moonUsdcSqrtPriceX96 = _initialSqrtPriceX96(
            plan.moonUsdcPoolKey,
            plan.moonTokenSimulation,
            config.usdcToken,
            config.moonUsdcInitialTokenAmount,
            config.moonUsdcInitialUsdcAmount
        );
        plan.moonUsdcInitialTick = TickMath.getTickAtSqrtPrice(plan.moonUsdcSqrtPriceX96);

        if (plan.sunUsdcPoolId == plan.moonUsdcPoolId) {
            revert DuplicateAddress(LABEL_SUN_POOL, LABEL_MOON_POOL, plan.predictedHook);
        }
    }

    function _simulateAllowlistAndInitialize(
        Rc3DryRunConfig memory config,
        Rc3DryRunPlan memory plan
    ) private {
        BaseSunMoonUsdcFeeV4Hook hook = BaseSunMoonUsdcFeeV4Hook(plan.deployedHookSimulation);

        vm.startPrank(config.sepoliaAdminWallet);
        hook.setAllowedSunUsdcPool(plan.sunUsdcPoolId, true);
        hook.setAllowedMoonUsdcPool(plan.moonUsdcPoolId, true);
        vm.stopPrank();

        plan.sunUsdcAllowedAfter = hook.allowedSunUsdcPools(plan.sunUsdcPoolId);
        plan.moonUsdcAllowedAfter = hook.allowedMoonUsdcPools(plan.moonUsdcPoolId);

        IStateView stateView = IStateView(config.stateView);
        (plan.sunUsdcSqrtPriceBefore,,,) = stateView.getSlot0(PoolId.wrap(plan.sunUsdcPoolId));
        vm.prank(config.sepoliaAdminWallet);
        IPoolManager(config.poolManager).initialize(plan.sunUsdcPoolKey, plan.sunUsdcSqrtPriceX96);
        (plan.sunUsdcSqrtPriceAfter,,,) = stateView.getSlot0(PoolId.wrap(plan.sunUsdcPoolId));

        (plan.moonUsdcSqrtPriceBefore,,,) = stateView.getSlot0(PoolId.wrap(plan.moonUsdcPoolId));
        vm.prank(config.sepoliaAdminWallet);
        IPoolManager(config.poolManager).initialize(plan.moonUsdcPoolKey, plan.moonUsdcSqrtPriceX96);
        (plan.moonUsdcSqrtPriceAfter,,,) = stateView.getSlot0(PoolId.wrap(plan.moonUsdcPoolId));
    }

    function _simulateRenounce(Rc3DryRunConfig memory config, Rc3DryRunPlan memory plan) private {
        BaseSunMoonUsdcFeeV4Hook hook = BaseSunMoonUsdcFeeV4Hook(plan.deployedHookSimulation);
        plan.ownerBeforeRenounce = hook.owner();

        vm.prank(config.sepoliaAdminWallet);
        hook.renounceOwnership();

        plan.ownerAfterRenounce = hook.owner();
        plan.renounceBlocksSunAllowlist = _renounceBlocksSunAllowlist(hook, config);
        plan.renounceBlocksMoonAllowlist = _renounceBlocksMoonAllowlist(hook, config);
        plan.renounceBlocksProtocolBudget = _renounceBlocksProtocolBudget(hook, config);

        if (plan.ownerAfterRenounce != address(0)) {
            revert RenounceGuardFailed(LABEL_SEPOLIA_ADMIN_WALLET);
        }
        if (!plan.renounceBlocksSunAllowlist || !plan.renounceBlocksMoonAllowlist) {
            revert RenounceGuardFailed(LABEL_SUN_POOL);
        }
        if (!plan.renounceBlocksProtocolBudget) {
            revert RenounceGuardFailed(LABEL_SEPOLIA_PROTOCOL_BUDGET_WALLET);
        }
    }

    function _renounceBlocksSunAllowlist(
        BaseSunMoonUsdcFeeV4Hook hook,
        Rc3DryRunConfig memory config
    ) private returns (bool blocked) {
        vm.prank(config.sepoliaAdminWallet);
        try hook.setAllowedSunUsdcPool(bytes32(uint256(1)), true) {
            blocked = false;
        } catch {
            blocked = true;
        }
    }

    function _renounceBlocksMoonAllowlist(
        BaseSunMoonUsdcFeeV4Hook hook,
        Rc3DryRunConfig memory config
    ) private returns (bool blocked) {
        vm.prank(config.sepoliaAdminWallet);
        try hook.setAllowedMoonUsdcPool(bytes32(uint256(2)), true) {
            blocked = false;
        } catch {
            blocked = true;
        }
    }

    function _renounceBlocksProtocolBudget(
        BaseSunMoonUsdcFeeV4Hook hook,
        Rc3DryRunConfig memory config
    ) private returns (bool blocked) {
        vm.prank(config.sepoliaAdminWallet);
        try hook.setProtocolBudget(config.sepoliaProtocolBudgetWallet) {
            blocked = false;
        } catch {
            blocked = true;
        }
    }

    function _hookInitCode(Rc3DryRunConfig memory config, Rc3DryRunPlan memory plan)
        private
        pure
        returns (bytes memory initCode)
    {
        initCode = abi.encodePacked(
            type(BaseSunMoonUsdcFeeV4Hook).creationCode,
            abi.encode(
                IPoolManager(config.poolManager),
                plan.sunTokenSimulation,
                plan.moonTokenSimulation,
                IERC20(config.usdcToken),
                SunCurve(plan.sunCurveSimulation),
                config.sepoliaProtocolBudgetWallet,
                config.sepoliaAdminWallet
            )
        );
    }

    function _poolKey(address tokenA, address tokenB, IHooks hooks, uint24 fee, int24 tickSpacing)
        private
        pure
        returns (PoolKey memory key)
    {
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

    function _initialSqrtPriceX96(
        PoolKey memory key,
        address token,
        address usdc,
        uint256 tokenAmount,
        uint256 usdcAmount
    ) private pure returns (uint160 sqrtPriceX96) {
        uint256 ratioNumerator;
        uint256 ratioDenominator;

        if (Currency.unwrap(key.currency0) == usdc && Currency.unwrap(key.currency1) == token) {
            ratioNumerator = tokenAmount;
            ratioDenominator = usdcAmount;
        } else if (
            Currency.unwrap(key.currency0) == token && Currency.unwrap(key.currency1) == usdc
        ) {
            ratioNumerator = usdcAmount;
            ratioDenominator = tokenAmount;
        } else {
            revert InvalidAddress("POOL_PRICE_TOKEN_ORDER");
        }

        sqrtPriceX96 = uint160(Math.sqrt(Math.mulDiv(ratioNumerator, Q192, ratioDenominator)));
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

    function _requirePoolConfig(bytes32 label, uint24 fee, int24 tickSpacing) private pure {
        if (fee != EXPECTED_POOL_FEE || tickSpacing != EXPECTED_TICK_SPACING) {
            revert InvalidPoolConfig(label, fee, tickSpacing);
        }
    }

    function _requireInitialPrice(bytes32 label, uint256 tokenAmount, uint256 usdcAmount)
        private
        pure
    {
        if (tokenAmount == 0 || usdcAmount == 0) {
            revert InvalidInitialPrice(label, tokenAmount, usdcAmount);
        }
    }

    function _requireOfficialSepoliaAddress(bytes32 label, address expected, address actual)
        private
        pure
    {
        if (actual != expected) {
            revert BaseSepoliaUnexpectedAddress(label, expected, actual);
        }
    }

    function _requireCode(bytes32 label, address target) private view {
        if (target.code.length == 0) revert DependencyCodeMissing(label, target);
    }

    function _logPlan(Rc3DryRunPlan memory plan) private pure {
        console2.log("Base Sepolia rc3 SUN/MOON USDC dry-run preparation");
        console2.log("simulationOnly:", plan.simulationOnly);
        console2.log("simulatedActionsPlanned:", plan.simulatedActionsPlanned);
        console2.log("chainId:", plan.chainId);
        console2.log("baseSepoliaConfirmed:", plan.baseSepoliaConfirmed);
        console2.log("broadcastRequested:", plan.broadcastRequested);
        console2.log("SEPOLIA_DEPLOYER:", plan.sepoliaDeployer);
        console2.log("SEPOLIA_DEPLOYER nonce:", plan.sepoliaDeployerNonce);
        console2.log("SEPOLIA_ADMIN_WALLET:", plan.sepoliaAdminWallet);
        console2.log("SEPOLIA_PROTOCOL_BUDGET_WALLET:", plan.sepoliaProtocolBudgetWallet);
        console2.log("SEPOLIA_CREATE2_DEPLOYER_OWNER:", plan.sepoliaCreate2DeployerOwner);
        console2.log("POOL_MANAGER:", plan.poolManager);
        console2.log("STATE_VIEW:", plan.stateView);
        console2.log("USDC_TOKEN:", plan.usdcToken);
        console2.log("USDC decimals:", plan.usdcDecimals);
        console2.log("moonLaunchTime:", plan.moonLaunchTime);
        console2.log("Predicted CREATE addresses if the deployer nonce does not change:");
        console2.log("PREDICTED_SUN_TOKEN:", plan.predictedSunToken);
        console2.log("PREDICTED_SUN_CURVE:", plan.predictedSunCurve);
        console2.log("PREDICTED_MOON_TOKEN:", plan.predictedMoonToken);
        console2.log("PREDICTED_MOON_CURVE:", plan.predictedMoonCurve);
        console2.log("PREDICTED_CREATE2_HOOK_DEPLOYER:", plan.predictedCreate2HookDeployer);
        console2.log("Simulation addresses are not broadcast addresses:");
        console2.log("SUN_TOKEN_SIMULATION:", plan.sunTokenSimulation);
        console2.log("SUN_CURVE_SIMULATION:", plan.sunCurveSimulation);
        console2.log("MOON_TOKEN_SIMULATION:", plan.moonTokenSimulation);
        console2.log("MOON_CURVE_SIMULATION:", plan.moonCurveSimulation);
        console2.log("CREATE2_DEPLOYER_SIMULATION:", plan.create2HookDeployerSimulation);
        console2.log("expectedHookMask:", plan.expectedHookMask);
        console2.log("actualLow14Bits:", plan.actualHookMask);
        console2.log("initCodeHash:");
        console2.logBytes32(plan.initCodeHash);
        console2.log("hookSalt:");
        console2.logBytes32(plan.hookSalt);
        console2.log("predictedHook:", plan.predictedHook);
        console2.log("deployedHookSimulation:", plan.deployedHookSimulation);
        console2.log("SUN/USDC poolId:");
        console2.logBytes32(plan.sunUsdcPoolId);
        console2.log("SUN/USDC expected poolId:");
        console2.logBytes32(plan.expectedSunUsdcPoolId);
        console2.log("SUN/USDC initialTick:", plan.sunUsdcInitialTick);
        console2.log("SUN/USDC sqrtPriceX96:", plan.sunUsdcSqrtPriceX96);
        console2.log("SUN/USDC sqrtPriceBefore:", plan.sunUsdcSqrtPriceBefore);
        console2.log("SUN/USDC sqrtPriceAfter:", plan.sunUsdcSqrtPriceAfter);
        console2.log("MOON/USDC poolId:");
        console2.logBytes32(plan.moonUsdcPoolId);
        console2.log("MOON/USDC expected poolId:");
        console2.logBytes32(plan.expectedMoonUsdcPoolId);
        console2.log("MOON/USDC initialTick:", plan.moonUsdcInitialTick);
        console2.log("MOON/USDC sqrtPriceX96:", plan.moonUsdcSqrtPriceX96);
        console2.log("MOON/USDC sqrtPriceBefore:", plan.moonUsdcSqrtPriceBefore);
        console2.log("MOON/USDC sqrtPriceAfter:", plan.moonUsdcSqrtPriceAfter);
        console2.log("sunUsdcAllowedAfter:", plan.sunUsdcAllowedAfter);
        console2.log("moonUsdcAllowedAfter:", plan.moonUsdcAllowedAfter);
        console2.log("ownerBeforeRenounce:", plan.ownerBeforeRenounce);
        console2.log("ownerAfterRenounce:", plan.ownerAfterRenounce);
        console2.log("renounceBlocksSunAllowlist:", plan.renounceBlocksSunAllowlist);
        console2.log("renounceBlocksMoonAllowlist:", plan.renounceBlocksMoonAllowlist);
        console2.log("renounceBlocksProtocolBudget:", plan.renounceBlocksProtocolBudget);
        console2.log("Next step:", "review output; still do not broadcast Base Sepolia");
    }
}
