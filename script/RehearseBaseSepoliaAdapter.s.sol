// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { Script, console2 } from "forge-std/Script.sol";
import { TestnetUsdcAdapter } from "../contracts/hooks/TestnetUsdcAdapter.sol";
import { MockUSDT } from "../contracts/mocks/MockUSDT.sol";
import { MockUsdcSwapRouter } from "../contracts/mocks/MockUsdcSwapRouter.sol";

contract RehearseBaseSepoliaAdapter is Script {
    uint256 internal constant TOKEN_ONE = 1e18;
    uint256 internal constant USDC_ONE = 1e6;

    function run()
        external
        returns (
            MockUSDT usdc,
            MockUSDT feeAsset,
            MockUsdcSwapRouter router,
            TestnetUsdcAdapter adapter
        )
    {
        address owner = vm.envOr("HOOK_OWNER", msg.sender);
        address simulatedHook =
            vm.envOr("HOOK_ADDRESS", address(0x000000000000000000000000000000000000bEEF));
        uint256 amountIn = vm.envOr("REHEARSAL_AMOUNT_IN", 30 * TOKEN_ONE);
        uint256 minUSDCOut = vm.envOr("REHEARSAL_MIN_USDC_OUT", 40 * USDC_ONE);
        uint256 mockUSDCOut = vm.envOr("REHEARSAL_MOCK_USDC_OUT", 45 * USDC_ONE);
        uint256 directUSDCAmount = vm.envOr("REHEARSAL_DIRECT_USDC_AMOUNT", 30 * USDC_ONE);
        uint256 directMinUSDCOut = vm.envOr("REHEARSAL_DIRECT_MIN_USDC_OUT", 25 * USDC_ONE);

        require(owner != address(0), "owner is zero");
        require(simulatedHook != address(0), "hook is zero");
        require(amountIn != 0, "amountIn is zero");
        require(minUSDCOut != 0, "minUSDCOut is zero");
        require(mockUSDCOut >= minUSDCOut, "mockUSDCOut below min");
        require(directUSDCAmount >= directMinUSDCOut, "direct USDC below min");

        usdc = new MockUSDT("Mock Base Sepolia USDC", "mUSDC", 6);
        feeAsset = new MockUSDT("Mock Base Sepolia Fee Asset", "mFEE", 18);
        router = new MockUsdcSwapRouter();
        adapter = new TestnetUsdcAdapter(usdc, simulatedHook, owner);

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

        require(actualUSDCOut == mockUSDCOut, "unexpected USDC out");
        require(usdc.balanceOf(simulatedHook) == mockUSDCOut, "hook USDC balance mismatch");
        require(feeAsset.balanceOf(address(router)) == amountIn, "router fee balance mismatch");
        require(feeAsset.balanceOf(address(adapter)) == 0, "adapter retained fee asset");

        usdc.mint(simulatedHook, directUSDCAmount);

        vm.prank(simulatedHook);
        uint256 directUSDCOut =
            adapter.swapFeeAssetToUSDT(address(usdc), directUSDCAmount, directMinUSDCOut);
        require(directUSDCOut == directUSDCAmount, "direct USDC mismatch");

        console2.log("Base Sepolia adapter local rehearsal passed");
        console2.log("owner:", owner);
        console2.log("simulatedHook:", simulatedHook);
        console2.log("mockUSDC:", address(usdc));
        console2.log("mockFeeAsset:", address(feeAsset));
        console2.log("mockRouter:", address(router));
        console2.log("testnetAdapter:", address(adapter));
        console2.log("amountIn:", amountIn);
        console2.log("minUSDCOut:", minUSDCOut);
        console2.log("actualUSDCOut:", actualUSDCOut);
        console2.log("directUSDCOut:", directUSDCOut);
    }
}
