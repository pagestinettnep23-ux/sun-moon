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
import { MoonCurve } from "../contracts/MoonCurve.sol";
import { MoonToken } from "../contracts/MoonToken.sol";
import { SunCurve } from "../contracts/SunCurve.sol";
import { SunToken } from "../contracts/SunToken.sol";
import { BaseSunMoonUsdcFeeV4Hook } from "../contracts/hooks/base/BaseSunMoonUsdcFeeV4Hook.sol";
import { BaseV4Addresses } from "../contracts/hooks/base/BaseV4Addresses.sol";
import { BaseV4HookAddressMiner } from "../contracts/hooks/base/BaseV4HookAddressMiner.sol";
import { Create2HookDeployer } from "../contracts/hooks/base/Create2HookDeployer.sol";

interface IOwnableTransfer {
    function transferOwnership(address newOwner) external;
}

contract PrepareBaseMainnetSunMoonUsdcBroadcastDraft is Script {
    using PoolIdLibrary for PoolKey;

    bytes32 internal constant LABEL_SUN_TOKEN = "SUN_TOKEN";
    bytes32 internal constant LABEL_SUN_CURVE = "SUN_CURVE";
    bytes32 internal constant LABEL_MOON_TOKEN = "MOON_TOKEN";
    bytes32 internal constant LABEL_MOON_CURVE = "MOON_CURVE";
    bytes32 internal constant LABEL_CREATE2_HOOK_DEPLOYER = "CREATE2_HOOK_DEPLOYER";
    bytes32 internal constant LABEL_HOOK_SALT = "HOOK_SALT";
    bytes32 internal constant LABEL_PREDICTED_HOOK = "PREDICTED_HOOK";

    uint24 internal constant EXPECTED_POOL_FEE = 3000;
    int24 internal constant EXPECTED_TICK_SPACING = 60;
    uint256 internal constant LOCAL_SIMULATION_CHAIN_ID = 31_337;
    uint256 internal constant Q192 = uint256(1) << 192;
    uint256 internal constant USDC_ONE = 1e6;
    uint256 internal constant TOKEN_ONE = 1e18;
    uint256 internal constant DEFAULT_SUN_USDC_PRICE = 1e6;
    uint256 internal constant DEFAULT_MOON_USDC_PRICE = 240_000;

    uint256 internal constant CORE_TXS = 12;
    uint256 internal constant HOOK_DEPLOY_TXS = 1;
    uint256 internal constant HOOK_ALLOWLIST_TXS = 2;
    uint256 internal constant HOOK_BIND_TXS = 1;
    uint256 internal constant HOOK_RENOUNCE_TXS = 1;

    uint256 internal constant SUN_MAX_MINT_USDC = 10_000 * USDC_ONE;
    uint256 internal constant MOON_MAX_MINT_USDC_EQUIV = 10_000 * USDC_ONE;
    uint256 internal constant MOON_K = 5_000_000 * TOKEN_ONE;
    uint256 internal constant MOON_S = 1_200_000 * TOKEN_ONE;

    address internal constant DEFAULT_MAINNET_DEPLOYER = 0xC0b399aE61d3Fb14EFE865A0304f0FC4b52b7B7b;
    address internal constant DEFAULT_MAINNET_ADMIN = 0xD37BDC458EdCe7006dDd3ce03eEBF29d629B2D6B;
    address internal constant DEFAULT_PROTOCOL_BUDGET = 0x215F1F09b765C0e893E8D7A40d51Bceb40B733F4;
    address internal constant DEFAULT_CREATE2_DEPLOYER_OWNER =
        0xf28020011C5e35329A78Cc4bCb34b2cA20958380;

    address internal constant DEFAULT_EXPECTED_SUN_TOKEN =
        0xbA010450885AadcDA402358d04be881Bd53E482b;
    address internal constant DEFAULT_EXPECTED_SUN_CURVE =
        0x4104250C9C2E19CCe8625D0c2972c5EaE035D83a;
    address internal constant DEFAULT_EXPECTED_MOON_TOKEN =
        0xf3Bff3b498369022313aD55138ea41B236B61EBf;
    address internal constant DEFAULT_EXPECTED_MOON_CURVE =
        0x5de55E74728f42e0265cd712aA54d9b7D532D38d;
    address internal constant DEFAULT_EXPECTED_CREATE2_HOOK_DEPLOYER =
        0xFdc4c4FC0200ee27345B179E52348bA4a4aC97c0;
    bytes32 internal constant DEFAULT_EXPECTED_HOOK_SALT =
        0x0000000000000000000000000000000000000000000000000000000000000d1a;
    address internal constant DEFAULT_EXPECTED_HOOK = 0x10cd8Ad3b2225842E2791f327e39d51eB4CFC0Cc;
    bytes32 internal constant DEFAULT_EXPECTED_SUN_USDC_POOL_ID =
        0x3138c4c0659267531412664a35564dcf0403d2bd67ef6e5710a6504e273f2ccd;
    bytes32 internal constant DEFAULT_EXPECTED_MOON_USDC_POOL_ID =
        0xbc7e8b87d4d43acb33e42348528f5df53ea247b27368d1502c146a486e7583d7;

    struct MainnetBroadcastDraftConfig {
        address mainnetDeployer;
        address mainnetAdminWallet;
        address protocolBudgetWallet;
        address create2DeployerOwner;
        address poolManager;
        address positionManager;
        address stateView;
        address quoter;
        address universalRouter;
        address permit2;
        address usdcToken;
        uint256 moonLaunchDelay;
        uint24 sunUsdcFee;
        int24 sunUsdcTickSpacing;
        uint256 sunUsdcInitialTokenAmount;
        uint256 sunUsdcInitialUsdcAmount;
        uint24 moonUsdcFee;
        int24 moonUsdcTickSpacing;
        uint256 moonUsdcInitialTokenAmount;
        uint256 moonUsdcInitialUsdcAmount;
        uint256 hookSaltStart;
        uint256 hookMaxSaltSearch;
        address expectedSunToken;
        address expectedSunCurve;
        address expectedMoonToken;
        address expectedMoonCurve;
        address expectedCreate2HookDeployer;
        bytes32 expectedHookSalt;
        address expectedHook;
        bytes32 expectedSunUsdcPoolId;
        bytes32 expectedMoonUsdcPoolId;
        bool baseMainnetDraftConfirmed;
        bool executeRequested;
        bool privateKeyPresent;
    }

    struct MainnetBroadcastDraftPlan {
        uint256 chainId;
        bool baseMainnetDraftConfirmed;
        bool executeRequested;
        bool privateKeyPresent;
        bool broadcastAllowed;
        bool executionBlocked;
        bool simulationOnly;
        bool moonAmmBindingTxIncluded;
        uint256 coreTxs;
        uint256 hookDeployTxs;
        uint256 hookAllowlistTxs;
        uint256 hookBindTxs;
        uint256 poolInitializeTxs;
        uint256 hookRenounceTxs;
        uint256 forkDryRunTxsWithoutMoonAmmBinding;
        uint256 totalTransactionsPlanned;
        address mainnetDeployer;
        address mainnetAdminWallet;
        address protocolBudgetWallet;
        address create2DeployerOwner;
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
        bool sunUsdcAlreadyInitialized;
        bool moonUsdcAlreadyInitialized;
        bool sunUsdcAllowedAfterDryRun;
        bool moonUsdcAllowedAfterDryRun;
        bool renounceBlocksSunAllowlist;
        bool renounceBlocksMoonAllowlist;
        bool renounceBlocksProtocolBudget;
        address[] txFrom;
        address[] txTo;
        bytes32[] txDataHash;
        bytes32[] txLabel;
    }

    struct CorePlan {
        uint256 chainId;
        address usdcToken;
        uint8 usdcDecimals;
        uint256 moonLaunchTime;
        address predictedSunToken;
        address predictedSunCurve;
        address predictedMoonToken;
        address predictedMoonCurve;
        address predictedCreate2HookDeployer;
    }

    struct HookPoolPlan {
        bytes32 initCodeHash;
        uint160 expectedHookMask;
        bytes32 hookSalt;
        address predictedHook;
        uint160 actualHookMask;
        PoolKey sunUsdcPoolKey;
        bytes32 sunUsdcPoolId;
        int24 sunUsdcInitialTick;
        uint160 sunUsdcSqrtPriceX96;
        bool sunUsdcAlreadyInitialized;
        PoolKey moonUsdcPoolKey;
        bytes32 moonUsdcPoolId;
        int24 moonUsdcInitialTick;
        uint160 moonUsdcSqrtPriceX96;
        bool moonUsdcAlreadyInitialized;
    }

    error BaseMainnetBroadcastDraftNotConfirmed(uint256 chainId);
    error BroadcastExecutionNotAllowed();
    error PrivateKeyEnvNotAllowed();
    error DependencyCodeMissing(bytes32 label, address target);
    error InvalidInitialPrice(bytes32 label, uint256 tokenAmount, uint256 usdcAmount);
    error InvalidPoolConfig(bytes32 label, uint24 fee, int24 tickSpacing);
    error SaltNotFound(uint256 startSalt, uint256 maxIterations);
    error UnsupportedChain(uint256 chainId);
    error UnexpectedDraftAddress(bytes32 label, address expected, address actual);
    error UnexpectedDraftBytes32(bytes32 label, bytes32 expected, bytes32 actual);
    error UsdcDecimalsMismatch(uint8 expected, uint8 actual);

    function run() external returns (MainnetBroadcastDraftPlan memory plan) {
        plan = prepare(_loadConfig());
    }

    function prepare(MainnetBroadcastDraftConfig memory config)
        public
        returns (MainnetBroadcastDraftPlan memory plan)
    {
        _validateDraft(config);
        _validateDependencies(config);

        CorePlan memory corePlan = _prepareCorePlan(config);
        _validateExpectedCoreAddresses(config, corePlan);

        HookPoolPlan memory hookPoolPlan = _prepareHookPoolPlan(config, corePlan);
        _validateExpectedHookAndPools(config, hookPoolPlan);

        plan = _buildPlan(config, corePlan, hookPoolPlan);
        _populateTransactionDrafts(config, corePlan, hookPoolPlan, plan);
        _logPlan(plan);
    }

    function _loadConfig() private view returns (MainnetBroadcastDraftConfig memory config) {
        bool confirmed = vm.envOr("CONFIRM_BASE_MAINNET_BROADCAST_DRAFT", uint256(0)) == 1;

        config = MainnetBroadcastDraftConfig({
            mainnetDeployer: vm.envOr("MAINNET_DEPLOYER", DEFAULT_MAINNET_DEPLOYER),
            mainnetAdminWallet: vm.envOr("MAINNET_ADMIN_WALLET", DEFAULT_MAINNET_ADMIN),
            protocolBudgetWallet: vm.envOr("PROTOCOL_BUDGET_WALLET", DEFAULT_PROTOCOL_BUDGET),
            create2DeployerOwner: vm.envOr(
                "CREATE2_DEPLOYER_OWNER", DEFAULT_CREATE2_DEPLOYER_OWNER
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
            usdcToken: vm.envOr("USDC_TOKEN", BaseV4Addresses.BASE_MAINNET_USDC),
            moonLaunchDelay: vm.envOr("MOON_LAUNCH_DELAY", uint256(0)),
            sunUsdcFee: uint24(vm.envOr("SUN_USDC_POOL_FEE", uint256(EXPECTED_POOL_FEE))),
            sunUsdcTickSpacing: int24(
                vm.envOr("SUN_USDC_POOL_TICK_SPACING", int256(EXPECTED_TICK_SPACING))
            ),
            sunUsdcInitialTokenAmount: vm.envOr("SUN_USDC_INITIAL_TOKEN_AMOUNT", TOKEN_ONE),
            sunUsdcInitialUsdcAmount: vm.envOr(
                "SUN_USDC_INITIAL_USDC_AMOUNT", DEFAULT_SUN_USDC_PRICE
            ),
            moonUsdcFee: uint24(vm.envOr("MOON_USDC_POOL_FEE", uint256(EXPECTED_POOL_FEE))),
            moonUsdcTickSpacing: int24(
                vm.envOr("MOON_USDC_POOL_TICK_SPACING", int256(EXPECTED_TICK_SPACING))
            ),
            moonUsdcInitialTokenAmount: vm.envOr("MOON_USDC_INITIAL_TOKEN_AMOUNT", TOKEN_ONE),
            moonUsdcInitialUsdcAmount: vm.envOr(
                "MOON_USDC_INITIAL_USDC_AMOUNT", DEFAULT_MOON_USDC_PRICE
            ),
            hookSaltStart: vm.envOr("HOOK_SALT_START", uint256(0)),
            hookMaxSaltSearch: vm.envOr("HOOK_MAX_SALT_SEARCH", uint256(200_000)),
            expectedSunToken: vm.envOr("EXPECTED_SUN_TOKEN", DEFAULT_EXPECTED_SUN_TOKEN),
            expectedSunCurve: vm.envOr("EXPECTED_SUN_CURVE", DEFAULT_EXPECTED_SUN_CURVE),
            expectedMoonToken: vm.envOr("EXPECTED_MOON_TOKEN", DEFAULT_EXPECTED_MOON_TOKEN),
            expectedMoonCurve: vm.envOr("EXPECTED_MOON_CURVE", DEFAULT_EXPECTED_MOON_CURVE),
            expectedCreate2HookDeployer: vm.envOr(
                "EXPECTED_CREATE2_HOOK_DEPLOYER", DEFAULT_EXPECTED_CREATE2_HOOK_DEPLOYER
            ),
            expectedHookSalt: vm.envOr("EXPECTED_HOOK_SALT", DEFAULT_EXPECTED_HOOK_SALT),
            expectedHook: vm.envOr("EXPECTED_HOOK", DEFAULT_EXPECTED_HOOK),
            expectedSunUsdcPoolId: vm.envOr("SUN_USDC_POOL_ID", DEFAULT_EXPECTED_SUN_USDC_POOL_ID),
            expectedMoonUsdcPoolId: vm.envOr(
                "MOON_USDC_POOL_ID", DEFAULT_EXPECTED_MOON_USDC_POOL_ID
            ),
            baseMainnetDraftConfirmed: confirmed,
            executeRequested: vm.envOr("EXECUTE_BASE_MAINNET_BROADCAST", uint256(0)) == 1,
            privateKeyPresent: bytes(vm.envOr("PRIVATE_KEY", string(""))).length != 0
        });
    }

    function _validateDraft(MainnetBroadcastDraftConfig memory config) private view {
        if (config.executeRequested) revert BroadcastExecutionNotAllowed();
        if (config.privateKeyPresent) revert PrivateKeyEnvNotAllowed();
        if (
            block.chainid == BaseV4Addresses.BASE_MAINNET_CHAIN_ID
                && !config.baseMainnetDraftConfirmed
        ) {
            revert BaseMainnetBroadcastDraftNotConfirmed(block.chainid);
        }
        if (
            block.chainid != LOCAL_SIMULATION_CHAIN_ID
                && block.chainid != BaseV4Addresses.BASE_MAINNET_CHAIN_ID
        ) {
            revert UnsupportedChain(block.chainid);
        }
    }

    function _validateDependencies(MainnetBroadcastDraftConfig memory config) private view {
        _requireCode("POOL_MANAGER", config.poolManager);
        _requireCode("STATE_VIEW", config.stateView);
        _requireCode("USDC_TOKEN", config.usdcToken);

        if (block.chainid == BaseV4Addresses.BASE_MAINNET_CHAIN_ID) {
            _requireCode("POSITION_MANAGER", config.positionManager);
            _requireCode("QUOTER", config.quoter);
            _requireCode("UNIVERSAL_ROUTER", config.universalRouter);
            _requireCode("PERMIT2", config.permit2);
        }

        _requirePoolConfig("SUN_USDC_POOL", config.sunUsdcFee, config.sunUsdcTickSpacing);
        _requirePoolConfig("MOON_USDC_POOL", config.moonUsdcFee, config.moonUsdcTickSpacing);
        _requireInitialPrice(
            "SUN_USDC_PRICE", config.sunUsdcInitialTokenAmount, config.sunUsdcInitialUsdcAmount
        );
        _requireInitialPrice(
            "MOON_USDC_PRICE", config.moonUsdcInitialTokenAmount, config.moonUsdcInitialUsdcAmount
        );
        if (config.hookMaxSaltSearch == 0) {
            revert SaltNotFound(config.hookSaltStart, config.hookMaxSaltSearch);
        }
    }

    function _prepareCorePlan(MainnetBroadcastDraftConfig memory config)
        private
        view
        returns (CorePlan memory corePlan)
    {
        corePlan.chainId = block.chainid;
        corePlan.usdcToken = config.usdcToken;
        corePlan.usdcDecimals = IERC20Metadata(config.usdcToken).decimals();
        if (corePlan.usdcDecimals != 6) revert UsdcDecimalsMismatch(6, corePlan.usdcDecimals);

        corePlan.moonLaunchTime = block.timestamp + config.moonLaunchDelay;
        uint64 nonce = vm.getNonce(config.mainnetDeployer);
        corePlan.predictedSunToken = vm.computeCreateAddress(config.mainnetDeployer, nonce);
        corePlan.predictedSunCurve = vm.computeCreateAddress(config.mainnetDeployer, nonce + 1);
        corePlan.predictedMoonToken = vm.computeCreateAddress(config.mainnetDeployer, nonce + 2);
        corePlan.predictedMoonCurve = vm.computeCreateAddress(config.mainnetDeployer, nonce + 3);
        corePlan.predictedCreate2HookDeployer =
            vm.computeCreateAddress(config.mainnetDeployer, nonce + 4);
    }

    function _prepareHookPoolPlan(
        MainnetBroadcastDraftConfig memory config,
        CorePlan memory corePlan
    ) private view returns (HookPoolPlan memory hookPoolPlan) {
        bytes memory initCode = _hookInitCode(corePlan, config);
        hookPoolPlan.initCodeHash = keccak256(initCode);
        hookPoolPlan.expectedHookMask = BaseV4HookAddressMiner.BASE_SUN_MOON_USDC_FEE_V4_HOOK_MASK;
        bool found;
        (hookPoolPlan.hookSalt, hookPoolPlan.predictedHook, found) = BaseV4HookAddressMiner.mineSalt(
            corePlan.predictedCreate2HookDeployer,
            hookPoolPlan.initCodeHash,
            hookPoolPlan.expectedHookMask,
            config.hookSaltStart,
            config.hookMaxSaltSearch
        );
        if (!found) revert SaltNotFound(config.hookSaltStart, config.hookMaxSaltSearch);
        hookPoolPlan.actualHookMask =
            uint160(hookPoolPlan.predictedHook) & BaseV4HookAddressMiner.V4_ALL_HOOK_MASK;

        hookPoolPlan.sunUsdcPoolKey = _poolKey(
            corePlan.predictedSunToken,
            corePlan.usdcToken,
            IHooks(hookPoolPlan.predictedHook),
            config.sunUsdcFee,
            config.sunUsdcTickSpacing
        );
        hookPoolPlan.sunUsdcPoolId = PoolId.unwrap(hookPoolPlan.sunUsdcPoolKey.toId());
        hookPoolPlan.sunUsdcSqrtPriceX96 = _initialSqrtPriceX96(
            hookPoolPlan.sunUsdcPoolKey,
            corePlan.predictedSunToken,
            corePlan.usdcToken,
            config.sunUsdcInitialTokenAmount,
            config.sunUsdcInitialUsdcAmount
        );
        hookPoolPlan.sunUsdcInitialTick =
            TickMath.getTickAtSqrtPrice(hookPoolPlan.sunUsdcSqrtPriceX96);

        hookPoolPlan.moonUsdcPoolKey = _poolKey(
            corePlan.predictedMoonToken,
            corePlan.usdcToken,
            IHooks(hookPoolPlan.predictedHook),
            config.moonUsdcFee,
            config.moonUsdcTickSpacing
        );
        hookPoolPlan.moonUsdcPoolId = PoolId.unwrap(hookPoolPlan.moonUsdcPoolKey.toId());
        hookPoolPlan.moonUsdcSqrtPriceX96 = _initialSqrtPriceX96(
            hookPoolPlan.moonUsdcPoolKey,
            corePlan.predictedMoonToken,
            corePlan.usdcToken,
            config.moonUsdcInitialTokenAmount,
            config.moonUsdcInitialUsdcAmount
        );
        hookPoolPlan.moonUsdcInitialTick =
            TickMath.getTickAtSqrtPrice(hookPoolPlan.moonUsdcSqrtPriceX96);

        IStateView stateView = IStateView(config.stateView);
        (uint160 sunSqrtPriceBefore,,,) =
            stateView.getSlot0(PoolId.wrap(hookPoolPlan.sunUsdcPoolId));
        (uint160 moonSqrtPriceBefore,,,) =
            stateView.getSlot0(PoolId.wrap(hookPoolPlan.moonUsdcPoolId));
        hookPoolPlan.sunUsdcAlreadyInitialized = sunSqrtPriceBefore != 0;
        hookPoolPlan.moonUsdcAlreadyInitialized = moonSqrtPriceBefore != 0;
    }

    function _validateExpectedCoreAddresses(
        MainnetBroadcastDraftConfig memory config,
        CorePlan memory corePlan
    ) private pure {
        _requireExpectedAddress(
            LABEL_SUN_TOKEN, config.expectedSunToken, corePlan.predictedSunToken
        );
        _requireExpectedAddress(
            LABEL_SUN_CURVE, config.expectedSunCurve, corePlan.predictedSunCurve
        );
        _requireExpectedAddress(
            LABEL_MOON_TOKEN, config.expectedMoonToken, corePlan.predictedMoonToken
        );
        _requireExpectedAddress(
            LABEL_MOON_CURVE, config.expectedMoonCurve, corePlan.predictedMoonCurve
        );
        _requireExpectedAddress(
            LABEL_CREATE2_HOOK_DEPLOYER,
            config.expectedCreate2HookDeployer,
            corePlan.predictedCreate2HookDeployer
        );
    }

    function _validateExpectedHookAndPools(
        MainnetBroadcastDraftConfig memory config,
        HookPoolPlan memory hookPoolPlan
    ) private pure {
        _requireExpectedBytes32(LABEL_HOOK_SALT, config.expectedHookSalt, hookPoolPlan.hookSalt);
        _requireExpectedAddress(
            LABEL_PREDICTED_HOOK, config.expectedHook, hookPoolPlan.predictedHook
        );
        _requireExpectedBytes32(
            "SUN_USDC_POOL_ID", config.expectedSunUsdcPoolId, hookPoolPlan.sunUsdcPoolId
        );
        _requireExpectedBytes32(
            "MOON_USDC_POOL_ID", config.expectedMoonUsdcPoolId, hookPoolPlan.moonUsdcPoolId
        );
    }

    function _buildPlan(
        MainnetBroadcastDraftConfig memory config,
        CorePlan memory corePlan,
        HookPoolPlan memory hookPoolPlan
    ) private pure returns (MainnetBroadcastDraftPlan memory plan) {
        uint256 poolInitializeTxs = 0;
        if (!hookPoolPlan.sunUsdcAlreadyInitialized) poolInitializeTxs++;
        if (!hookPoolPlan.moonUsdcAlreadyInitialized) poolInitializeTxs++;

        plan.chainId = corePlan.chainId;
        plan.baseMainnetDraftConfirmed = config.baseMainnetDraftConfirmed;
        plan.executeRequested = config.executeRequested;
        plan.privateKeyPresent = config.privateKeyPresent;
        plan.broadcastAllowed = false;
        plan.executionBlocked = true;
        plan.simulationOnly = true;
        plan.moonAmmBindingTxIncluded = true;
        plan.coreTxs = CORE_TXS;
        plan.hookDeployTxs = HOOK_DEPLOY_TXS;
        plan.hookAllowlistTxs = HOOK_ALLOWLIST_TXS;
        plan.hookBindTxs = HOOK_BIND_TXS;
        plan.poolInitializeTxs = poolInitializeTxs;
        plan.hookRenounceTxs = HOOK_RENOUNCE_TXS;
        plan.forkDryRunTxsWithoutMoonAmmBinding =
            HOOK_DEPLOY_TXS + HOOK_ALLOWLIST_TXS + poolInitializeTxs + HOOK_RENOUNCE_TXS;
        plan.totalTransactionsPlanned = CORE_TXS + HOOK_DEPLOY_TXS + HOOK_ALLOWLIST_TXS
            + HOOK_BIND_TXS + poolInitializeTxs + HOOK_RENOUNCE_TXS;
        plan.mainnetDeployer = config.mainnetDeployer;
        plan.mainnetAdminWallet = config.mainnetAdminWallet;
        plan.protocolBudgetWallet = config.protocolBudgetWallet;
        plan.create2DeployerOwner = config.create2DeployerOwner;
        plan.predictedSunToken = corePlan.predictedSunToken;
        plan.predictedSunCurve = corePlan.predictedSunCurve;
        plan.predictedMoonToken = corePlan.predictedMoonToken;
        plan.predictedMoonCurve = corePlan.predictedMoonCurve;
        plan.predictedCreate2HookDeployer = corePlan.predictedCreate2HookDeployer;
        plan.hookSalt = hookPoolPlan.hookSalt;
        plan.predictedHook = hookPoolPlan.predictedHook;
        plan.sunUsdcPoolId = hookPoolPlan.sunUsdcPoolId;
        plan.sunUsdcInitialTick = hookPoolPlan.sunUsdcInitialTick;
        plan.sunUsdcSqrtPriceX96 = hookPoolPlan.sunUsdcSqrtPriceX96;
        plan.moonUsdcPoolId = hookPoolPlan.moonUsdcPoolId;
        plan.moonUsdcInitialTick = hookPoolPlan.moonUsdcInitialTick;
        plan.moonUsdcSqrtPriceX96 = hookPoolPlan.moonUsdcSqrtPriceX96;
        plan.sunUsdcAlreadyInitialized = hookPoolPlan.sunUsdcAlreadyInitialized;
        plan.moonUsdcAlreadyInitialized = hookPoolPlan.moonUsdcAlreadyInitialized;
        plan.sunUsdcAllowedAfterDryRun = true;
        plan.moonUsdcAllowedAfterDryRun = true;
        plan.renounceBlocksSunAllowlist = true;
        plan.renounceBlocksMoonAllowlist = true;
        plan.renounceBlocksProtocolBudget = true;
    }

    function _populateTransactionDrafts(
        MainnetBroadcastDraftConfig memory config,
        CorePlan memory corePlan,
        HookPoolPlan memory hookPoolPlan,
        MainnetBroadcastDraftPlan memory plan
    ) private pure {
        plan.txFrom = new address[](plan.totalTransactionsPlanned);
        plan.txTo = new address[](plan.totalTransactionsPlanned);
        plan.txDataHash = new bytes32[](plan.totalTransactionsPlanned);
        plan.txLabel = new bytes32[](plan.totalTransactionsPlanned);

        uint256 i = 0;
        i = _setTx(
            plan,
            i,
            "TX01_SUN_TOKEN",
            config.mainnetDeployer,
            address(0),
            _sunTokenInitCode(config.mainnetDeployer)
        );
        i = _setTx(
            plan,
            i,
            "TX02_SUN_CURVE",
            config.mainnetDeployer,
            address(0),
            _sunCurveInitCode(corePlan, config)
        );
        i = _setTx(
            plan,
            i,
            "TX03_MOON_TOKEN",
            config.mainnetDeployer,
            address(0),
            _moonTokenInitCode(config.mainnetDeployer)
        );
        i = _setTx(
            plan,
            i,
            "TX04_MOON_CURVE",
            config.mainnetDeployer,
            address(0),
            _moonCurveInitCode(corePlan, config)
        );
        i = _setTx(
            plan,
            i,
            "TX05_CREATE2",
            config.mainnetDeployer,
            address(0),
            _create2HookDeployerInitCode(config.create2DeployerOwner)
        );
        i = _setTx(
            plan,
            i,
            "TX06_SUN_MINTER",
            config.mainnetDeployer,
            corePlan.predictedSunToken,
            abi.encodeCall(SunToken.setMinter, (corePlan.predictedSunCurve))
        );
        i = _setTx(
            plan,
            i,
            "TX07_MOON_CURVE",
            config.mainnetDeployer,
            corePlan.predictedSunCurve,
            abi.encodeCall(SunCurve.setMoonCurve, (corePlan.predictedMoonCurve))
        );
        i = _setTx(
            plan,
            i,
            "TX08_MOON_MINTER",
            config.mainnetDeployer,
            corePlan.predictedMoonToken,
            abi.encodeCall(MoonToken.setMinter, (corePlan.predictedMoonCurve))
        );
        i = _setTx(
            plan,
            i,
            "TX09_SUN_OWNER",
            config.mainnetDeployer,
            corePlan.predictedSunToken,
            abi.encodeCall(IOwnableTransfer.transferOwnership, (config.mainnetAdminWallet))
        );
        i = _setTx(
            plan,
            i,
            "TX10_CURVE_OWNER",
            config.mainnetDeployer,
            corePlan.predictedSunCurve,
            abi.encodeCall(IOwnableTransfer.transferOwnership, (config.mainnetAdminWallet))
        );
        i = _setTx(
            plan,
            i,
            "TX11_MOON_OWNER",
            config.mainnetDeployer,
            corePlan.predictedMoonToken,
            abi.encodeCall(IOwnableTransfer.transferOwnership, (config.mainnetAdminWallet))
        );
        i = _setTx(
            plan,
            i,
            "TX12_MCURVE_OWNER",
            config.mainnetDeployer,
            corePlan.predictedMoonCurve,
            abi.encodeCall(IOwnableTransfer.transferOwnership, (config.mainnetAdminWallet))
        );

        bytes memory hookInitCode = _hookInitCode(corePlan, config);
        i = _setTx(
            plan,
            i,
            "TX13_HOOK_DEPLOY",
            config.create2DeployerOwner,
            corePlan.predictedCreate2HookDeployer,
            abi.encodeCall(
                Create2HookDeployer.deployHook,
                (hookPoolPlan.hookSalt, hookInitCode, hookPoolPlan.expectedHookMask)
            )
        );
        i = _setTx(
            plan,
            i,
            "TX14_ALLOW_SUN",
            config.mainnetAdminWallet,
            hookPoolPlan.predictedHook,
            abi.encodeCall(
                BaseSunMoonUsdcFeeV4Hook.setAllowedSunUsdcPool, (hookPoolPlan.sunUsdcPoolId, true)
            )
        );
        i = _setTx(
            plan,
            i,
            "TX15_ALLOW_MOON",
            config.mainnetAdminWallet,
            hookPoolPlan.predictedHook,
            abi.encodeCall(
                BaseSunMoonUsdcFeeV4Hook.setAllowedMoonUsdcPool, (hookPoolPlan.moonUsdcPoolId, true)
            )
        );
        i = _setTx(
            plan,
            i,
            "TX16_BIND_AMM",
            config.mainnetAdminWallet,
            corePlan.predictedSunCurve,
            abi.encodeCall(SunCurve.setMoonAMM, (hookPoolPlan.predictedHook))
        );
        if (!hookPoolPlan.sunUsdcAlreadyInitialized) {
            i = _setTx(
                plan,
                i,
                "TX17_INIT_SUN",
                config.mainnetAdminWallet,
                config.poolManager,
                abi.encodeCall(
                    IPoolManager.initialize,
                    (hookPoolPlan.sunUsdcPoolKey, hookPoolPlan.sunUsdcSqrtPriceX96)
                )
            );
        }
        if (!hookPoolPlan.moonUsdcAlreadyInitialized) {
            i = _setTx(
                plan,
                i,
                "TX18_INIT_MOON",
                config.mainnetAdminWallet,
                config.poolManager,
                abi.encodeCall(
                    IPoolManager.initialize,
                    (hookPoolPlan.moonUsdcPoolKey, hookPoolPlan.moonUsdcSqrtPriceX96)
                )
            );
        }
        _setTx(
            plan,
            i,
            "TX19_RENOUNCE",
            config.mainnetAdminWallet,
            hookPoolPlan.predictedHook,
            abi.encodeCall(BaseSunMoonUsdcFeeV4Hook.renounceOwnership, ())
        );
    }

    function _setTx(
        MainnetBroadcastDraftPlan memory plan,
        uint256 index,
        bytes32 label,
        address from,
        address to,
        bytes memory data
    ) private pure returns (uint256 nextIndex) {
        plan.txLabel[index] = label;
        plan.txFrom[index] = from;
        plan.txTo[index] = to;
        plan.txDataHash[index] = keccak256(data);
        nextIndex = index + 1;
    }

    function _sunTokenInitCode(address initialOwner) private pure returns (bytes memory initCode) {
        initCode =
            abi.encodePacked(type(SunToken).creationCode, abi.encode("SUN", "SUN", initialOwner));
    }

    function _sunCurveInitCode(CorePlan memory corePlan, MainnetBroadcastDraftConfig memory config)
        private
        pure
        returns (bytes memory initCode)
    {
        initCode = abi.encodePacked(
            type(SunCurve).creationCode,
            abi.encode(
                SunToken(corePlan.predictedSunToken),
                IERC20Metadata(corePlan.usdcToken),
                config.protocolBudgetWallet,
                SUN_MAX_MINT_USDC,
                config.mainnetDeployer
            )
        );
    }

    function _moonTokenInitCode(address initialOwner) private pure returns (bytes memory initCode) {
        initCode = abi.encodePacked(
            type(MoonToken).creationCode, abi.encode("MOON", "MOON", initialOwner)
        );
    }

    function _moonCurveInitCode(CorePlan memory corePlan, MainnetBroadcastDraftConfig memory config)
        private
        pure
        returns (bytes memory initCode)
    {
        initCode = abi.encodePacked(
            type(MoonCurve).creationCode,
            abi.encode(
                MoonToken(corePlan.predictedMoonToken),
                SunToken(corePlan.predictedSunToken),
                SunCurve(corePlan.predictedSunCurve),
                config.protocolBudgetWallet,
                MOON_K,
                MOON_S,
                corePlan.moonLaunchTime,
                MOON_MAX_MINT_USDC_EQUIV,
                config.mainnetDeployer
            )
        );
    }

    function _create2HookDeployerInitCode(address owner_)
        private
        pure
        returns (bytes memory initCode)
    {
        initCode = abi.encodePacked(type(Create2HookDeployer).creationCode, abi.encode(owner_));
    }

    function _hookInitCode(CorePlan memory corePlan, MainnetBroadcastDraftConfig memory config)
        private
        pure
        returns (bytes memory initCode)
    {
        initCode = abi.encodePacked(
            type(BaseSunMoonUsdcFeeV4Hook).creationCode,
            abi.encode(
                IPoolManager(config.poolManager),
                corePlan.predictedSunToken,
                corePlan.predictedMoonToken,
                IERC20(corePlan.usdcToken),
                SunCurve(corePlan.predictedSunCurve),
                config.protocolBudgetWallet,
                config.mainnetAdminWallet
            )
        );
    }

    function _requireExpectedAddress(bytes32 label, address expected, address actual) private pure {
        if (expected != address(0) && expected != actual) {
            revert UnexpectedDraftAddress(label, expected, actual);
        }
    }

    function _requireExpectedBytes32(bytes32 label, bytes32 expected, bytes32 actual) private pure {
        if (expected != bytes32(0) && expected != actual) {
            revert UnexpectedDraftBytes32(label, expected, actual);
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
            revert UnexpectedDraftAddress("POOL_PRICE_TOKEN_ORDER", token, usdc);
        }

        sqrtPriceX96 = uint160(Math.sqrt(Math.mulDiv(ratioNumerator, Q192, ratioDenominator)));
    }

    function _requireCode(bytes32 label, address target) private view {
        if (target.code.length == 0) revert DependencyCodeMissing(label, target);
    }

    function _requirePoolConfig(bytes32 label, uint24 fee, int24 tickSpacing) private pure {
        if (fee == 0 || tickSpacing <= 0) revert InvalidPoolConfig(label, fee, tickSpacing);
    }

    function _requireInitialPrice(bytes32 label, uint256 tokenAmount, uint256 usdcAmount)
        private
        pure
    {
        if (tokenAmount == 0 || usdcAmount == 0) {
            revert InvalidInitialPrice(label, tokenAmount, usdcAmount);
        }
    }

    function _logPlan(MainnetBroadcastDraftPlan memory plan) private pure {
        console2.log("Base mainnet SUN/MOON USDC broadcast draft");
        console2.log("broadcastAllowed:", plan.broadcastAllowed);
        console2.log("executionBlocked:", plan.executionBlocked);
        console2.log("simulationOnly:", plan.simulationOnly);
        console2.log("moonAmmBindingTxIncluded:", plan.moonAmmBindingTxIncluded);
        console2.log("chainId:", plan.chainId);
        console2.log("baseMainnetDraftConfirmed:", plan.baseMainnetDraftConfirmed);
        console2.log("executeRequested:", plan.executeRequested);
        console2.log("privateKeyPresent:", plan.privateKeyPresent);
        console2.log("coreTxs:", plan.coreTxs);
        console2.log("hookDeployTxs:", plan.hookDeployTxs);
        console2.log("hookAllowlistTxs:", plan.hookAllowlistTxs);
        console2.log("hookBindTxs:", plan.hookBindTxs);
        console2.log("poolInitializeTxs:", plan.poolInitializeTxs);
        console2.log("hookRenounceTxs:", plan.hookRenounceTxs);
        console2.log("forkDryRunTxsWithoutMoonAmmBinding:", plan.forkDryRunTxsWithoutMoonAmmBinding);
        console2.log("totalTransactionsPlanned:", plan.totalTransactionsPlanned);
        console2.log("MAINNET_DEPLOYER:", plan.mainnetDeployer);
        console2.log("MAINNET_ADMIN_WALLET:", plan.mainnetAdminWallet);
        console2.log("PROTOCOL_BUDGET_WALLET:", plan.protocolBudgetWallet);
        console2.log("CREATE2_DEPLOYER_OWNER:", plan.create2DeployerOwner);
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
        console2.log("sunUsdcAlreadyInitialized:", plan.sunUsdcAlreadyInitialized);
        console2.log("moonUsdcAlreadyInitialized:", plan.moonUsdcAlreadyInitialized);
        console2.log("sunUsdcAllowedAfterDryRun:", plan.sunUsdcAllowedAfterDryRun);
        console2.log("moonUsdcAllowedAfterDryRun:", plan.moonUsdcAllowedAfterDryRun);
        console2.log("renounceBlocksSunAllowlist:", plan.renounceBlocksSunAllowlist);
        console2.log("renounceBlocksMoonAllowlist:", plan.renounceBlocksMoonAllowlist);
        console2.log("renounceBlocksProtocolBudget:", plan.renounceBlocksProtocolBudget);
        for (uint256 i = 0; i < plan.totalTransactionsPlanned; i++) {
            console2.log("txIndex:", i + 1);
            console2.log("txLabel:");
            console2.logBytes32(plan.txLabel[i]);
            console2.log("txFrom:", plan.txFrom[i]);
            console2.log("txTo:", plan.txTo[i]);
            console2.log("txDataHash:");
            console2.logBytes32(plan.txDataHash[i]);
        }
    }
}
