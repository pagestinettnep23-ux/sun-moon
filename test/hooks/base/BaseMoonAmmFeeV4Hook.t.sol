// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Deployers } from "@uniswap/v4-core/test/utils/Deployers.sol";
import { MockERC20 } from "solmate/src/test/utils/mocks/MockERC20.sol";
import { IHooks } from "@uniswap/v4-core/src/interfaces/IHooks.sol";
import { IPoolManager } from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import { Hooks } from "@uniswap/v4-core/src/libraries/Hooks.sol";
import { PoolSwapTest } from "@uniswap/v4-core/src/test/PoolSwapTest.sol";
import { BalanceDelta } from "@uniswap/v4-core/src/types/BalanceDelta.sol";
import { Currency } from "@uniswap/v4-core/src/types/Currency.sol";
import { PoolId, PoolIdLibrary } from "@uniswap/v4-core/src/types/PoolId.sol";
import { PoolKey } from "@uniswap/v4-core/src/types/PoolKey.sol";
import { SwapParams } from "@uniswap/v4-core/src/types/PoolOperation.sol";
import { AmmSwapAdapter } from "../../../contracts/hooks/AmmSwapAdapter.sol";
import { TestnetUsdcAdapter } from "../../../contracts/hooks/TestnetUsdcAdapter.sol";
import { BaseMoonAmmFeePolicy } from "../../../contracts/hooks/base/BaseMoonAmmFeePolicy.sol";
import { BaseMoonAmmFeeV4Hook } from "../../../contracts/hooks/base/BaseMoonAmmFeeV4Hook.sol";
import { MockUSDT } from "../../../contracts/mocks/MockUSDT.sol";
import { MockUsdcSwapRouter } from "../../../contracts/mocks/MockUsdcSwapRouter.sol";
import { SunCurve } from "../../../contracts/SunCurve.sol";
import { SunToken } from "../../../contracts/SunToken.sol";

contract BaseMoonAmmFeeV4HookTest is Deployers {
    using PoolIdLibrary for PoolKey;

    uint256 internal constant SWAP_AMOUNT = 10_000;
    uint256 internal constant EXPECTED_FEE_TO_SUN_CURVE = 300;
    uint256 internal constant EXPECTED_FEE_TO_PROTOCOL = 200;
    uint256 internal constant MOCK_USDT_OUT = 450;
    uint256 internal constant MIN_USDT_OUT = 400;

    address internal owner = makeAddr("owner");
    address internal protocolBudget = makeAddr("protocolBudget");
    address internal newProtocolBudget = makeAddr("newProtocolBudget");

    MockUSDT internal usdt;
    SunToken internal sun;
    SunCurve internal sunCurve;
    AmmSwapAdapter internal adapter;
    BaseMoonAmmFeeV4Hook internal hook;
    MockERC20 internal feeAsset;
    MockERC20 internal moon;

    PoolKey internal feeAssetMoonKey;
    PoolKey internal usdtMoonKey;

    event MoonAmmFeeRouted(
        bytes32 indexed poolId,
        address indexed feeToken,
        uint256 feeBaseAmount,
        uint256 feeToSunCurve,
        uint256 feeToProtocol,
        uint256 usdtInjected,
        BaseMoonAmmFeePolicy.CollectionStage collectionStage,
        BaseMoonAmmFeePolicy.SettlementMethod settlementMethod
    );
    event MoonPoolAllowedSet(bytes32 indexed poolId, bool allowed);
    event PausedSet(bool paused);
    event ProtocolBudgetSet(address indexed protocolBudget);
    event SwapAdapterSet(address indexed swapAdapter);

    function setUp() public {
        deployFreshManagerAndRouters();
        deployMintAndApprove2Currencies();

        feeAsset = MockERC20(Currency.unwrap(currency0));
        moon = MockERC20(Currency.unwrap(currency1));

        usdt = new MockUSDT("Mock USDC", "USDC", 6);
        usdt.mint(address(this), type(uint128).max);
        usdt.approve(address(swapRouter), type(uint256).max);
        usdt.approve(address(modifyLiquidityRouter), type(uint256).max);

        sun = new SunToken("SUN", "SUN", owner);
        sunCurve = new SunCurve(sun, usdt, protocolBudget, type(uint128).max, owner);

        address hookAddress = address(
            uint160(
                Hooks.BEFORE_SWAP_FLAG | Hooks.AFTER_SWAP_FLAG
                    | Hooks.BEFORE_SWAP_RETURNS_DELTA_FLAG | Hooks.AFTER_SWAP_RETURNS_DELTA_FLAG
            )
        );

        adapter = new AmmSwapAdapter(usdt, hookAddress, owner);
        BaseMoonAmmFeeV4Hook implementation = new BaseMoonAmmFeeV4Hook(
            manager, address(moon), IERC20(address(usdt)), sunCurve, protocolBudget, adapter, owner
        );
        vm.etch(hookAddress, address(implementation).code);
        hook = BaseMoonAmmFeeV4Hook(hookAddress);

        vm.startPrank(owner);
        sun.setMinter(address(sunCurve));
        sunCurve.setMoonAMM(hookAddress);
        hook.setProtocolBudget(protocolBudget);
        hook.setSwapAdapter(address(adapter));
        adapter.setMockUSDTOut(MOCK_USDT_OUT);
        vm.stopPrank();

        (feeAssetMoonKey,) = initPoolAndAddLiquidity(
            currency0, currency1, IHooks(hookAddress), 3000, SQRT_PRICE_1_1
        );

        (Currency stableCurrency0, Currency stableCurrency1) =
            _sortedCurrencies(address(usdt), address(moon));
        (usdtMoonKey,) = initPoolAndAddLiquidity(
            stableCurrency0, stableCurrency1, IHooks(hookAddress), 3000, SQRT_PRICE_1_1
        );

        vm.startPrank(owner);
        hook.setAllowedMoonPool(PoolId.unwrap(feeAssetMoonKey.toId()), true);
        hook.setAllowedMoonPool(PoolId.unwrap(usdtMoonKey.toId()), true);
        vm.stopPrank();
    }

    function testExpectedHookMaskMatchesReturnDeltaSwapPermissions() public view {
        uint160 expectedMask = Hooks.BEFORE_SWAP_FLAG | Hooks.AFTER_SWAP_FLAG
            | Hooks.BEFORE_SWAP_RETURNS_DELTA_FLAG | Hooks.AFTER_SWAP_RETURNS_DELTA_FLAG;

        assertEq(hook.expectedHookMask(), expectedMask);
        assertEq(uint160(address(hook)) & expectedMask, expectedMask);
    }

    function testNonMoonPoolIsUnaffectedWithoutHookData() public {
        PoolKey memory nonMoonKey = PoolKey({
            currency0: Currency.wrap(address(0x4000)),
            currency1: Currency.wrap(address(0x5000)),
            fee: 3000,
            tickSpacing: 60,
            hooks: IHooks(address(hook))
        });

        vm.prank(address(manager));
        (bytes4 beforeSelector,,) =
            hook.beforeSwap(address(this), nonMoonKey, _swapParams(true, -1), bytes(""));

        vm.prank(address(manager));
        (bytes4 afterSelector, int128 hookDelta) = hook.afterSwap(
            address(this), nonMoonKey, _swapParams(true, -1), BalanceDelta.wrap(0), bytes("")
        );

        assertEq(beforeSelector, hook.beforeSwap.selector);
        assertEq(afterSelector, hook.afterSwap.selector);
        assertEq(hookDelta, 0);
        assertEq(sunCurve.curveReserve(), 0);
        assertEq(usdt.balanceOf(protocolBudget), 0);
    }

    function testSpecifiedNonUsdcFeeRoutesThroughAdapterAndOriginalAssetBudget() public {
        vm.expectEmit(true, true, false, true, address(hook));
        emit MoonAmmFeeRouted(
            PoolId.unwrap(feeAssetMoonKey.toId()),
            address(feeAsset),
            SWAP_AMOUNT,
            EXPECTED_FEE_TO_SUN_CURVE,
            EXPECTED_FEE_TO_PROTOCOL,
            MOCK_USDT_OUT,
            BaseMoonAmmFeePolicy.CollectionStage.BeforeSwap,
            BaseMoonAmmFeePolicy.SettlementMethod.BeforeSwapSpecifiedReturnDelta
        );

        _swapExactFeeTokenInput(feeAssetMoonKey, address(feeAsset), SWAP_AMOUNT, MIN_USDT_OUT);

        assertEq(feeAsset.balanceOf(address(adapter)), EXPECTED_FEE_TO_SUN_CURVE);
        assertEq(feeAsset.balanceOf(protocolBudget), EXPECTED_FEE_TO_PROTOCOL);
        assertEq(sunCurve.curveReserve(), MOCK_USDT_OUT);
        assertEq(usdt.balanceOf(address(sunCurve)), MOCK_USDT_OUT);
        assertEq(feeAsset.balanceOf(address(hook)), 0);
        assertEq(usdt.balanceOf(address(hook)), 0);
    }

    function testSpecifiedNonUsdcFeeRoutesThroughTestnetUsdcAdapterAndMockRouter() public {
        MockUsdcSwapRouter testnetRouter = new MockUsdcSwapRouter();
        TestnetUsdcAdapter testnetAdapter = new TestnetUsdcAdapter(usdt, address(hook), owner);
        testnetRouter.setUSDCOut(MOCK_USDT_OUT);

        vm.startPrank(owner);
        testnetAdapter.setRouterAllowed(address(testnetRouter), true);
        testnetAdapter.setTokenRoute(address(feeAsset), address(testnetRouter));
        hook.setSwapAdapter(address(testnetAdapter));
        vm.stopPrank();

        vm.expectEmit(true, true, false, true, address(hook));
        emit MoonAmmFeeRouted(
            PoolId.unwrap(feeAssetMoonKey.toId()),
            address(feeAsset),
            SWAP_AMOUNT,
            EXPECTED_FEE_TO_SUN_CURVE,
            EXPECTED_FEE_TO_PROTOCOL,
            MOCK_USDT_OUT,
            BaseMoonAmmFeePolicy.CollectionStage.BeforeSwap,
            BaseMoonAmmFeePolicy.SettlementMethod.BeforeSwapSpecifiedReturnDelta
        );

        _swapExactFeeTokenInput(feeAssetMoonKey, address(feeAsset), SWAP_AMOUNT, MIN_USDT_OUT);

        assertEq(feeAsset.balanceOf(address(testnetRouter)), EXPECTED_FEE_TO_SUN_CURVE);
        assertEq(feeAsset.balanceOf(address(testnetAdapter)), 0);
        assertEq(feeAsset.balanceOf(protocolBudget), EXPECTED_FEE_TO_PROTOCOL);
        assertEq(sunCurve.curveReserve(), MOCK_USDT_OUT);
        assertEq(usdt.balanceOf(address(sunCurve)), MOCK_USDT_OUT);
        assertEq(usdt.balanceOf(address(hook)), 0);
    }

    function testUnspecifiedNonUsdcFeeRoutesThroughAdapterAndOriginalAssetBudget() public {
        _swapExactMoonInputForFeeTokenOutput(
            feeAssetMoonKey, address(feeAsset), SWAP_AMOUNT, MIN_USDT_OUT
        );

        assertGt(feeAsset.balanceOf(address(adapter)), 0);
        assertGt(feeAsset.balanceOf(protocolBudget), 0);
        assertEq(sunCurve.curveReserve(), MOCK_USDT_OUT);
        assertEq(usdt.balanceOf(address(sunCurve)), MOCK_USDT_OUT);
        assertEq(feeAsset.balanceOf(address(hook)), 0);
        assertEq(usdt.balanceOf(address(hook)), 0);
    }

    function testSpecifiedUsdcFeeInjectsDirectlyAndSendsUsdcBudget() public {
        uint256 adapterUsdtBefore = usdt.balanceOf(address(adapter));
        uint256 budgetUsdtBefore = usdt.balanceOf(protocolBudget);

        vm.expectEmit(true, true, false, true, address(hook));
        emit MoonAmmFeeRouted(
            PoolId.unwrap(usdtMoonKey.toId()),
            address(usdt),
            SWAP_AMOUNT,
            EXPECTED_FEE_TO_SUN_CURVE,
            EXPECTED_FEE_TO_PROTOCOL,
            EXPECTED_FEE_TO_SUN_CURVE,
            BaseMoonAmmFeePolicy.CollectionStage.BeforeSwap,
            BaseMoonAmmFeePolicy.SettlementMethod.BeforeSwapSpecifiedReturnDelta
        );

        _swapExactFeeTokenInput(usdtMoonKey, address(usdt), SWAP_AMOUNT, EXPECTED_FEE_TO_SUN_CURVE);

        assertEq(usdt.balanceOf(address(adapter)), adapterUsdtBefore);
        assertEq(usdt.balanceOf(protocolBudget) - budgetUsdtBefore, EXPECTED_FEE_TO_PROTOCOL);
        assertEq(sunCurve.curveReserve(), EXPECTED_FEE_TO_SUN_CURVE);
        assertEq(usdt.balanceOf(address(hook)), 0);
    }

    function testUnspecifiedUsdcFeeInjectsDirectlyAndSendsUsdcBudget() public {
        uint256 budgetUsdtBefore = usdt.balanceOf(protocolBudget);

        _swapExactMoonInputForFeeTokenOutput(usdtMoonKey, address(usdt), SWAP_AMOUNT, 1);

        assertGt(usdt.balanceOf(protocolBudget) - budgetUsdtBefore, 0);
        assertGt(sunCurve.curveReserve(), 0);
        assertEq(usdt.balanceOf(address(hook)), 0);
        assertEq(usdt.balanceOf(address(adapter)), 0);
    }

    function testUnallowedMoonPoolRevertsBeforeSwap() public {
        PoolKey memory unallowedMoonKey =
            _poolKey(address(moon), address(0x6000), IHooks(address(hook)));
        bytes32 unallowedPoolId = PoolId.unwrap(unallowedMoonKey.toId());

        vm.prank(address(manager));
        vm.expectRevert(
            abi.encodeWithSelector(
                BaseMoonAmmFeeV4Hook.MoonPoolNotAllowed.selector, unallowedPoolId
            )
        );
        hook.beforeSwap(
            address(this),
            unallowedMoonKey,
            _swapParams(Currency.unwrap(unallowedMoonKey.currency0) != address(moon), -1),
            _hookData(1)
        );
    }

    function testMoonPoolRequiresHookDataWhenFeeIsCollected() public {
        vm.expectRevert();
        _swapExactFeeTokenInput(feeAssetMoonKey, address(feeAsset), SWAP_AMOUNT, 0, bytes(""));
    }

    function testMinUsdtOutMustBeNonZero() public {
        vm.expectRevert();
        _swapExactFeeTokenInput(feeAssetMoonKey, address(feeAsset), SWAP_AMOUNT, 0, _hookData(0));
    }

    function testRevertsWhenDirectUsdcFeeIsBelowMinUsdtOut() public {
        vm.expectRevert();
        _swapExactFeeTokenInput(
            usdtMoonKey, address(usdt), SWAP_AMOUNT, EXPECTED_FEE_TO_SUN_CURVE + 1
        );
    }

    function testPauseBlocksMoonFeeRoute() public {
        vm.prank(owner);
        hook.setPaused(true);

        vm.expectRevert();
        _swapExactFeeTokenInput(feeAssetMoonKey, address(feeAsset), SWAP_AMOUNT, MIN_USDT_OUT);
    }

    function testOwnerCanChangeConfig() public {
        bytes32 poolId = keccak256("newPool");

        vm.startPrank(owner);

        vm.expectEmit(true, false, false, true, address(hook));
        emit ProtocolBudgetSet(newProtocolBudget);
        hook.setProtocolBudget(newProtocolBudget);

        vm.expectEmit(true, false, false, true, address(hook));
        emit SwapAdapterSet(address(adapter));
        hook.setSwapAdapter(address(adapter));

        vm.expectEmit(true, false, false, true, address(hook));
        emit MoonPoolAllowedSet(poolId, true);
        hook.setAllowedMoonPool(poolId, true);

        vm.expectEmit(false, false, false, true, address(hook));
        emit PausedSet(true);
        hook.setPaused(true);

        vm.stopPrank();

        assertEq(hook.protocolBudget(), newProtocolBudget);
        assertEq(address(hook.swapAdapter()), address(adapter));
        assertTrue(hook.allowedMoonPools(poolId));
        assertTrue(hook.paused());
    }

    function testNonOwnerCannotChangeConfig() public {
        vm.startPrank(address(0xBEEF));

        vm.expectRevert(BaseMoonAmmFeeV4Hook.NotOwner.selector);
        hook.setProtocolBudget(newProtocolBudget);

        vm.expectRevert(BaseMoonAmmFeeV4Hook.NotOwner.selector);
        hook.setSwapAdapter(address(adapter));

        vm.expectRevert(BaseMoonAmmFeeV4Hook.NotOwner.selector);
        hook.setAllowedMoonPool(keccak256("pool"), true);

        vm.expectRevert(BaseMoonAmmFeeV4Hook.NotOwner.selector);
        hook.setPaused(true);

        vm.stopPrank();
    }

    function testOnlyPoolManagerCanCallV4Hook() public {
        vm.expectRevert(BaseMoonAmmFeeV4Hook.NotPoolManager.selector);
        hook.beforeSwap(address(this), feeAssetMoonKey, _swapParams(true, -1), _hookData(1));

        vm.expectRevert(BaseMoonAmmFeeV4Hook.NotPoolManager.selector);
        hook.afterSwap(
            address(this),
            feeAssetMoonKey,
            _swapParams(true, -1),
            BalanceDelta.wrap(0),
            _hookData(1)
        );
    }

    function testRejectsInvalidConfig() public {
        vm.expectRevert(BaseMoonAmmFeeV4Hook.InvalidAddress.selector);
        new BaseMoonAmmFeeV4Hook(
            IPoolManager(address(0)),
            address(moon),
            IERC20(address(usdt)),
            sunCurve,
            protocolBudget,
            adapter,
            owner
        );

        vm.expectRevert(BaseMoonAmmFeeV4Hook.InvalidAddress.selector);
        new BaseMoonAmmFeeV4Hook(
            manager, address(0), IERC20(address(usdt)), sunCurve, protocolBudget, adapter, owner
        );

        vm.startPrank(owner);

        vm.expectRevert(BaseMoonAmmFeeV4Hook.InvalidAddress.selector);
        hook.setProtocolBudget(address(0));

        vm.expectRevert(BaseMoonAmmFeeV4Hook.InvalidAddress.selector);
        hook.setSwapAdapter(address(0));

        vm.expectRevert(BaseMoonAmmFeeV4Hook.InvalidPoolId.selector);
        hook.setAllowedMoonPool(bytes32(0), true);

        vm.stopPrank();
    }

    function _swapExactFeeTokenInput(
        PoolKey memory poolKey,
        address feeToken,
        uint256 amountIn,
        uint256 minUSDTOut
    ) private returns (BalanceDelta) {
        return _swapExactFeeTokenInput(
            poolKey, feeToken, amountIn, minUSDTOut, _hookData(minUSDTOut)
        );
    }

    function _swapExactFeeTokenInput(
        PoolKey memory poolKey,
        address feeToken,
        uint256 amountIn,
        uint256,
        bytes memory hookData
    ) private returns (BalanceDelta) {
        return _swap(
            poolKey, Currency.unwrap(poolKey.currency0) == feeToken, -int256(amountIn), hookData
        );
    }

    function _swapExactMoonInputForFeeTokenOutput(
        PoolKey memory poolKey,
        address feeToken,
        uint256 moonAmountIn,
        uint256 minUSDTOut
    ) private returns (BalanceDelta) {
        bool moonIsCurrency0 = Currency.unwrap(poolKey.currency0) != feeToken;
        return _swap(poolKey, moonIsCurrency0, -int256(moonAmountIn), _hookData(minUSDTOut));
    }

    function _swap(
        PoolKey memory poolKey,
        bool zeroForOne,
        int256 amountSpecified,
        bytes memory hookData
    ) private returns (BalanceDelta) {
        return swapRouter.swap(
            poolKey,
            _swapParams(zeroForOne, amountSpecified),
            PoolSwapTest.TestSettings({ takeClaims: false, settleUsingBurn: false }),
            hookData
        );
    }

    function _hookData(uint256 minUSDTOut) private pure returns (bytes memory) {
        return abi.encode(BaseMoonAmmFeeV4Hook.MoonFeeHookData({ minUSDTOut: minUSDTOut }));
    }

    function _poolKey(address tokenA, address tokenB, IHooks hooks)
        internal
        pure
        returns (PoolKey memory key)
    {
        (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);

        key = PoolKey({
            currency0: Currency.wrap(token0),
            currency1: Currency.wrap(token1),
            fee: 3000,
            tickSpacing: 60,
            hooks: hooks
        });
    }

    function _swapParams(bool zeroForOne, int256 amountSpecified)
        internal
        pure
        returns (SwapParams memory params)
    {
        params = SwapParams({
            zeroForOne: zeroForOne,
            amountSpecified: amountSpecified,
            sqrtPriceLimitX96: zeroForOne ? MIN_PRICE_LIMIT : MAX_PRICE_LIMIT
        });
    }

    function _sortedCurrencies(address tokenA, address tokenB)
        private
        pure
        returns (Currency currencyA, Currency currencyB)
    {
        (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        return (Currency.wrap(token0), Currency.wrap(token1));
    }
}
