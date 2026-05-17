// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { Script, console2 } from "forge-std/Script.sol";
import { IHooks } from "@uniswap/v4-core/src/interfaces/IHooks.sol";
import { IPoolManager } from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import { TickMath } from "@uniswap/v4-core/src/libraries/TickMath.sol";
import { Currency } from "@uniswap/v4-core/src/types/Currency.sol";
import { PoolId, PoolIdLibrary } from "@uniswap/v4-core/src/types/PoolId.sol";
import { PoolKey } from "@uniswap/v4-core/src/types/PoolKey.sol";
import { IStateView } from "@uniswap/v4-periphery/src/interfaces/IStateView.sol";
import { SunCurve } from "../contracts/SunCurve.sol";
import { BaseSunMoonUsdcFeeV4Hook } from "../contracts/hooks/base/BaseSunMoonUsdcFeeV4Hook.sol";
import { BaseV4Addresses } from "../contracts/hooks/base/BaseV4Addresses.sol";
import { BaseV4HookAddressMiner } from "../contracts/hooks/base/BaseV4HookAddressMiner.sol";
import { Create2HookDeployer } from "../contracts/hooks/base/Create2HookDeployer.sol";

contract PrepareBaseMainnetSunMoonUsdcForkDryRun is Script {
    using PoolIdLibrary for PoolKey;

    bytes32 internal constant LABEL_MAINNET_DEPLOYER = "MAINNET_DEPLOYER";
    bytes32 internal constant LABEL_MAINNET_ADMIN_WALLET = "MAINNET_ADMIN_WALLET";
    bytes32 internal constant LABEL_PROTOCOL_BUDGET_WALLET = "PROTOCOL_BUDGET_WALLET";
    bytes32 internal constant LABEL_CREATE2_DEPLOYER_OWNER = "CREATE2_DEPLOYER_OWNER";
    bytes32 internal constant LABEL_CREATE2_HOOK_DEPLOYER = "CREATE2_HOOK_DEPLOYER";
    bytes32 internal constant LABEL_POOL_MANAGER = "POOL_MANAGER";
    bytes32 internal constant LABEL_POSITION_MANAGER = "POSITION_MANAGER";
    bytes32 internal constant LABEL_STATE_VIEW = "STATE_VIEW";
    bytes32 internal constant LABEL_QUOTER = "QUOTER";
    bytes32 internal constant LABEL_UNIVERSAL_ROUTER = "UNIVERSAL_ROUTER";
    bytes32 internal constant LABEL_PERMIT2 = "PERMIT2";
    bytes32 internal constant LABEL_SUN_TOKEN = "SUN_TOKEN";
    bytes32 internal constant LABEL_MOON_TOKEN = "MOON_TOKEN";
    bytes32 internal constant LABEL_USDC_TOKEN = "USDC_TOKEN";
    bytes32 internal constant LABEL_SUN_CURVE = "SUN_CURVE";
    bytes32 internal constant LABEL_SUN_POOL = "SUN_USDC_POOL";
    bytes32 internal constant LABEL_MOON_POOL = "MOON_USDC_POOL";
    bytes32 internal constant LABEL_SUN_POOL_ID = "SUN_USDC_POOL_ID";
    bytes32 internal constant LABEL_MOON_POOL_ID = "MOON_USDC_POOL_ID";
    bytes32 internal constant LABEL_SUN_PRICE = "SUN_USDC_INITIAL_PRICE";
    bytes32 internal constant LABEL_MOON_PRICE = "MOON_USDC_INITIAL_PRICE";
    bytes32 internal constant LABEL_RENOUNCE_SUN_ALLOWLIST = "RENOUNCE_SUN_ALLOWLIST";
    bytes32 internal constant LABEL_RENOUNCE_MOON_ALLOWLIST = "RENOUNCE_MOON_ALLOWLIST";
    bytes32 internal constant LABEL_RENOUNCE_PROTOCOL_BUDGET = "RENOUNCE_PROTOCOL_BUDGET";

    uint24 internal constant EXPECTED_POOL_FEE = 3000;
    int24 internal constant EXPECTED_TICK_SPACING = 60;
    uint256 internal constant LOCAL_SIMULATION_CHAIN_ID = 31_337;
    uint256 internal constant Q192 = uint256(1) << 192;
    uint256 internal constant DEFAULT_TOKEN_UNIT = 1e18;
    uint256 internal constant DEFAULT_SUN_USDC_PRICE = 1e6;
    uint256 internal constant DEFAULT_MOON_USDC_PRICE = 240_000;
    address internal constant LOCAL_CREATE2_TEMPLATE_DEPLOYER =
        0x00000000000000000000000000000000000D2E10;

    struct ForkDryRunConfig {
        address mainnetDeployer;
        address mainnetAdminWallet;
        address protocolBudgetWallet;
        address create2DeployerOwner;
        address create2HookDeployer;
        address poolManager;
        address positionManager;
        address stateView;
        address quoter;
        address universalRouter;
        address permit2;
        address sunToken;
        address moonToken;
        address usdcToken;
        address sunCurve;
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
        bool baseMainnetConfirmed;
        bool broadcastRequested;
    }

    struct ForkDryRunPlan {
        uint256 chainId;
        bool baseMainnetConfirmed;
        bool broadcastRequested;
        bool simulationOnly;
        uint256 transactionsPlanned;
        address mainnetDeployer;
        address mainnetAdminWallet;
        address protocolBudgetWallet;
        address create2DeployerOwner;
        address create2HookDeployer;
        address poolManager;
        address stateView;
        address usdcToken;
        uint8 usdcDecimals;
        bool create2DeployerSimulated;
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
        int24 sunUsdcTickBefore;
        bool sunUsdcAlreadyInitialized;
        uint160 sunUsdcSqrtPriceAfter;
        int24 sunUsdcTickAfter;
        PoolKey moonUsdcPoolKey;
        bytes32 moonUsdcPoolId;
        bytes32 expectedMoonUsdcPoolId;
        uint256 moonUsdcInitialTokenAmount;
        uint256 moonUsdcInitialUsdcAmount;
        int24 moonUsdcInitialTick;
        uint160 moonUsdcSqrtPriceX96;
        uint160 moonUsdcSqrtPriceBefore;
        int24 moonUsdcTickBefore;
        bool moonUsdcAlreadyInitialized;
        uint160 moonUsdcSqrtPriceAfter;
        int24 moonUsdcTickAfter;
        bool sunUsdcAllowedBefore;
        bool moonUsdcAllowedBefore;
        bool sunUsdcAllowedAfter;
        bool moonUsdcAllowedAfter;
        address ownerBeforeRenounce;
        address ownerAfterRenounce;
        bool renounceBlocksSunAllowlist;
        bool renounceBlocksMoonAllowlist;
        bool renounceBlocksProtocolBudget;
    }

    error BaseMainnetForkDryRunNotConfirmed(uint256 chainId);
    error BaseMainnetUnexpectedAddress(bytes32 label, address expected, address actual);
    error BroadcastNotAllowed();
    error Create2OwnerMismatch(address expected, address actual);
    error DependencyCodeMissing(bytes32 label, address target);
    error DuplicateAddress(bytes32 leftLabel, bytes32 rightLabel, address value);
    error HookCodeMissing(address hook);
    error HookDeploymentMismatch(address expected, address actual);
    error InvalidAddress(bytes32 label);
    error InvalidInitialPrice(bytes32 label, uint256 tokenAmount, uint256 usdcAmount);
    error InvalidPoolConfig(bytes32 label, uint24 fee, int24 tickSpacing);
    error PoolNotInitialized(bytes32 poolId);
    error RenounceGuardFailed(bytes32 label);
    error SaltNotFound(uint256 startSalt, uint256 maxIterations);
    error UnexpectedInitializedPool(
        bytes32 poolId, uint160 expectedSqrtPriceX96, uint160 actualSqrtPriceX96
    );
    error UnexpectedHookMask(uint160 expectedMask, uint160 actualMask);
    error UnexpectedPoolId(bytes32 label, bytes32 expected, bytes32 actual);
    error UnsupportedChain(uint256 chainId);
    error UsdcDecimalsMismatch(uint8 expected, uint8 actual);

    function run() external returns (ForkDryRunPlan memory plan) {
        plan = _prepare(_loadConfig());
    }

    function prepare(ForkDryRunConfig memory config) external returns (ForkDryRunPlan memory plan) {
        plan = _prepare(config);
    }

    function _loadConfig() private view returns (ForkDryRunConfig memory config) {
        config = ForkDryRunConfig({
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
            create2HookDeployer: _requiredEnvAddress(
                "CREATE2_HOOK_DEPLOYER", LABEL_CREATE2_HOOK_DEPLOYER
            ),
            poolManager: vm.envOr("POOL_MANAGER", BaseV4Addresses.BASE_MAINNET_POOL_MANAGER),
            positionManager: vm.envOr(
                "POSITION_MANAGER", BaseV4Addresses.BASE_MAINNET_POSITION_MANAGER
            ),
            stateView: vm.envOr("STATE_VIEW", BaseV4Addresses.BASE_MAINNET_STATE_VIEW),
            quoter: vm.envOr("QUOTER", BaseV4Addresses.BASE_MAINNET_QUOTER),
            universalRouter: vm.envOr(
                "UNIVERSAL_ROUTER", BaseV4Addresses.BASE_MAINNET_UNIVERSAL_ROUTER
            ),
            permit2: vm.envOr("PERMIT2", BaseV4Addresses.PERMIT2),
            sunToken: _requiredEnvAddress("SUN_TOKEN", LABEL_SUN_TOKEN),
            moonToken: _requiredEnvAddress("MOON_TOKEN", LABEL_MOON_TOKEN),
            usdcToken: vm.envOr("USDC_TOKEN", BaseV4Addresses.BASE_MAINNET_USDC),
            sunCurve: _requiredEnvAddress("SUN_CURVE", LABEL_SUN_CURVE),
            sunUsdcFee: uint24(vm.envOr("SUN_USDC_POOL_FEE", uint256(EXPECTED_POOL_FEE))),
            sunUsdcTickSpacing: int24(
                vm.envOr("SUN_USDC_POOL_TICK_SPACING", int256(EXPECTED_TICK_SPACING))
            ),
            sunUsdcInitialTokenAmount: vm.envOr(
                "SUN_USDC_INITIAL_TOKEN_AMOUNT", DEFAULT_TOKEN_UNIT
            ),
            sunUsdcInitialUsdcAmount: vm.envOr(
                "SUN_USDC_INITIAL_USDC_AMOUNT", DEFAULT_SUN_USDC_PRICE
            ),
            expectedSunUsdcPoolId: vm.envOr("SUN_USDC_POOL_ID", bytes32(0)),
            moonUsdcFee: uint24(vm.envOr("MOON_USDC_POOL_FEE", uint256(EXPECTED_POOL_FEE))),
            moonUsdcTickSpacing: int24(
                vm.envOr("MOON_USDC_POOL_TICK_SPACING", int256(EXPECTED_TICK_SPACING))
            ),
            moonUsdcInitialTokenAmount: vm.envOr(
                "MOON_USDC_INITIAL_TOKEN_AMOUNT", DEFAULT_TOKEN_UNIT
            ),
            moonUsdcInitialUsdcAmount: vm.envOr(
                "MOON_USDC_INITIAL_USDC_AMOUNT", DEFAULT_MOON_USDC_PRICE
            ),
            expectedMoonUsdcPoolId: vm.envOr("MOON_USDC_POOL_ID", bytes32(0)),
            hookSaltStart: vm.envOr("HOOK_SALT_START", uint256(0)),
            hookMaxSaltSearch: vm.envOr("HOOK_MAX_SALT_SEARCH", uint256(200_000)),
            baseMainnetConfirmed: vm.envOr("CONFIRM_BASE_MAINNET_SUN_MOON_FORK_DRY_RUN", uint256(0))
                == 1,
            broadcastRequested: vm.envOr("EXECUTE_BASE_MAINNET_BROADCAST", uint256(0)) == 1
        });
    }

    function _prepare(ForkDryRunConfig memory config) private returns (ForkDryRunPlan memory plan) {
        bool create2DeployerSimulated = _validateConfig(config);

        plan.chainId = block.chainid;
        plan.baseMainnetConfirmed = config.baseMainnetConfirmed;
        plan.broadcastRequested = config.broadcastRequested;
        plan.simulationOnly = true;
        plan.mainnetDeployer = config.mainnetDeployer;
        plan.mainnetAdminWallet = config.mainnetAdminWallet;
        plan.protocolBudgetWallet = config.protocolBudgetWallet;
        plan.create2DeployerOwner = config.create2DeployerOwner;
        plan.create2HookDeployer = config.create2HookDeployer;
        plan.poolManager = config.poolManager;
        plan.stateView = config.stateView;
        plan.usdcToken = config.usdcToken;
        plan.create2DeployerSimulated = create2DeployerSimulated;
        plan.usdcDecimals = IERC20Metadata(config.usdcToken).decimals();
        if (plan.usdcDecimals != 6) revert UsdcDecimalsMismatch(6, plan.usdcDecimals);

        vm.deal(config.create2DeployerOwner, 1 ether);
        vm.deal(config.mainnetAdminWallet, 1 ether);

        bytes memory initCode = _hookInitCode(config);
        plan.initCodeHash = keccak256(initCode);
        plan.expectedHookMask = BaseV4HookAddressMiner.BASE_SUN_MOON_USDC_FEE_V4_HOOK_MASK;
        (plan.hookSalt, plan.predictedHook, plan.actualHookMask) =
            _mineHookAddress(config, plan.initCodeHash, plan.expectedHookMask);

        plan.deployedHookSimulation = _deployHookSimulation(config, initCode, plan);
        BaseSunMoonUsdcFeeV4Hook hook = BaseSunMoonUsdcFeeV4Hook(plan.deployedHookSimulation);

        _validateHookConstructorState(hook, config, plan.expectedHookMask);
        _preparePoolIds(config, plan);
        _simulateAllowlist(hook, config, plan);
        _simulatePoolInitialization(config, plan);
        _simulateRenounce(hook, config, plan);
        plan.transactionsPlanned = 4;
        if (!plan.sunUsdcAlreadyInitialized) plan.transactionsPlanned += 1;
        if (!plan.moonUsdcAlreadyInitialized) plan.transactionsPlanned += 1;
        _logPlan(plan);
    }

    function _validateConfig(ForkDryRunConfig memory config)
        private
        returns (bool create2DeployerSimulated)
    {
        if (config.broadcastRequested) revert BroadcastNotAllowed();

        _requireAddress(config.mainnetDeployer, LABEL_MAINNET_DEPLOYER);
        _requireAddress(config.mainnetAdminWallet, LABEL_MAINNET_ADMIN_WALLET);
        _requireAddress(config.protocolBudgetWallet, LABEL_PROTOCOL_BUDGET_WALLET);
        _requireAddress(config.create2DeployerOwner, LABEL_CREATE2_DEPLOYER_OWNER);
        _requireAddress(config.create2HookDeployer, LABEL_CREATE2_HOOK_DEPLOYER);
        _requireAddress(config.poolManager, LABEL_POOL_MANAGER);
        _requireAddress(config.positionManager, LABEL_POSITION_MANAGER);
        _requireAddress(config.stateView, LABEL_STATE_VIEW);
        _requireAddress(config.quoter, LABEL_QUOTER);
        _requireAddress(config.universalRouter, LABEL_UNIVERSAL_ROUTER);
        _requireAddress(config.permit2, LABEL_PERMIT2);
        _requireAddress(config.sunToken, LABEL_SUN_TOKEN);
        _requireAddress(config.moonToken, LABEL_MOON_TOKEN);
        _requireAddress(config.usdcToken, LABEL_USDC_TOKEN);
        _requireAddress(config.sunCurve, LABEL_SUN_CURVE);

        _requireDistinct(
            config.protocolBudgetWallet,
            LABEL_PROTOCOL_BUDGET_WALLET,
            config.mainnetAdminWallet,
            LABEL_MAINNET_ADMIN_WALLET
        );
        _requireDistinct(
            config.protocolBudgetWallet,
            LABEL_PROTOCOL_BUDGET_WALLET,
            config.mainnetDeployer,
            LABEL_MAINNET_DEPLOYER
        );
        _requireDistinct(
            config.protocolBudgetWallet,
            LABEL_PROTOCOL_BUDGET_WALLET,
            config.create2DeployerOwner,
            LABEL_CREATE2_DEPLOYER_OWNER
        );
        _requireDistinct(config.sunToken, LABEL_SUN_TOKEN, config.moonToken, LABEL_MOON_TOKEN);
        _requireDistinct(config.sunToken, LABEL_SUN_TOKEN, config.usdcToken, LABEL_USDC_TOKEN);
        _requireDistinct(config.moonToken, LABEL_MOON_TOKEN, config.usdcToken, LABEL_USDC_TOKEN);

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

        _validateChainAndDependencies(config);
        create2DeployerSimulated = _ensureCreate2DeployerCode(config);

        Create2HookDeployer create2Deployer = Create2HookDeployer(config.create2HookDeployer);
        address actualCreate2Owner = create2Deployer.owner();
        if (actualCreate2Owner != config.create2DeployerOwner) {
            revert Create2OwnerMismatch(config.create2DeployerOwner, actualCreate2Owner);
        }
    }

    function _validateChainAndDependencies(ForkDryRunConfig memory config) private view {
        _requireCode(LABEL_POOL_MANAGER, config.poolManager);
        _requireCode(LABEL_STATE_VIEW, config.stateView);
        _requireCode(LABEL_USDC_TOKEN, config.usdcToken);

        if (block.chainid == BaseV4Addresses.BASE_MAINNET_CHAIN_ID) {
            if (!config.baseMainnetConfirmed) {
                revert BaseMainnetForkDryRunNotConfirmed(block.chainid);
            }
            _requireOfficialMainnetAddress(
                LABEL_POOL_MANAGER, BaseV4Addresses.BASE_MAINNET_POOL_MANAGER, config.poolManager
            );
            _requireOfficialMainnetAddress(
                LABEL_POSITION_MANAGER,
                BaseV4Addresses.BASE_MAINNET_POSITION_MANAGER,
                config.positionManager
            );
            _requireOfficialMainnetAddress(
                LABEL_STATE_VIEW, BaseV4Addresses.BASE_MAINNET_STATE_VIEW, config.stateView
            );
            _requireOfficialMainnetAddress(
                LABEL_QUOTER, BaseV4Addresses.BASE_MAINNET_QUOTER, config.quoter
            );
            _requireOfficialMainnetAddress(
                LABEL_UNIVERSAL_ROUTER,
                BaseV4Addresses.BASE_MAINNET_UNIVERSAL_ROUTER,
                config.universalRouter
            );
            _requireOfficialMainnetAddress(
                LABEL_USDC_TOKEN, BaseV4Addresses.BASE_MAINNET_USDC, config.usdcToken
            );
            _requireOfficialMainnetAddress(LABEL_PERMIT2, BaseV4Addresses.PERMIT2, config.permit2);

            _requireCode(LABEL_POSITION_MANAGER, config.positionManager);
            _requireCode(LABEL_QUOTER, config.quoter);
            _requireCode(LABEL_UNIVERSAL_ROUTER, config.universalRouter);
            _requireCode(LABEL_PERMIT2, config.permit2);
        } else if (block.chainid != LOCAL_SIMULATION_CHAIN_ID) {
            revert UnsupportedChain(block.chainid);
        }
    }

    function _ensureCreate2DeployerCode(ForkDryRunConfig memory config)
        private
        returns (bool simulated)
    {
        if (config.create2HookDeployer.code.length != 0) return false;

        vm.deal(LOCAL_CREATE2_TEMPLATE_DEPLOYER, 1 ether);
        vm.prank(LOCAL_CREATE2_TEMPLATE_DEPLOYER);
        Create2HookDeployer template = new Create2HookDeployer(config.create2DeployerOwner);
        vm.etch(config.create2HookDeployer, address(template).code);
        _requireCode(LABEL_CREATE2_HOOK_DEPLOYER, config.create2HookDeployer);

        simulated = true;
    }

    function _hookInitCode(ForkDryRunConfig memory config)
        private
        pure
        returns (bytes memory initCode)
    {
        initCode = abi.encodePacked(
            type(BaseSunMoonUsdcFeeV4Hook).creationCode,
            abi.encode(
                IPoolManager(config.poolManager),
                config.sunToken,
                config.moonToken,
                IERC20(config.usdcToken),
                SunCurve(config.sunCurve),
                config.protocolBudgetWallet,
                config.mainnetAdminWallet
            )
        );
    }

    function _mineHookAddress(
        ForkDryRunConfig memory config,
        bytes32 initCodeHash,
        uint160 expectedHookMask
    ) private pure returns (bytes32 hookSalt, address predictedHook, uint160 actualHookMask) {
        bool found;
        (hookSalt, predictedHook, found) = BaseV4HookAddressMiner.mineSalt(
            config.create2HookDeployer,
            initCodeHash,
            expectedHookMask,
            config.hookSaltStart,
            config.hookMaxSaltSearch
        );
        if (!found) revert SaltNotFound(config.hookSaltStart, config.hookMaxSaltSearch);

        actualHookMask = uint160(predictedHook) & BaseV4HookAddressMiner.V4_ALL_HOOK_MASK;
        if (actualHookMask != expectedHookMask) {
            revert UnexpectedHookMask(expectedHookMask, actualHookMask);
        }
    }

    function _deployHookSimulation(
        ForkDryRunConfig memory config,
        bytes memory initCode,
        ForkDryRunPlan memory plan
    ) private returns (address deployedHook) {
        Create2HookDeployer create2Deployer = Create2HookDeployer(config.create2HookDeployer);
        address computed = create2Deployer.computeAddress(plan.hookSalt, plan.initCodeHash);
        if (computed != plan.predictedHook) {
            revert HookDeploymentMismatch(plan.predictedHook, computed);
        }

        vm.prank(config.create2DeployerOwner);
        deployedHook = create2Deployer.deployHook(plan.hookSalt, initCode, plan.expectedHookMask);
        if (deployedHook != plan.predictedHook) {
            revert HookDeploymentMismatch(plan.predictedHook, deployedHook);
        }
        if (deployedHook.code.length == 0) revert HookCodeMissing(deployedHook);
    }

    function _validateHookConstructorState(
        BaseSunMoonUsdcFeeV4Hook hook,
        ForkDryRunConfig memory config,
        uint160 expectedHookMask
    ) private view {
        require(address(hook.poolManager()) == config.poolManager, "pool manager mismatch");
        require(hook.sunToken() == config.sunToken, "SUN token mismatch");
        require(hook.moonToken() == config.moonToken, "MOON token mismatch");
        require(address(hook.usdc()) == config.usdcToken, "USDC mismatch");
        require(address(hook.sunCurve()) == config.sunCurve, "SunCurve mismatch");
        require(hook.protocolBudget() == config.protocolBudgetWallet, "protocol budget mismatch");
        require(hook.owner() == config.mainnetAdminWallet, "owner mismatch");
        require(hook.expectedHookMask() == expectedHookMask, "hook mask mismatch");
    }

    function _preparePoolIds(ForkDryRunConfig memory config, ForkDryRunPlan memory plan)
        private
        pure
    {
        plan.sunUsdcPoolKey = _poolKey(
            config.sunToken,
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
            config.sunToken,
            config.usdcToken,
            config.sunUsdcInitialTokenAmount,
            config.sunUsdcInitialUsdcAmount
        );
        plan.sunUsdcInitialTick = TickMath.getTickAtSqrtPrice(plan.sunUsdcSqrtPriceX96);

        plan.moonUsdcPoolKey = _poolKey(
            config.moonToken,
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
            config.moonToken,
            config.usdcToken,
            config.moonUsdcInitialTokenAmount,
            config.moonUsdcInitialUsdcAmount
        );
        plan.moonUsdcInitialTick = TickMath.getTickAtSqrtPrice(plan.moonUsdcSqrtPriceX96);

        if (plan.sunUsdcPoolId == plan.moonUsdcPoolId) {
            revert DuplicateAddress(LABEL_SUN_POOL, LABEL_MOON_POOL, plan.predictedHook);
        }
    }

    function _simulateAllowlist(
        BaseSunMoonUsdcFeeV4Hook hook,
        ForkDryRunConfig memory config,
        ForkDryRunPlan memory plan
    ) private {
        plan.ownerBeforeRenounce = hook.owner();
        plan.sunUsdcAllowedBefore = hook.allowedSunUsdcPools(plan.sunUsdcPoolId);
        plan.moonUsdcAllowedBefore = hook.allowedMoonUsdcPools(plan.moonUsdcPoolId);

        vm.startPrank(config.mainnetAdminWallet);
        hook.setAllowedSunUsdcPool(plan.sunUsdcPoolId, true);
        hook.setAllowedMoonUsdcPool(plan.moonUsdcPoolId, true);
        vm.stopPrank();

        plan.sunUsdcAllowedAfter = hook.allowedSunUsdcPools(plan.sunUsdcPoolId);
        plan.moonUsdcAllowedAfter = hook.allowedMoonUsdcPools(plan.moonUsdcPoolId);

        if (!plan.sunUsdcAllowedAfter || !plan.moonUsdcAllowedAfter) {
            revert RenounceGuardFailed(LABEL_SUN_POOL);
        }
    }

    function _simulatePoolInitialization(ForkDryRunConfig memory config, ForkDryRunPlan memory plan)
        private
    {
        IStateView stateView = IStateView(config.stateView);

        (plan.sunUsdcSqrtPriceBefore, plan.sunUsdcTickBefore,,) =
            stateView.getSlot0(PoolId.wrap(plan.sunUsdcPoolId));
        plan.sunUsdcAlreadyInitialized = plan.sunUsdcSqrtPriceBefore != 0;

        if (plan.sunUsdcAlreadyInitialized) {
            _requireExpectedInitializedPool(
                plan.sunUsdcPoolId, plan.sunUsdcSqrtPriceX96, plan.sunUsdcSqrtPriceBefore
            );
        } else {
            vm.prank(config.mainnetAdminWallet);
            plan.sunUsdcTickAfter = IPoolManager(config.poolManager)
                .initialize(plan.sunUsdcPoolKey, plan.sunUsdcSqrtPriceX96);
        }

        (plan.sunUsdcSqrtPriceAfter, plan.sunUsdcTickAfter,,) =
            stateView.getSlot0(PoolId.wrap(plan.sunUsdcPoolId));
        _requireInitializedPool(
            plan.sunUsdcPoolId, plan.sunUsdcSqrtPriceX96, plan.sunUsdcSqrtPriceAfter
        );

        (plan.moonUsdcSqrtPriceBefore, plan.moonUsdcTickBefore,,) =
            stateView.getSlot0(PoolId.wrap(plan.moonUsdcPoolId));
        plan.moonUsdcAlreadyInitialized = plan.moonUsdcSqrtPriceBefore != 0;

        if (plan.moonUsdcAlreadyInitialized) {
            _requireExpectedInitializedPool(
                plan.moonUsdcPoolId, plan.moonUsdcSqrtPriceX96, plan.moonUsdcSqrtPriceBefore
            );
        } else {
            vm.prank(config.mainnetAdminWallet);
            plan.moonUsdcTickAfter = IPoolManager(config.poolManager)
                .initialize(plan.moonUsdcPoolKey, plan.moonUsdcSqrtPriceX96);
        }

        (plan.moonUsdcSqrtPriceAfter, plan.moonUsdcTickAfter,,) =
            stateView.getSlot0(PoolId.wrap(plan.moonUsdcPoolId));
        _requireInitializedPool(
            plan.moonUsdcPoolId, plan.moonUsdcSqrtPriceX96, plan.moonUsdcSqrtPriceAfter
        );
    }

    function _simulateRenounce(
        BaseSunMoonUsdcFeeV4Hook hook,
        ForkDryRunConfig memory config,
        ForkDryRunPlan memory plan
    ) private {
        vm.prank(config.mainnetAdminWallet);
        hook.renounceOwnership();

        plan.ownerAfterRenounce = hook.owner();
        if (plan.ownerAfterRenounce != address(0)) {
            revert RenounceGuardFailed(LABEL_MAINNET_ADMIN_WALLET);
        }

        plan.renounceBlocksSunAllowlist =
            _renounceBlocksSunAllowlist(hook, config.mainnetAdminWallet);
        plan.renounceBlocksMoonAllowlist =
            _renounceBlocksMoonAllowlist(hook, config.mainnetAdminWallet);
        plan.renounceBlocksProtocolBudget = _renounceBlocksProtocolBudget(
            hook, config.mainnetAdminWallet, config.protocolBudgetWallet
        );

        if (!plan.renounceBlocksSunAllowlist) {
            revert RenounceGuardFailed(LABEL_RENOUNCE_SUN_ALLOWLIST);
        }
        if (!plan.renounceBlocksMoonAllowlist) {
            revert RenounceGuardFailed(LABEL_RENOUNCE_MOON_ALLOWLIST);
        }
        if (!plan.renounceBlocksProtocolBudget) {
            revert RenounceGuardFailed(LABEL_RENOUNCE_PROTOCOL_BUDGET);
        }
    }

    function _renounceBlocksSunAllowlist(BaseSunMoonUsdcFeeV4Hook hook, address formerOwner)
        private
        returns (bool blocked)
    {
        vm.prank(formerOwner);
        try hook.setAllowedSunUsdcPool(bytes32(uint256(1)), true) {
            blocked = false;
        } catch {
            blocked = true;
        }
    }

    function _renounceBlocksMoonAllowlist(BaseSunMoonUsdcFeeV4Hook hook, address formerOwner)
        private
        returns (bool blocked)
    {
        vm.prank(formerOwner);
        try hook.setAllowedMoonUsdcPool(bytes32(uint256(2)), true) {
            blocked = false;
        } catch {
            blocked = true;
        }
    }

    function _renounceBlocksProtocolBudget(
        BaseSunMoonUsdcFeeV4Hook hook,
        address formerOwner,
        address protocolBudgetWallet
    ) private returns (bool blocked) {
        vm.prank(formerOwner);
        try hook.setProtocolBudget(protocolBudgetWallet) {
            blocked = false;
        } catch {
            blocked = true;
        }
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

    function _requireExpectedInitializedPool(
        bytes32 poolId,
        uint160 expectedSqrtPriceX96,
        uint160 actualSqrtPriceX96
    ) private pure {
        if (actualSqrtPriceX96 != expectedSqrtPriceX96) {
            revert UnexpectedInitializedPool(poolId, expectedSqrtPriceX96, actualSqrtPriceX96);
        }
    }

    function _requireInitializedPool(
        bytes32 poolId,
        uint160 expectedSqrtPriceX96,
        uint160 actualSqrtPriceX96
    ) private pure {
        if (actualSqrtPriceX96 == 0) {
            revert PoolNotInitialized(poolId);
        }
        _requireExpectedInitializedPool(poolId, expectedSqrtPriceX96, actualSqrtPriceX96);
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

    function _logPlan(ForkDryRunPlan memory plan) private pure {
        console2.log("Base mainnet SUN/MOON USDC fork dry-run preparation");
        console2.log("simulationOnly:", plan.simulationOnly);
        console2.log("transactionsPlanned:", plan.transactionsPlanned);
        console2.log("chainId:", plan.chainId);
        console2.log("baseMainnetConfirmed:", plan.baseMainnetConfirmed);
        console2.log("broadcastRequested:", plan.broadcastRequested);
        console2.log("MAINNET_DEPLOYER:", plan.mainnetDeployer);
        console2.log("MAINNET_ADMIN_WALLET:", plan.mainnetAdminWallet);
        console2.log("PROTOCOL_BUDGET_WALLET:", plan.protocolBudgetWallet);
        console2.log("CREATE2_DEPLOYER_OWNER:", plan.create2DeployerOwner);
        console2.log("CREATE2_HOOK_DEPLOYER:", plan.create2HookDeployer);
        console2.log("create2DeployerSimulated:", plan.create2DeployerSimulated);
        console2.log("POOL_MANAGER:", plan.poolManager);
        console2.log("STATE_VIEW:", plan.stateView);
        console2.log("USDC_TOKEN:", plan.usdcToken);
        console2.log("USDC decimals:", plan.usdcDecimals);
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
        console2.log("SUN/USDC initial token amount:", plan.sunUsdcInitialTokenAmount);
        console2.log("SUN/USDC initial USDC amount:", plan.sunUsdcInitialUsdcAmount);
        console2.log("SUN/USDC initialTick:", plan.sunUsdcInitialTick);
        console2.log("SUN/USDC sqrtPriceX96:", plan.sunUsdcSqrtPriceX96);
        console2.log("SUN/USDC sqrtPriceBefore:", plan.sunUsdcSqrtPriceBefore);
        console2.log("SUN/USDC tickBefore:", plan.sunUsdcTickBefore);
        console2.log("SUN/USDC alreadyInitialized:", plan.sunUsdcAlreadyInitialized);
        console2.log("SUN/USDC sqrtPriceAfter:", plan.sunUsdcSqrtPriceAfter);
        console2.log("SUN/USDC tickAfter:", plan.sunUsdcTickAfter);
        console2.log("MOON/USDC poolId:");
        console2.logBytes32(plan.moonUsdcPoolId);
        console2.log("MOON/USDC expected poolId:");
        console2.logBytes32(plan.expectedMoonUsdcPoolId);
        console2.log("MOON/USDC initial token amount:", plan.moonUsdcInitialTokenAmount);
        console2.log("MOON/USDC initial USDC amount:", plan.moonUsdcInitialUsdcAmount);
        console2.log("MOON/USDC initialTick:", plan.moonUsdcInitialTick);
        console2.log("MOON/USDC sqrtPriceX96:", plan.moonUsdcSqrtPriceX96);
        console2.log("MOON/USDC sqrtPriceBefore:", plan.moonUsdcSqrtPriceBefore);
        console2.log("MOON/USDC tickBefore:", plan.moonUsdcTickBefore);
        console2.log("MOON/USDC alreadyInitialized:", plan.moonUsdcAlreadyInitialized);
        console2.log("MOON/USDC sqrtPriceAfter:", plan.moonUsdcSqrtPriceAfter);
        console2.log("MOON/USDC tickAfter:", plan.moonUsdcTickAfter);
        console2.log("ownerBeforeRenounce:", plan.ownerBeforeRenounce);
        console2.log("ownerAfterRenounce:", plan.ownerAfterRenounce);
        console2.log("renounceBlocksSunAllowlist:", plan.renounceBlocksSunAllowlist);
        console2.log("renounceBlocksMoonAllowlist:", plan.renounceBlocksMoonAllowlist);
        console2.log("renounceBlocksProtocolBudget:", plan.renounceBlocksProtocolBudget);
        console2.log("Next step:", "review output; do not broadcast mainnet");
    }
}
