// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { Deployers } from "@uniswap/v4-core/test/utils/Deployers.sol";
import { MockERC20 } from "solmate/src/test/utils/mocks/MockERC20.sol";
import { IHooks } from "@uniswap/v4-core/src/interfaces/IHooks.sol";
import { IPoolManager } from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import { Hooks } from "@uniswap/v4-core/src/libraries/Hooks.sol";
import { BaseTestHooks } from "@uniswap/v4-core/src/test/BaseTestHooks.sol";
import { PoolSwapTest } from "@uniswap/v4-core/src/test/PoolSwapTest.sol";
import { BalanceDelta } from "@uniswap/v4-core/src/types/BalanceDelta.sol";
import {
    BeforeSwapDelta,
    BeforeSwapDeltaLibrary,
    toBeforeSwapDelta
} from "@uniswap/v4-core/src/types/BeforeSwapDelta.sol";
import { Currency } from "@uniswap/v4-core/src/types/Currency.sol";
import { PoolKey } from "@uniswap/v4-core/src/types/PoolKey.sol";
import { SwapParams } from "@uniswap/v4-core/src/types/PoolOperation.sol";
import { BaseMoonAmmFeePolicy } from "../../../contracts/hooks/base/BaseMoonAmmFeePolicy.sol";

contract BaseMoonAmmFeeReturnDeltaSettlementHook is BaseTestHooks {
    uint256 internal constant FEE_BIPS = 500;
    uint256 internal constant BIPS_DENOMINATOR = 10_000;

    IPoolManager public immutable manager;
    address public immutable moonToken;

    address public lastFeeToken;
    uint256 public lastFeeBaseAmount;
    uint256 public lastFeeAmount;
    BaseMoonAmmFeePolicy.CollectionStage public lastCollectionStage;
    BaseMoonAmmFeePolicy.SettlementMethod public lastSettlementMethod;

    error InvalidFeeAmount();
    error NotPoolManager();
    error ZeroAddress();

    constructor(IPoolManager manager_, address moonToken_) {
        if (address(manager_) == address(0) || moonToken_ == address(0)) {
            revert ZeroAddress();
        }

        manager = manager_;
        moonToken = moonToken_;
    }

    function beforeSwap(address, PoolKey calldata key, SwapParams calldata params, bytes calldata)
        external
        override
        onlyPoolManager
        returns (bytes4, BeforeSwapDelta, uint24)
    {
        (address feeToken, bool isMoonPair) = _feeTokenFromMoonPair(key);
        if (!isMoonPair || !_isFeeTokenSpecified(key, params, feeToken)) {
            return (IHooks.beforeSwap.selector, BeforeSwapDeltaLibrary.ZERO_DELTA, 0);
        }

        uint256 feeBaseAmount = _absoluteAmountSpecified(params.amountSpecified);
        uint256 feeAmount = _feeAmount(feeBaseAmount);

        manager.take(Currency.wrap(feeToken), address(this), feeAmount);
        _record(
            feeToken,
            feeBaseAmount,
            feeAmount,
            BaseMoonAmmFeePolicy.CollectionStage.BeforeSwap,
            BaseMoonAmmFeePolicy.SettlementMethod.BeforeSwapSpecifiedReturnDelta
        );

        return (IHooks.beforeSwap.selector, toBeforeSwapDelta(_toInt128(feeAmount), 0), 0);
    }

    function afterSwap(
        address,
        PoolKey calldata key,
        SwapParams calldata params,
        BalanceDelta swapDelta,
        bytes calldata
    ) external override onlyPoolManager returns (bytes4, int128) {
        (, bool isMoonPair) = _feeTokenFromMoonPair(key);
        if (!isMoonPair) {
            return (IHooks.afterSwap.selector, 0);
        }

        BaseMoonAmmFeePolicy.FeeSource memory source =
            BaseMoonAmmFeePolicy.quoteNonMoonFeeSource(key, params, swapDelta, moonToken);

        if (source.collectionStage != BaseMoonAmmFeePolicy.CollectionStage.AfterSwap) {
            return (IHooks.afterSwap.selector, 0);
        }

        uint256 feeAmount = _feeAmount(source.feeBaseAmount);

        manager.take(Currency.wrap(source.feeToken), address(this), feeAmount);
        _record(
            source.feeToken,
            source.feeBaseAmount,
            feeAmount,
            BaseMoonAmmFeePolicy.CollectionStage.AfterSwap,
            BaseMoonAmmFeePolicy.SettlementMethod.AfterSwapUnspecifiedReturnDelta
        );

        return (IHooks.afterSwap.selector, _toInt128(feeAmount));
    }

    modifier onlyPoolManager() {
        if (msg.sender != address(manager)) revert NotPoolManager();
        _;
    }

    function _record(
        address feeToken,
        uint256 feeBaseAmount,
        uint256 feeAmount,
        BaseMoonAmmFeePolicy.CollectionStage collectionStage,
        BaseMoonAmmFeePolicy.SettlementMethod settlementMethod
    ) private {
        lastFeeToken = feeToken;
        lastFeeBaseAmount = feeBaseAmount;
        lastFeeAmount = feeAmount;
        lastCollectionStage = collectionStage;
        lastSettlementMethod = settlementMethod;
    }

    function _feeTokenFromMoonPair(PoolKey calldata key)
        private
        view
        returns (address feeToken, bool isMoonPair)
    {
        address token0 = Currency.unwrap(key.currency0);
        address token1 = Currency.unwrap(key.currency1);
        bool token0IsMoon = token0 == moonToken;
        bool token1IsMoon = token1 == moonToken;

        if (token0IsMoon == token1IsMoon) {
            return (address(0), false);
        }

        return (token0IsMoon ? token1 : token0, true);
    }

    function _isFeeTokenSpecified(
        PoolKey calldata key,
        SwapParams calldata params,
        address feeToken
    ) private pure returns (bool) {
        bool exactInput = params.amountSpecified < 0;
        address specifiedToken =
            Currency.unwrap(params.zeroForOne == exactInput ? key.currency0 : key.currency1);

        return specifiedToken == feeToken;
    }

    function _absoluteAmountSpecified(int256 amountSpecified) private pure returns (uint256) {
        return amountSpecified < 0 ? uint256(-amountSpecified) : uint256(amountSpecified);
    }

    function _feeAmount(uint256 feeBaseAmount) private pure returns (uint256) {
        uint256 feeAmount = feeBaseAmount * FEE_BIPS / BIPS_DENOMINATOR;
        if (feeAmount == 0) revert InvalidFeeAmount();
        return feeAmount;
    }

    function _toInt128(uint256 amount) private pure returns (int128) {
        if (amount > uint256(uint128(type(int128).max))) {
            revert InvalidFeeAmount();
        }

        return int128(uint128(amount));
    }
}

contract BaseMoonAmmFeeReturnDeltaSettlementTest is Deployers {
    uint256 internal constant SWAP_AMOUNT = 10_000;
    uint256 internal constant EXPECTED_SPECIFIED_FEE = 500;

    BaseMoonAmmFeeReturnDeltaSettlementHook internal hook;
    MockERC20 internal feeToken;
    MockERC20 internal moon;

    function setUp() public {
        deployFreshManagerAndRouters();
        deployMintAndApprove2Currencies();

        feeToken = MockERC20(Currency.unwrap(currency0));
        moon = MockERC20(Currency.unwrap(currency1));

        address hookAddress = address(
            uint160(
                Hooks.BEFORE_SWAP_FLAG | Hooks.AFTER_SWAP_FLAG
                    | Hooks.BEFORE_SWAP_RETURNS_DELTA_FLAG | Hooks.AFTER_SWAP_RETURNS_DELTA_FLAG
            )
        );

        BaseMoonAmmFeeReturnDeltaSettlementHook implementation =
            new BaseMoonAmmFeeReturnDeltaSettlementHook(manager, address(moon));
        vm.etch(hookAddress, address(implementation).code);
        hook = BaseMoonAmmFeeReturnDeltaSettlementHook(hookAddress);

        (key,) = initPoolAndAddLiquidity(
            currency0, currency1, IHooks(hookAddress), 3000, SQRT_PRICE_1_1
        );
    }

    function testBeforeSwapSpecifiedInputDeltaSettlesFeeToHook() public {
        uint256 hookBalanceBefore = feeToken.balanceOf(address(hook));

        BalanceDelta delta = _swap(true, -int256(SWAP_AMOUNT));

        assertEq(uint256(int256(-delta.amount0())), SWAP_AMOUNT);
        assertEq(feeToken.balanceOf(address(hook)) - hookBalanceBefore, EXPECTED_SPECIFIED_FEE);
        assertEq(hook.lastFeeToken(), address(feeToken));
        assertEq(hook.lastFeeBaseAmount(), SWAP_AMOUNT);
        assertEq(hook.lastFeeAmount(), EXPECTED_SPECIFIED_FEE);
        assertEq(
            uint8(hook.lastCollectionStage()),
            uint8(BaseMoonAmmFeePolicy.CollectionStage.BeforeSwap)
        );
        assertEq(
            uint8(hook.lastSettlementMethod()),
            uint8(BaseMoonAmmFeePolicy.SettlementMethod.BeforeSwapSpecifiedReturnDelta)
        );
    }

    function testBeforeSwapSpecifiedOutputDeltaSettlesFeeToHook() public {
        uint256 hookBalanceBefore = feeToken.balanceOf(address(hook));

        BalanceDelta delta = _swap(false, int256(SWAP_AMOUNT));

        assertEq(uint256(int256(delta.amount0())), SWAP_AMOUNT);
        assertEq(feeToken.balanceOf(address(hook)) - hookBalanceBefore, EXPECTED_SPECIFIED_FEE);
        assertEq(hook.lastFeeToken(), address(feeToken));
        assertEq(hook.lastFeeBaseAmount(), SWAP_AMOUNT);
        assertEq(hook.lastFeeAmount(), EXPECTED_SPECIFIED_FEE);
        assertEq(
            uint8(hook.lastCollectionStage()),
            uint8(BaseMoonAmmFeePolicy.CollectionStage.BeforeSwap)
        );
        assertEq(
            uint8(hook.lastSettlementMethod()),
            uint8(BaseMoonAmmFeePolicy.SettlementMethod.BeforeSwapSpecifiedReturnDelta)
        );
    }

    function testAfterSwapUnspecifiedInputDeltaSettlesFeeToHook() public {
        uint256 hookBalanceBefore = feeToken.balanceOf(address(hook));

        BalanceDelta delta = _swap(true, int256(SWAP_AMOUNT));
        uint256 feeBaseAmount = hook.lastFeeBaseAmount();
        uint256 feeAmount = hook.lastFeeAmount();

        assertEq(uint256(int256(delta.amount1())), SWAP_AMOUNT);
        assertEq(uint256(int256(-delta.amount0())), feeBaseAmount + feeAmount);
        assertEq(feeAmount, feeBaseAmount * 500 / 10_000);
        assertEq(feeToken.balanceOf(address(hook)) - hookBalanceBefore, feeAmount);
        assertEq(hook.lastFeeToken(), address(feeToken));
        assertEq(
            uint8(hook.lastCollectionStage()), uint8(BaseMoonAmmFeePolicy.CollectionStage.AfterSwap)
        );
        assertEq(
            uint8(hook.lastSettlementMethod()),
            uint8(BaseMoonAmmFeePolicy.SettlementMethod.AfterSwapUnspecifiedReturnDelta)
        );
    }

    function testAfterSwapUnspecifiedOutputDeltaSettlesFeeToHook() public {
        uint256 hookBalanceBefore = feeToken.balanceOf(address(hook));

        BalanceDelta delta = _swap(false, -int256(SWAP_AMOUNT));
        uint256 feeBaseAmount = hook.lastFeeBaseAmount();
        uint256 feeAmount = hook.lastFeeAmount();

        assertEq(uint256(int256(-delta.amount1())), SWAP_AMOUNT);
        assertEq(uint256(int256(delta.amount0())) + feeAmount, feeBaseAmount);
        assertEq(feeAmount, feeBaseAmount * 500 / 10_000);
        assertEq(feeToken.balanceOf(address(hook)) - hookBalanceBefore, feeAmount);
        assertEq(hook.lastFeeToken(), address(feeToken));
        assertEq(
            uint8(hook.lastCollectionStage()), uint8(BaseMoonAmmFeePolicy.CollectionStage.AfterSwap)
        );
        assertEq(
            uint8(hook.lastSettlementMethod()),
            uint8(BaseMoonAmmFeePolicy.SettlementMethod.AfterSwapUnspecifiedReturnDelta)
        );
    }

    function _swap(bool zeroForOne, int256 amountSpecified) private returns (BalanceDelta) {
        return swapRouter.swap(
            key,
            SwapParams({
                zeroForOne: zeroForOne,
                amountSpecified: amountSpecified,
                sqrtPriceLimitX96: zeroForOne ? MIN_PRICE_LIMIT : MAX_PRICE_LIMIT
            }),
            PoolSwapTest.TestSettings({ takeClaims: false, settleUsingBurn: false }),
            ZERO_BYTES
        );
    }
}
