// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Deployers } from "@uniswap/v4-core/test/utils/Deployers.sol";
import { MockERC20 } from "solmate/src/test/utils/mocks/MockERC20.sol";
import { IHooks } from "@uniswap/v4-core/src/interfaces/IHooks.sol";
import { Hooks } from "@uniswap/v4-core/src/libraries/Hooks.sol";
import { PoolSwapTest } from "@uniswap/v4-core/src/test/PoolSwapTest.sol";
import { BalanceDelta } from "@uniswap/v4-core/src/types/BalanceDelta.sol";
import { Currency } from "@uniswap/v4-core/src/types/Currency.sol";
import { PoolId, PoolIdLibrary } from "@uniswap/v4-core/src/types/PoolId.sol";
import { PoolKey } from "@uniswap/v4-core/src/types/PoolKey.sol";
import { SwapParams } from "@uniswap/v4-core/src/types/PoolOperation.sol";
import { AmmSwapAdapter } from "../../../contracts/hooks/AmmSwapAdapter.sol";
import { BaseMoonAmmFeeV4Hook } from "../../../contracts/hooks/base/BaseMoonAmmFeeV4Hook.sol";
import { MockUSDT } from "../../../contracts/mocks/MockUSDT.sol";
import { SunCurve } from "../../../contracts/SunCurve.sol";
import { SunToken } from "../../../contracts/SunToken.sol";

contract ReenteringFeeToken is MockERC20 {
    PoolSwapTest public attackSwapRouter;
    PoolKey internal attackKey;
    bytes public attackHookData;
    address public targetHook;
    bool public attackEnabled;
    bool public attackAttempted;
    bool public attackReverted;
    bool public attackSucceeded;
    bool public attackZeroForOne;
    uint160 public attackSqrtPriceLimitX96;

    constructor() MockERC20("Reentering Fee Token", "RFEE", 18) { }

    function configureAttack(
        PoolSwapTest attackSwapRouter_,
        PoolKey memory attackKey_,
        address targetHook_,
        bool attackZeroForOne_,
        uint160 attackSqrtPriceLimitX96_,
        bytes memory attackHookData_
    ) external {
        attackSwapRouter = attackSwapRouter_;
        attackKey = attackKey_;
        targetHook = targetHook_;
        attackZeroForOne = attackZeroForOne_;
        attackSqrtPriceLimitX96 = attackSqrtPriceLimitX96_;
        attackHookData = attackHookData_;
        allowance[address(this)][address(attackSwapRouter_)] = type(uint256).max;
        emit Approval(address(this), address(attackSwapRouter_), type(uint256).max);
    }

    function setAttackEnabled(bool newAttackEnabled) external {
        attackEnabled = newAttackEnabled;
    }

    function transfer(address to, uint256 amount) public override returns (bool) {
        if (attackEnabled && !attackAttempted && to == targetHook) {
            _attemptReentrantSwap();
        }

        return super.transfer(to, amount);
    }

    function _attemptReentrantSwap() private {
        attackAttempted = true;

        try attackSwapRouter.swap(
            attackKey,
            SwapParams({
                zeroForOne: attackZeroForOne,
                amountSpecified: -int256(1000),
                sqrtPriceLimitX96: attackSqrtPriceLimitX96
            }),
            PoolSwapTest.TestSettings({ takeClaims: false, settleUsingBurn: false }),
            attackHookData
        ) returns (
            BalanceDelta
        ) {
            attackSucceeded = true;
        } catch {
            attackReverted = true;
        }
    }
}

contract BaseMoonAmmFeeV4HookSecurityTest is Deployers {
    using PoolIdLibrary for PoolKey;

    uint256 internal constant SWAP_AMOUNT = 10_000;
    uint256 internal constant EXPECTED_FEE_TO_SUN_CURVE = 300;
    uint256 internal constant EXPECTED_FEE_TO_PROTOCOL = 200;
    uint256 internal constant MOCK_USDT_OUT = 450;
    uint256 internal constant MIN_USDT_OUT = 400;

    address internal owner = makeAddr("owner");
    address internal protocolBudget = makeAddr("protocolBudget");

    ReenteringFeeToken internal feeToken;
    MockERC20 internal moon;
    MockUSDT internal usdt;
    SunToken internal sun;
    SunCurve internal sunCurve;
    AmmSwapAdapter internal adapter;
    BaseMoonAmmFeeV4Hook internal hook;
    PoolKey internal feeMoonKey;

    function setUp() public {
        deployFreshManagerAndRouters();

        feeToken = new ReenteringFeeToken();
        moon = new MockERC20("MOON", "MOON", 18);
        feeToken.mint(address(this), type(uint128).max);
        feeToken.mint(address(feeToken), 100_000);
        moon.mint(address(this), type(uint128).max);

        feeToken.approve(address(swapRouter), type(uint256).max);
        feeToken.approve(address(modifyLiquidityRouter), type(uint256).max);
        moon.approve(address(swapRouter), type(uint256).max);
        moon.approve(address(modifyLiquidityRouter), type(uint256).max);

        usdt = new MockUSDT("Mock USDC", "USDC", 6);
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

        (Currency currencyA, Currency currencyB) =
            _sortedCurrencies(address(feeToken), address(moon));
        (feeMoonKey,) = initPoolAndAddLiquidity(
            currencyA, currencyB, IHooks(hookAddress), 3000, SQRT_PRICE_1_1
        );

        vm.prank(owner);
        hook.setAllowedMoonPool(PoolId.unwrap(feeMoonKey.toId()), true);

        bool feeTokenIsCurrency0 = Currency.unwrap(feeMoonKey.currency0) == address(feeToken);
        feeToken.configureAttack(
            swapRouter,
            feeMoonKey,
            hookAddress,
            feeTokenIsCurrency0,
            feeTokenIsCurrency0 ? MIN_PRICE_LIMIT : MAX_PRICE_LIMIT,
            _hookData(MIN_USDT_OUT)
        );
    }

    function testMaliciousFeeTokenCannotReenterMoonV2HookThroughNestedSwap() public {
        feeToken.setAttackEnabled(true);

        _swapExactFeeTokenInput();

        assertTrue(feeToken.attackAttempted());
        assertTrue(feeToken.attackReverted());
        assertFalse(feeToken.attackSucceeded());
        assertEq(feeToken.balanceOf(address(adapter)), EXPECTED_FEE_TO_SUN_CURVE);
        assertEq(feeToken.balanceOf(protocolBudget), EXPECTED_FEE_TO_PROTOCOL);
        assertEq(sunCurve.curveReserve(), MOCK_USDT_OUT);
        assertEq(usdt.balanceOf(address(sunCurve)), MOCK_USDT_OUT);
        assertEq(feeToken.balanceOf(address(hook)), 0);
        assertEq(usdt.balanceOf(address(hook)), 0);
    }

    function _swapExactFeeTokenInput() private returns (BalanceDelta) {
        bool zeroForOne = Currency.unwrap(feeMoonKey.currency0) == address(feeToken);

        return swapRouter.swap(
            feeMoonKey,
            SwapParams({
                zeroForOne: zeroForOne,
                amountSpecified: -int256(SWAP_AMOUNT),
                sqrtPriceLimitX96: zeroForOne ? MIN_PRICE_LIMIT : MAX_PRICE_LIMIT
            }),
            PoolSwapTest.TestSettings({ takeClaims: false, settleUsingBurn: false }),
            _hookData(MIN_USDT_OUT)
        );
    }

    function _hookData(uint256 minUSDTOut) private pure returns (bytes memory) {
        return abi.encode(BaseMoonAmmFeeV4Hook.MoonFeeHookData({ minUSDTOut: minUSDTOut }));
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
