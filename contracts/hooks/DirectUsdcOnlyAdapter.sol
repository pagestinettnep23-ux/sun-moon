// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { IMoonAmmSwapAdapter } from "./MoonAmmFeeHook.sol";

contract DirectUsdcOnlyAdapter is Ownable, ReentrancyGuard, IMoonAmmSwapAdapter {
    error AdapterPaused();
    error InsufficientUSDTOut(uint256 usdtOut, uint256 minUSDTOut);
    error InvalidAddress();
    error InvalidAmount();
    error InvalidMinUSDTOut();
    error NotAuthorizedHook();
    error TokenNotAllowed(address tokenIn);

    IERC20 public immutable usdc;

    address public authorizedHook;
    bool public paused;

    event AuthorizedHookSet(address indexed authorizedHook);
    event PausedSet(bool paused);
    event UsdcFeeAssetDirect(address indexed hook, uint256 amountIn, uint256 minUSDTOut);

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
        if (tokenIn != address(usdc)) revert TokenNotAllowed(tokenIn);

        usdtOut = amountIn;
        if (usdtOut < minUSDTOut) revert InsufficientUSDTOut(usdtOut, minUSDTOut);

        emit UsdcFeeAssetDirect(msg.sender, amountIn, minUSDTOut);
    }

    modifier onlyAuthorizedHook() {
        if (msg.sender != authorizedHook) revert NotAuthorizedHook();
        _;
    }
}
