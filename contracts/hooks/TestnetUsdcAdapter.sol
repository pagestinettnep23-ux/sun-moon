// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { IMoonAmmSwapAdapter } from "./MoonAmmFeeHook.sol";

interface ITestnetUsdcSwapRouter {
    function swapExactInputToUSDC(
        address tokenIn,
        address usdc,
        uint256 amountIn,
        uint256 minUSDCOut,
        address recipient
    ) external returns (uint256 routerReportedUSDCOut);
}

contract TestnetUsdcAdapter is Ownable, ReentrancyGuard, IMoonAmmSwapAdapter {
    using SafeERC20 for IERC20;

    error AdapterPaused();
    error InsufficientUSDTOut(uint256 usdtOut, uint256 minUSDTOut);
    error InvalidAddress();
    error InvalidAmount();
    error InvalidMinUSDTOut();
    error NotAuthorizedHook();
    error RouterNotAllowed(address router);
    error TokenNotAllowed(address tokenIn);

    IERC20 public immutable usdc;

    address public authorizedHook;
    bool public paused;

    mapping(address router => bool allowed) public allowedRouters;
    mapping(address tokenIn => address router) public tokenRouter;

    event AuthorizedHookSet(address indexed authorizedHook);
    event PausedSet(bool paused);
    event RouterAllowedSet(address indexed router, bool allowed);
    event TokenRouteSet(address indexed tokenIn, address indexed router);
    event UsdcFeeAssetDirect(address indexed hook, uint256 amountIn, uint256 minUSDTOut);
    event FeeAssetSwappedToUSDC(
        address indexed hook,
        address indexed tokenIn,
        address indexed router,
        uint256 amountIn,
        uint256 minUSDTOut,
        uint256 routerReportedUSDCOut,
        uint256 actualUSDCOut
    );

    constructor(IERC20 usdc_, address authorizedHook_, address initialOwner) Ownable(initialOwner) {
        if (address(usdc_) == address(0) || authorizedHook_ == address(0)) {
            revert InvalidAddress();
        }

        usdc = usdc_;
        authorizedHook = authorizedHook_;

        emit AuthorizedHookSet(authorizedHook_);
    }

    function setAuthorizedHook(address newAuthorizedHook) external onlyOwner {
        if (newAuthorizedHook == address(0)) revert InvalidAddress();

        authorizedHook = newAuthorizedHook;

        emit AuthorizedHookSet(newAuthorizedHook);
    }

    function setPaused(bool newPaused) external onlyOwner {
        paused = newPaused;

        emit PausedSet(newPaused);
    }

    function setRouterAllowed(address router, bool allowed) external onlyOwner {
        if (router == address(0)) revert InvalidAddress();

        allowedRouters[router] = allowed;

        emit RouterAllowedSet(router, allowed);
    }

    function setTokenRoute(address tokenIn, address router) external onlyOwner {
        if (tokenIn == address(0)) revert InvalidAddress();

        if (router != address(0) && !allowedRouters[router]) {
            revert RouterNotAllowed(router);
        }

        tokenRouter[tokenIn] = router;

        emit TokenRouteSet(tokenIn, router);
    }

    function swapFeeAssetToUSDT(address tokenIn, uint256 amountIn, uint256 minUSDTOut)
        external
        override
        onlyAuthorizedHook
        nonReentrant
        returns (uint256 usdtOut)
    {
        if (paused) revert AdapterPaused();
        if (tokenIn == address(0)) revert InvalidAddress();
        if (amountIn == 0) revert InvalidAmount();
        if (minUSDTOut == 0) revert InvalidMinUSDTOut();

        if (tokenIn == address(usdc)) {
            usdtOut = amountIn;
            if (usdtOut < minUSDTOut) revert InsufficientUSDTOut(usdtOut, minUSDTOut);

            emit UsdcFeeAssetDirect(msg.sender, amountIn, minUSDTOut);
            return usdtOut;
        }

        address router = tokenRouter[tokenIn];
        if (router == address(0)) revert TokenNotAllowed(tokenIn);
        if (!allowedRouters[router]) revert RouterNotAllowed(router);

        IERC20(tokenIn).safeTransferFrom(msg.sender, address(this), amountIn);
        IERC20(tokenIn).forceApprove(router, amountIn);

        uint256 usdcBalanceBefore = usdc.balanceOf(msg.sender);
        uint256 routerReportedUSDCOut = ITestnetUsdcSwapRouter(router)
            .swapExactInputToUSDC(tokenIn, address(usdc), amountIn, minUSDTOut, msg.sender);
        IERC20(tokenIn).forceApprove(router, 0);

        usdtOut = usdc.balanceOf(msg.sender) - usdcBalanceBefore;
        if (usdtOut < minUSDTOut) revert InsufficientUSDTOut(usdtOut, minUSDTOut);

        emit FeeAssetSwappedToUSDC(
            msg.sender, tokenIn, router, amountIn, minUSDTOut, routerReportedUSDCOut, usdtOut
        );
    }

    modifier onlyAuthorizedHook() {
        if (msg.sender != authorizedHook) revert NotAuthorizedHook();
        _;
    }
}
