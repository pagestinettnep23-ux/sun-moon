// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import { IHooks } from "@uniswap/v4-core/src/interfaces/IHooks.sol";
import { IPoolManager } from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import { Hooks } from "@uniswap/v4-core/src/libraries/Hooks.sol";
import { BalanceDelta, BalanceDeltaLibrary } from "@uniswap/v4-core/src/types/BalanceDelta.sol";
import {
    BeforeSwapDelta,
    BeforeSwapDeltaLibrary,
    toBeforeSwapDelta
} from "@uniswap/v4-core/src/types/BeforeSwapDelta.sol";
import { Currency } from "@uniswap/v4-core/src/types/Currency.sol";
import { PoolId, PoolIdLibrary } from "@uniswap/v4-core/src/types/PoolId.sol";
import { PoolKey } from "@uniswap/v4-core/src/types/PoolKey.sol";
import { ModifyLiquidityParams, SwapParams } from "@uniswap/v4-core/src/types/PoolOperation.sol";
import { IMoonAmmSwapAdapter } from "../MoonAmmFeeHook.sol";
import { SunCurve } from "../../SunCurve.sol";
import { BaseMoonAmmFeePolicy } from "./BaseMoonAmmFeePolicy.sol";

contract BaseMoonAmmFeeV4Hook is IHooks, ReentrancyGuard {
    using PoolIdLibrary for PoolKey;
    using SafeERC20 for IERC20;

    uint256 public constant BPS = 10_000;
    uint256 public constant FEE_TO_SUN_CURVE_BPS = 300;
    uint256 public constant FEE_TO_PROTOCOL_BPS = 200;

    struct MoonFeeHookData {
        uint256 minUSDTOut;
    }

    error HookPaused();
    error InsufficientUSDTOut(uint256 usdtOut, uint256 minUSDTOut);
    error InvalidAddress();
    error InvalidAmount();
    error InvalidHookData();
    error InvalidMinUSDTOut();
    error InvalidPoolId();
    error MoonPoolNotAllowed(bytes32 poolId);
    error NotOwner();
    error NotPoolManager();

    IPoolManager public immutable poolManager;
    address public immutable moonToken;
    IERC20 public immutable usdt;
    SunCurve public immutable sunCurve;
    address public immutable owner;

    address public protocolBudget;
    IMoonAmmSwapAdapter public swapAdapter;
    bool public paused;

    mapping(bytes32 poolId => bool allowed) public allowedMoonPools;

    event MoonAmmFeeRouted(
        bytes32 indexed poolId,
        address indexed feeToken,
        uint256 feeBaseAmount,
        uint256 feeToSunCurve,
        uint256 feeToProtocol,
        uint256 usdtInjected,
        BaseMoonAmmFeePolicy.CollectionStage collectionStage,
        BaseMoonAmmFeePolicy.SettlementMethod settlementMethod
    );
    event MoonPoolAllowedSet(bytes32 indexed poolId, bool allowed);
    event PausedSet(bool paused);
    event ProtocolBudgetSet(address indexed protocolBudget);
    event SwapAdapterSet(address indexed swapAdapter);

    constructor(
        IPoolManager poolManager_,
        address moonToken_,
        IERC20 usdt_,
        SunCurve sunCurve_,
        address protocolBudget_,
        IMoonAmmSwapAdapter swapAdapter_,
        address owner_
    ) {
        if (
            address(poolManager_) == address(0) || moonToken_ == address(0)
                || address(usdt_) == address(0) || address(sunCurve_) == address(0)
                || protocolBudget_ == address(0) || address(swapAdapter_) == address(0)
                || owner_ == address(0)
        ) {
            revert InvalidAddress();
        }

        poolManager = poolManager_;
        moonToken = moonToken_;
        usdt = usdt_;
        sunCurve = sunCurve_;
        owner = owner_;
        protocolBudget = protocolBudget_;
        swapAdapter = swapAdapter_;

        emit ProtocolBudgetSet(protocolBudget_);
        emit SwapAdapterSet(address(swapAdapter_));
    }

    function expectedHookMask() external pure returns (uint160) {
        return Hooks.BEFORE_SWAP_FLAG | Hooks.AFTER_SWAP_FLAG | Hooks.BEFORE_SWAP_RETURNS_DELTA_FLAG
            | Hooks.AFTER_SWAP_RETURNS_DELTA_FLAG;
    }

    function encodeHookData(uint256 minUSDTOut) external pure returns (bytes memory) {
        return abi.encode(MoonFeeHookData({ minUSDTOut: minUSDTOut }));
    }

    function setProtocolBudget(address newProtocolBudget) external onlyOwner {
        if (newProtocolBudget == address(0)) revert InvalidAddress();

        protocolBudget = newProtocolBudget;

        emit ProtocolBudgetSet(newProtocolBudget);
    }

    function setSwapAdapter(address newSwapAdapter) external onlyOwner {
        if (newSwapAdapter == address(0)) revert InvalidAddress();

        swapAdapter = IMoonAmmSwapAdapter(newSwapAdapter);

        emit SwapAdapterSet(newSwapAdapter);
    }

    function setAllowedMoonPool(bytes32 poolId, bool allowed) external onlyOwner {
        if (poolId == bytes32(0)) revert InvalidPoolId();

        allowedMoonPools[poolId] = allowed;

        emit MoonPoolAllowedSet(poolId, allowed);
    }

    function setPaused(bool newPaused) external onlyOwner {
        paused = newPaused;

        emit PausedSet(newPaused);
    }

    function beforeInitialize(address, PoolKey calldata, uint160)
        external
        view
        override
        onlyPoolManager
        returns (bytes4)
    {
        return this.beforeInitialize.selector;
    }

    function afterInitialize(address, PoolKey calldata, uint160, int24)
        external
        view
        override
        onlyPoolManager
        returns (bytes4)
    {
        return this.afterInitialize.selector;
    }

    function beforeAddLiquidity(
        address,
        PoolKey calldata,
        ModifyLiquidityParams calldata,
        bytes calldata
    ) external view override onlyPoolManager returns (bytes4) {
        return this.beforeAddLiquidity.selector;
    }

    function afterAddLiquidity(
        address,
        PoolKey calldata,
        ModifyLiquidityParams calldata,
        BalanceDelta,
        BalanceDelta,
        bytes calldata
    ) external view override onlyPoolManager returns (bytes4, BalanceDelta) {
        return (this.afterAddLiquidity.selector, BalanceDeltaLibrary.ZERO_DELTA);
    }

    function beforeRemoveLiquidity(
        address,
        PoolKey calldata,
        ModifyLiquidityParams calldata,
        bytes calldata
    ) external view override onlyPoolManager returns (bytes4) {
        return this.beforeRemoveLiquidity.selector;
    }

    function afterRemoveLiquidity(
        address,
        PoolKey calldata,
        ModifyLiquidityParams calldata,
        BalanceDelta,
        BalanceDelta,
        bytes calldata
    ) external view override onlyPoolManager returns (bytes4, BalanceDelta) {
        return (this.afterRemoveLiquidity.selector, BalanceDeltaLibrary.ZERO_DELTA);
    }

    function beforeSwap(
        address,
        PoolKey calldata key,
        SwapParams calldata params,
        bytes calldata hookData
    ) external override onlyPoolManager nonReentrant returns (bytes4, BeforeSwapDelta, uint24) {
        PoolKey memory poolKey = key;
        PoolId poolId = poolKey.toId();
        (address feeToken, bool moonPair) = _feeTokenFromMoonPair(key);
        if (!moonPair) {
            return (this.beforeSwap.selector, BeforeSwapDeltaLibrary.ZERO_DELTA, 0);
        }

        _validateMoonSwap(PoolId.unwrap(poolId));
        if (!_isFeeTokenSpecified(key, params, feeToken)) {
            return (this.beforeSwap.selector, BeforeSwapDeltaLibrary.ZERO_DELTA, 0);
        }

        uint256 totalFee = _collectAndRouteFee(
            PoolId.unwrap(poolId),
            feeToken,
            _absoluteAmountSpecified(params.amountSpecified),
            _minUSDTOut(hookData),
            BaseMoonAmmFeePolicy.CollectionStage.BeforeSwap,
            BaseMoonAmmFeePolicy.SettlementMethod.BeforeSwapSpecifiedReturnDelta
        );

        return (this.beforeSwap.selector, toBeforeSwapDelta(_toInt128(totalFee), 0), 0);
    }

    function afterSwap(
        address,
        PoolKey calldata key,
        SwapParams calldata params,
        BalanceDelta swapDelta,
        bytes calldata hookData
    ) external override onlyPoolManager nonReentrant returns (bytes4, int128) {
        PoolKey memory poolKey = key;
        PoolId poolId = poolKey.toId();
        (, bool moonPair) = _feeTokenFromMoonPair(key);
        if (!moonPair) {
            return (this.afterSwap.selector, 0);
        }

        _validateMoonSwap(PoolId.unwrap(poolId));
        BaseMoonAmmFeePolicy.FeeSource memory source =
            BaseMoonAmmFeePolicy.quoteNonMoonFeeSource(poolKey, params, swapDelta, moonToken);
        if (source.collectionStage != BaseMoonAmmFeePolicy.CollectionStage.AfterSwap) {
            return (this.afterSwap.selector, 0);
        }

        uint256 totalFee = _collectAndRouteFee(
            PoolId.unwrap(poolId),
            source.feeToken,
            source.feeBaseAmount,
            _minUSDTOut(hookData),
            BaseMoonAmmFeePolicy.CollectionStage.AfterSwap,
            BaseMoonAmmFeePolicy.SettlementMethod.AfterSwapUnspecifiedReturnDelta
        );

        return (this.afterSwap.selector, _toInt128(totalFee));
    }

    function beforeDonate(address, PoolKey calldata, uint256, uint256, bytes calldata)
        external
        view
        override
        onlyPoolManager
        returns (bytes4)
    {
        return this.beforeDonate.selector;
    }

    function afterDonate(address, PoolKey calldata, uint256, uint256, bytes calldata)
        external
        view
        override
        onlyPoolManager
        returns (bytes4)
    {
        return this.afterDonate.selector;
    }

    function isMoonPair(address token0, address token1) public view returns (bool) {
        return (token0 == moonToken) != (token1 == moonToken);
    }

    function _collectAndRouteFee(
        bytes32 poolId,
        address feeToken,
        uint256 feeBaseAmount,
        uint256 minUSDTOut,
        BaseMoonAmmFeePolicy.CollectionStage collectionStage,
        BaseMoonAmmFeePolicy.SettlementMethod settlementMethod
    ) private returns (uint256 totalFee) {
        (uint256 feeToSunCurve, uint256 feeToProtocol) = _feeBreakdown(feeBaseAmount);
        totalFee = feeToSunCurve + feeToProtocol;

        poolManager.take(Currency.wrap(feeToken), address(this), totalFee);
        uint256 usdtInjected = _routeFee(feeToken, feeToSunCurve, feeToProtocol, minUSDTOut);

        emit MoonAmmFeeRouted(
            poolId,
            feeToken,
            feeBaseAmount,
            feeToSunCurve,
            feeToProtocol,
            usdtInjected,
            collectionStage,
            settlementMethod
        );
    }

    function _routeFee(
        address feeToken,
        uint256 feeToSunCurve,
        uint256 feeToProtocol,
        uint256 minUSDTOut
    ) private returns (uint256 usdtOut) {
        if (feeToken == address(0)) revert InvalidAddress();

        IERC20 collectedFeeToken = IERC20(feeToken);

        if (feeToken == address(usdt)) {
            usdtOut = feeToSunCurve;
        } else {
            IMoonAmmSwapAdapter adapter = swapAdapter;
            if (address(adapter) == address(0)) revert InvalidAddress();

            collectedFeeToken.forceApprove(address(adapter), feeToSunCurve);
            usdtOut = adapter.swapFeeAssetToUSDT(feeToken, feeToSunCurve, minUSDTOut);
        }

        if (usdtOut < minUSDTOut) revert InsufficientUSDTOut(usdtOut, minUSDTOut);

        usdt.forceApprove(address(sunCurve), usdtOut);
        sunCurve.injectUSDT(usdtOut);
        collectedFeeToken.safeTransfer(protocolBudget, feeToProtocol);
    }

    function _validateMoonSwap(bytes32 poolId) private view {
        if (paused) revert HookPaused();
        if (!allowedMoonPools[poolId]) revert MoonPoolNotAllowed(poolId);
        if (protocolBudget == address(0)) revert InvalidAddress();
    }

    function _feeBreakdown(uint256 feeBaseAmount)
        private
        pure
        returns (uint256 feeToSunCurve, uint256 feeToProtocol)
    {
        feeToSunCurve = Math.mulDiv(feeBaseAmount, FEE_TO_SUN_CURVE_BPS, BPS);
        feeToProtocol = Math.mulDiv(feeBaseAmount, FEE_TO_PROTOCOL_BPS, BPS);
        if (feeToSunCurve == 0 || feeToProtocol == 0) revert InvalidAmount();
    }

    function _feeTokenFromMoonPair(PoolKey calldata key)
        private
        view
        returns (address feeToken, bool isMoonPair_)
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
        if (amountSpecified == 0 || amountSpecified == type(int256).min) revert InvalidAmount();

        return amountSpecified < 0 ? uint256(-amountSpecified) : uint256(amountSpecified);
    }

    function _minUSDTOut(bytes calldata hookData) private pure returns (uint256 minUSDTOut) {
        if (hookData.length == 0) revert InvalidHookData();

        MoonFeeHookData memory feeData = abi.decode(hookData, (MoonFeeHookData));
        minUSDTOut = feeData.minUSDTOut;
        if (minUSDTOut == 0) revert InvalidMinUSDTOut();
    }

    function _toInt128(uint256 amount) private pure returns (int128) {
        if (amount > uint256(uint128(type(int128).max))) revert InvalidAmount();

        return int128(uint128(amount));
    }

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    modifier onlyPoolManager() {
        if (msg.sender != address(poolManager)) revert NotPoolManager();
        _;
    }
}
