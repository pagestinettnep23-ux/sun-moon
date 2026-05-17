// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { Test } from "forge-std/Test.sol";
import { TestnetUsdcAdapter } from "../../../contracts/hooks/TestnetUsdcAdapter.sol";
import { MockUSDT } from "../../../contracts/mocks/MockUSDT.sol";
import { MockUsdcSwapRouter } from "../../../contracts/mocks/MockUsdcSwapRouter.sol";

contract BaseSepoliaAdapterRehearsalTest is Test {
    uint256 internal constant TOKEN_ONE = 1e18;
    uint256 internal constant USDC_ONE = 1e6;

    address internal owner = makeAddr("owner");
    address internal simulatedHook = makeAddr("simulatedHook");

    function testLocalBaseSepoliaAdapterRehearsalUsesTestTokensAndControlledRouter() public {
        MockUSDT usdc = new MockUSDT("Mock Base Sepolia USDC", "mUSDC", 6);
        MockUSDT feeAsset = new MockUSDT("Mock Base Sepolia Fee Asset", "mFEE", 18);
        MockUsdcSwapRouter router = new MockUsdcSwapRouter();
        TestnetUsdcAdapter adapter = new TestnetUsdcAdapter(usdc, simulatedHook, owner);

        uint256 amountIn = 30 * TOKEN_ONE;
        uint256 minUSDCOut = 40 * USDC_ONE;
        uint256 mockUSDCOut = 45 * USDC_ONE;

        router.setUSDCOut(mockUSDCOut);

        vm.startPrank(owner);
        adapter.setRouterAllowed(address(router), true);
        adapter.setTokenRoute(address(feeAsset), address(router));
        vm.stopPrank();

        feeAsset.mint(simulatedHook, amountIn);

        vm.startPrank(simulatedHook);
        feeAsset.approve(address(adapter), amountIn);
        uint256 actualUSDCOut = adapter.swapFeeAssetToUSDT(address(feeAsset), amountIn, minUSDCOut);
        vm.stopPrank();

        assertEq(actualUSDCOut, mockUSDCOut);
        assertEq(usdc.balanceOf(simulatedHook), mockUSDCOut);
        assertEq(feeAsset.balanceOf(simulatedHook), 0);
        assertEq(feeAsset.balanceOf(address(router)), amountIn);
        assertEq(feeAsset.balanceOf(address(adapter)), 0);
        assertEq(adapter.tokenRouter(address(feeAsset)), address(router));
        assertTrue(adapter.allowedRouters(address(router)));

        uint256 directUSDCAmount = 30 * USDC_ONE;
        usdc.mint(simulatedHook, directUSDCAmount);

        vm.prank(simulatedHook);
        uint256 directUSDCOut =
            adapter.swapFeeAssetToUSDT(address(usdc), directUSDCAmount, 25 * USDC_ONE);

        assertEq(directUSDCOut, directUSDCAmount);
        assertEq(usdc.balanceOf(simulatedHook), mockUSDCOut + directUSDCAmount);
        assertEq(usdc.balanceOf(address(adapter)), 0);
    }
}
