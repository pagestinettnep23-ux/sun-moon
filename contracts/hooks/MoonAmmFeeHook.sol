// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { SunCurve } from "../SunCurve.sol";

interface IMoonAmmSwapAdapter {
    function swapFeeAssetToUSDT(address tokenIn, uint256 amountIn, uint256 minUSDTOut)
        external
        returns (uint256 usdtOut);
}

contract MoonAmmFeeHook is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    uint256 public constant BPS = 10_000;
    uint256 public constant FEE_TO_SUN_CURVE_BPS = 300;
    uint256 public constant FEE_TO_PROTOCOL_BPS = 200;

    error InvalidAddress();
    error InvalidPoolId();
    error InvalidAmount();
    error InvalidMinUSDTOut();
    error NotHookCaller();
    error HookPaused();
    error MoonPoolNotAllowed(bytes32 poolId);
    error InsufficientUSDTOut(uint256 usdtOut, uint256 minUSDTOut);

    address public immutable moonToken;
    IERC20 public immutable usdt;
    SunCurve public immutable sunCurve;

    address public hookCaller;
    address public protocolBudget;
    IMoonAmmSwapAdapter public swapAdapter;
    bool public paused;

    mapping(bytes32 poolId => bool allowed) public allowedMoonPools;

    event HookCallerSet(address indexed hookCaller);
    event ProtocolBudgetSet(address indexed protocolBudget);
    event SwapAdapterSet(address indexed swapAdapter);
    event MoonPoolAllowedSet(bytes32 indexed poolId, bool allowed);
    event PausedSet(bool paused);
    event MoonAmmFeeRouted(
        bytes32 indexed poolId,
        address indexed trader,
        address indexed feeToken,
        uint256 feeBaseAmount,
        uint256 feeToSunCurve,
        uint256 feeToProtocol,
        uint256 usdtInjected
    );

    constructor(
        address moonToken_,
        IERC20 usdt_,
        SunCurve sunCurve_,
        address protocolBudget_,
        address hookCaller_,
        address initialOwner
    ) Ownable(initialOwner) {
        if (
            moonToken_ == address(0) || address(usdt_) == address(0)
                || address(sunCurve_) == address(0) || protocolBudget_ == address(0)
                || hookCaller_ == address(0)
        ) {
            revert InvalidAddress();
        }

        moonToken = moonToken_;
        usdt = usdt_;
        sunCurve = sunCurve_;
        protocolBudget = protocolBudget_;
        hookCaller = hookCaller_;

        emit ProtocolBudgetSet(protocolBudget_);
        emit HookCallerSet(hookCaller_);
    }

    function setHookCaller(address newHookCaller) external onlyOwner {
        if (newHookCaller == address(0)) revert InvalidAddress();

        hookCaller = newHookCaller;

        emit HookCallerSet(newHookCaller);
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

    function afterSwap(
        address trader,
        bytes32 poolId,
        address token0,
        address token1,
        address feeToken,
        uint256 feeBaseAmount,
        uint256 minUSDTOut
    ) external onlyHookCaller nonReentrant returns (bytes4) {
        if (paused) revert HookPaused();
        if (!isMoonPair(token0, token1)) return this.afterSwap.selector;
        if (!allowedMoonPools[poolId]) revert MoonPoolNotAllowed(poolId);
        if (trader == address(0) || feeToken == address(0)) revert InvalidAddress();
        if (feeBaseAmount == 0) revert InvalidAmount();
        if (minUSDTOut == 0) revert InvalidMinUSDTOut();

        uint256 feeToSunCurve = Math.mulDiv(feeBaseAmount, FEE_TO_SUN_CURVE_BPS, BPS);
        uint256 feeToProtocol = Math.mulDiv(feeBaseAmount, FEE_TO_PROTOCOL_BPS, BPS);
        if (feeToSunCurve == 0 || feeToProtocol == 0) revert InvalidAmount();

        IERC20 collectedFeeToken = IERC20(feeToken);
        collectedFeeToken.safeTransferFrom(trader, address(this), feeToSunCurve + feeToProtocol);

        uint256 usdtInjected =
            _convertAndInjectSunCurveFee(collectedFeeToken, feeToken, feeToSunCurve, minUSDTOut);
        collectedFeeToken.safeTransfer(protocolBudget, feeToProtocol);

        emit MoonAmmFeeRouted(
            poolId, trader, feeToken, feeBaseAmount, feeToSunCurve, feeToProtocol, usdtInjected
        );

        return this.afterSwap.selector;
    }

    function isMoonPair(address token0, address token1) public view returns (bool) {
        return token0 == moonToken || token1 == moonToken;
    }

    function _convertAndInjectSunCurveFee(
        IERC20 feeToken,
        address feeTokenAddress,
        uint256 feeToSunCurve,
        uint256 minUSDTOut
    ) private returns (uint256 usdtOut) {
        if (feeTokenAddress == address(usdt)) {
            usdtOut = feeToSunCurve;
        } else {
            IMoonAmmSwapAdapter adapter = swapAdapter;
            if (address(adapter) == address(0)) revert InvalidAddress();

            feeToken.forceApprove(address(adapter), feeToSunCurve);
            usdtOut = adapter.swapFeeAssetToUSDT(feeTokenAddress, feeToSunCurve, minUSDTOut);
        }

        if (usdtOut < minUSDTOut) revert InsufficientUSDTOut(usdtOut, minUSDTOut);

        usdt.forceApprove(address(sunCurve), usdtOut);
        sunCurve.injectUSDT(usdtOut);
    }

    modifier onlyHookCaller() {
        if (msg.sender != hookCaller) revert NotHookCaller();
        _;
    }
}
