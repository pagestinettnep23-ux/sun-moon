// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Test } from "forge-std/Test.sol";
import { DirectUsdcOnlyAdapter } from "../../contracts/hooks/DirectUsdcOnlyAdapter.sol";
import { MockUSDT } from "../../contracts/mocks/MockUSDT.sol";

contract DirectUsdcOnlyAdapterTest is Test {
    uint256 internal constant USDC_ONE = 1e6;
    uint256 internal constant TOKEN_ONE = 1e18;

    address internal owner = makeAddr("owner");
    address internal hook = makeAddr("hook");
    address internal newHook = makeAddr("newHook");
    address internal alice = makeAddr("alice");

    MockUSDT internal usdc;
    MockUSDT internal feeAsset;
    DirectUsdcOnlyAdapter internal adapter;

    event AuthorizedHookSet(address indexed authorizedHook);
    event PausedSet(bool paused);
    event UsdcFeeAssetDirect(address indexed hook, uint256 amountIn, uint256 minUSDTOut);

    function setUp() public {
        usdc = new MockUSDT("Mock USDC", "USDC", 6);
        feeAsset = new MockUSDT("Mock Fee Asset", "MFEE", 18);
        adapter = new DirectUsdcOnlyAdapter(usdc, hook, owner);

        usdc.mint(hook, 100 * USDC_ONE);
        feeAsset.mint(hook, 100 * TOKEN_ONE);
    }

    function testConstructorSetsConfig() public view {
        assertEq(address(adapter.usdc()), address(usdc));
        assertEq(adapter.authorizedHook(), hook);
        assertEq(adapter.owner(), owner);
        assertFalse(adapter.paused());
    }

    function testAuthorizedHookCanUseDirectUsdcPathWithoutMovingTokens() public {
        uint256 hookUsdcBefore = usdc.balanceOf(hook);
        uint256 adapterUsdcBefore = usdc.balanceOf(address(adapter));

        vm.prank(hook);
        vm.expectEmit(true, false, false, true, address(adapter));
        emit UsdcFeeAssetDirect(hook, 30 * USDC_ONE, 25 * USDC_ONE);
        uint256 usdtOut = adapter.swapFeeAssetToUSDT(address(usdc), 30 * USDC_ONE, 25 * USDC_ONE);

        assertEq(usdtOut, 30 * USDC_ONE);
        assertEq(usdc.balanceOf(hook), hookUsdcBefore);
        assertEq(usdc.balanceOf(address(adapter)), adapterUsdcBefore);
    }

    function testOnlyAuthorizedHookCanCall() public {
        vm.prank(alice);
        vm.expectRevert(DirectUsdcOnlyAdapter.NotAuthorizedHook.selector);
        adapter.swapFeeAssetToUSDT(address(usdc), 30 * USDC_ONE, 25 * USDC_ONE);
    }

    function testPausedAdapterBlocksDirectPath() public {
        vm.prank(owner);
        adapter.setPaused(true);

        vm.prank(hook);
        vm.expectRevert(DirectUsdcOnlyAdapter.AdapterPaused.selector);
        adapter.swapFeeAssetToUSDT(address(usdc), 30 * USDC_ONE, 25 * USDC_ONE);
    }

    function testRejectsZeroInputs() public {
        vm.startPrank(hook);

        vm.expectRevert(DirectUsdcOnlyAdapter.InvalidAddress.selector);
        adapter.swapFeeAssetToUSDT(address(0), 30 * USDC_ONE, 25 * USDC_ONE);

        vm.expectRevert(DirectUsdcOnlyAdapter.InvalidAmount.selector);
        adapter.swapFeeAssetToUSDT(address(usdc), 0, 25 * USDC_ONE);

        vm.expectRevert(DirectUsdcOnlyAdapter.InvalidMinUSDTOut.selector);
        adapter.swapFeeAssetToUSDT(address(usdc), 30 * USDC_ONE, 0);

        vm.stopPrank();
    }

    function testRejectsNonUsdcFeeAsset() public {
        vm.prank(hook);
        vm.expectRevert(
            abi.encodeWithSelector(
                DirectUsdcOnlyAdapter.TokenNotAllowed.selector, address(feeAsset)
            )
        );
        adapter.swapFeeAssetToUSDT(address(feeAsset), 30 * TOKEN_ONE, 25 * USDC_ONE);
    }

    function testRejectsWhenAmountBelowMinUsdtOut() public {
        vm.prank(hook);
        vm.expectRevert(
            abi.encodeWithSelector(
                DirectUsdcOnlyAdapter.InsufficientUSDTOut.selector, 30 * USDC_ONE, 40 * USDC_ONE
            )
        );
        adapter.swapFeeAssetToUSDT(address(usdc), 30 * USDC_ONE, 40 * USDC_ONE);
    }

    function testOwnerCanChangeConfig() public {
        vm.startPrank(owner);

        vm.expectEmit(true, false, false, true, address(adapter));
        emit AuthorizedHookSet(newHook);
        adapter.setAuthorizedHook(newHook);

        vm.expectEmit(false, false, false, true, address(adapter));
        emit PausedSet(true);
        adapter.setPaused(true);

        vm.stopPrank();

        assertEq(adapter.authorizedHook(), newHook);
        assertTrue(adapter.paused());
    }

    function testNonOwnerCannotChangeConfig() public {
        vm.startPrank(alice);

        vm.expectRevert();
        adapter.setAuthorizedHook(alice);

        vm.expectRevert();
        adapter.setPaused(true);

        vm.stopPrank();
    }

    function testRejectsInvalidConfig() public {
        vm.expectRevert(DirectUsdcOnlyAdapter.InvalidAddress.selector);
        new DirectUsdcOnlyAdapter(IERC20(address(0)), hook, owner);

        vm.expectRevert(DirectUsdcOnlyAdapter.InvalidAddress.selector);
        new DirectUsdcOnlyAdapter(usdc, address(0), owner);

        vm.prank(owner);
        vm.expectRevert(DirectUsdcOnlyAdapter.InvalidAddress.selector);
        adapter.setAuthorizedHook(address(0));
    }
}
