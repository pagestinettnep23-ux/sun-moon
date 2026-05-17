// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { MockUSDT } from "./MockUSDT.sol";

contract MockUsdcSwapRouter {
    using SafeERC20 for IERC20;

    error MockRouterFailed();

    uint256 public usdcOut;
    uint256 public routerReportedUSDCOut;
    bool public shouldFail;
    bool public sendToWrongRecipient;

    function setUSDCOut(uint256 newUSDCOut) external {
        usdcOut = newUSDCOut;
    }

    function setRouterReportedUSDCOut(uint256 newRouterReportedUSDCOut) external {
        routerReportedUSDCOut = newRouterReportedUSDCOut;
    }

    function setShouldFail(bool newShouldFail) external {
        shouldFail = newShouldFail;
    }

    function setSendToWrongRecipient(bool newSendToWrongRecipient) external {
        sendToWrongRecipient = newSendToWrongRecipient;
    }

    function swapExactInputToUSDC(
        address tokenIn,
        address usdc,
        uint256 amountIn,
        uint256,
        address recipient
    ) external returns (uint256 reportedUSDCOut) {
        if (shouldFail) revert MockRouterFailed();

        IERC20(tokenIn).safeTransferFrom(msg.sender, address(this), amountIn);

        address usdcRecipient = sendToWrongRecipient ? address(this) : recipient;
        MockUSDT(usdc).mint(usdcRecipient, usdcOut);

        reportedUSDCOut = routerReportedUSDCOut == 0 ? usdcOut : routerReportedUSDCOut;
    }
}
