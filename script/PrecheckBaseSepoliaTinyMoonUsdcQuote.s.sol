// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Script, console2 } from "forge-std/Script.sol";
import { TickMath } from "@uniswap/v4-core/src/libraries/TickMath.sol";
import { Currency } from "@uniswap/v4-core/src/types/Currency.sol";
import { PoolId } from "@uniswap/v4-core/src/types/PoolId.sol";
import { PoolKey } from "@uniswap/v4-core/src/types/PoolKey.sol";
import { IPositionManager } from "@uniswap/v4-periphery/src/interfaces/IPositionManager.sol";
import { IV4Quoter } from "@uniswap/v4-periphery/src/interfaces/IV4Quoter.sol";
import { Actions } from "@uniswap/v4-periphery/src/libraries/Actions.sol";
import { LiquidityAmounts } from "@uniswap/v4-periphery/src/libraries/LiquidityAmounts.sol";
import { BaseV4Addresses } from "../contracts/hooks/base/BaseV4Addresses.sol";
import {
    PrepareBaseSepoliaTinyMoonUsdcRehearsal
} from "./PrepareBaseSepoliaTinyMoonUsdcRehearsal.s.sol";

// DEPRECATED / LEGACY BaseMoonAmmFeeV4Hook path.
// Old Base Sepolia-only quote precheck helper; do not use for rc4 or Base mainnet.
// Current rc4/mainnet path uses BaseSunMoonUsdcFeeV4Hook.
contract PrecheckBaseSepoliaTinyMoonUsdcQuote is Script {
    uint256 internal constant BPS = 10_000;
    uint256 internal constant DEFAULT_SLIPPAGE_BPS = 1000;
    int24 internal constant DEFAULT_TICK_RANGE = 600;

    struct QuotePrecheck {
        uint256 chainId;
        bool baseSepoliaConfirmed;
        address rehearsalActor;
        address quoter;
        address positionManager;
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
        uint256 usdcSpentForLiquidity;
        uint256 moonSpentForLiquidity;
        uint256 swapUsdcIn;
        uint256 swapFeeToSunCurve;
        uint256 swapFeeToProtocol;
        uint256 swapUsdcGrossInputWithHookFee;
        uint256 quoteMoonOut;
        uint256 quoteGasEstimate;
        uint256 slippageBps;
        uint256 suggestedMinMoonOut;
        bool readinessPassed;
        bool liquiditySimulationPassed;
        bool quoteSimulationPassed;
        bool readyForTinyBroadcast;
    }

    error DependencyCodeMissing(bytes32 label, address target);
    error InvalidAddress(bytes32 label);
    error InvalidAmount(bytes32 label, uint256 amount);
    error InvalidTickRange(int24 tickLower, int24 tickUpper);
    error ReadinessFailed();

    function run() external returns (QuotePrecheck memory result) {
        console2.log("DEPRECATED LEGACY SCRIPT: old BaseMoonAmmFeeV4Hook path; not for rc4/mainnet");

        PrepareBaseSepoliaTinyMoonUsdcRehearsal prep = new PrepareBaseSepoliaTinyMoonUsdcRehearsal();
        PrepareBaseSepoliaTinyMoonUsdcRehearsal.TinyRehearsalPlan memory plan = prep.run();

        if (!plan.readyForCombinedDryRun) revert ReadinessFailed();

        result.chainId = plan.chainId;
        result.baseSepoliaConfirmed = plan.baseSepoliaConfirmed;
        result.rehearsalActor = plan.rehearsalActor;
        result.positionManager = plan.positionManager;
        result.moonToken = plan.moonToken;
        result.usdcToken = plan.usdcToken;
        result.poolId = plan.poolId;
        result.currentTick = plan.tick;
        result.sqrtPriceX96 = plan.sqrtPriceX96;
        result.liquidityUsdcAmount = plan.liquidityUsdcAmount;
        result.liquidityMoonAmount = plan.liquidityMoonAmount;
        result.swapUsdcIn = plan.swapUsdcIn;
        result.swapFeeToSunCurve = plan.swapFeeToSunCurve;
        result.swapFeeToProtocol = plan.swapFeeToProtocol;
        result.swapUsdcGrossInputWithHookFee = plan.swapUsdcGrossInputWithHookFee;
        result.slippageBps = vm.envOr("TINY_SWAP_SLIPPAGE_BPS", DEFAULT_SLIPPAGE_BPS);
        result.quoter =
            _envAddressOrDefault("QUOTER", BaseV4Addresses.BASE_SEPOLIA_QUOTER, "QUOTER");
        _requireCode("QUOTER", result.quoter);

        (result.tickLower, result.tickUpper) = _defaultTickRange(
            plan.tick,
            plan.tickSpacing,
            int24(vm.envOr("TINY_LIQUIDITY_TICK_RANGE", int256(DEFAULT_TICK_RANGE)))
        );
        _validateTickRange(result.tickLower, result.tickUpper, plan.tickSpacing);

        (result.amount0Max, result.amount1Max) = _amountsForPoolOrder(
            plan.poolKey,
            plan.usdcToken,
            plan.moonToken,
            plan.liquidityUsdcAmount,
            plan.liquidityMoonAmount
        );
        result.liquidity = LiquidityAmounts.getLiquidityForAmounts(
            plan.sqrtPriceX96,
            TickMath.getSqrtPriceAtTick(result.tickLower),
            TickMath.getSqrtPriceAtTick(result.tickUpper),
            result.amount0Max,
            result.amount1Max
        );
        if (result.liquidity == 0) revert InvalidAmount("LIQUIDITY", result.liquidity);

        result.readinessPassed = true;
        _simulateLiquidityMint(plan, result);
        _simulateQuote(plan, result);

        result.suggestedMinMoonOut = result.quoteMoonOut * (BPS - result.slippageBps) / BPS;
        result.readyForTinyBroadcast = result.readinessPassed && result.liquiditySimulationPassed
            && result.quoteSimulationPassed && result.suggestedMinMoonOut > 0;

        _logResult(result);
    }

    function _simulateLiquidityMint(
        PrepareBaseSepoliaTinyMoonUsdcRehearsal.TinyRehearsalPlan memory plan,
        QuotePrecheck memory result
    ) private {
        IERC20 usdc = IERC20(plan.usdcToken);
        IERC20 moon = IERC20(plan.moonToken);
        IPositionManager positionManager = IPositionManager(plan.positionManager);

        uint256 usdcBefore = usdc.balanceOf(plan.rehearsalActor);
        uint256 moonBefore = moon.balanceOf(plan.rehearsalActor);
        result.positionTokenId = positionManager.nextTokenId();

        bytes memory calls = _mintPositionCalls(
            plan.poolKey,
            result.tickLower,
            result.tickUpper,
            result.liquidity,
            result.amount0Max,
            result.amount1Max,
            plan.rehearsalActor
        );

        vm.startPrank(plan.rehearsalActor);
        positionManager.modifyLiquidities(calls, block.timestamp + 600);
        vm.stopPrank();

        result.positionLiquidityAfterMint =
            positionManager.getPositionLiquidity(result.positionTokenId);
        result.usdcSpentForLiquidity = usdcBefore - usdc.balanceOf(plan.rehearsalActor);
        result.moonSpentForLiquidity = moonBefore - moon.balanceOf(plan.rehearsalActor);
        result.liquiditySimulationPassed = result.positionLiquidityAfterMint == result.liquidity
            && result.usdcSpentForLiquidity <= plan.liquidityUsdcAmount
            && result.moonSpentForLiquidity <= plan.liquidityMoonAmount;
    }

    function _simulateQuote(
        PrepareBaseSepoliaTinyMoonUsdcRehearsal.TinyRehearsalPlan memory plan,
        QuotePrecheck memory result
    ) private {
        IV4Quoter.QuoteExactSingleParams memory params = IV4Quoter.QuoteExactSingleParams({
            poolKey: plan.poolKey,
            zeroForOne: plan.zeroForOneUsdcToMoon,
            exactAmount: uint128(plan.swapUsdcIn),
            hookData: plan.swapHookData
        });

        (result.quoteMoonOut, result.quoteGasEstimate) =
            IV4Quoter(result.quoter).quoteExactInputSingle(params);
        result.quoteSimulationPassed = result.quoteMoonOut > 0 && result.quoteGasEstimate > 0;
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

    function _logResult(QuotePrecheck memory result) private pure {
        console2.log("Base Sepolia tiny MOON/USDC quote precheck");
        console2.log("simulationOnly:", "local fork only; this script does not broadcast");
        console2.log("chainId:", result.chainId);
        console2.log("baseSepoliaConfirmed:", result.baseSepoliaConfirmed);
        console2.log("REHEARSAL_ACTOR:", result.rehearsalActor);
        console2.log("QUOTER:", result.quoter);
        console2.log("POSITION_MANAGER:", result.positionManager);
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
        console2.log("usdcSpentForLiquidity:", result.usdcSpentForLiquidity);
        console2.log("moonSpentForLiquidity:", result.moonSpentForLiquidity);
        console2.log("swapUsdcIn:", result.swapUsdcIn);
        console2.log("swapFeeToSunCurve:", result.swapFeeToSunCurve);
        console2.log("swapFeeToProtocol:", result.swapFeeToProtocol);
        console2.log("swapUsdcGrossInputWithHookFee:", result.swapUsdcGrossInputWithHookFee);
        console2.log("quoteMoonOut:", result.quoteMoonOut);
        console2.log("quoteGasEstimate:", result.quoteGasEstimate);
        console2.log("slippageBps:", result.slippageBps);
        console2.log("suggestedMinMoonOut:", result.suggestedMinMoonOut);
        console2.log("readinessPassed:", result.readinessPassed);
        console2.log("liquiditySimulationPassed:", result.liquiditySimulationPassed);
        console2.log("quoteSimulationPassed:", result.quoteSimulationPassed);
        console2.log("readyForTinyBroadcast:", result.readyForTinyBroadcast);
    }
}
