// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { BalanceDelta } from "@uniswap/v4-core/src/types/BalanceDelta.sol";
import { BalanceDeltaLibrary } from "@uniswap/v4-core/src/types/BalanceDelta.sol";
import { Currency } from "@uniswap/v4-core/src/types/Currency.sol";
import { PoolKey } from "@uniswap/v4-core/src/types/PoolKey.sol";
import { SwapParams } from "@uniswap/v4-core/src/types/PoolOperation.sol";

library BaseMoonAmmFeePolicy {
    using BalanceDeltaLibrary for BalanceDelta;

    enum CollectionStage {
        BeforeSwap,
        AfterSwap
    }

    enum SettlementMethod {
        BeforeSwapSpecifiedReturnDelta,
        AfterSwapUnspecifiedReturnDelta
    }

    struct FeeSource {
        address feeToken;
        uint256 feeBaseAmount;
        bool feeTokenIsInput;
        bool feeTokenIsSpecified;
        bool feeBaseAmountFromSwapDelta;
        CollectionStage collectionStage;
        SettlementMethod settlementMethod;
    }

    error InvalidAddress();
    error InvalidAmountSpecified();
    error InvalidMoonPair();
    error InvalidSwapDelta();

    function quoteNonMoonFeeSource(
        PoolKey memory key,
        SwapParams memory params,
        BalanceDelta swapDelta,
        address moonToken
    ) internal pure returns (FeeSource memory source) {
        if (moonToken == address(0)) {
            revert InvalidAddress();
        }
        if (params.amountSpecified == 0 || params.amountSpecified == type(int256).min) {
            revert InvalidAmountSpecified();
        }

        (address feeToken, bool feeTokenIsToken0) = _feeTokenFromMoonPair(key, moonToken);
        bool feeTokenIsInput = _isFeeTokenInput(key, params.zeroForOne, feeToken);
        bool feeTokenIsSpecified = _isFeeTokenSpecified(key, params, feeToken);

        source = FeeSource({
            feeToken: feeToken,
            feeBaseAmount: feeTokenIsSpecified
                ? _absoluteAmountSpecified(params.amountSpecified)
                : _feeTokenSwapDeltaAmount(swapDelta, feeTokenIsToken0, feeTokenIsInput),
            feeTokenIsInput: feeTokenIsInput,
            feeTokenIsSpecified: feeTokenIsSpecified,
            feeBaseAmountFromSwapDelta: !feeTokenIsSpecified,
            collectionStage: feeTokenIsSpecified
                ? CollectionStage.BeforeSwap
                : CollectionStage.AfterSwap,
            settlementMethod: feeTokenIsSpecified
                ? SettlementMethod.BeforeSwapSpecifiedReturnDelta
                : SettlementMethod.AfterSwapUnspecifiedReturnDelta
        });
    }

    function _absoluteAmountSpecified(int256 amountSpecified) private pure returns (uint256) {
        return amountSpecified < 0 ? uint256(-amountSpecified) : uint256(amountSpecified);
    }

    function _feeTokenFromMoonPair(PoolKey memory key, address moonToken)
        private
        pure
        returns (address feeToken, bool feeTokenIsToken0)
    {
        address token0 = Currency.unwrap(key.currency0);
        address token1 = Currency.unwrap(key.currency1);
        bool token0IsMoon = token0 == moonToken;

        if (token0IsMoon == (token1 == moonToken)) {
            revert InvalidMoonPair();
        }

        feeToken = token0IsMoon ? token1 : token0;
        feeTokenIsToken0 = feeToken == token0;
    }

    function _isFeeTokenInput(PoolKey memory key, bool zeroForOne, address feeToken)
        private
        pure
        returns (bool)
    {
        address inputToken =
            zeroForOne ? Currency.unwrap(key.currency0) : Currency.unwrap(key.currency1);

        return inputToken == feeToken;
    }

    function _isFeeTokenSpecified(PoolKey memory key, SwapParams memory params, address feeToken)
        private
        pure
        returns (bool)
    {
        bool exactInput = params.amountSpecified < 0;
        address specifiedToken =
            Currency.unwrap(params.zeroForOne == exactInput ? key.currency0 : key.currency1);

        return specifiedToken == feeToken;
    }

    function _feeTokenSwapDeltaAmount(
        BalanceDelta swapDelta,
        bool feeTokenIsToken0,
        bool feeTokenIsInput
    ) private pure returns (uint256) {
        int128 signedAmount = feeTokenIsToken0 ? swapDelta.amount0() : swapDelta.amount1();

        if (feeTokenIsInput) {
            if (signedAmount >= 0) revert InvalidSwapDelta();
            return uint256(-int256(signedAmount));
        }

        if (signedAmount <= 0) revert InvalidSwapDelta();
        return uint256(int256(signedAmount));
    }
}
