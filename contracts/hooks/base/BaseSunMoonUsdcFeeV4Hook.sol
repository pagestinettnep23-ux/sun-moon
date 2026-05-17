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
import { SunCurve } from "../../SunCurve.sol";

contract BaseSunMoonUsdcFeeV4Hook is IHooks, ReentrancyGuard {
    using BalanceDeltaLibrary for BalanceDelta;
    using PoolIdLibrary for PoolKey;
    using SafeERC20 for IERC20;

    uint256 public constant BPS = 10_000;
    uint256 public constant SUN_FEE_TO_CURVE_BPS = 150;
    uint256 public constant SUN_FEE_TO_PROTOCOL_BPS = 50;
    uint256 public constant MOON_FEE_TO_CURVE_BPS = 300;
    uint256 public constant MOON_FEE_TO_PROTOCOL_BPS = 200;

    enum PoolKind {
        Unsupported,
        SunUsdc,
        MoonUsdc
    }

    struct UsdcFeeHookData {
        uint256 minUSDCToSunCurve;
    }

    error FeePoolNotAllowed(bytes32 poolId, PoolKind kind);
    error HookPaused();
    error InsufficientUSDCToSunCurve(uint256 usdcToSunCurve, uint256 minUSDCToSunCurve);
    error InvalidAddress();
    error InvalidAmount();
    error InvalidHookData();
    error InvalidMinUSDCToSunCurve();
    error InvalidPoolId();
    error NotOwner();
    error NotPoolManager();

    IPoolManager public immutable poolManager;
    address public immutable sunToken;
    address public immutable moonToken;
    IERC20 public immutable usdc;
    SunCurve public immutable sunCurve;

    address public owner;
    address public protocolBudget;
    bool public paused;

    mapping(bytes32 poolId => bool allowed) public allowedSunUsdcPools;
    mapping(bytes32 poolId => bool allowed) public allowedMoonUsdcPools;

    event FeeRouted(
        bytes32 indexed poolId,
        PoolKind indexed kind,
        uint256 feeBaseAmount,
        uint256 feeToSunCurve,
        uint256 feeToProtocol,
        uint256 usdcInjected
    );
    event MoonUsdcPoolAllowedSet(bytes32 indexed poolId, bool allowed);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event PausedSet(bool paused);
    event ProtocolBudgetSet(address indexed protocolBudget);
    event SunUsdcPoolAllowedSet(bytes32 indexed poolId, bool allowed);

    constructor(
        IPoolManager poolManager_,
        address sunToken_,
        address moonToken_,
        IERC20 usdc_,
        SunCurve sunCurve_,
        address protocolBudget_,
        address owner_
    ) {
        if (
            address(poolManager_) == address(0) || sunToken_ == address(0)
                || moonToken_ == address(0) || address(usdc_) == address(0)
                || address(sunCurve_) == address(0) || protocolBudget_ == address(0)
                || owner_ == address(0)
        ) {
            revert InvalidAddress();
        }
        if (sunToken_ == moonToken_) revert InvalidAddress();

        poolManager = poolManager_;
        sunToken = sunToken_;
        moonToken = moonToken_;
        usdc = usdc_;
        sunCurve = sunCurve_;
        protocolBudget = protocolBudget_;
        owner = owner_;

        emit ProtocolBudgetSet(protocolBudget_);
        emit OwnershipTransferred(address(0), owner_);
    }

    function expectedHookMask() external pure returns (uint160) {
        return Hooks.BEFORE_SWAP_FLAG | Hooks.AFTER_SWAP_FLAG | Hooks.BEFORE_SWAP_RETURNS_DELTA_FLAG
            | Hooks.AFTER_SWAP_RETURNS_DELTA_FLAG;
    }

    function encodeHookData(uint256 minUSDCToSunCurve) external pure returns (bytes memory) {
        return abi.encode(UsdcFeeHookData({ minUSDCToSunCurve: minUSDCToSunCurve }));
    }

    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert InvalidAddress();

        _transferOwnership(newOwner);
    }

    function renounceOwnership() external onlyOwner {
        _transferOwnership(address(0));
    }

    function setProtocolBudget(address newProtocolBudget) external onlyOwner {
        if (newProtocolBudget == address(0)) revert InvalidAddress();

        protocolBudget = newProtocolBudget;

        emit ProtocolBudgetSet(newProtocolBudget);
    }

    function setAllowedSunUsdcPool(bytes32 poolId, bool allowed) external onlyOwner {
        if (poolId == bytes32(0)) revert InvalidPoolId();

        allowedSunUsdcPools[poolId] = allowed;

        emit SunUsdcPoolAllowedSet(poolId, allowed);
    }

    function setAllowedMoonUsdcPool(bytes32 poolId, bool allowed) external onlyOwner {
        if (poolId == bytes32(0)) revert InvalidPoolId();

        allowedMoonUsdcPools[poolId] = allowed;

        emit MoonUsdcPoolAllowedSet(poolId, allowed);
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
        PoolKind kind = _poolKind(key);
        if (kind == PoolKind.Unsupported) {
            return (this.beforeSwap.selector, BeforeSwapDeltaLibrary.ZERO_DELTA, 0);
        }

        _validateFeePool(PoolId.unwrap(poolId), kind);
        if (!_isUsdcSpecified(key, params)) {
            return (this.beforeSwap.selector, BeforeSwapDeltaLibrary.ZERO_DELTA, 0);
        }

        uint256 totalFee = _collectAndRouteUsdcFee(
            PoolId.unwrap(poolId),
            kind,
            _absoluteAmountSpecified(params.amountSpecified),
            _minUSDCToSunCurve(hookData)
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
        PoolKind kind = _poolKind(key);
        if (kind == PoolKind.Unsupported) {
            return (this.afterSwap.selector, 0);
        }

        _validateFeePool(PoolId.unwrap(poolId), kind);
        if (_isUsdcSpecified(key, params)) {
            return (this.afterSwap.selector, 0);
        }

        uint256 totalFee = _collectAndRouteUsdcFee(
            PoolId.unwrap(poolId),
            kind,
            _usdcSwapDeltaAmount(key, params, swapDelta),
            _minUSDCToSunCurve(hookData)
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

    function _transferOwnership(address newOwner) private {
        address previousOwner = owner;
        owner = newOwner;

        emit OwnershipTransferred(previousOwner, newOwner);
    }

    function _collectAndRouteUsdcFee(
        bytes32 poolId,
        PoolKind kind,
        uint256 feeBaseAmount,
        uint256 minUSDCToSunCurve
    ) private returns (uint256 totalFee) {
        (uint256 feeToSunCurve, uint256 feeToProtocol) = _feeBreakdown(kind, feeBaseAmount);
        totalFee = feeToSunCurve + feeToProtocol;

        poolManager.take(Currency.wrap(address(usdc)), address(this), totalFee);
        uint256 usdcInjected = _routeUsdcFee(feeToSunCurve, feeToProtocol, minUSDCToSunCurve);

        emit FeeRouted(poolId, kind, feeBaseAmount, feeToSunCurve, feeToProtocol, usdcInjected);
    }

    function _routeUsdcFee(uint256 feeToSunCurve, uint256 feeToProtocol, uint256 minUSDCToSunCurve)
        private
        returns (uint256 usdcInjected)
    {
        usdcInjected = feeToSunCurve;
        if (usdcInjected < minUSDCToSunCurve) {
            revert InsufficientUSDCToSunCurve(usdcInjected, minUSDCToSunCurve);
        }

        usdc.forceApprove(address(sunCurve), usdcInjected);
        sunCurve.injectUSDT(usdcInjected);
        usdc.safeTransfer(protocolBudget, feeToProtocol);
    }

    function _validateFeePool(bytes32 poolId, PoolKind kind) private view {
        if (paused) revert HookPaused();
        if (protocolBudget == address(0)) revert InvalidAddress();

        bool allowed =
            kind == PoolKind.SunUsdc ? allowedSunUsdcPools[poolId] : allowedMoonUsdcPools[poolId];
        if (!allowed) revert FeePoolNotAllowed(poolId, kind);
    }

    function _feeBreakdown(PoolKind kind, uint256 feeBaseAmount)
        private
        pure
        returns (uint256 feeToSunCurve, uint256 feeToProtocol)
    {
        if (kind == PoolKind.SunUsdc) {
            feeToSunCurve = Math.mulDiv(feeBaseAmount, SUN_FEE_TO_CURVE_BPS, BPS);
            feeToProtocol = Math.mulDiv(feeBaseAmount, SUN_FEE_TO_PROTOCOL_BPS, BPS);
        } else if (kind == PoolKind.MoonUsdc) {
            feeToSunCurve = Math.mulDiv(feeBaseAmount, MOON_FEE_TO_CURVE_BPS, BPS);
            feeToProtocol = Math.mulDiv(feeBaseAmount, MOON_FEE_TO_PROTOCOL_BPS, BPS);
        } else {
            revert InvalidAmount();
        }

        if (feeToSunCurve == 0 || feeToProtocol == 0) revert InvalidAmount();
    }

    function _poolKind(PoolKey calldata key) private view returns (PoolKind) {
        address token0 = Currency.unwrap(key.currency0);
        address token1 = Currency.unwrap(key.currency1);
        bool token0IsUsdc = token0 == address(usdc);
        bool token1IsUsdc = token1 == address(usdc);
        if (token0IsUsdc == token1IsUsdc) return PoolKind.Unsupported;

        address otherToken = token0IsUsdc ? token1 : token0;
        if (otherToken == sunToken) return PoolKind.SunUsdc;
        if (otherToken == moonToken) return PoolKind.MoonUsdc;

        return PoolKind.Unsupported;
    }

    function _isUsdcSpecified(PoolKey calldata key, SwapParams calldata params)
        private
        view
        returns (bool)
    {
        bool exactInput = params.amountSpecified < 0;
        address specifiedToken =
            Currency.unwrap(params.zeroForOne == exactInput ? key.currency0 : key.currency1);

        return specifiedToken == address(usdc);
    }

    function _usdcSwapDeltaAmount(
        PoolKey calldata key,
        SwapParams calldata params,
        BalanceDelta swapDelta
    ) private view returns (uint256) {
        bool usdcIsToken0 =
            Currency.unwrap(key.currency0) == address(usdc);
        bool usdcIsInput = params.zeroForOne == usdcIsToken0;
        int128 signedAmount = usdcIsToken0 ? swapDelta.amount0() : swapDelta.amount1();

        if (usdcIsInput) {
            if (signedAmount >= 0) revert InvalidAmount();
            return uint256(-int256(signedAmount));
        }

        if (signedAmount <= 0) revert InvalidAmount();
        return uint256(int256(signedAmount));
    }

    function _absoluteAmountSpecified(int256 amountSpecified) private pure returns (uint256) {
        if (amountSpecified == 0 || amountSpecified == type(int256).min) revert InvalidAmount();

        return amountSpecified < 0 ? uint256(-amountSpecified) : uint256(amountSpecified);
    }

    function _minUSDCToSunCurve(bytes calldata hookData)
        private
        pure
        returns (uint256 minUSDCToSunCurve)
    {
        if (hookData.length == 0) revert InvalidHookData();

        UsdcFeeHookData memory feeData = abi.decode(hookData, (UsdcFeeHookData));
        minUSDCToSunCurve = feeData.minUSDCToSunCurve;
        if (minUSDCToSunCurve == 0) revert InvalidMinUSDCToSunCurve();
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
