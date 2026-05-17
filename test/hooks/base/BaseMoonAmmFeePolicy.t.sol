// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { Test } from "forge-std/Test.sol";
import { IHooks } from "@uniswap/v4-core/src/interfaces/IHooks.sol";
import {
    BalanceDelta,
    BalanceDeltaLibrary,
    toBalanceDelta
} from "@uniswap/v4-core/src/types/BalanceDelta.sol";
import { Currency } from "@uniswap/v4-core/src/types/Currency.sol";
import { PoolKey } from "@uniswap/v4-core/src/types/PoolKey.sol";
import { SwapParams } from "@uniswap/v4-core/src/types/PoolOperation.sol";
import { BaseMoonAmmFeePolicy } from "../../../contracts/hooks/base/BaseMoonAmmFeePolicy.sol";

contract BaseMoonAmmFeePolicyHarness {
    function quoteNonMoonFeeSource(
        PoolKey memory key,
        SwapParams memory params,
        BalanceDelta swapDelta,
        address moonToken
    ) external pure returns (BaseMoonAmmFeePolicy.FeeSource memory source) {
        return BaseMoonAmmFeePolicy.quoteNonMoonFeeSource(key, params, swapDelta, moonToken);
    }
}

contract BaseMoonAmmFeePolicyTest is Test {
    uint256 internal constant TOKEN_ONE = 1e18;
    uint256 internal constant USDC_ONE = 1e6;

    address internal usdc = address(0x1000);
    address internal moon = address(0x2000);
    address internal weth = address(0x3000);

    BaseMoonAmmFeePolicyHarness internal harness;
    PoolKey internal moonUsdcKey;

    function setUp() public {
        harness = new BaseMoonAmmFeePolicyHarness();
        moonUsdcKey = _poolKey(usdc, moon);
    }

    function testBuyMoonWithExactNonMoonInputUsesBeforeSwapSpecifiedFeeToken() public view {
        BaseMoonAmmFeePolicy.FeeSource memory source = harness.quoteNonMoonFeeSource(
            moonUsdcKey,
            _swapParams(true, -int256(1000 * USDC_ONE)),
            BalanceDeltaLibrary.ZERO_DELTA,
            moon
        );

        assertEq(source.feeToken, usdc);
        assertEq(source.feeBaseAmount, 1000 * USDC_ONE);
        assertTrue(source.feeTokenIsInput);
        assertTrue(source.feeTokenIsSpecified);
        assertFalse(source.feeBaseAmountFromSwapDelta);
        assertEq(
            uint8(source.collectionStage), uint8(BaseMoonAmmFeePolicy.CollectionStage.BeforeSwap)
        );
        assertEq(
            uint8(source.settlementMethod),
            uint8(BaseMoonAmmFeePolicy.SettlementMethod.BeforeSwapSpecifiedReturnDelta)
        );
    }

    function testBuyMoonWithExactMoonOutputUsesAfterSwapActualFeeTokenInput() public view {
        BalanceDelta swapDelta = toBalanceDelta(-1100e6, int128(int256(500 * TOKEN_ONE)));

        BaseMoonAmmFeePolicy.FeeSource memory source = harness.quoteNonMoonFeeSource(
            moonUsdcKey, _swapParams(true, int256(500 * TOKEN_ONE)), swapDelta, moon
        );

        assertEq(source.feeToken, usdc);
        assertEq(source.feeBaseAmount, 1100 * USDC_ONE);
        assertTrue(source.feeTokenIsInput);
        assertFalse(source.feeTokenIsSpecified);
        assertTrue(source.feeBaseAmountFromSwapDelta);
        assertEq(
            uint8(source.collectionStage), uint8(BaseMoonAmmFeePolicy.CollectionStage.AfterSwap)
        );
        assertEq(
            uint8(source.settlementMethod),
            uint8(BaseMoonAmmFeePolicy.SettlementMethod.AfterSwapUnspecifiedReturnDelta)
        );
    }

    function testSellMoonWithExactMoonInputUsesAfterSwapActualFeeTokenOutput() public view {
        BalanceDelta swapDelta = toBalanceDelta(900e6, -int128(int256(500 * TOKEN_ONE)));

        BaseMoonAmmFeePolicy.FeeSource memory source = harness.quoteNonMoonFeeSource(
            moonUsdcKey, _swapParams(false, -int256(500 * TOKEN_ONE)), swapDelta, moon
        );

        assertEq(source.feeToken, usdc);
        assertEq(source.feeBaseAmount, 900 * USDC_ONE);
        assertFalse(source.feeTokenIsInput);
        assertFalse(source.feeTokenIsSpecified);
        assertTrue(source.feeBaseAmountFromSwapDelta);
        assertEq(
            uint8(source.collectionStage), uint8(BaseMoonAmmFeePolicy.CollectionStage.AfterSwap)
        );
        assertEq(
            uint8(source.settlementMethod),
            uint8(BaseMoonAmmFeePolicy.SettlementMethod.AfterSwapUnspecifiedReturnDelta)
        );
    }

    function testSellMoonWithExactFeeTokenOutputUsesBeforeSwapSpecifiedFeeToken() public view {
        BaseMoonAmmFeePolicy.FeeSource memory source = harness.quoteNonMoonFeeSource(
            moonUsdcKey,
            _swapParams(false, int256(1000 * USDC_ONE)),
            BalanceDeltaLibrary.ZERO_DELTA,
            moon
        );

        assertEq(source.feeToken, usdc);
        assertEq(source.feeBaseAmount, 1000 * USDC_ONE);
        assertFalse(source.feeTokenIsInput);
        assertTrue(source.feeTokenIsSpecified);
        assertFalse(source.feeBaseAmountFromSwapDelta);
        assertEq(
            uint8(source.collectionStage), uint8(BaseMoonAmmFeePolicy.CollectionStage.BeforeSwap)
        );
        assertEq(
            uint8(source.settlementMethod),
            uint8(BaseMoonAmmFeePolicy.SettlementMethod.BeforeSwapSpecifiedReturnDelta)
        );
    }

    function testPolicyWorksWhenFeeTokenIsCurrency1() public view {
        address lowMoon = address(0x1000);
        address highFeeToken = address(0x2000);
        PoolKey memory key = _poolKey(lowMoon, highFeeToken);

        BaseMoonAmmFeePolicy.FeeSource memory source = harness.quoteNonMoonFeeSource(
            key,
            _swapParams(false, -int256(1000 * USDC_ONE)),
            BalanceDeltaLibrary.ZERO_DELTA,
            lowMoon
        );

        assertEq(source.feeToken, highFeeToken);
        assertEq(source.feeBaseAmount, 1000 * USDC_ONE);
        assertTrue(source.feeTokenIsInput);
        assertTrue(source.feeTokenIsSpecified);
        assertEq(
            uint8(source.collectionStage), uint8(BaseMoonAmmFeePolicy.CollectionStage.BeforeSwap)
        );
    }

    function testMoonWethPairUsesWethAsFeeToken() public view {
        PoolKey memory key = _poolKey(moon, weth);

        BaseMoonAmmFeePolicy.FeeSource memory source = harness.quoteNonMoonFeeSource(
            key, _swapParams(false, -int256(2 * TOKEN_ONE)), BalanceDeltaLibrary.ZERO_DELTA, moon
        );

        assertEq(source.feeToken, weth);
        assertEq(source.feeBaseAmount, 2 * TOKEN_ONE);
        assertTrue(source.feeTokenIsInput);
        assertTrue(source.feeTokenIsSpecified);
        assertEq(
            uint8(source.collectionStage), uint8(BaseMoonAmmFeePolicy.CollectionStage.BeforeSwap)
        );
    }

    function testMoonWethPairCanUseAfterSwapWhenWethIsActualOutput() public view {
        PoolKey memory key = _poolKey(moon, weth);
        BalanceDelta swapDelta =
            toBalanceDelta(-int128(int256(500 * TOKEN_ONE)), int128(int256(2 * TOKEN_ONE)));

        BaseMoonAmmFeePolicy.FeeSource memory source = harness.quoteNonMoonFeeSource(
            key, _swapParams(true, -int256(500 * TOKEN_ONE)), swapDelta, moon
        );

        assertEq(source.feeToken, weth);
        assertEq(source.feeBaseAmount, 2 * TOKEN_ONE);
        assertFalse(source.feeTokenIsInput);
        assertFalse(source.feeTokenIsSpecified);
        assertTrue(source.feeBaseAmountFromSwapDelta);
        assertEq(
            uint8(source.collectionStage), uint8(BaseMoonAmmFeePolicy.CollectionStage.AfterSwap)
        );
        assertEq(
            uint8(source.settlementMethod),
            uint8(BaseMoonAmmFeePolicy.SettlementMethod.AfterSwapUnspecifiedReturnDelta)
        );
    }

    function testRejectsNonMoonPair() public {
        PoolKey memory invalidKey = _poolKey(usdc, address(0x3000));

        vm.expectRevert(BaseMoonAmmFeePolicy.InvalidMoonPair.selector);
        harness.quoteNonMoonFeeSource(
            invalidKey, _swapParams(true, -1), BalanceDeltaLibrary.ZERO_DELTA, moon
        );
    }

    function testRejectsZeroAmountSpecified() public {
        vm.expectRevert(BaseMoonAmmFeePolicy.InvalidAmountSpecified.selector);
        harness.quoteNonMoonFeeSource(
            moonUsdcKey, _swapParams(true, 0), BalanceDeltaLibrary.ZERO_DELTA, moon
        );
    }

    function testRejectsInvalidAfterSwapDeltaSign() public {
        vm.expectRevert(BaseMoonAmmFeePolicy.InvalidSwapDelta.selector);
        harness.quoteNonMoonFeeSource(
            moonUsdcKey,
            _swapParams(false, -int256(500 * TOKEN_ONE)),
            toBalanceDelta(-900e6, -int128(int256(500 * TOKEN_ONE))),
            moon
        );
    }

    function _poolKey(address tokenA, address tokenB) internal pure returns (PoolKey memory key) {
        (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);

        key = PoolKey({
            currency0: Currency.wrap(token0),
            currency1: Currency.wrap(token1),
            fee: 3000,
            tickSpacing: 60,
            hooks: IHooks(address(0))
        });
    }

    function _swapParams(bool zeroForOne, int256 amountSpecified)
        internal
        pure
        returns (SwapParams memory params)
    {
        params = SwapParams({
            zeroForOne: zeroForOne, amountSpecified: amountSpecified, sqrtPriceLimitX96: 0
        });
    }
}
