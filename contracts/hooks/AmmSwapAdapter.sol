// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { IMoonAmmSwapAdapter } from "./MoonAmmFeeHook.sol";
import { MockUSDT } from "../mocks/MockUSDT.sol";

contract AmmSwapAdapter is Ownable, ReentrancyGuard, IMoonAmmSwapAdapter {
    using SafeERC20 for IERC20;

    error InvalidAddress();
    error InvalidAmount();
    error InvalidMinUSDTOut();
    error NotAuthorizedHook();
    error AdapterPaused();
    error MockSwapFailed();
    error InsufficientUSDTOut(uint256 usdtOut, uint256 minUSDTOut);

    MockUSDT public immutable usdt;

    address public authorizedHook;
    uint256 public mockUSDTOut;
    bool public paused;
    bool public mockSwapShouldFail;

    event AuthorizedHookSet(address indexed authorizedHook);
    event MockUSDTOutSet(uint256 mockUSDTOut);
    event MockSwapShouldFailSet(bool mockSwapShouldFail);
    event PausedSet(bool paused);
    event MockSwapExecuted(
        address indexed hook,
        address indexed tokenIn,
        uint256 amountIn,
        uint256 minUSDTOut,
        uint256 usdtOut
    );

    constructor(MockUSDT usdt_, address authorizedHook_, address initialOwner)
        Ownable(initialOwner)
    {
        if (address(usdt_) == address(0) || authorizedHook_ == address(0)) {
            revert InvalidAddress();
        }

        usdt = usdt_;
        authorizedHook = authorizedHook_;

        emit AuthorizedHookSet(authorizedHook_);
    }

    function setAuthorizedHook(address newAuthorizedHook) external onlyOwner {
        if (newAuthorizedHook == address(0)) revert InvalidAddress();

        authorizedHook = newAuthorizedHook;

        emit AuthorizedHookSet(newAuthorizedHook);
    }

    function setMockUSDTOut(uint256 newMockUSDTOut) external onlyOwner {
        mockUSDTOut = newMockUSDTOut;

        emit MockUSDTOutSet(newMockUSDTOut);
    }

    function setMockSwapShouldFail(bool newMockSwapShouldFail) external onlyOwner {
        mockSwapShouldFail = newMockSwapShouldFail;

        emit MockSwapShouldFailSet(newMockSwapShouldFail);
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
        if (mockSwapShouldFail) revert MockSwapFailed();

        usdtOut = mockUSDTOut;
        if (usdtOut < minUSDTOut) revert InsufficientUSDTOut(usdtOut, minUSDTOut);

        IERC20(tokenIn).safeTransferFrom(msg.sender, address(this), amountIn);
        usdt.mint(msg.sender, usdtOut);

        emit MockSwapExecuted(msg.sender, tokenIn, amountIn, minUSDTOut, usdtOut);
    }

    modifier onlyAuthorizedHook() {
        if (msg.sender != authorizedHook) revert NotAuthorizedHook();
        _;
    }
}
