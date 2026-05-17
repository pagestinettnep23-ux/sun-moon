// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Script, console2 } from "forge-std/Script.sol";
import { TickMath } from "@uniswap/v4-core/src/libraries/TickMath.sol";
import { Currency } from "@uniswap/v4-core/src/types/Currency.sol";
import { PoolKey } from "@uniswap/v4-core/src/types/PoolKey.sol";
import { IPositionManager } from "@uniswap/v4-periphery/src/interfaces/IPositionManager.sol";
import { IV4Quoter } from "@uniswap/v4-periphery/src/interfaces/IV4Quoter.sol";
import { IV4Router } from "@uniswap/v4-periphery/src/interfaces/IV4Router.sol";
import { Actions } from "@uniswap/v4-periphery/src/libraries/Actions.sol";
import { LiquidityAmounts } from "@uniswap/v4-periphery/src/libraries/LiquidityAmounts.sol";
import { BaseV4Addresses } from "../contracts/hooks/base/BaseV4Addresses.sol";
import {
    PrepareBaseSepoliaTinyMoonUsdcRehearsal
} from "./PrepareBaseSepoliaTinyMoonUsdcRehearsal.s.sol";

interface IUniversalRouter {
    function execute(bytes calldata commands, bytes[] calldata inputs, uint256 deadline)
        external
        payable;
}

contract PrepareBaseSepoliaTinyMoonUsdcBroadcast is Script {
    uint256 internal constant BPS = 10_000;
    uint256 internal constant DEFAULT_SLIPPAGE_BPS = 1000;
    int24 internal constant DEFAULT_TICK_RANGE = 600;
    uint256 internal constant DEFAULT_DEADLINE_SECONDS = 600;
    uint256 internal constant UNIVERSAL_ROUTER_V4_SWAP = 0x10;

    struct TinyBroadcastConfig {
        bool baseSepoliaConfirmed;
        bool executeLiquidity;
        bool executeSwap;
        bool quoteAfterLiquiditySimulation;
        bool useLegacyRouterSwapParams;
        address rehearsalActor;
        address quoter;
        uint256 slippageBps;
        uint256 minMoonOut;
        uint256 deadlineSeconds;
        int24 tickRange;
    }

    struct TinyBroadcastPlan {
        uint256 chainId;
        bool baseSepoliaConfirmed;
        bool executeLiquidity;
        bool executeSwap;
        bool quoteAfterLiquiditySimulation;
        bool useLegacyRouterSwapParams;
        address rehearsalActor;
        address positionManager;
        address universalRouter;
        address quoter;
        address moonToken;
        address usdcToken;
        bytes32 poolId;
        int24 currentTick;
        int24 tickLower;
        int24 tickUpper;
        uint160 sqrtPriceX96;
        uint128 liquidity;
        uint256 liquidityUsdcAmount;
        uint256 liquidityMoonAmount;
        uint256 amount0Max;
        uint256 amount1Max;
        uint256 positionTokenId;
        uint256 positionLiquidityAfterMint;
        uint256 swapUsdcIn;
        uint256 swapFeeToSunCurve;
        uint256 swapFeeToProtocol;
        uint256 swapUsdcGrossInputWithHookFee;
        uint256 quoteMoonOut;
        uint256 quoteGasEstimate;
        uint256 slippageBps;
        uint256 minMoonOut;
        uint256 deadline;
        bytes liquidityCalls;
        bytes swapCommands;
        bytes swapInput;
        bool readinessPassed;
        bool liquiditySimulationPassed;
        bool quoteSimulationPassed;
        bool readyForTinyBroadcast;
        uint256 draftTransactions;
        uint256 transactionsPlanned;
        uint256 transactionsExecuted;
        uint256 actorUsdcBalanceAfter;
        uint256 actorMoonBalanceAfter;
    }

    struct LegacyExactInputSingleParams {
        PoolKey poolKey;
        bool zeroForOne;
        uint128 amountIn;
        uint128 amountOutMinimum;
        bytes hookData;
    }

    error BaseMainnetNotAllowed(uint256 chainId);
    error BaseSepoliaRunNotConfirmed(uint256 chainId);
    error CannotExecuteTinyBroadcast(bytes32 reason);
    error DependencyCodeMissing(bytes32 label, address target);
    error InvalidAddress(bytes32 label);
    error InvalidAmount(bytes32 label, uint256 amount);
    error InvalidSlippageBps(uint256 slippageBps);
    error InvalidTickRange(int24 tickLower, int24 tickUpper);
    error QuoteAssumesUnbroadcastLiquidity();
    error SnapshotRevertFailed();
    error UnexpectedChain(uint256 expected, uint256 actual);
    error UnexpectedParameter(bytes32 label, address expected, address actual);

    function run() external returns (TinyBroadcastPlan memory result) {
        PrepareBaseSepoliaTinyMoonUsdcRehearsal rehearsalScript =
            new PrepareBaseSepoliaTinyMoonUsdcRehearsal();
        PrepareBaseSepoliaTinyMoonUsdcRehearsal.TinyRehearsalPlan memory rehearsal =
            rehearsalScript.run();

        result = prepare(rehearsal, _loadConfig(rehearsal.rehearsalActor));
    }

    function prepare(
        PrepareBaseSepoliaTinyMoonUsdcRehearsal.TinyRehearsalPlan memory rehearsal,
        TinyBroadcastConfig memory config
    ) public returns (TinyBroadcastPlan memory result) {
        _validateConfig(rehearsal, config);
        result = _buildPlan(rehearsal, config);
        _simulateQuotePath(rehearsal, result);
        _finalizePlan(rehearsal, result);

        if (result.executeLiquidity || result.executeSwap) {
            _requireExecutable(result);
            result.transactionsExecuted = _execute(result);
            result.actorUsdcBalanceAfter = IERC20(result.usdcToken).balanceOf(result.rehearsalActor);
            result.actorMoonBalanceAfter = IERC20(result.moonToken).balanceOf(result.rehearsalActor);
        }

        _logPlan(result);
    }

    function _loadConfig(address defaultActor)
        private
        view
        returns (TinyBroadcastConfig memory config)
    {
        config.baseSepoliaConfirmed =
            vm.envOr("CONFIRM_BASE_SEPOLIA_TINY_BROADCAST_RUN", uint256(0)) == 1;
        config.executeLiquidity = vm.envOr("EXECUTE_BASE_SEPOLIA_TINY_LIQUIDITY", uint256(0)) == 1;
        config.executeSwap = vm.envOr("EXECUTE_BASE_SEPOLIA_TINY_SWAP", uint256(0)) == 1;
        config.quoteAfterLiquiditySimulation =
            vm.envOr("QUOTE_AFTER_TINY_LIQUIDITY_SIMULATION", uint256(1)) == 1;
        config.useLegacyRouterSwapParams =
            vm.envOr("USE_LEGACY_V4_ROUTER_SWAP_PARAMS", uint256(1)) == 1;
        config.rehearsalActor =
            _envAddressOrDefault("REHEARSAL_ACTOR", defaultActor, "REHEARSAL_ACTOR");
        config.quoter =
            _envAddressOrDefault("QUOTER", BaseV4Addresses.BASE_SEPOLIA_QUOTER, "QUOTER");
        config.slippageBps = vm.envOr("TINY_SWAP_SLIPPAGE_BPS", DEFAULT_SLIPPAGE_BPS);
        config.minMoonOut = vm.envOr("TINY_SWAP_MIN_MOON_OUT", uint256(0));
        config.deadlineSeconds =
            vm.envOr("TINY_BROADCAST_DEADLINE_SECONDS", DEFAULT_DEADLINE_SECONDS);
        config.tickRange = int24(vm.envOr("TINY_LIQUIDITY_TICK_RANGE", int256(DEFAULT_TICK_RANGE)));
    }

    function _validateConfig(
        PrepareBaseSepoliaTinyMoonUsdcRehearsal.TinyRehearsalPlan memory rehearsal,
        TinyBroadcastConfig memory config
    ) private view {
        if (rehearsal.chainId != 0 && rehearsal.chainId != block.chainid) {
            revert UnexpectedChain(rehearsal.chainId, block.chainid);
        }

        bool baseSepoliaConfirmed = config.baseSepoliaConfirmed || rehearsal.baseSepoliaConfirmed;
        _validateChain(block.chainid, baseSepoliaConfirmed);

        if (config.rehearsalActor == address(0)) revert InvalidAddress("REHEARSAL_ACTOR");
        if (config.rehearsalActor != rehearsal.rehearsalActor) {
            revert UnexpectedParameter(
                "REHEARSAL_ACTOR", rehearsal.rehearsalActor, config.rehearsalActor
            );
        }
        if (config.quoter == address(0)) revert InvalidAddress("QUOTER");
        _requireCode("QUOTER", config.quoter);

        if (config.slippageBps >= BPS) revert InvalidSlippageBps(config.slippageBps);
        if (config.deadlineSeconds == 0) {
            revert InvalidAmount("TINY_BROADCAST_DEADLINE_SECONDS", config.deadlineSeconds);
        }
        if (config.tickRange <= 0) revert InvalidTickRange(0, config.tickRange);

        if (config.quoteAfterLiquiditySimulation && !rehearsal.readyForLiquidityDryRun) {
            revert CannotExecuteTinyBroadcast("LIQUIDITY_READINESS_FAILED");
        }
        if (!rehearsal.readyForSwapDryRun) {
            revert CannotExecuteTinyBroadcast("SWAP_READINESS_FAILED");
        }
        if (config.executeLiquidity && !rehearsal.readyForLiquidityDryRun) {
            revert CannotExecuteTinyBroadcast("LIQUIDITY_READINESS_FAILED");
        }
        if (config.executeLiquidity && config.executeSwap && !rehearsal.readyForCombinedDryRun) {
            revert CannotExecuteTinyBroadcast("COMBINED_READINESS_FAILED");
        }
        if (config.executeSwap && !config.executeLiquidity && config.quoteAfterLiquiditySimulation)
        {
            revert QuoteAssumesUnbroadcastLiquidity();
        }
    }

    function _buildPlan(
        PrepareBaseSepoliaTinyMoonUsdcRehearsal.TinyRehearsalPlan memory rehearsal,
        TinyBroadcastConfig memory config
    ) private view returns (TinyBroadcastPlan memory result) {
        result.chainId = block.chainid;
        result.baseSepoliaConfirmed = config.baseSepoliaConfirmed || rehearsal.baseSepoliaConfirmed;
        result.executeLiquidity = config.executeLiquidity;
        result.executeSwap = config.executeSwap;
        result.quoteAfterLiquiditySimulation = config.quoteAfterLiquiditySimulation;
        result.useLegacyRouterSwapParams = config.useLegacyRouterSwapParams;
        result.rehearsalActor = rehearsal.rehearsalActor;
        result.positionManager = rehearsal.positionManager;
        result.universalRouter = rehearsal.universalRouter;
        result.quoter = config.quoter;
        result.moonToken = rehearsal.moonToken;
        result.usdcToken = rehearsal.usdcToken;
        result.poolId = rehearsal.poolId;
        result.currentTick = rehearsal.tick;
        result.sqrtPriceX96 = rehearsal.sqrtPriceX96;
        result.liquidityUsdcAmount = rehearsal.liquidityUsdcAmount;
        result.liquidityMoonAmount = rehearsal.liquidityMoonAmount;
        result.swapUsdcIn = rehearsal.swapUsdcIn;
        result.swapFeeToSunCurve = rehearsal.swapFeeToSunCurve;
        result.swapFeeToProtocol = rehearsal.swapFeeToProtocol;
        result.swapUsdcGrossInputWithHookFee = rehearsal.swapUsdcGrossInputWithHookFee;
        result.slippageBps = config.slippageBps;
        result.minMoonOut = config.minMoonOut;
        result.deadline = block.timestamp + config.deadlineSeconds;

        (result.tickLower, result.tickUpper) =
            _defaultTickRange(rehearsal.tick, rehearsal.tickSpacing, config.tickRange);
        _validateTickRange(result.tickLower, result.tickUpper, rehearsal.tickSpacing);

        (result.amount0Max, result.amount1Max) = _amountsForPoolOrder(
            rehearsal.poolKey,
            rehearsal.usdcToken,
            rehearsal.moonToken,
            rehearsal.liquidityUsdcAmount,
            rehearsal.liquidityMoonAmount
        );
        result.liquidity = LiquidityAmounts.getLiquidityForAmounts(
            rehearsal.sqrtPriceX96,
            TickMath.getSqrtPriceAtTick(result.tickLower),
            TickMath.getSqrtPriceAtTick(result.tickUpper),
            result.amount0Max,
            result.amount1Max
        );
        if (result.liquidity == 0) revert InvalidAmount("LIQUIDITY", result.liquidity);

        result.liquidityCalls = _mintPositionCalls(
            rehearsal.poolKey,
            result.tickLower,
            result.tickUpper,
            result.liquidity,
            result.amount0Max,
            result.amount1Max,
            result.rehearsalActor
        );
        result.readinessPassed =
            (!result.quoteAfterLiquiditySimulation || rehearsal.readyForLiquidityDryRun)
                && rehearsal.readyForSwapDryRun;
        result.draftTransactions = 2;
        result.transactionsPlanned =
            (result.executeLiquidity ? 1 : 0) + (result.executeSwap ? 1 : 0);
    }

    function _simulateQuotePath(
        PrepareBaseSepoliaTinyMoonUsdcRehearsal.TinyRehearsalPlan memory rehearsal,
        TinyBroadcastPlan memory result
    ) private {
        if (!result.quoteAfterLiquiditySimulation) {
            result.liquiditySimulationPassed = true;
            _simulateQuote(rehearsal, result);
            return;
        }

        uint256 snapshotId = vm.snapshotState();
        _simulateLiquidityMint(rehearsal, result);
        _simulateQuote(rehearsal, result);
        if (!vm.revertToStateAndDelete(snapshotId)) revert SnapshotRevertFailed();
    }

    function _simulateLiquidityMint(
        PrepareBaseSepoliaTinyMoonUsdcRehearsal.TinyRehearsalPlan memory rehearsal,
        TinyBroadcastPlan memory result
    ) private {
        IERC20 usdc = IERC20(rehearsal.usdcToken);
        IERC20 moon = IERC20(rehearsal.moonToken);
        IPositionManager positionManager = IPositionManager(rehearsal.positionManager);

        uint256 usdcBefore = usdc.balanceOf(rehearsal.rehearsalActor);
        uint256 moonBefore = moon.balanceOf(rehearsal.rehearsalActor);
        result.positionTokenId = positionManager.nextTokenId();

        vm.prank(rehearsal.rehearsalActor);
        positionManager.modifyLiquidities(result.liquidityCalls, result.deadline);

        result.positionLiquidityAfterMint =
            positionManager.getPositionLiquidity(result.positionTokenId);
        uint256 usdcSpent = usdcBefore - usdc.balanceOf(rehearsal.rehearsalActor);
        uint256 moonSpent = moonBefore - moon.balanceOf(rehearsal.rehearsalActor);
        result.liquiditySimulationPassed = result.positionLiquidityAfterMint == result.liquidity
            && usdcSpent <= rehearsal.liquidityUsdcAmount
            && moonSpent <= rehearsal.liquidityMoonAmount;
    }

    function _simulateQuote(
        PrepareBaseSepoliaTinyMoonUsdcRehearsal.TinyRehearsalPlan memory rehearsal,
        TinyBroadcastPlan memory result
    ) private {
        IV4Quoter.QuoteExactSingleParams memory params = IV4Quoter.QuoteExactSingleParams({
            poolKey: rehearsal.poolKey,
            zeroForOne: rehearsal.zeroForOneUsdcToMoon,
            exactAmount: uint128(rehearsal.swapUsdcIn),
            hookData: rehearsal.swapHookData
        });

        (result.quoteMoonOut, result.quoteGasEstimate) =
            IV4Quoter(result.quoter).quoteExactInputSingle(params);
        result.quoteSimulationPassed = result.quoteMoonOut > 0 && result.quoteGasEstimate > 0;
    }

    function _finalizePlan(
        PrepareBaseSepoliaTinyMoonUsdcRehearsal.TinyRehearsalPlan memory rehearsal,
        TinyBroadcastPlan memory result
    ) private pure {
        uint256 suggestedMinMoonOut = _minMoonOut(result.quoteMoonOut, result.slippageBps);
        if (result.minMoonOut == 0) result.minMoonOut = suggestedMinMoonOut;
        if (result.minMoonOut > result.quoteMoonOut) {
            revert InvalidAmount("TINY_SWAP_MIN_MOON_OUT", result.minMoonOut);
        }
        if (result.minMoonOut == 0) revert InvalidAmount("TINY_SWAP_MIN_MOON_OUT", 0);

        result.swapCommands = _universalRouterV4SwapCommand();
        result.swapInput = _swapInput(
            rehearsal.poolKey,
            rehearsal.zeroForOneUsdcToMoon,
            rehearsal.swapUsdcIn,
            result.minMoonOut,
            rehearsal.swapHookData,
            result.swapUsdcGrossInputWithHookFee,
            result.useLegacyRouterSwapParams
        );
        result.readyForTinyBroadcast = result.readinessPassed && result.liquiditySimulationPassed
            && result.quoteSimulationPassed;
    }

    function _requireExecutable(TinyBroadcastPlan memory result) private pure {
        if (!result.readyForTinyBroadcast) {
            revert CannotExecuteTinyBroadcast("NOT_READY_FOR_TINY_BROADCAST");
        }
        if (result.executeLiquidity && result.liquidityCalls.length == 0) {
            revert CannotExecuteTinyBroadcast("MISSING_LIQUIDITY_CALLS");
        }
        if (result.executeSwap && (result.swapCommands.length == 0 || result.swapInput.length == 0))
        {
            revert CannotExecuteTinyBroadcast("MISSING_SWAP_CALLS");
        }
    }

    function _execute(TinyBroadcastPlan memory result)
        private
        returns (uint256 transactionsExecuted)
    {
        vm.startBroadcast(result.rehearsalActor);

        if (result.executeLiquidity) {
            IPositionManager(result.positionManager)
                .modifyLiquidities(result.liquidityCalls, result.deadline);
            transactionsExecuted++;
        }
        if (result.executeSwap) {
            bytes[] memory inputs = new bytes[](1);
            inputs[0] = result.swapInput;
            IUniversalRouter(result.universalRouter)
                .execute(result.swapCommands, inputs, result.deadline);
            transactionsExecuted++;
        }

        vm.stopBroadcast();
    }

    function _mintPositionCalls(
        PoolKey memory poolKey,
        int24 tickLower,
        int24 tickUpper,
        uint128 liquidity,
        uint256 amount0Max,
        uint256 amount1Max,
        address owner
    ) private pure returns (bytes memory) {
        bytes memory actions = new bytes(3);
        actions[0] = bytes1(uint8(Actions.MINT_POSITION));
        actions[1] = bytes1(uint8(Actions.CLOSE_CURRENCY));
        actions[2] = bytes1(uint8(Actions.CLOSE_CURRENCY));

        bytes[] memory params = new bytes[](3);
        params[0] = abi.encode(
            poolKey,
            tickLower,
            tickUpper,
            uint256(liquidity),
            uint128(amount0Max),
            uint128(amount1Max),
            owner,
            bytes("")
        );
        params[1] = abi.encode(poolKey.currency0);
        params[2] = abi.encode(poolKey.currency1);

        return abi.encode(actions, params);
    }

    function _universalRouterV4SwapCommand() private pure returns (bytes memory commands) {
        commands = new bytes(1);
        commands[0] = bytes1(uint8(UNIVERSAL_ROUTER_V4_SWAP));
    }

    function _swapInput(
        PoolKey memory poolKey,
        bool zeroForOne,
        uint256 amountIn,
        uint256 minAmountOut,
        bytes memory hookData,
        uint256 maxSettleAmount,
        bool useLegacyRouterSwapParams
    ) private pure returns (bytes memory) {
        Currency inputCurrency = zeroForOne ? poolKey.currency0 : poolKey.currency1;
        Currency outputCurrency = zeroForOne ? poolKey.currency1 : poolKey.currency0;

        bytes memory actions = new bytes(3);
        actions[0] = bytes1(uint8(Actions.SWAP_EXACT_IN_SINGLE));
        actions[1] = bytes1(uint8(Actions.SETTLE_ALL));
        actions[2] = bytes1(uint8(Actions.TAKE_ALL));

        bytes[] memory params = new bytes[](3);
        params[0] = useLegacyRouterSwapParams
            ? abi.encode(
                LegacyExactInputSingleParams({
                    poolKey: poolKey,
                    zeroForOne: zeroForOne,
                    amountIn: uint128(amountIn),
                    amountOutMinimum: uint128(minAmountOut),
                    hookData: hookData
                })
            )
            : abi.encode(
                IV4Router.ExactInputSingleParams({
                    poolKey: poolKey,
                    zeroForOne: zeroForOne,
                    amountIn: uint128(amountIn),
                    amountOutMinimum: uint128(minAmountOut),
                    minHopPriceX36: 0,
                    hookData: hookData
                })
            );
        params[1] = abi.encode(inputCurrency, maxSettleAmount);
        params[2] = abi.encode(outputCurrency, minAmountOut);

        return abi.encode(actions, params);
    }

    function _amountsForPoolOrder(
        PoolKey memory poolKey,
        address usdcToken,
        address moonToken,
        uint256 usdcAmount,
        uint256 moonAmount
    ) private pure returns (uint256 amount0Max, uint256 amount1Max) {
        address currency0 = Currency.unwrap(poolKey.currency0);
        address currency1 = Currency.unwrap(poolKey.currency1);

        if (currency0 == usdcToken && currency1 == moonToken) {
            return (usdcAmount, moonAmount);
        }
        if (currency0 == moonToken && currency1 == usdcToken) {
            return (moonAmount, usdcAmount);
        }

        revert InvalidAddress("POOL_TOKEN_ORDER");
    }

    function _defaultTickRange(int24 currentTick, int24 tickSpacing, int24 tickRange)
        private
        pure
        returns (int24 tickLower, int24 tickUpper)
    {
        if (tickRange <= 0) revert InvalidTickRange(0, tickRange);

        tickLower = _floorToSpacing(currentTick - tickRange, tickSpacing);
        tickUpper = _floorToSpacing(currentTick + tickRange, tickSpacing);
        if (tickLower >= currentTick) tickLower -= tickSpacing;
        if (tickUpper <= currentTick) tickUpper += tickSpacing;

        int24 minTick = TickMath.minUsableTick(tickSpacing);
        int24 maxTick = TickMath.maxUsableTick(tickSpacing);
        if (tickLower < minTick) tickLower = minTick;
        if (tickUpper > maxTick) tickUpper = maxTick;
    }

    function _floorToSpacing(int24 tick, int24 tickSpacing) private pure returns (int24) {
        int24 compressed = tick / tickSpacing;
        if (tick < 0 && tick % tickSpacing != 0) compressed -= 1;
        return compressed * tickSpacing;
    }

    function _validateTickRange(int24 tickLower, int24 tickUpper, int24 tickSpacing) private pure {
        if (
            tickLower >= tickUpper || tickLower % tickSpacing != 0 || tickUpper % tickSpacing != 0
                || tickLower < TickMath.minUsableTick(tickSpacing)
                || tickUpper > TickMath.maxUsableTick(tickSpacing)
        ) {
            revert InvalidTickRange(tickLower, tickUpper);
        }
    }

    function _minMoonOut(uint256 quoteMoonOut, uint256 slippageBps) private pure returns (uint256) {
        return quoteMoonOut * (BPS - slippageBps) / BPS;
    }

    function _validateChain(uint256 chainId, bool baseSepoliaConfirmed) private pure {
        if (chainId == BaseV4Addresses.BASE_MAINNET_CHAIN_ID) {
            revert BaseMainnetNotAllowed(chainId);
        }
        if (chainId == BaseV4Addresses.BASE_SEPOLIA_CHAIN_ID && !baseSepoliaConfirmed) {
            revert BaseSepoliaRunNotConfirmed(chainId);
        }
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

    function _requireCode(bytes32 label, address target) private view {
        if (target.code.length == 0) revert DependencyCodeMissing(label, target);
    }

    function _logPlan(TinyBroadcastPlan memory result) private pure {
        console2.log("Base Sepolia tiny MOON/USDC liquidity and swap broadcast draft");
        console2.log(
            "simulationOnly:", "default read-only; execution requires explicit env and approval"
        );
        console2.log("chainId:", result.chainId);
        console2.log("baseSepoliaConfirmed:", result.baseSepoliaConfirmed);
        console2.log("executeLiquidity:", result.executeLiquidity);
        console2.log("executeSwap:", result.executeSwap);
        console2.log("quoteAfterLiquiditySimulation:", result.quoteAfterLiquiditySimulation);
        console2.log("useLegacyRouterSwapParams:", result.useLegacyRouterSwapParams);
        console2.log("REHEARSAL_ACTOR:", result.rehearsalActor);
        console2.log("POSITION_MANAGER:", result.positionManager);
        console2.log("UNIVERSAL_ROUTER:", result.universalRouter);
        console2.log("QUOTER:", result.quoter);
        console2.log("MOON_TOKEN:", result.moonToken);
        console2.log("USDC_TOKEN:", result.usdcToken);
        console2.logBytes32(result.poolId);
        console2.log("currentTick:", result.currentTick);
        console2.log("tickLower:", result.tickLower);
        console2.log("tickUpper:", result.tickUpper);
        console2.log("sqrtPriceX96:", result.sqrtPriceX96);
        console2.log("liquidity:", result.liquidity);
        console2.log("liquidityUsdcAmount:", result.liquidityUsdcAmount);
        console2.log("liquidityMoonAmount:", result.liquidityMoonAmount);
        console2.log("amount0Max:", result.amount0Max);
        console2.log("amount1Max:", result.amount1Max);
        console2.log("positionTokenId:", result.positionTokenId);
        console2.log("positionLiquidityAfterMint:", result.positionLiquidityAfterMint);
        console2.log("swapUsdcIn:", result.swapUsdcIn);
        console2.log("swapFeeToSunCurve:", result.swapFeeToSunCurve);
        console2.log("swapFeeToProtocol:", result.swapFeeToProtocol);
        console2.log("swapUsdcGrossInputWithHookFee:", result.swapUsdcGrossInputWithHookFee);
        console2.log("quoteMoonOut:", result.quoteMoonOut);
        console2.log("quoteGasEstimate:", result.quoteGasEstimate);
        console2.log("slippageBps:", result.slippageBps);
        console2.log("minMoonOut:", result.minMoonOut);
        console2.log("deadline:", result.deadline);
        console2.logBytes(result.swapCommands);
        console2.log("liquidityCallsLength:", result.liquidityCalls.length);
        console2.log("swapInputLength:", result.swapInput.length);
        console2.log("readinessPassed:", result.readinessPassed);
        console2.log("liquiditySimulationPassed:", result.liquiditySimulationPassed);
        console2.log("quoteSimulationPassed:", result.quoteSimulationPassed);
        console2.log("readyForTinyBroadcast:", result.readyForTinyBroadcast);
        console2.log("draftTransactions:", result.draftTransactions);
        console2.log("transactionsPlanned:", result.transactionsPlanned);
        console2.log("transactionsExecuted:", result.transactionsExecuted);
        console2.log("actorUsdcBalanceAfter:", result.actorUsdcBalanceAfter);
        console2.log("actorMoonBalanceAfter:", result.actorMoonBalanceAfter);
        console2.log("Private key prompt rule:");
        console2.log(
            "enter only the private key for REHEARSAL_ACTOR shown above; never paste it in chat"
        );
    }
}
