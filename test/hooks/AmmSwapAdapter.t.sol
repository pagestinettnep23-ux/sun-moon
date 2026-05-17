// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { Test } from "forge-std/Test.sol";
import { AmmSwapAdapter } from "../../contracts/hooks/AmmSwapAdapter.sol";
import { MockUSDT } from "../../contracts/mocks/MockUSDT.sol";

contract AmmSwapAdapterTest is Test {
    uint256 internal constant TOKEN_ONE = 1e18;
    uint256 internal constant USDT_ONE = 1e6;

    address internal owner = makeAddr("owner");
    address internal hook = makeAddr("hook");
    address internal newHook = makeAddr("newHook");
    address internal alice = makeAddr("alice");

    MockUSDT internal usdt;
    MockUSDT internal feeAsset;
    AmmSwapAdapter internal adapter;

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

    function setUp() public {
        usdt = new MockUSDT("Mock USDT", "USDT", 6);
        feeAsset = new MockUSDT("Mock Fee Asset", "MFEE", 18);
        adapter = new AmmSwapAdapter(usdt, hook, owner);

        feeAsset.mint(hook, 10_000 * TOKEN_ONE);
        vm.prank(hook);
        feeAsset.approve(address(adapter), type(uint256).max);
    }

    function testAuthorizedHookCanSwapFeeAssetToMockUsdt() public {
        uint256 amountIn = 30 * TOKEN_ONE;
        uint256 usdtOut = 45 * USDT_ONE;

        vm.prank(owner);
        adapter.setMockUSDTOut(usdtOut);

        vm.prank(hook);
        vm.expectEmit(true, true, false, true, address(adapter));
        emit MockSwapExecuted(hook, address(feeAsset), amountIn, 40 * USDT_ONE, usdtOut);
        uint256 actualUsdtOut =
            adapter.swapFeeAssetToUSDT(address(feeAsset), amountIn, 40 * USDT_ONE);

        assertEq(actualUsdtOut, usdtOut);
        assertEq(feeAsset.balanceOf(hook), 10_000 * TOKEN_ONE - amountIn);
        assertEq(feeAsset.balanceOf(address(adapter)), amountIn);
        assertEq(usdt.balanceOf(hook), usdtOut);
    }

    function testOnlyAuthorizedHookCanSwap() public {
        vm.prank(owner);
        adapter.setMockUSDTOut(45 * USDT_ONE);

        feeAsset.mint(alice, 30 * TOKEN_ONE);
        vm.startPrank(alice);
        feeAsset.approve(address(adapter), 30 * TOKEN_ONE);
        vm.expectRevert(AmmSwapAdapter.NotAuthorizedHook.selector);
        adapter.swapFeeAssetToUSDT(address(feeAsset), 30 * TOKEN_ONE, 40 * USDT_ONE);
        vm.stopPrank();
    }

    function testRejectsZeroTokenIn() public {
        vm.prank(hook);
        vm.expectRevert(AmmSwapAdapter.InvalidAddress.selector);
        adapter.swapFeeAssetToUSDT(address(0), 30 * TOKEN_ONE, 40 * USDT_ONE);
    }

    function testRejectsZeroAmountIn() public {
        vm.prank(hook);
        vm.expectRevert(AmmSwapAdapter.InvalidAmount.selector);
        adapter.swapFeeAssetToUSDT(address(feeAsset), 0, 40 * USDT_ONE);
    }

    function testRejectsZeroMinUsdtOut() public {
        vm.prank(hook);
        vm.expectRevert(AmmSwapAdapter.InvalidMinUSDTOut.selector);
        adapter.swapFeeAssetToUSDT(address(feeAsset), 30 * TOKEN_ONE, 0);
    }

    function testRejectsWhenMockUsdtOutBelowMinUsdtOut() public {
        uint256 usdtOut = 39 * USDT_ONE;
        uint256 minUSDTOut = 40 * USDT_ONE;

        vm.prank(owner);
        adapter.setMockUSDTOut(usdtOut);

        vm.prank(hook);
        vm.expectRevert(
            abi.encodeWithSelector(AmmSwapAdapter.InsufficientUSDTOut.selector, usdtOut, minUSDTOut)
        );
        adapter.swapFeeAssetToUSDT(address(feeAsset), 30 * TOKEN_ONE, minUSDTOut);

        assertEq(feeAsset.balanceOf(address(adapter)), 0);
        assertEq(usdt.balanceOf(hook), 0);
    }

    function testPausedAdapterBlocksSwap() public {
        vm.startPrank(owner);
        adapter.setMockUSDTOut(45 * USDT_ONE);
        adapter.setPaused(true);
        vm.stopPrank();

        vm.prank(hook);
        vm.expectRevert(AmmSwapAdapter.AdapterPaused.selector);
        adapter.swapFeeAssetToUSDT(address(feeAsset), 30 * TOKEN_ONE, 40 * USDT_ONE);
    }

    function testConfiguredMockFailureRevertsBeforeMovingTokens() public {
        uint256 hookFeeBalanceBefore = feeAsset.balanceOf(hook);

        vm.startPrank(owner);
        adapter.setMockUSDTOut(45 * USDT_ONE);
        adapter.setMockSwapShouldFail(true);
        vm.stopPrank();

        vm.prank(hook);
        vm.expectRevert(AmmSwapAdapter.MockSwapFailed.selector);
        adapter.swapFeeAssetToUSDT(address(feeAsset), 30 * TOKEN_ONE, 40 * USDT_ONE);

        assertEq(feeAsset.balanceOf(hook), hookFeeBalanceBefore);
        assertEq(feeAsset.balanceOf(address(adapter)), 0);
        assertEq(usdt.balanceOf(hook), 0);
    }

    function testSwapRequiresTokenAllowanceFromHook() public {
        vm.prank(owner);
        adapter.setMockUSDTOut(45 * USDT_ONE);

        vm.prank(hook);
        feeAsset.approve(address(adapter), 0);

        vm.prank(hook);
        vm.expectRevert();
        adapter.swapFeeAssetToUSDT(address(feeAsset), 30 * TOKEN_ONE, 40 * USDT_ONE);
    }

    function testOwnerCanChangeConfig() public {
        vm.startPrank(owner);

        vm.expectEmit(true, false, false, true, address(adapter));
        emit AuthorizedHookSet(newHook);
        adapter.setAuthorizedHook(newHook);

        vm.expectEmit(false, false, false, true, address(adapter));
        emit MockUSDTOutSet(55 * USDT_ONE);
        adapter.setMockUSDTOut(55 * USDT_ONE);

        vm.expectEmit(false, false, false, true, address(adapter));
        emit MockSwapShouldFailSet(true);
        adapter.setMockSwapShouldFail(true);

        vm.expectEmit(false, false, false, true, address(adapter));
        emit PausedSet(true);
        adapter.setPaused(true);

        vm.stopPrank();

        assertEq(adapter.authorizedHook(), newHook);
        assertEq(adapter.mockUSDTOut(), 55 * USDT_ONE);
        assertTrue(adapter.mockSwapShouldFail());
        assertTrue(adapter.paused());
    }

    function testNonOwnerCannotChangeConfig() public {
        vm.startPrank(alice);

        vm.expectRevert();
        adapter.setAuthorizedHook(alice);

        vm.expectRevert();
        adapter.setMockUSDTOut(1);

        vm.expectRevert();
        adapter.setMockSwapShouldFail(true);

        vm.expectRevert();
        adapter.setPaused(true);

        vm.stopPrank();
    }

    function testRejectsInvalidConfig() public {
        vm.expectRevert(AmmSwapAdapter.InvalidAddress.selector);
        new AmmSwapAdapter(MockUSDT(address(0)), hook, owner);

        vm.expectRevert(AmmSwapAdapter.InvalidAddress.selector);
        new AmmSwapAdapter(usdt, address(0), owner);

        vm.prank(owner);
        vm.expectRevert(AmmSwapAdapter.InvalidAddress.selector);
        adapter.setAuthorizedHook(address(0));
    }
}
