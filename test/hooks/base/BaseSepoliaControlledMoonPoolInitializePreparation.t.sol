// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import { Test } from "forge-std/Test.sol";
import { IHooks } from "@uniswap/v4-core/src/interfaces/IHooks.sol";
import { IPoolManager } from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import { PoolManager } from "@uniswap/v4-core/src/PoolManager.sol";
import { TickMath } from "@uniswap/v4-core/src/libraries/TickMath.sol";
import { Currency } from "@uniswap/v4-core/src/types/Currency.sol";
import { PoolId, PoolIdLibrary } from "@uniswap/v4-core/src/types/PoolId.sol";
import { PoolKey } from "@uniswap/v4-core/src/types/PoolKey.sol";
import { StateView } from "@uniswap/v4-periphery/src/lens/StateView.sol";
import { IMoonAmmSwapAdapter } from "../../../contracts/hooks/MoonAmmFeeHook.sol";
import { TestnetUsdcAdapter } from "../../../contracts/hooks/TestnetUsdcAdapter.sol";
import { BaseMoonAmmFeeV4Hook } from "../../../contracts/hooks/base/BaseMoonAmmFeeV4Hook.sol";
import { BaseV4Addresses } from "../../../contracts/hooks/base/BaseV4Addresses.sol";
import { BaseV4HookAddressMiner } from "../../../contracts/hooks/base/BaseV4HookAddressMiner.sol";
import { MockUSDT } from "../../../contracts/mocks/MockUSDT.sol";
import { MoonToken } from "../../../contracts/MoonToken.sol";
import { SunCurve } from "../../../contracts/SunCurve.sol";
import { SunToken } from "../../../contracts/SunToken.sol";
import {
    PrepareBaseSepoliaControlledMoonPoolInitialize
} from "../../../script/PrepareBaseSepoliaControlledMoonPoolInitialize.s.sol";

contract BaseSepoliaControlledMoonPoolInitializePreparationTest is Test {
    using PoolIdLibrary for PoolKey;

    address internal hookOwner = 0x6E22b2e6fFAA30Fe75B71d53d1eC469b4e97A986;
    address internal protocolBudget = 0x277ba3Cf597CdAaF958C301db3cF6a631F793039;
    int24 internal constant INITIAL_TICK = 276_300;
    uint160 internal nextHookHighBits = 1;

    struct Fixture {
        PoolManager poolManager;
        StateView stateView;
        BaseMoonAmmFeeV4Hook hook;
        MoonToken moon;
        MockUSDT usdc;
        PoolKey poolKey;
        bytes32 poolId;
        uint160 sqrtPriceX96;
    }

    function testControlledMoonPoolInitializationGuardsAndInitializes() public {
        _assertLocalSimulationInitializesMoonUsdcPool();
        _assertIdempotentWhenPoolAlreadyInitialized();
        _assertRejectsUnallowedPool();
        _assertRejectsUnexpectedInitializedPrice();
        _assertBaseMainnetIsRejected();
        _assertBaseSepoliaRequiresExplicitConfirmation();
        _assertRejectsInvalidInitialTick();
        _resetSharedEnv();
    }

    function _assertLocalSimulationInitializesMoonUsdcPool() private {
        vm.chainId(31_337);
        Fixture memory fixture = _deployFixture(true, false);
        _setPoolEnv(fixture);

        PrepareBaseSepoliaControlledMoonPoolInitialize script =
            new PrepareBaseSepoliaControlledMoonPoolInitialize();
        PrepareBaseSepoliaControlledMoonPoolInitialize.PoolInitialization memory pool = script.run();

        assertEq(pool.chainId, 31_337);
        assertFalse(pool.baseSepoliaConfirmed);
        assertEq(pool.poolInitializer, hookOwner);
        assertEq(address(pool.poolManager), address(fixture.poolManager));
        assertEq(address(pool.stateView), address(fixture.stateView));
        assertEq(address(pool.hook), address(fixture.hook));
        assertEq(pool.moonToken, address(fixture.moon));
        assertEq(pool.usdcToken, address(fixture.usdc));
        assertEq(pool.poolId, fixture.poolId);
        assertTrue(pool.allowedMoonPool);
        assertEq(pool.initialTick, INITIAL_TICK);
        assertEq(pool.sqrtPriceX96, fixture.sqrtPriceX96);
        assertEq(pool.sqrtPriceBefore, 0);
        assertFalse(pool.alreadyInitialized);
        assertEq(pool.transactionsPlanned, 1);
        assertEq(pool.sqrtPriceAfter, fixture.sqrtPriceX96);
        assertEq(pool.tickAfter, INITIAL_TICK);

        (uint160 sqrtPriceX96, int24 tick,,) =
            fixture.stateView.getSlot0(PoolId.wrap(fixture.poolId));
        assertEq(sqrtPriceX96, fixture.sqrtPriceX96);
        assertEq(tick, INITIAL_TICK);
    }

    function _assertIdempotentWhenPoolAlreadyInitialized() private {
        vm.chainId(31_337);
        Fixture memory fixture = _deployFixture(true, true);
        _setPoolEnv(fixture);

        PrepareBaseSepoliaControlledMoonPoolInitialize script =
            new PrepareBaseSepoliaControlledMoonPoolInitialize();
        PrepareBaseSepoliaControlledMoonPoolInitialize.PoolInitialization memory pool = script.run();

        assertTrue(pool.alreadyInitialized);
        assertEq(pool.transactionsPlanned, 0);
        assertEq(pool.sqrtPriceBefore, fixture.sqrtPriceX96);
        assertEq(pool.sqrtPriceAfter, fixture.sqrtPriceX96);
    }

    function _assertRejectsUnallowedPool() private {
        vm.chainId(31_337);
        Fixture memory fixture = _deployFixture(false, false);
        _setPoolEnv(fixture);

        PrepareBaseSepoliaControlledMoonPoolInitialize script =
            new PrepareBaseSepoliaControlledMoonPoolInitialize();

        vm.expectRevert(
            abi.encodeWithSelector(
                PrepareBaseSepoliaControlledMoonPoolInitialize.MoonPoolNotAllowed.selector,
                fixture.poolId
            )
        );
        script.run();
    }

    function _assertRejectsUnexpectedInitializedPrice() private {
        vm.chainId(31_337);
        Fixture memory fixture = _deployFixture(true, false);
        _setPoolEnv(fixture);
        uint160 wrongSqrtPriceX96 = TickMath.getSqrtPriceAtTick(INITIAL_TICK + 60);
        fixture.poolManager.initialize(fixture.poolKey, wrongSqrtPriceX96);

        PrepareBaseSepoliaControlledMoonPoolInitialize script =
            new PrepareBaseSepoliaControlledMoonPoolInitialize();

        vm.expectRevert(
            abi.encodeWithSelector(
                PrepareBaseSepoliaControlledMoonPoolInitialize.UnexpectedInitializedPool.selector,
                fixture.poolId,
                fixture.sqrtPriceX96,
                wrongSqrtPriceX96
            )
        );
        script.run();
    }

    function _assertBaseMainnetIsRejected() private {
        vm.chainId(BaseV4Addresses.BASE_MAINNET_CHAIN_ID);
        Fixture memory fixture = _deployFixture(true, false);
        _setPoolEnv(fixture);

        PrepareBaseSepoliaControlledMoonPoolInitialize script =
            new PrepareBaseSepoliaControlledMoonPoolInitialize();

        vm.expectRevert(
            abi.encodeWithSelector(
                PrepareBaseSepoliaControlledMoonPoolInitialize.BaseMainnetNotAllowed.selector,
                BaseV4Addresses.BASE_MAINNET_CHAIN_ID
            )
        );
        script.run();
    }

    function _assertBaseSepoliaRequiresExplicitConfirmation() private {
        vm.chainId(BaseV4Addresses.BASE_SEPOLIA_CHAIN_ID);
        Fixture memory fixture = _deployFixture(true, false);
        _setPoolEnv(fixture);
        vm.setEnv("CONFIRM_BASE_SEPOLIA_POOL_INITIALIZE_RUN", "0");

        PrepareBaseSepoliaControlledMoonPoolInitialize script =
            new PrepareBaseSepoliaControlledMoonPoolInitialize();

        vm.expectRevert(
            abi.encodeWithSelector(
                PrepareBaseSepoliaControlledMoonPoolInitialize.BaseSepoliaRunNotConfirmed.selector,
                BaseV4Addresses.BASE_SEPOLIA_CHAIN_ID
            )
        );
        script.run();
    }

    function _assertRejectsInvalidInitialTick() private {
        vm.chainId(31_337);
        Fixture memory fixture = _deployFixture(true, false);
        _setPoolEnv(fixture);
        vm.setEnv("MOON_USDC_INITIAL_TICK", "276301");

        PrepareBaseSepoliaControlledMoonPoolInitialize script =
            new PrepareBaseSepoliaControlledMoonPoolInitialize();

        vm.expectRevert(
            abi.encodeWithSelector(
                PrepareBaseSepoliaControlledMoonPoolInitialize.InvalidInitialTick.selector,
                int24(276_301),
                int24(60)
            )
        );
        script.run();
    }

    function _deployFixture(bool allowPool, bool initializePool)
        private
        returns (Fixture memory fixture)
    {
        fixture.poolManager = new PoolManager(hookOwner);
        fixture.stateView = new StateView(IPoolManager(address(fixture.poolManager)));
        fixture.usdc = new MockUSDT("Base Sepolia USDC", "USDC", 6);
        fixture.moon = new MoonToken("MOON", "MOON", hookOwner);
        SunToken sunToken = new SunToken("SUN", "SUN", hookOwner);
        SunCurve sunCurve = new SunCurve(
            sunToken, IERC20Metadata(address(fixture.usdc)), protocolBudget, 10_000e6, hookOwner
        );
        TestnetUsdcAdapter adapter =
            new TestnetUsdcAdapter(IERC20(address(fixture.usdc)), hookOwner, hookOwner);
        address hookAddress = _nextPermissionedHookAddress();

        BaseMoonAmmFeeV4Hook implementation = new BaseMoonAmmFeeV4Hook(
            IPoolManager(address(fixture.poolManager)),
            address(fixture.moon),
            IERC20(address(fixture.usdc)),
            sunCurve,
            protocolBudget,
            IMoonAmmSwapAdapter(address(adapter)),
            hookOwner
        );
        vm.etch(hookAddress, address(implementation).code);
        fixture.hook = BaseMoonAmmFeeV4Hook(hookAddress);
        fixture.poolKey =
            _poolKey(address(fixture.moon), address(fixture.usdc), IHooks(hookAddress));
        fixture.poolId = PoolId.unwrap(fixture.poolKey.toId());
        fixture.sqrtPriceX96 = TickMath.getSqrtPriceAtTick(INITIAL_TICK);

        if (allowPool) {
            vm.prank(hookOwner);
            fixture.hook.setAllowedMoonPool(fixture.poolId, true);
        }

        if (initializePool) {
            fixture.poolManager.initialize(fixture.poolKey, fixture.sqrtPriceX96);
        }
    }

    function _nextPermissionedHookAddress() private returns (address hookAddress) {
        hookAddress = address(
            uint160(BaseV4HookAddressMiner.BASE_MOON_AMM_FEE_V4_HOOK_MASK)
                | (nextHookHighBits << 14)
        );
        nextHookHighBits++;
    }

    function _poolKey(address tokenA, address tokenB, IHooks hook)
        private
        pure
        returns (PoolKey memory key)
    {
        (Currency currency0, Currency currency1) = tokenA < tokenB
            ? (Currency.wrap(tokenA), Currency.wrap(tokenB))
            : (Currency.wrap(tokenB), Currency.wrap(tokenA));
        key = PoolKey({
            currency0: currency0, currency1: currency1, fee: 3000, tickSpacing: 60, hooks: hook
        });
    }

    function _setPoolEnv(Fixture memory fixture) private {
        vm.setEnv("HOOK_OWNER", vm.toString(hookOwner));
        vm.setEnv("POOL_INITIALIZER", "");
        vm.setEnv("POOL_MANAGER", vm.toString(address(fixture.poolManager)));
        vm.setEnv("STATE_VIEW", vm.toString(address(fixture.stateView)));
        vm.setEnv("HOOK_ADDRESS", vm.toString(address(fixture.hook)));
        vm.setEnv("CONTROLLED_POOL_MOON_TOKEN", vm.toString(address(fixture.moon)));
        vm.setEnv("CONTROLLED_POOL_USDC_TOKEN", vm.toString(address(fixture.usdc)));
        vm.setEnv("MOON_USDC_POOL_FEE", "3000");
        vm.setEnv("MOON_USDC_POOL_TICK_SPACING", "60");
        vm.setEnv("MOON_USDC_INITIAL_TICK", vm.toString(INITIAL_TICK));
        vm.setEnv("CONFIRM_BASE_SEPOLIA_POOL_INITIALIZE_RUN", "0");
    }

    function _resetSharedEnv() private {
        vm.setEnv("POOL_INITIALIZER", "");
        vm.setEnv("POOL_MANAGER", "");
        vm.setEnv("STATE_VIEW", "");
        vm.setEnv("CONTROLLED_POOL_MOON_TOKEN", "");
        vm.setEnv("CONTROLLED_POOL_USDC_TOKEN", "");
        vm.setEnv("MOON_USDC_POOL_FEE", "3000");
        vm.setEnv("MOON_USDC_POOL_TICK_SPACING", "60");
        vm.setEnv("MOON_USDC_INITIAL_TICK", "");
        vm.setEnv("CONFIRM_BASE_SEPOLIA_POOL_INITIALIZE_RUN", "0");
    }
}
