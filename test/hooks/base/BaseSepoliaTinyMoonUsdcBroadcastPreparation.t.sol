// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { Test } from "forge-std/Test.sol";
import { IHooks } from "@uniswap/v4-core/src/interfaces/IHooks.sol";
import { Currency } from "@uniswap/v4-core/src/types/Currency.sol";
import { PoolId, PoolIdLibrary } from "@uniswap/v4-core/src/types/PoolId.sol";
import { PoolKey } from "@uniswap/v4-core/src/types/PoolKey.sol";
import { IV4Quoter } from "@uniswap/v4-periphery/src/interfaces/IV4Quoter.sol";
import { Actions } from "@uniswap/v4-periphery/src/libraries/Actions.sol";
import { BaseMoonAmmFeeV4Hook } from "../../../contracts/hooks/base/BaseMoonAmmFeeV4Hook.sol";
import { BaseV4Addresses } from "../../../contracts/hooks/base/BaseV4Addresses.sol";
import { TestnetUsdcAdapter } from "../../../contracts/hooks/TestnetUsdcAdapter.sol";
import { SunCurve } from "../../../contracts/SunCurve.sol";
import {
    PrepareBaseSepoliaTinyMoonUsdcBroadcast
} from "../../../script/PrepareBaseSepoliaTinyMoonUsdcBroadcast.s.sol";
import {
    PrepareBaseSepoliaTinyMoonUsdcRehearsal
} from "../../../script/PrepareBaseSepoliaTinyMoonUsdcRehearsal.s.sol";

contract MockTinyV4Quoter {
    uint256 internal immutable amountOut;
    uint256 internal immutable gasEstimate;

    constructor(uint256 amountOut_, uint256 gasEstimate_) {
        amountOut = amountOut_;
        gasEstimate = gasEstimate_;
    }

    function quoteExactInputSingle(IV4Quoter.QuoteExactSingleParams memory)
        external
        view
        returns (uint256, uint256)
    {
        return (amountOut, gasEstimate);
    }
}

contract BaseSepoliaTinyMoonUsdcBroadcastPreparationTest is Test {
    using PoolIdLibrary for PoolKey;

    struct LegacyExactInputSingleParams {
        PoolKey poolKey;
        bool zeroForOne;
        uint128 amountIn;
        uint128 amountOutMinimum;
        bytes hookData;
    }

    address internal rehearsalActor = 0x6E22b2e6fFAA30Fe75B71d53d1eC469b4e97A986;
    address internal usdc = address(0x1000);
    address internal moon = address(0x2000);
    address internal hook = address(0x3000);
    address internal positionManager = address(0x4000);
    address internal universalRouter = address(0x5000);
    MockTinyV4Quoter internal quoter;

    function setUp() public {
        quoter = new MockTinyV4Quoter(1 ether, 198_242);
    }

    function testTinyMoonUsdcBroadcastDraftEncodesLiquidityAndSwapCalls() public {
        vm.chainId(31_337);

        PrepareBaseSepoliaTinyMoonUsdcBroadcast script =
            new PrepareBaseSepoliaTinyMoonUsdcBroadcast();
        PrepareBaseSepoliaTinyMoonUsdcBroadcast.TinyBroadcastPlan memory plan =
            script.prepare(_rehearsalPlan(false), _config(false, false, false, false, 0));

        assertEq(plan.chainId, 31_337);
        assertEq(plan.rehearsalActor, rehearsalActor);
        assertEq(plan.tickLower, 275_700);
        assertEq(plan.tickUpper, 276_900);
        assertGt(plan.liquidity, 0);
        assertEq(plan.quoteMoonOut, 1 ether);
        assertEq(plan.minMoonOut, 0.9 ether);
        assertTrue(plan.useLegacyRouterSwapParams);
        assertEq(plan.draftTransactions, 2);
        assertEq(plan.transactionsPlanned, 0);
        assertTrue(plan.readyForTinyBroadcast);

        (bytes memory liquidityActions, bytes[] memory liquidityParams) =
            abi.decode(plan.liquidityCalls, (bytes, bytes[]));
        assertEq(uint8(liquidityActions[0]), Actions.MINT_POSITION);
        assertEq(uint8(liquidityActions[1]), Actions.CLOSE_CURRENCY);
        assertEq(uint8(liquidityActions[2]), Actions.CLOSE_CURRENCY);
        assertEq(liquidityParams.length, 3);

        (
            PoolKey memory decodedPoolKey,
            int24 decodedTickLower,
            int24 decodedTickUpper,
            uint256 decodedLiquidity,
            uint128 decodedAmount0Max,
            uint128 decodedAmount1Max,
            address decodedOwner,
        ) = abi.decode(
            liquidityParams[0], (PoolKey, int24, int24, uint256, uint128, uint128, address, bytes)
        );
        assertEq(Currency.unwrap(decodedPoolKey.currency0), usdc);
        assertEq(Currency.unwrap(decodedPoolKey.currency1), moon);
        assertEq(decodedTickLower, plan.tickLower);
        assertEq(decodedTickUpper, plan.tickUpper);
        assertEq(decodedLiquidity, plan.liquidity);
        assertEq(decodedAmount0Max, 1_000_000);
        assertEq(decodedAmount1Max, 1 ether);
        assertEq(decodedOwner, rehearsalActor);

        assertEq(plan.swapCommands.length, 1);
        assertEq(uint8(plan.swapCommands[0]), 0x10);

        (bytes memory swapActions, bytes[] memory swapParams) =
            abi.decode(plan.swapInput, (bytes, bytes[]));
        assertEq(uint8(swapActions[0]), Actions.SWAP_EXACT_IN_SINGLE);
        assertEq(uint8(swapActions[1]), Actions.SETTLE_ALL);
        assertEq(uint8(swapActions[2]), Actions.TAKE_ALL);
        assertEq(swapParams.length, 3);

        LegacyExactInputSingleParams memory swapParams0 =
            abi.decode(swapParams[0], (LegacyExactInputSingleParams));
        assertEq(Currency.unwrap(swapParams0.poolKey.currency0), usdc);
        assertTrue(swapParams0.zeroForOne);
        assertEq(swapParams0.amountIn, 100_000);
        assertEq(swapParams0.amountOutMinimum, 0.9 ether);
        assertEq(
            keccak256(swapParams0.hookData),
            keccak256(abi.encode(BaseMoonAmmFeeV4Hook.MoonFeeHookData({ minUSDTOut: 3000 })))
        );

        (Currency inputCurrency, uint256 maxSettleAmount) =
            abi.decode(swapParams[1], (Currency, uint256));
        (Currency outputCurrency, uint256 minTakeAmount) =
            abi.decode(swapParams[2], (Currency, uint256));
        assertEq(Currency.unwrap(inputCurrency), usdc);
        assertEq(maxSettleAmount, 105_000);
        assertEq(Currency.unwrap(outputCurrency), moon);
        assertEq(minTakeAmount, 0.9 ether);
    }

    function testTinyMoonUsdcBroadcastDraftHonorsMinMoonOutOverride() public {
        vm.chainId(31_337);

        PrepareBaseSepoliaTinyMoonUsdcBroadcast script =
            new PrepareBaseSepoliaTinyMoonUsdcBroadcast();
        PrepareBaseSepoliaTinyMoonUsdcBroadcast.TinyBroadcastPlan memory plan =
            script.prepare(_rehearsalPlan(false), _config(false, false, false, false, 0.8 ether));

        assertEq(plan.quoteMoonOut, 1 ether);
        assertEq(plan.minMoonOut, 0.8 ether);
    }

    function testTinyMoonUsdcBroadcastDraftGuardsExecutionAndChain() public {
        _assertRejectsSwapExecutionWhenQuoteAssumesUnbroadcastLiquidity();
        _assertRejectsBaseMainnet();
        _assertBaseSepoliaRequiresExplicitConfirmation();
    }

    function _assertRejectsSwapExecutionWhenQuoteAssumesUnbroadcastLiquidity() private {
        vm.chainId(31_337);

        PrepareBaseSepoliaTinyMoonUsdcBroadcast script =
            new PrepareBaseSepoliaTinyMoonUsdcBroadcast();

        vm.expectRevert(
            PrepareBaseSepoliaTinyMoonUsdcBroadcast.QuoteAssumesUnbroadcastLiquidity.selector
        );
        script.prepare(_rehearsalPlan(false), _config(false, false, true, true, 0));
    }

    function _assertRejectsBaseMainnet() private {
        vm.chainId(BaseV4Addresses.BASE_MAINNET_CHAIN_ID);

        PrepareBaseSepoliaTinyMoonUsdcBroadcast script =
            new PrepareBaseSepoliaTinyMoonUsdcBroadcast();

        vm.expectRevert(
            abi.encodeWithSelector(
                PrepareBaseSepoliaTinyMoonUsdcBroadcast.BaseMainnetNotAllowed.selector,
                BaseV4Addresses.BASE_MAINNET_CHAIN_ID
            )
        );
        script.prepare(_rehearsalPlan(false), _config(true, false, false, false, 0));
    }

    function _assertBaseSepoliaRequiresExplicitConfirmation() private {
        vm.chainId(BaseV4Addresses.BASE_SEPOLIA_CHAIN_ID);

        PrepareBaseSepoliaTinyMoonUsdcBroadcast script =
            new PrepareBaseSepoliaTinyMoonUsdcBroadcast();

        vm.expectRevert(
            abi.encodeWithSelector(
                PrepareBaseSepoliaTinyMoonUsdcBroadcast.BaseSepoliaRunNotConfirmed.selector,
                BaseV4Addresses.BASE_SEPOLIA_CHAIN_ID
            )
        );
        script.prepare(_rehearsalPlan(false), _config(false, false, false, false, 0));
    }

    function _rehearsalPlan(bool baseSepoliaConfirmed)
        private
        view
        returns (PrepareBaseSepoliaTinyMoonUsdcRehearsal.TinyRehearsalPlan memory plan)
    {
        PoolKey memory poolKey = PoolKey({
            currency0: Currency.wrap(usdc),
            currency1: Currency.wrap(moon),
            fee: 3000,
            tickSpacing: 60,
            hooks: IHooks(hook)
        });

        plan.chainId = block.chainid;
        plan.baseSepoliaConfirmed = baseSepoliaConfirmed;
        plan.rehearsalActor = rehearsalActor;
        plan.positionManager = positionManager;
        plan.universalRouter = universalRouter;
        plan.moonToken = moon;
        plan.usdcToken = usdc;
        plan.poolKey = poolKey;
        plan.poolId = PoolId.unwrap(poolKey.toId());
        plan.tick = 276_300;
        plan.tickSpacing = 60;
        plan.sqrtPriceX96 = 79_133_045_881_256_921_541_446_514_419_412_387;
        plan.liquidityUsdcAmount = 1_000_000;
        plan.liquidityMoonAmount = 1 ether;
        plan.swapUsdcIn = 100_000;
        plan.swapFeeToSunCurve = 3000;
        plan.swapFeeToProtocol = 2000;
        plan.swapUsdcGrossInputWithHookFee = 105_000;
        plan.zeroForOneUsdcToMoon = true;
        plan.swapHookData = abi.encode(BaseMoonAmmFeeV4Hook.MoonFeeHookData({ minUSDTOut: 3000 }));
        plan.readyForLiquidityDryRun = true;
        plan.readyForSwapDryRun = true;
        plan.readyForCombinedDryRun = true;
    }

    function _config(
        bool baseSepoliaConfirmed,
        bool executeLiquidity,
        bool executeSwap,
        bool quoteAfterLiquiditySimulation,
        uint256 minMoonOut
    )
        private
        view
        returns (PrepareBaseSepoliaTinyMoonUsdcBroadcast.TinyBroadcastConfig memory config)
    {
        config = PrepareBaseSepoliaTinyMoonUsdcBroadcast.TinyBroadcastConfig({
            baseSepoliaConfirmed: baseSepoliaConfirmed,
            executeLiquidity: executeLiquidity,
            executeSwap: executeSwap,
            quoteAfterLiquiditySimulation: quoteAfterLiquiditySimulation,
            useLegacyRouterSwapParams: true,
            rehearsalActor: rehearsalActor,
            quoter: address(quoter),
            slippageBps: 1000,
            minMoonOut: minMoonOut,
            deadlineSeconds: 600,
            tickRange: 600
        });
    }
}
