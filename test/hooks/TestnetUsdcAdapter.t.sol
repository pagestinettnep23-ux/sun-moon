// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Test } from "forge-std/Test.sol";
import { TestnetUsdcAdapter } from "../../contracts/hooks/TestnetUsdcAdapter.sol";
import { MockUSDT } from "../../contracts/mocks/MockUSDT.sol";
import { MockUsdcSwapRouter } from "../../contracts/mocks/MockUsdcSwapRouter.sol";

contract TestnetUsdcAdapterTest is Test {
    uint256 internal constant TOKEN_ONE = 1e18;
    uint256 internal constant USDC_ONE = 1e6;

    address internal owner = makeAddr("owner");
    address internal hook = makeAddr("hook");
    address internal newHook = makeAddr("newHook");
    address internal alice = makeAddr("alice");

    MockUSDT internal usdc;
    MockUSDT internal feeAsset;
    MockUSDT internal otherFeeAsset;
    MockUsdcSwapRouter internal router;
    MockUsdcSwapRouter internal secondRouter;
    TestnetUsdcAdapter internal adapter;

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

    function setUp() public {
        usdc = new MockUSDT("Mock USDC", "USDC", 6);
        feeAsset = new MockUSDT("Mock Fee Asset", "MFEE", 18);
        otherFeeAsset = new MockUSDT("Other Fee Asset", "OFEE", 18);
        router = new MockUsdcSwapRouter();
        secondRouter = new MockUsdcSwapRouter();
        adapter = new TestnetUsdcAdapter(usdc, hook, owner);

        vm.startPrank(owner);
        adapter.setRouterAllowed(address(router), true);
        adapter.setTokenRoute(address(feeAsset), address(router));
        vm.stopPrank();

        feeAsset.mint(hook, 10_000 * TOKEN_ONE);
        otherFeeAsset.mint(hook, 10_000 * TOKEN_ONE);
        usdc.mint(hook, 100 * USDC_ONE);

        vm.startPrank(hook);
        feeAsset.approve(address(adapter), type(uint256).max);
        otherFeeAsset.approve(address(adapter), type(uint256).max);
        vm.stopPrank();
    }

    function testAuthorizedHookSwapsAllowedFeeAssetToUsdcViaMockRouter() public {
        uint256 amountIn = 30 * TOKEN_ONE;
        uint256 usdcOut = 45 * USDC_ONE;
        router.setUSDCOut(usdcOut);

        vm.prank(hook);
        vm.expectEmit(true, true, true, true, address(adapter));
        emit FeeAssetSwappedToUSDC(
            hook, address(feeAsset), address(router), amountIn, 40 * USDC_ONE, usdcOut, usdcOut
        );
        uint256 actualUsdcOut =
            adapter.swapFeeAssetToUSDT(address(feeAsset), amountIn, 40 * USDC_ONE);

        assertEq(actualUsdcOut, usdcOut);
        assertEq(feeAsset.balanceOf(hook), 10_000 * TOKEN_ONE - amountIn);
        assertEq(feeAsset.balanceOf(address(adapter)), 0);
        assertEq(feeAsset.balanceOf(address(router)), amountIn);
        assertEq(usdc.balanceOf(hook), 100 * USDC_ONE + usdcOut);
    }

    function testAdapterUsesActualUsdcBalanceDeltaInsteadOfRouterReturnValue() public {
        uint256 amountIn = 30 * TOKEN_ONE;
        uint256 usdcOut = 45 * USDC_ONE;
        uint256 fakeRouterReturn = 999 * USDC_ONE;
        router.setUSDCOut(usdcOut);
        router.setRouterReportedUSDCOut(fakeRouterReturn);

        vm.prank(hook);
        vm.expectEmit(true, true, true, true, address(adapter));
        emit FeeAssetSwappedToUSDC(
            hook,
            address(feeAsset),
            address(router),
            amountIn,
            40 * USDC_ONE,
            fakeRouterReturn,
            usdcOut
        );
        uint256 actualUsdcOut =
            adapter.swapFeeAssetToUSDT(address(feeAsset), amountIn, 40 * USDC_ONE);

        assertEq(actualUsdcOut, usdcOut);
    }

    function testDirectUsdcPathReturnsAmountWithoutMovingTokens() public {
        uint256 hookUsdcBefore = usdc.balanceOf(hook);

        vm.prank(hook);
        vm.expectEmit(true, false, false, true, address(adapter));
        emit UsdcFeeAssetDirect(hook, 30 * USDC_ONE, 25 * USDC_ONE);
        uint256 actualUsdcOut =
            adapter.swapFeeAssetToUSDT(address(usdc), 30 * USDC_ONE, 25 * USDC_ONE);

        assertEq(actualUsdcOut, 30 * USDC_ONE);
        assertEq(usdc.balanceOf(hook), hookUsdcBefore);
        assertEq(usdc.balanceOf(address(adapter)), 0);
    }

    function testOnlyAuthorizedHookCanSwap() public {
        router.setUSDCOut(45 * USDC_ONE);

        feeAsset.mint(alice, 30 * TOKEN_ONE);
        vm.startPrank(alice);
        feeAsset.approve(address(adapter), 30 * TOKEN_ONE);
        vm.expectRevert(TestnetUsdcAdapter.NotAuthorizedHook.selector);
        adapter.swapFeeAssetToUSDT(address(feeAsset), 30 * TOKEN_ONE, 40 * USDC_ONE);
        vm.stopPrank();
    }

    function testRejectsZeroInputs() public {
        vm.startPrank(hook);

        vm.expectRevert(TestnetUsdcAdapter.InvalidAddress.selector);
        adapter.swapFeeAssetToUSDT(address(0), 30 * TOKEN_ONE, 40 * USDC_ONE);

        vm.expectRevert(TestnetUsdcAdapter.InvalidAmount.selector);
        adapter.swapFeeAssetToUSDT(address(feeAsset), 0, 40 * USDC_ONE);

        vm.expectRevert(TestnetUsdcAdapter.InvalidMinUSDTOut.selector);
        adapter.swapFeeAssetToUSDT(address(feeAsset), 30 * TOKEN_ONE, 0);

        vm.stopPrank();
    }

    function testRejectsUnlistedFeeAsset() public {
        vm.prank(hook);
        vm.expectRevert(
            abi.encodeWithSelector(
                TestnetUsdcAdapter.TokenNotAllowed.selector, address(otherFeeAsset)
            )
        );
        adapter.swapFeeAssetToUSDT(address(otherFeeAsset), 30 * TOKEN_ONE, 40 * USDC_ONE);
    }

    function testRejectsRouteWhenRouterWasDisabled() public {
        vm.prank(owner);
        adapter.setRouterAllowed(address(router), false);

        vm.prank(hook);
        vm.expectRevert(
            abi.encodeWithSelector(TestnetUsdcAdapter.RouterNotAllowed.selector, address(router))
        );
        adapter.swapFeeAssetToUSDT(address(feeAsset), 30 * TOKEN_ONE, 40 * USDC_ONE);
    }

    function testRejectsWhenActualUsdcOutBelowMinUsdtOut() public {
        uint256 usdcOut = 39 * USDC_ONE;
        uint256 minUSDTOut = 40 * USDC_ONE;
        router.setUSDCOut(usdcOut);

        uint256 hookFeeBalanceBefore = feeAsset.balanceOf(hook);
        uint256 hookUsdcBalanceBefore = usdc.balanceOf(hook);

        vm.prank(hook);
        vm.expectRevert(
            abi.encodeWithSelector(
                TestnetUsdcAdapter.InsufficientUSDTOut.selector, usdcOut, minUSDTOut
            )
        );
        adapter.swapFeeAssetToUSDT(address(feeAsset), 30 * TOKEN_ONE, minUSDTOut);

        assertEq(feeAsset.balanceOf(hook), hookFeeBalanceBefore);
        assertEq(feeAsset.balanceOf(address(router)), 0);
        assertEq(usdc.balanceOf(hook), hookUsdcBalanceBefore);
    }

    function testRejectsDirectUsdcBelowMinUsdtOut() public {
        vm.prank(hook);
        vm.expectRevert(
            abi.encodeWithSelector(
                TestnetUsdcAdapter.InsufficientUSDTOut.selector, 30 * USDC_ONE, 40 * USDC_ONE
            )
        );
        adapter.swapFeeAssetToUSDT(address(usdc), 30 * USDC_ONE, 40 * USDC_ONE);
    }

    function testRouterFailureRollsBackWithoutMovingAssets() public {
        router.setUSDCOut(45 * USDC_ONE);
        router.setShouldFail(true);

        uint256 hookFeeBalanceBefore = feeAsset.balanceOf(hook);
        uint256 hookUsdcBalanceBefore = usdc.balanceOf(hook);

        vm.prank(hook);
        vm.expectRevert(MockUsdcSwapRouter.MockRouterFailed.selector);
        adapter.swapFeeAssetToUSDT(address(feeAsset), 30 * TOKEN_ONE, 40 * USDC_ONE);

        assertEq(feeAsset.balanceOf(hook), hookFeeBalanceBefore);
        assertEq(feeAsset.balanceOf(address(adapter)), 0);
        assertEq(feeAsset.balanceOf(address(router)), 0);
        assertEq(usdc.balanceOf(hook), hookUsdcBalanceBefore);
    }

    function testRouterMustSendUsdcToAuthorizedHook() public {
        router.setUSDCOut(45 * USDC_ONE);
        router.setSendToWrongRecipient(true);

        vm.prank(hook);
        vm.expectRevert(
            abi.encodeWithSelector(
                TestnetUsdcAdapter.InsufficientUSDTOut.selector, 0, 40 * USDC_ONE
            )
        );
        adapter.swapFeeAssetToUSDT(address(feeAsset), 30 * TOKEN_ONE, 40 * USDC_ONE);
    }

    function testPausedAdapterBlocksSwap() public {
        router.setUSDCOut(45 * USDC_ONE);

        vm.prank(owner);
        adapter.setPaused(true);

        vm.prank(hook);
        vm.expectRevert(TestnetUsdcAdapter.AdapterPaused.selector);
        adapter.swapFeeAssetToUSDT(address(feeAsset), 30 * TOKEN_ONE, 40 * USDC_ONE);
    }

    function testOwnerCanChangeConfig() public {
        vm.startPrank(owner);

        vm.expectEmit(true, false, false, true, address(adapter));
        emit AuthorizedHookSet(newHook);
        adapter.setAuthorizedHook(newHook);

        vm.expectEmit(false, false, false, true, address(adapter));
        emit PausedSet(true);
        adapter.setPaused(true);

        vm.expectEmit(true, false, false, true, address(adapter));
        emit RouterAllowedSet(address(secondRouter), true);
        adapter.setRouterAllowed(address(secondRouter), true);

        vm.expectEmit(true, true, false, true, address(adapter));
        emit TokenRouteSet(address(otherFeeAsset), address(secondRouter));
        adapter.setTokenRoute(address(otherFeeAsset), address(secondRouter));

        vm.expectEmit(true, true, false, true, address(adapter));
        emit TokenRouteSet(address(otherFeeAsset), address(0));
        adapter.setTokenRoute(address(otherFeeAsset), address(0));

        vm.stopPrank();

        assertEq(adapter.authorizedHook(), newHook);
        assertTrue(adapter.paused());
        assertTrue(adapter.allowedRouters(address(secondRouter)));
        assertEq(adapter.tokenRouter(address(otherFeeAsset)), address(0));
    }

    function testNonOwnerCannotChangeConfig() public {
        vm.startPrank(alice);

        vm.expectRevert();
        adapter.setAuthorizedHook(alice);

        vm.expectRevert();
        adapter.setPaused(true);

        vm.expectRevert();
        adapter.setRouterAllowed(address(secondRouter), true);

        vm.expectRevert();
        adapter.setTokenRoute(address(otherFeeAsset), address(router));

        vm.stopPrank();
    }

    function testRejectsInvalidConfig() public {
        vm.expectRevert(TestnetUsdcAdapter.InvalidAddress.selector);
        new TestnetUsdcAdapter(IERC20(address(0)), hook, owner);

        vm.expectRevert(TestnetUsdcAdapter.InvalidAddress.selector);
        new TestnetUsdcAdapter(usdc, address(0), owner);

        vm.startPrank(owner);

        vm.expectRevert(TestnetUsdcAdapter.InvalidAddress.selector);
        adapter.setAuthorizedHook(address(0));

        vm.expectRevert(TestnetUsdcAdapter.InvalidAddress.selector);
        adapter.setRouterAllowed(address(0), true);

        vm.expectRevert(TestnetUsdcAdapter.InvalidAddress.selector);
        adapter.setTokenRoute(address(0), address(router));

        vm.expectRevert(
            abi.encodeWithSelector(
                TestnetUsdcAdapter.RouterNotAllowed.selector, address(secondRouter)
            )
        );
        adapter.setTokenRoute(address(otherFeeAsset), address(secondRouter));

        vm.stopPrank();
    }
}
