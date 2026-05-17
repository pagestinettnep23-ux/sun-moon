// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Script, console2 } from "forge-std/Script.sol";
import { IHooks } from "@uniswap/v4-core/src/interfaces/IHooks.sol";
import { Currency } from "@uniswap/v4-core/src/types/Currency.sol";
import { PoolId, PoolIdLibrary } from "@uniswap/v4-core/src/types/PoolId.sol";
import { PoolKey } from "@uniswap/v4-core/src/types/PoolKey.sol";
import { IStateView } from "@uniswap/v4-periphery/src/interfaces/IStateView.sol";
import { IAllowanceTransfer } from "permit2/src/interfaces/IAllowanceTransfer.sol";
import { TestnetUsdcAdapter } from "../contracts/hooks/TestnetUsdcAdapter.sol";
import { BaseMoonAmmFeeV4Hook } from "../contracts/hooks/base/BaseMoonAmmFeeV4Hook.sol";
import { BaseV4Addresses } from "../contracts/hooks/base/BaseV4Addresses.sol";
import { BaseV4HookAddressMiner } from "../contracts/hooks/base/BaseV4HookAddressMiner.sol";
import { SunCurve } from "../contracts/SunCurve.sol";

contract PrepareBaseSepoliaTinyMoonUsdcRehearsal is Script {
    using PoolIdLibrary for PoolKey;

    uint256 internal constant BPS = 10_000;
    uint256 internal constant FEE_TO_SUN_CURVE_BPS = 300;
    uint256 internal constant FEE_TO_PROTOCOL_BPS = 200;
    uint256 internal constant DEFAULT_TINY_LIQUIDITY_USDC_AMOUNT = 1_000_000;
    uint256 internal constant DEFAULT_TINY_LIQUIDITY_MOON_AMOUNT = 1 ether;
    uint256 internal constant DEFAULT_TINY_SWAP_USDC_IN = 100_000;

    bytes32 internal constant LABEL_REHEARSAL_ACTOR = "REHEARSAL_ACTOR";
    bytes32 internal constant LABEL_POOL_MANAGER = "POOL_MANAGER";
    bytes32 internal constant LABEL_STATE_VIEW = "STATE_VIEW";
    bytes32 internal constant LABEL_POSITION_MANAGER = "POSITION_MANAGER";
    bytes32 internal constant LABEL_UNIVERSAL_ROUTER = "UNIVERSAL_ROUTER";
    bytes32 internal constant LABEL_PERMIT2 = "PERMIT2";
    bytes32 internal constant LABEL_HOOK = "HOOK";
    bytes32 internal constant LABEL_SWAP_ADAPTER = "SWAP_ADAPTER";
    bytes32 internal constant LABEL_SUN_CURVE = "SUN_CURVE";
    bytes32 internal constant LABEL_MOON_TOKEN = "MOON_TOKEN";
    bytes32 internal constant LABEL_USDC_TOKEN = "USDC_TOKEN";
    bytes32 internal constant LABEL_POOL_ID = "POOL_ID";

    struct Permit2Allowance {
        uint160 amount;
        uint48 expiration;
        uint48 nonce;
        bool active;
    }

    struct TinyRehearsalPlan {
        uint256 chainId;
        bool baseSepoliaConfirmed;
        address rehearsalActor;
        address poolManager;
        address stateView;
        address positionManager;
        address universalRouter;
        address permit2;
        BaseMoonAmmFeeV4Hook hook;
        TestnetUsdcAdapter adapter;
        SunCurve sunCurve;
        address protocolBudget;
        address moonToken;
        address usdcToken;
        uint24 fee;
        int24 tickSpacing;
        PoolKey poolKey;
        bytes32 poolId;
        bool allowedMoonPool;
        bool hookPaused;
        bool adapterAuthorized;
        bool sunCurveBound;
        bool protocolBudgetConfigured;
        uint160 sqrtPriceX96;
        int24 tick;
        uint24 protocolFee;
        uint24 lpFee;
        bool poolInitialized;
        uint256 liquidityUsdcAmount;
        uint256 liquidityMoonAmount;
        uint256 swapUsdcIn;
        uint256 swapFeeToSunCurve;
        uint256 swapFeeToProtocol;
        uint256 swapUsdcGrossInputWithHookFee;
        uint256 swapMinUsdcToCurve;
        bool zeroForOneUsdcToMoon;
        bytes swapHookData;
        uint256 actorUsdcBalance;
        uint256 actorMoonBalance;
        uint256 actorUsdcAllowanceToPermit2;
        uint256 actorMoonAllowanceToPermit2;
        Permit2Allowance actorUsdcPermit2ToPositionManager;
        Permit2Allowance actorMoonPermit2ToPositionManager;
        Permit2Allowance actorUsdcPermit2ToUniversalRouter;
        bool hasLiquidityBalances;
        bool hasSwapBalance;
        bool hasPermit2TokenApprovals;
        bool hasPositionManagerPermit2Allowances;
        bool hasUniversalRouterPermit2Allowance;
        bool readyForLiquidityDryRun;
        bool readyForSwapDryRun;
        bool readyForCombinedDryRun;
        bool quoteRequiredBeforeBroadcast;
        uint256 transactionsPlanned;
    }

    struct TinyRehearsalConfig {
        bool baseSepoliaConfirmed;
        address rehearsalActor;
        address poolManager;
        address stateView;
        address positionManager;
        address universalRouter;
        address permit2;
        address hook;
        address adapter;
        address sunCurve;
        address moonToken;
        address usdcToken;
        uint24 fee;
        int24 tickSpacing;
        uint256 liquidityUsdcAmount;
        uint256 liquidityMoonAmount;
        uint256 swapUsdcIn;
        uint256 swapMinUsdcToCurve;
    }

    error BaseMainnetNotAllowed(uint256 chainId);
    error BaseSepoliaRunNotConfirmed(uint256 chainId);
    error DependencyCodeMissing(bytes32 label, address target);
    error InvalidAddress(bytes32 label);
    error InvalidAmount(bytes32 label, uint256 amount);
    error InvalidMinUsdcOut(uint256 minUsdcOut, uint256 maxDirectUsdcOut);
    error InvalidPoolConfig(uint24 fee, int24 tickSpacing);
    error MoonPoolNotAllowed(bytes32 poolId);
    error PoolNotInitialized(bytes32 poolId);
    error UnexpectedHookMask(uint160 expectedMask, uint160 actualMask);
    error UnexpectedParameter(bytes32 label, address expected, address actual);
    error UnexpectedPoolFee(uint24 expectedFee, uint24 actualFee);

    function run() external view returns (TinyRehearsalPlan memory plan) {
        uint256 chainId = block.chainid;
        bool baseSepoliaConfirmed =
            vm.envOr("CONFIRM_BASE_SEPOLIA_TINY_REHEARSAL_RUN", uint256(0)) == 1;
        _validateChain(chainId, baseSepoliaConfirmed);

        plan = _loadPlan(chainId, baseSepoliaConfirmed);
        plan = _completePlan(plan);
    }

    function prepare(TinyRehearsalConfig memory config)
        external
        view
        returns (TinyRehearsalPlan memory plan)
    {
        uint256 chainId = block.chainid;
        _validateChain(chainId, config.baseSepoliaConfirmed);

        plan = _loadPlan(chainId, config);
        plan = _completePlan(plan);
    }

    function _completePlan(TinyRehearsalPlan memory plan)
        private
        view
        returns (TinyRehearsalPlan memory)
    {
        _validateRun(plan);
        _loadPoolState(plan);
        _validatePoolState(plan);
        _loadActorState(plan);
        _logPlan(plan);
        return plan;
    }

    function _loadPlan(uint256 chainId, bool baseSepoliaConfirmed)
        private
        view
        returns (TinyRehearsalPlan memory plan)
    {
        plan.chainId = chainId;
        plan.baseSepoliaConfirmed = baseSepoliaConfirmed;
        plan.rehearsalActor = _envAddressOr("REHEARSAL_ACTOR", "HOOK_OWNER", LABEL_REHEARSAL_ACTOR);
        plan.poolManager = _envAddressOrDefault(
            "POOL_MANAGER", BaseV4Addresses.BASE_SEPOLIA_POOL_MANAGER, LABEL_POOL_MANAGER
        );
        plan.stateView = _envAddressOrDefault(
            "STATE_VIEW", BaseV4Addresses.BASE_SEPOLIA_STATE_VIEW, LABEL_STATE_VIEW
        );
        plan.positionManager = _envAddressOrDefault(
            "POSITION_MANAGER",
            BaseV4Addresses.BASE_SEPOLIA_POSITION_MANAGER,
            LABEL_POSITION_MANAGER
        );
        plan.universalRouter = _envAddressOrDefault(
            "UNIVERSAL_ROUTER",
            BaseV4Addresses.BASE_SEPOLIA_UNIVERSAL_ROUTER,
            LABEL_UNIVERSAL_ROUTER
        );
        plan.permit2 = _envAddressOrDefault("PERMIT2", BaseV4Addresses.PERMIT2, LABEL_PERMIT2);
        plan.hook = BaseMoonAmmFeeV4Hook(_requiredEnvAddress("HOOK_ADDRESS", LABEL_HOOK));
        plan.adapter = TestnetUsdcAdapter(
            _envAddressOrDefault(
                "SWAP_ADAPTER", address(plan.hook.swapAdapter()), LABEL_SWAP_ADAPTER
            )
        );
        plan.sunCurve = SunCurve(
            _envAddressOrDefault("SUN_CURVE", address(plan.hook.sunCurve()), LABEL_SUN_CURVE)
        );
        plan.moonToken = _envAddressOrDefault(
            "CONTROLLED_POOL_MOON_TOKEN", plan.hook.moonToken(), LABEL_MOON_TOKEN
        );
        plan.usdcToken = _envAddressOrDefault(
            "CONTROLLED_POOL_USDC_TOKEN", BaseV4Addresses.BASE_SEPOLIA_USDC, LABEL_USDC_TOKEN
        );
        plan.fee = uint24(vm.envOr("MOON_USDC_POOL_FEE", uint256(3000)));
        plan.tickSpacing = int24(vm.envOr("MOON_USDC_POOL_TICK_SPACING", int256(60)));
        plan.poolKey = _poolKey(
            plan.moonToken, plan.usdcToken, IHooks(address(plan.hook)), plan.fee, plan.tickSpacing
        );
        plan.poolId = PoolId.unwrap(plan.poolKey.toId());
        plan.liquidityUsdcAmount =
            vm.envOr("TINY_LIQUIDITY_USDC_AMOUNT", DEFAULT_TINY_LIQUIDITY_USDC_AMOUNT);
        plan.liquidityMoonAmount =
            vm.envOr("TINY_LIQUIDITY_MOON_AMOUNT", DEFAULT_TINY_LIQUIDITY_MOON_AMOUNT);
        plan.swapUsdcIn = vm.envOr("TINY_SWAP_USDC_IN", DEFAULT_TINY_SWAP_USDC_IN);
        plan.swapFeeToSunCurve = plan.swapUsdcIn * FEE_TO_SUN_CURVE_BPS / BPS;
        plan.swapFeeToProtocol = plan.swapUsdcIn * FEE_TO_PROTOCOL_BPS / BPS;
        plan.swapUsdcGrossInputWithHookFee =
            plan.swapUsdcIn + plan.swapFeeToSunCurve + plan.swapFeeToProtocol;
        plan.swapMinUsdcToCurve = vm.envOr("TINY_SWAP_MIN_USDC_TO_CURVE", plan.swapFeeToSunCurve);
        plan.zeroForOneUsdcToMoon = Currency.unwrap(plan.poolKey.currency0) == plan.usdcToken;
        plan.swapHookData = abi.encode(
            BaseMoonAmmFeeV4Hook.MoonFeeHookData({ minUSDTOut: plan.swapMinUsdcToCurve })
        );
        plan.quoteRequiredBeforeBroadcast = true;
        plan.transactionsPlanned = 0;
    }

    function _loadPlan(uint256 chainId, TinyRehearsalConfig memory config)
        private
        view
        returns (TinyRehearsalPlan memory plan)
    {
        plan.chainId = chainId;
        plan.baseSepoliaConfirmed = config.baseSepoliaConfirmed;
        plan.rehearsalActor = _requiredConfigAddress(config.rehearsalActor, LABEL_REHEARSAL_ACTOR);
        plan.poolManager =
            _configAddressOrDefault(config.poolManager, BaseV4Addresses.BASE_SEPOLIA_POOL_MANAGER);
        plan.stateView =
            _configAddressOrDefault(config.stateView, BaseV4Addresses.BASE_SEPOLIA_STATE_VIEW);
        plan.positionManager = _configAddressOrDefault(
            config.positionManager, BaseV4Addresses.BASE_SEPOLIA_POSITION_MANAGER
        );
        plan.universalRouter = _configAddressOrDefault(
            config.universalRouter, BaseV4Addresses.BASE_SEPOLIA_UNIVERSAL_ROUTER
        );
        plan.permit2 = _configAddressOrDefault(config.permit2, BaseV4Addresses.PERMIT2);
        plan.hook = BaseMoonAmmFeeV4Hook(_requiredConfigAddress(config.hook, LABEL_HOOK));
        plan.adapter = TestnetUsdcAdapter(
            _configAddressOrDefault(config.adapter, address(plan.hook.swapAdapter()))
        );
        plan.sunCurve =
            SunCurve(_configAddressOrDefault(config.sunCurve, address(plan.hook.sunCurve())));
        plan.moonToken = _configAddressOrDefault(config.moonToken, plan.hook.moonToken());
        plan.usdcToken =
            _configAddressOrDefault(config.usdcToken, BaseV4Addresses.BASE_SEPOLIA_USDC);
        plan.fee = config.fee;
        plan.tickSpacing = config.tickSpacing;
        plan.poolKey = _poolKey(
            plan.moonToken, plan.usdcToken, IHooks(address(plan.hook)), plan.fee, plan.tickSpacing
        );
        plan.poolId = PoolId.unwrap(plan.poolKey.toId());
        plan.liquidityUsdcAmount = config.liquidityUsdcAmount;
        plan.liquidityMoonAmount = config.liquidityMoonAmount;
        plan.swapUsdcIn = config.swapUsdcIn;
        plan.swapFeeToSunCurve = plan.swapUsdcIn * FEE_TO_SUN_CURVE_BPS / BPS;
        plan.swapFeeToProtocol = plan.swapUsdcIn * FEE_TO_PROTOCOL_BPS / BPS;
        plan.swapUsdcGrossInputWithHookFee =
            plan.swapUsdcIn + plan.swapFeeToSunCurve + plan.swapFeeToProtocol;
        plan.swapMinUsdcToCurve = config.swapMinUsdcToCurve;
        plan.zeroForOneUsdcToMoon = Currency.unwrap(plan.poolKey.currency0) == plan.usdcToken;
        plan.swapHookData = abi.encode(
            BaseMoonAmmFeeV4Hook.MoonFeeHookData({ minUSDTOut: plan.swapMinUsdcToCurve })
        );
        plan.quoteRequiredBeforeBroadcast = true;
        plan.transactionsPlanned = 0;
    }

    function _requiredEnvAddress(string memory key, bytes32 label)
        private
        view
        returns (address value)
    {
        value = _parseRequiredAddress(vm.envOr(key, string("")), label);
    }

    function _envAddressOr(string memory primaryKey, string memory fallbackKey, bytes32 label)
        private
        view
        returns (address value)
    {
        string memory rawValue = vm.envOr(primaryKey, string(""));
        if (bytes(rawValue).length == 0) {
            rawValue = vm.envOr(fallbackKey, string(""));
        }

        value = _parseRequiredAddress(rawValue, label);
    }

    function _envAddressOrDefault(string memory key, address defaultValue, bytes32 label)
        private
        view
        returns (address value)
    {
        string memory rawValue = vm.envOr(key, string(""));
        if (bytes(rawValue).length == 0) {
            value = defaultValue;
        } else {
            value = vm.parseAddress(rawValue);
        }
        if (value == address(0)) revert InvalidAddress(label);
    }

    function _parseRequiredAddress(string memory rawValue, bytes32 label)
        private
        pure
        returns (address value)
    {
        if (bytes(rawValue).length == 0) revert InvalidAddress(label);

        value = vm.parseAddress(rawValue);
        if (value == address(0)) revert InvalidAddress(label);
    }

    function _requiredConfigAddress(address value, bytes32 label) private pure returns (address) {
        if (value == address(0)) revert InvalidAddress(label);
        return value;
    }

    function _configAddressOrDefault(address value, address defaultValue)
        private
        pure
        returns (address)
    {
        return value == address(0) ? defaultValue : value;
    }

    function _validateRun(TinyRehearsalPlan memory plan) private view {
        if (plan.fee == 0 || plan.tickSpacing <= 0) {
            revert InvalidPoolConfig(plan.fee, plan.tickSpacing);
        }
        if (plan.liquidityUsdcAmount == 0) {
            revert InvalidAmount("TINY_LIQUIDITY_USDC_AMOUNT", plan.liquidityUsdcAmount);
        }
        if (plan.liquidityMoonAmount == 0) {
            revert InvalidAmount("TINY_LIQUIDITY_MOON_AMOUNT", plan.liquidityMoonAmount);
        }
        if (plan.swapUsdcIn == 0) revert InvalidAmount("TINY_SWAP_USDC_IN", plan.swapUsdcIn);
        if (plan.swapFeeToSunCurve == 0) {
            revert InvalidAmount("TINY_SWAP_FEE_TO_SUN_CURVE", plan.swapFeeToSunCurve);
        }
        if (plan.swapFeeToProtocol == 0) {
            revert InvalidAmount("TINY_SWAP_FEE_TO_PROTOCOL", plan.swapFeeToProtocol);
        }
        if (plan.swapMinUsdcToCurve == 0 || plan.swapMinUsdcToCurve > plan.swapFeeToSunCurve) {
            revert InvalidMinUsdcOut(plan.swapMinUsdcToCurve, plan.swapFeeToSunCurve);
        }

        _requireCode(LABEL_POOL_MANAGER, plan.poolManager);
        _requireCode(LABEL_STATE_VIEW, plan.stateView);
        _requireCode(LABEL_POSITION_MANAGER, plan.positionManager);
        _requireCode(LABEL_UNIVERSAL_ROUTER, plan.universalRouter);
        _requireCode(LABEL_PERMIT2, plan.permit2);
        _requireCode(LABEL_HOOK, address(plan.hook));
        _requireCode(LABEL_SWAP_ADAPTER, address(plan.adapter));
        _requireCode(LABEL_SUN_CURVE, address(plan.sunCurve));
        _requireCode(LABEL_MOON_TOKEN, plan.moonToken);
        _requireCode(LABEL_USDC_TOKEN, plan.usdcToken);

        _requireParameter(LABEL_POOL_MANAGER, plan.poolManager, address(plan.hook.poolManager()));
        _requireParameter(LABEL_MOON_TOKEN, plan.moonToken, plan.hook.moonToken());
        _requireParameter(LABEL_USDC_TOKEN, plan.usdcToken, address(plan.hook.usdt()));
        _requireParameter(
            LABEL_SWAP_ADAPTER, address(plan.adapter), address(plan.hook.swapAdapter())
        );
        _requireParameter(LABEL_SUN_CURVE, address(plan.sunCurve), address(plan.hook.sunCurve()));
        _requireParameter(LABEL_SWAP_ADAPTER, address(plan.hook), plan.adapter.authorizedHook());
        _requireParameter(LABEL_SUN_CURVE, address(plan.hook), plan.sunCurve.moonAMM());

        if (
            plan.chainId == BaseV4Addresses.BASE_SEPOLIA_CHAIN_ID
                && plan.usdcToken != BaseV4Addresses.BASE_SEPOLIA_USDC
        ) {
            revert UnexpectedParameter(
                LABEL_USDC_TOKEN, BaseV4Addresses.BASE_SEPOLIA_USDC, plan.usdcToken
            );
        }

        uint160 expectedMask = BaseV4HookAddressMiner.BASE_MOON_AMM_FEE_V4_HOOK_MASK;
        uint160 actualMask = uint160(address(plan.hook)) & BaseV4HookAddressMiner.V4_ALL_HOOK_MASK;
        if (actualMask != expectedMask) revert UnexpectedHookMask(expectedMask, actualMask);
        if (plan.hook.expectedHookMask() != expectedMask) {
            revert UnexpectedHookMask(expectedMask, plan.hook.expectedHookMask());
        }
        if (plan.poolId == bytes32(0)) revert InvalidAddress(LABEL_POOL_ID);

        plan.allowedMoonPool = plan.hook.allowedMoonPools(plan.poolId);
        if (!plan.allowedMoonPool) revert MoonPoolNotAllowed(plan.poolId);
        plan.hookPaused = plan.hook.paused();
        plan.adapterAuthorized = plan.adapter.authorizedHook() == address(plan.hook);
        plan.sunCurveBound = plan.sunCurve.moonAMM() == address(plan.hook);
        plan.protocolBudget = plan.hook.protocolBudget();
        plan.protocolBudgetConfigured = plan.protocolBudget != address(0);
    }

    function _validateChain(uint256 chainId, bool baseSepoliaConfirmed) private pure {
        if (chainId == BaseV4Addresses.BASE_MAINNET_CHAIN_ID) {
            revert BaseMainnetNotAllowed(chainId);
        }
        if (chainId == BaseV4Addresses.BASE_SEPOLIA_CHAIN_ID && !baseSepoliaConfirmed) {
            revert BaseSepoliaRunNotConfirmed(chainId);
        }
    }

    function _loadPoolState(TinyRehearsalPlan memory plan) private view {
        (plan.sqrtPriceX96, plan.tick, plan.protocolFee, plan.lpFee) =
            IStateView(plan.stateView).getSlot0(PoolId.wrap(plan.poolId));
        plan.poolInitialized = plan.sqrtPriceX96 != 0;
    }

    function _validatePoolState(TinyRehearsalPlan memory plan) private pure {
        if (!plan.poolInitialized) revert PoolNotInitialized(plan.poolId);
        if (plan.lpFee != plan.fee) revert UnexpectedPoolFee(plan.fee, plan.lpFee);
    }

    function _loadActorState(TinyRehearsalPlan memory plan) private view {
        IERC20 usdc = IERC20(plan.usdcToken);
        IERC20 moon = IERC20(plan.moonToken);
        IAllowanceTransfer permit2 = IAllowanceTransfer(plan.permit2);

        plan.actorUsdcBalance = usdc.balanceOf(plan.rehearsalActor);
        plan.actorMoonBalance = moon.balanceOf(plan.rehearsalActor);
        plan.actorUsdcAllowanceToPermit2 = usdc.allowance(plan.rehearsalActor, plan.permit2);
        plan.actorMoonAllowanceToPermit2 = moon.allowance(plan.rehearsalActor, plan.permit2);
        plan.actorUsdcPermit2ToPositionManager =
            _permit2Allowance(permit2, plan.rehearsalActor, plan.usdcToken, plan.positionManager);
        plan.actorMoonPermit2ToPositionManager =
            _permit2Allowance(permit2, plan.rehearsalActor, plan.moonToken, plan.positionManager);
        plan.actorUsdcPermit2ToUniversalRouter =
            _permit2Allowance(permit2, plan.rehearsalActor, plan.usdcToken, plan.universalRouter);

        plan.hasLiquidityBalances = plan.actorUsdcBalance >= plan.liquidityUsdcAmount
            && plan.actorMoonBalance >= plan.liquidityMoonAmount;
        plan.hasSwapBalance = plan.actorUsdcBalance >= plan.swapUsdcGrossInputWithHookFee;
        plan.hasPermit2TokenApprovals = plan.actorUsdcAllowanceToPermit2
                >= plan.liquidityUsdcAmount + plan.swapUsdcGrossInputWithHookFee
            && plan.actorMoonAllowanceToPermit2 >= plan.liquidityMoonAmount;
        plan.hasPositionManagerPermit2Allowances = _permit2Ready(
            plan.actorUsdcPermit2ToPositionManager, plan.liquidityUsdcAmount
        ) && _permit2Ready(plan.actorMoonPermit2ToPositionManager, plan.liquidityMoonAmount);
        plan.hasUniversalRouterPermit2Allowance = _permit2Ready(
            plan.actorUsdcPermit2ToUniversalRouter, plan.swapUsdcGrossInputWithHookFee
        );

        plan.readyForLiquidityDryRun = plan.poolInitialized && plan.allowedMoonPool
            && !plan.hookPaused && plan.adapterAuthorized && plan.sunCurveBound
            && plan.protocolBudgetConfigured && plan.hasLiquidityBalances
            && plan.hasPermit2TokenApprovals && plan.hasPositionManagerPermit2Allowances;
        plan.readyForSwapDryRun = plan.poolInitialized && plan.allowedMoonPool && !plan.hookPaused
            && plan.adapterAuthorized && plan.sunCurveBound && plan.protocolBudgetConfigured
            && plan.hasSwapBalance
            && plan.actorUsdcAllowanceToPermit2 >= plan.swapUsdcGrossInputWithHookFee
            && plan.hasUniversalRouterPermit2Allowance;
        plan.readyForCombinedDryRun = plan.poolInitialized && plan.allowedMoonPool
            && !plan.hookPaused && plan.adapterAuthorized && plan.sunCurveBound
            && plan.protocolBudgetConfigured
            && plan.actorUsdcBalance
                >= plan.liquidityUsdcAmount + plan.swapUsdcGrossInputWithHookFee
            && plan.actorMoonBalance >= plan.liquidityMoonAmount && plan.hasPermit2TokenApprovals
            && plan.hasPositionManagerPermit2Allowances && plan.hasUniversalRouterPermit2Allowance;
    }

    function _permit2Allowance(
        IAllowanceTransfer permit2,
        address owner,
        address token,
        address spender
    ) private view returns (Permit2Allowance memory allowance_) {
        (allowance_.amount, allowance_.expiration, allowance_.nonce) =
            permit2.allowance(owner, token, spender);
        allowance_.active = allowance_.amount != 0 && allowance_.expiration >= block.timestamp;
    }

    function _permit2Ready(Permit2Allowance memory allowance_, uint256 amount)
        private
        view
        returns (bool)
    {
        return uint256(allowance_.amount) >= amount && allowance_.expiration >= block.timestamp;
    }

    function _poolKey(address tokenA, address tokenB, IHooks hooks, uint24 fee, int24 tickSpacing)
        private
        pure
        returns (PoolKey memory key)
    {
        if (tokenA == tokenB || tokenA == address(0) || tokenB == address(0)) {
            revert InvalidAddress("POOL_TOKEN");
        }
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

    function _requireCode(bytes32 label, address target) private view {
        if (target.code.length == 0) revert DependencyCodeMissing(label, target);
    }

    function _requireParameter(bytes32 label, address expected, address actual) private pure {
        if (actual != expected) revert UnexpectedParameter(label, expected, actual);
    }

    function _logPlan(TinyRehearsalPlan memory plan) private pure {
        console2.log("Base Sepolia tiny MOON/USDC liquidity/swap rehearsal preparation");
        console2.log("simulationOnly:", "read-only plan; this script never broadcasts transactions");
        console2.log("chainId:", plan.chainId);
        console2.log("baseSepoliaConfirmed:", plan.baseSepoliaConfirmed);
        console2.log("REHEARSAL_ACTOR:", plan.rehearsalActor);
        console2.log("POOL_MANAGER:", plan.poolManager);
        console2.log("STATE_VIEW:", plan.stateView);
        console2.log("POSITION_MANAGER:", plan.positionManager);
        console2.log("UNIVERSAL_ROUTER:", plan.universalRouter);
        console2.log("PERMIT2:", plan.permit2);
        console2.log("HOOK_ADDRESS:", address(plan.hook));
        console2.log("SWAP_ADAPTER:", address(plan.adapter));
        console2.log("SUN_CURVE:", address(plan.sunCurve));
        console2.log("PROTOCOL_BUDGET:", plan.protocolBudget);
        console2.log("MOON_TOKEN:", plan.moonToken);
        console2.log("USDC_TOKEN:", plan.usdcToken);
        console2.log("pool.currency0:", Currency.unwrap(plan.poolKey.currency0));
        console2.log("pool.currency1:", Currency.unwrap(plan.poolKey.currency1));
        console2.log("pool.fee:", plan.fee);
        console2.log("pool.tickSpacing:", plan.tickSpacing);
        console2.logBytes32(plan.poolId);
        console2.log("poolInitialized:", plan.poolInitialized);
        console2.log("slot0.sqrtPriceX96:", plan.sqrtPriceX96);
        console2.log("slot0.tick:", plan.tick);
        console2.log("slot0.protocolFee:", plan.protocolFee);
        console2.log("slot0.lpFee:", plan.lpFee);
        console2.log("allowedMoonPool:", plan.allowedMoonPool);
        console2.log("hookPaused:", plan.hookPaused);
        console2.log("adapterAuthorized:", plan.adapterAuthorized);
        console2.log("sunCurveBound:", plan.sunCurveBound);
        console2.log("protocolBudgetConfigured:", plan.protocolBudgetConfigured);
        console2.log("tinyLiquidityUsdcAmount:", plan.liquidityUsdcAmount);
        console2.log("tinyLiquidityMoonAmount:", plan.liquidityMoonAmount);
        console2.log("tinySwapUsdcIn:", plan.swapUsdcIn);
        console2.log("swapFeeToSunCurve:", plan.swapFeeToSunCurve);
        console2.log("swapFeeToProtocol:", plan.swapFeeToProtocol);
        console2.log("swapUsdcGrossInputWithHookFee:", plan.swapUsdcGrossInputWithHookFee);
        console2.log("swapMinUsdcToCurve:", plan.swapMinUsdcToCurve);
        console2.log("zeroForOneUsdcToMoon:", plan.zeroForOneUsdcToMoon);
        console2.log("swapHookDataLength:", plan.swapHookData.length);
        console2.log("actorUsdcBalance:", plan.actorUsdcBalance);
        console2.log("actorMoonBalance:", plan.actorMoonBalance);
        console2.log("actorUsdcAllowanceToPermit2:", plan.actorUsdcAllowanceToPermit2);
        console2.log("actorMoonAllowanceToPermit2:", plan.actorMoonAllowanceToPermit2);
        console2.log(
            "actorUsdcPermit2ToPositionManager:", plan.actorUsdcPermit2ToPositionManager.amount
        );
        console2.log(
            "actorMoonPermit2ToPositionManager:", plan.actorMoonPermit2ToPositionManager.amount
        );
        console2.log(
            "actorUsdcPermit2ToUniversalRouter:", plan.actorUsdcPermit2ToUniversalRouter.amount
        );
        console2.log("hasLiquidityBalances:", plan.hasLiquidityBalances);
        console2.log("hasSwapBalance:", plan.hasSwapBalance);
        console2.log("hasPermit2TokenApprovals:", plan.hasPermit2TokenApprovals);
        console2.log(
            "hasPositionManagerPermit2Allowances:", plan.hasPositionManagerPermit2Allowances
        );
        console2.log("hasUniversalRouterPermit2Allowance:", plan.hasUniversalRouterPermit2Allowance);
        console2.log("readyForLiquidityDryRun:", plan.readyForLiquidityDryRun);
        console2.log("readyForSwapDryRun:", plan.readyForSwapDryRun);
        console2.log("readyForCombinedDryRun:", plan.readyForCombinedDryRun);
        console2.log("quoteRequiredBeforeBroadcast:", plan.quoteRequiredBeforeBroadcast);
        console2.log("transactionsPlanned:", plan.transactionsPlanned);
        console2.log("Next step:");
        console2.log(
            "fund the rehearsal actor with tiny Base Sepolia USDC/MOON and set Permit2 approvals"
        );
    }
}
