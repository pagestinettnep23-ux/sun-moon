// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
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
import { AmmSwapAdapter } from "../../../contracts/hooks/AmmSwapAdapter.sol";
import { IMoonAmmSwapAdapter } from "../../../contracts/hooks/MoonAmmFeeHook.sol";
import { BaseMoonAmmFeePolicy } from "../../../contracts/hooks/base/BaseMoonAmmFeePolicy.sol";
import { MockUSDT } from "../../../contracts/mocks/MockUSDT.sol";
import { SunCurve } from "../../../contracts/SunCurve.sol";
import { SunToken } from "../../../contracts/SunToken.sol";

contract BaseMoonAmmFeeReturnDeltaRouteHook is BaseTestHooks {
    using SafeERC20 for IERC20;

    uint256 internal constant BPS = 10_000;
    uint256 internal constant FEE_TO_SUN_CURVE_BPS = 300;
    uint256 internal constant FEE_TO_PROTOCOL_BPS = 200;

    IPoolManager public immutable manager;
    address public immutable moonToken;
    IERC20 public immutable usdt;
    SunCurve public immutable sunCurve;
    address public immutable protocolBudget;
    IMoonAmmSwapAdapter public immutable swapAdapter;

    address public lastFeeToken;
    uint256 public lastFeeBaseAmount;
    uint256 public lastFeeToSunCurve;
    uint256 public lastFeeToProtocol;
    uint256 public lastUSDTInjected;
    BaseMoonAmmFeePolicy.CollectionStage public lastCollectionStage;
    BaseMoonAmmFeePolicy.SettlementMethod public lastSettlementMethod;

    error InvalidAmount();
    error InvalidHookData();
    error InsufficientUSDTOut(uint256 usdtOut, uint256 minUSDTOut);
    error NotPoolManager();
    error ZeroAddress();

    constructor(
        IPoolManager manager_,
        address moonToken_,
        IERC20 usdt_,
        SunCurve sunCurve_,
        address protocolBudget_,
        IMoonAmmSwapAdapter swapAdapter_
    ) {
        if (
            address(manager_) == address(0) || moonToken_ == address(0)
                || address(usdt_) == address(0) || address(sunCurve_) == address(0)
                || protocolBudget_ == address(0) || address(swapAdapter_) == address(0)
        ) {
            revert ZeroAddress();
        }

        manager = manager_;
        moonToken = moonToken_;
        usdt = usdt_;
        sunCurve = sunCurve_;
        protocolBudget = protocolBudget_;
        swapAdapter = swapAdapter_;
    }

    function beforeSwap(
        address,
        PoolKey calldata key,
        SwapParams calldata params,
        bytes calldata hookData
    ) external override onlyPoolManager returns (bytes4, BeforeSwapDelta, uint24) {
        (address feeToken, bool isMoonPair) = _feeTokenFromMoonPair(key);
        if (!isMoonPair || !_isFeeTokenSpecified(key, params, feeToken)) {
            return (IHooks.beforeSwap.selector, BeforeSwapDeltaLibrary.ZERO_DELTA, 0);
        }

        (uint256 feeBaseAmount, uint256 feeToSunCurve, uint256 feeToProtocol) =
            _feeBreakdown(_absoluteAmountSpecified(params.amountSpecified));

        manager.take(Currency.wrap(feeToken), address(this), feeToSunCurve + feeToProtocol);
        uint256 usdtInjected =
            _routeFee(feeToken, feeToSunCurve, feeToProtocol, _minUSDTOut(hookData));
        _record(
            feeToken,
            feeBaseAmount,
            feeToSunCurve,
            feeToProtocol,
            usdtInjected,
            BaseMoonAmmFeePolicy.CollectionStage.BeforeSwap,
            BaseMoonAmmFeePolicy.SettlementMethod.BeforeSwapSpecifiedReturnDelta
        );

        return (
            IHooks.beforeSwap.selector,
            toBeforeSwapDelta(_toInt128(feeToSunCurve + feeToProtocol), 0),
            0
        );
    }

    function afterSwap(
        address,
        PoolKey calldata key,
        SwapParams calldata params,
        BalanceDelta swapDelta,
        bytes calldata hookData
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

        (uint256 feeBaseAmount, uint256 feeToSunCurve, uint256 feeToProtocol) =
            _feeBreakdown(source.feeBaseAmount);

        manager.take(Currency.wrap(source.feeToken), address(this), feeToSunCurve + feeToProtocol);
        uint256 usdtInjected =
            _routeFee(source.feeToken, feeToSunCurve, feeToProtocol, _minUSDTOut(hookData));
        _record(
            source.feeToken,
            feeBaseAmount,
            feeToSunCurve,
            feeToProtocol,
            usdtInjected,
            BaseMoonAmmFeePolicy.CollectionStage.AfterSwap,
            BaseMoonAmmFeePolicy.SettlementMethod.AfterSwapUnspecifiedReturnDelta
        );

        return (IHooks.afterSwap.selector, _toInt128(feeToSunCurve + feeToProtocol));
    }

    modifier onlyPoolManager() {
        if (msg.sender != address(manager)) revert NotPoolManager();
        _;
    }

    function _routeFee(
        address feeToken,
        uint256 feeToSunCurve,
        uint256 feeToProtocol,
        uint256 minUSDTOut
    ) private returns (uint256 usdtOut) {
        IERC20 collectedFeeToken = IERC20(feeToken);

        if (feeToken == address(usdt)) {
            usdtOut = feeToSunCurve;
        } else {
            collectedFeeToken.forceApprove(address(swapAdapter), feeToSunCurve);
            usdtOut = swapAdapter.swapFeeAssetToUSDT(feeToken, feeToSunCurve, minUSDTOut);
        }

        if (usdtOut < minUSDTOut) revert InsufficientUSDTOut(usdtOut, minUSDTOut);

        usdt.forceApprove(address(sunCurve), usdtOut);
        sunCurve.injectUSDT(usdtOut);
        collectedFeeToken.safeTransfer(protocolBudget, feeToProtocol);
    }

    function _record(
        address feeToken,
        uint256 feeBaseAmount,
        uint256 feeToSunCurve,
        uint256 feeToProtocol,
        uint256 usdtInjected,
        BaseMoonAmmFeePolicy.CollectionStage collectionStage,
        BaseMoonAmmFeePolicy.SettlementMethod settlementMethod
    ) private {
        lastFeeToken = feeToken;
        lastFeeBaseAmount = feeBaseAmount;
        lastFeeToSunCurve = feeToSunCurve;
        lastFeeToProtocol = feeToProtocol;
        lastUSDTInjected = usdtInjected;
        lastCollectionStage = collectionStage;
        lastSettlementMethod = settlementMethod;
    }

    function _feeBreakdown(uint256 feeBaseAmount)
        private
        pure
        returns (uint256, uint256 feeToSunCurve, uint256 feeToProtocol)
    {
        feeToSunCurve = feeBaseAmount * FEE_TO_SUN_CURVE_BPS / BPS;
        feeToProtocol = feeBaseAmount * FEE_TO_PROTOCOL_BPS / BPS;
        if (feeToSunCurve == 0 || feeToProtocol == 0) revert InvalidAmount();

        return (feeBaseAmount, feeToSunCurve, feeToProtocol);
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

    function _minUSDTOut(bytes calldata hookData) private pure returns (uint256 minUSDTOut) {
        if (hookData.length == 0) revert InvalidHookData();
        minUSDTOut = abi.decode(hookData, (uint256));
        if (minUSDTOut == 0) revert InvalidAmount();
    }

    function _toInt128(uint256 amount) private pure returns (int128) {
        if (amount > uint256(uint128(type(int128).max))) revert InvalidAmount();

        return int128(uint128(amount));
    }
}

contract BaseMoonAmmFeeReturnDeltaRouteTest is Deployers {
    uint256 internal constant SWAP_AMOUNT = 10_000;
    uint256 internal constant EXPECTED_FEE_TO_SUN_CURVE = 300;
    uint256 internal constant EXPECTED_FEE_TO_PROTOCOL = 200;
    uint256 internal constant MOCK_USDT_OUT = 450;
    uint256 internal constant MIN_USDT_OUT = 400;

    address internal protocolBudget = makeAddr("protocolBudget");

    MockUSDT internal usdt;
    SunToken internal sun;
    SunCurve internal sunCurve;
    AmmSwapAdapter internal adapter;
    BaseMoonAmmFeeReturnDeltaRouteHook internal hook;
    MockERC20 internal feeAsset;
    MockERC20 internal moon;

    PoolKey internal feeAssetMoonKey;
    PoolKey internal usdtMoonKey;

    function setUp() public {
        deployFreshManagerAndRouters();
        deployMintAndApprove2Currencies();

        feeAsset = MockERC20(Currency.unwrap(currency0));
        moon = MockERC20(Currency.unwrap(currency1));

        usdt = new MockUSDT("Mock USDC", "USDC", 6);
        usdt.mint(address(this), type(uint128).max);
        usdt.approve(address(swapRouter), type(uint256).max);
        usdt.approve(address(modifyLiquidityRouter), type(uint256).max);

        sun = new SunToken("SUN", "SUN", address(this));
        sunCurve = new SunCurve(sun, usdt, protocolBudget, type(uint128).max, address(this));
        sun.setMinter(address(sunCurve));

        address hookAddress = address(
            uint160(
                Hooks.BEFORE_SWAP_FLAG | Hooks.AFTER_SWAP_FLAG
                    | Hooks.BEFORE_SWAP_RETURNS_DELTA_FLAG | Hooks.AFTER_SWAP_RETURNS_DELTA_FLAG
            )
        );

        adapter = new AmmSwapAdapter(usdt, hookAddress, address(this));
        BaseMoonAmmFeeReturnDeltaRouteHook implementation = new BaseMoonAmmFeeReturnDeltaRouteHook(
            manager, address(moon), usdt, sunCurve, protocolBudget, adapter
        );
        vm.etch(hookAddress, address(implementation).code);
        hook = BaseMoonAmmFeeReturnDeltaRouteHook(hookAddress);

        sunCurve.setMoonAMM(hookAddress);
        adapter.setMockUSDTOut(MOCK_USDT_OUT);

        (feeAssetMoonKey,) = initPoolAndAddLiquidity(
            currency0, currency1, IHooks(hookAddress), 3000, SQRT_PRICE_1_1
        );

        (Currency stableCurrency0, Currency stableCurrency1) =
            _sortedCurrencies(address(usdt), address(moon));
        (usdtMoonKey,) = initPoolAndAddLiquidity(
            stableCurrency0, stableCurrency1, IHooks(hookAddress), 3000, SQRT_PRICE_1_1
        );
    }

    function testSpecifiedNonUsdcFeeRoutesThroughAdapterAndOriginalAssetBudget() public {
        uint256 adapterFeeBefore = feeAsset.balanceOf(address(adapter));
        uint256 budgetFeeBefore = feeAsset.balanceOf(protocolBudget);

        _swapExactFeeTokenInput(feeAssetMoonKey, address(feeAsset), SWAP_AMOUNT, MIN_USDT_OUT);

        assertEq(hook.lastFeeToken(), address(feeAsset));
        assertEq(hook.lastFeeBaseAmount(), SWAP_AMOUNT);
        assertEq(hook.lastFeeToSunCurve(), EXPECTED_FEE_TO_SUN_CURVE);
        assertEq(hook.lastFeeToProtocol(), EXPECTED_FEE_TO_PROTOCOL);
        assertEq(hook.lastUSDTInjected(), MOCK_USDT_OUT);
        assertEq(feeAsset.balanceOf(address(adapter)) - adapterFeeBefore, EXPECTED_FEE_TO_SUN_CURVE);
        assertEq(feeAsset.balanceOf(protocolBudget) - budgetFeeBefore, EXPECTED_FEE_TO_PROTOCOL);
        assertEq(sunCurve.curveReserve(), MOCK_USDT_OUT);
        assertEq(usdt.balanceOf(address(sunCurve)), MOCK_USDT_OUT);
        assertEq(feeAsset.balanceOf(address(hook)), 0);
        assertEq(usdt.balanceOf(address(hook)), 0);
    }

    function testUnspecifiedNonUsdcFeeRoutesThroughAdapterAndOriginalAssetBudget() public {
        _swapExactMoonInputForFeeTokenOutput(
            feeAssetMoonKey, address(feeAsset), SWAP_AMOUNT, MIN_USDT_OUT
        );

        assertEq(hook.lastFeeToken(), address(feeAsset));
        assertGt(hook.lastFeeBaseAmount(), 0);
        assertEq(hook.lastFeeToSunCurve(), hook.lastFeeBaseAmount() * 300 / 10_000);
        assertEq(hook.lastFeeToProtocol(), hook.lastFeeBaseAmount() * 200 / 10_000);
        assertEq(hook.lastUSDTInjected(), MOCK_USDT_OUT);
        assertEq(feeAsset.balanceOf(address(adapter)), hook.lastFeeToSunCurve());
        assertEq(feeAsset.balanceOf(protocolBudget), hook.lastFeeToProtocol());
        assertEq(sunCurve.curveReserve(), MOCK_USDT_OUT);
        assertEq(usdt.balanceOf(address(sunCurve)), MOCK_USDT_OUT);
        assertEq(
            uint8(hook.lastSettlementMethod()),
            uint8(BaseMoonAmmFeePolicy.SettlementMethod.AfterSwapUnspecifiedReturnDelta)
        );
    }

    function testSpecifiedUsdcFeeInjectsDirectlyAndSendsUsdcBudget() public {
        uint256 adapterUsdtBefore = usdt.balanceOf(address(adapter));
        uint256 budgetUsdtBefore = usdt.balanceOf(protocolBudget);

        _swapExactFeeTokenInput(usdtMoonKey, address(usdt), SWAP_AMOUNT, EXPECTED_FEE_TO_SUN_CURVE);

        assertEq(hook.lastFeeToken(), address(usdt));
        assertEq(hook.lastFeeBaseAmount(), SWAP_AMOUNT);
        assertEq(hook.lastFeeToSunCurve(), EXPECTED_FEE_TO_SUN_CURVE);
        assertEq(hook.lastFeeToProtocol(), EXPECTED_FEE_TO_PROTOCOL);
        assertEq(hook.lastUSDTInjected(), EXPECTED_FEE_TO_SUN_CURVE);
        assertEq(usdt.balanceOf(address(adapter)), adapterUsdtBefore);
        assertEq(usdt.balanceOf(protocolBudget) - budgetUsdtBefore, EXPECTED_FEE_TO_PROTOCOL);
        assertEq(sunCurve.curveReserve(), EXPECTED_FEE_TO_SUN_CURVE);
        assertEq(usdt.balanceOf(address(hook)), 0);
        assertEq(
            uint8(hook.lastSettlementMethod()),
            uint8(BaseMoonAmmFeePolicy.SettlementMethod.BeforeSwapSpecifiedReturnDelta)
        );
    }

    function testUnspecifiedUsdcFeeInjectsDirectlyAndSendsUsdcBudget() public {
        uint256 budgetUsdtBefore = usdt.balanceOf(protocolBudget);

        _swapExactMoonInputForFeeTokenOutput(usdtMoonKey, address(usdt), SWAP_AMOUNT, 1);

        assertEq(hook.lastFeeToken(), address(usdt));
        assertGt(hook.lastFeeBaseAmount(), 0);
        assertEq(hook.lastFeeToSunCurve(), hook.lastFeeBaseAmount() * 300 / 10_000);
        assertEq(hook.lastFeeToProtocol(), hook.lastFeeBaseAmount() * 200 / 10_000);
        assertEq(hook.lastUSDTInjected(), hook.lastFeeToSunCurve());
        assertEq(usdt.balanceOf(protocolBudget) - budgetUsdtBefore, hook.lastFeeToProtocol());
        assertEq(sunCurve.curveReserve(), hook.lastFeeToSunCurve());
        assertEq(usdt.balanceOf(address(hook)), 0);
        assertEq(usdt.balanceOf(address(adapter)), 0);
        assertEq(
            uint8(hook.lastSettlementMethod()),
            uint8(BaseMoonAmmFeePolicy.SettlementMethod.AfterSwapUnspecifiedReturnDelta)
        );
    }

    function _swapExactFeeTokenInput(
        PoolKey memory poolKey,
        address feeToken,
        uint256 amountIn,
        uint256 minUSDTOut
    ) private returns (BalanceDelta) {
        return _swap(
            poolKey, Currency.unwrap(poolKey.currency0) == feeToken, -int256(amountIn), minUSDTOut
        );
    }

    function _swapExactMoonInputForFeeTokenOutput(
        PoolKey memory poolKey,
        address feeToken,
        uint256 moonAmountIn,
        uint256 minUSDTOut
    ) private returns (BalanceDelta) {
        bool moonIsCurrency0 = Currency.unwrap(poolKey.currency0) != feeToken;
        return _swap(poolKey, moonIsCurrency0, -int256(moonAmountIn), minUSDTOut);
    }

    function _swap(
        PoolKey memory poolKey,
        bool zeroForOne,
        int256 amountSpecified,
        uint256 minUSDTOut
    ) private returns (BalanceDelta) {
        return swapRouter.swap(
            poolKey,
            SwapParams({
                zeroForOne: zeroForOne,
                amountSpecified: amountSpecified,
                sqrtPriceLimitX96: zeroForOne ? MIN_PRICE_LIMIT : MAX_PRICE_LIMIT
            }),
            PoolSwapTest.TestSettings({ takeClaims: false, settleUsingBurn: false }),
            abi.encode(minUSDTOut)
        );
    }

    function _sortedCurrencies(address tokenA, address tokenB)
        private
        pure
        returns (Currency currencyA, Currency currencyB)
    {
        (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        return (Currency.wrap(token0), Currency.wrap(token1));
    }
}
