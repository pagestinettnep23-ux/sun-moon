// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Test } from "forge-std/Test.sol";
import { IHooks } from "@uniswap/v4-core/src/interfaces/IHooks.sol";
import { IPoolManager } from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import { PoolManager } from "@uniswap/v4-core/src/PoolManager.sol";
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
    PrepareBaseSepoliaTinyMoonUsdcRehearsal
} from "../../../script/PrepareBaseSepoliaTinyMoonUsdcRehearsal.s.sol";

contract DummyTarget { }

contract MockPermit2 {
    struct Allowance {
        uint160 amount;
        uint48 expiration;
        uint48 nonce;
    }

    mapping(address user => mapping(address token => mapping(address spender => Allowance)))
        internal allowances;

    function allowance(address user, address token, address spender)
        external
        view
        returns (uint160 amount, uint48 expiration, uint48 nonce)
    {
        Allowance memory allowance_ = allowances[user][token][spender];
        return (allowance_.amount, allowance_.expiration, allowance_.nonce);
    }

    function approve(address token, address spender, uint160 amount, uint48 expiration) external {
        Allowance storage allowance_ = allowances[msg.sender][token][spender];
        allowance_.amount = amount;
        allowance_.expiration = expiration;
    }
}

contract BaseSepoliaTinyMoonUsdcRehearsalPreparationTest is Test {
    using PoolIdLibrary for PoolKey;

    address internal hookOwner = 0x6E22b2e6fFAA30Fe75B71d53d1eC469b4e97A986;
    address internal protocolBudget = 0x277ba3Cf597CdAaF958C301db3cF6a631F793039;
    address internal rehearsalActor = makeAddr("rehearsalActor");
    uint160 internal nextHookHighBits = 1;

    struct Fixture {
        PoolManager poolManager;
        StateView stateView;
        address positionManager;
        address universalRouter;
        MockPermit2 permit2;
        BaseMoonAmmFeeV4Hook hook;
        TestnetUsdcAdapter adapter;
        SunCurve sunCurve;
        MoonToken moon;
        MockUSDT usdc;
        PoolKey poolKey;
        bytes32 poolId;
    }

    function testTinyMoonUsdcRehearsalPreparationGuardsAndReportsReadiness() public {
        _assertReportsReadyTinyRehearsalPlan();
        _assertReportsMissingActorBalancesAndApprovalsWithoutReverting();
        _assertRejectsUninitializedPool();
        _assertRejectsUnallowedPool();
        _assertRejectsUnboundAdapter();
        _assertRejectsBaseMainnet();
        _assertBaseSepoliaRequiresExplicitConfirmation();
        _assertRejectsMinUsdcAboveDirectFeeAmount();
    }

    function _assertReportsReadyTinyRehearsalPlan() private {
        vm.chainId(31_337);
        Fixture memory fixture = _deployFixture(true, true, true, true);
        _fundAndApproveActor(fixture);

        PrepareBaseSepoliaTinyMoonUsdcRehearsal script =
            new PrepareBaseSepoliaTinyMoonUsdcRehearsal();
        PrepareBaseSepoliaTinyMoonUsdcRehearsal.TinyRehearsalPlan memory plan =
            script.prepare(_planConfig(fixture, false, 3000));

        assertEq(plan.chainId, 31_337);
        assertFalse(plan.baseSepoliaConfirmed);
        assertEq(plan.rehearsalActor, rehearsalActor);
        assertEq(address(plan.hook), address(fixture.hook));
        assertEq(address(plan.adapter), address(fixture.adapter));
        assertEq(address(plan.sunCurve), address(fixture.sunCurve));
        assertEq(plan.protocolBudget, protocolBudget);
        assertEq(plan.poolId, fixture.poolId);
        assertTrue(plan.poolInitialized);
        assertTrue(plan.allowedMoonPool);
        assertFalse(plan.hookPaused);
        assertTrue(plan.adapterAuthorized);
        assertTrue(plan.sunCurveBound);
        assertTrue(plan.protocolBudgetConfigured);
        assertEq(plan.lpFee, 3000);
        assertEq(plan.liquidityUsdcAmount, 1_000_000);
        assertEq(plan.liquidityMoonAmount, 1 ether);
        assertEq(plan.swapUsdcIn, 100_000);
        assertEq(plan.swapFeeToSunCurve, 3000);
        assertEq(plan.swapFeeToProtocol, 2000);
        assertEq(plan.swapUsdcGrossInputWithHookFee, 105_000);
        assertEq(plan.swapMinUsdcToCurve, 3000);
        assertEq(
            plan.zeroForOneUsdcToMoon,
            Currency.unwrap(fixture.poolKey.currency0) == address(fixture.usdc)
        );
        assertEq(
            keccak256(plan.swapHookData),
            keccak256(abi.encode(BaseMoonAmmFeeV4Hook.MoonFeeHookData({ minUSDTOut: 3000 })))
        );
        assertTrue(plan.hasLiquidityBalances);
        assertTrue(plan.hasSwapBalance);
        assertTrue(plan.hasPermit2TokenApprovals);
        assertTrue(plan.hasPositionManagerPermit2Allowances);
        assertTrue(plan.hasUniversalRouterPermit2Allowance);
        assertTrue(plan.readyForLiquidityDryRun);
        assertTrue(plan.readyForSwapDryRun);
        assertTrue(plan.readyForCombinedDryRun);
        assertTrue(plan.quoteRequiredBeforeBroadcast);
        assertEq(plan.transactionsPlanned, 0);
    }

    function _assertReportsMissingActorBalancesAndApprovalsWithoutReverting() private {
        vm.chainId(31_337);
        Fixture memory fixture = _deployFixture(true, true, true, true);

        PrepareBaseSepoliaTinyMoonUsdcRehearsal script =
            new PrepareBaseSepoliaTinyMoonUsdcRehearsal();
        PrepareBaseSepoliaTinyMoonUsdcRehearsal.TinyRehearsalPlan memory plan =
            script.prepare(_planConfig(fixture, false, 3000));

        assertEq(plan.actorUsdcBalance, 0);
        assertEq(plan.actorMoonBalance, 0);
        assertFalse(plan.hasLiquidityBalances);
        assertFalse(plan.hasSwapBalance);
        assertFalse(plan.hasPermit2TokenApprovals);
        assertFalse(plan.readyForLiquidityDryRun);
        assertFalse(plan.readyForSwapDryRun);
        assertFalse(plan.readyForCombinedDryRun);
    }

    function _assertRejectsUninitializedPool() private {
        vm.chainId(31_337);
        Fixture memory fixture = _deployFixture(false, true, true, true);

        PrepareBaseSepoliaTinyMoonUsdcRehearsal script =
            new PrepareBaseSepoliaTinyMoonUsdcRehearsal();

        vm.expectRevert(
            abi.encodeWithSelector(
                PrepareBaseSepoliaTinyMoonUsdcRehearsal.PoolNotInitialized.selector, fixture.poolId
            )
        );
        script.prepare(_planConfig(fixture, false, 3000));
    }

    function _assertRejectsUnallowedPool() private {
        vm.chainId(31_337);
        Fixture memory fixture = _deployFixture(true, false, true, true);

        PrepareBaseSepoliaTinyMoonUsdcRehearsal script =
            new PrepareBaseSepoliaTinyMoonUsdcRehearsal();

        vm.expectRevert(
            abi.encodeWithSelector(
                PrepareBaseSepoliaTinyMoonUsdcRehearsal.MoonPoolNotAllowed.selector, fixture.poolId
            )
        );
        script.prepare(_planConfig(fixture, false, 3000));
    }

    function _assertRejectsUnboundAdapter() private {
        vm.chainId(31_337);
        Fixture memory fixture = _deployFixture(true, true, false, true);

        PrepareBaseSepoliaTinyMoonUsdcRehearsal script =
            new PrepareBaseSepoliaTinyMoonUsdcRehearsal();

        vm.expectRevert(
            abi.encodeWithSelector(
                PrepareBaseSepoliaTinyMoonUsdcRehearsal.UnexpectedParameter.selector,
                bytes32("SWAP_ADAPTER"),
                address(fixture.hook),
                hookOwner
            )
        );
        script.prepare(_planConfig(fixture, false, 3000));
    }

    function _assertRejectsBaseMainnet() private {
        vm.chainId(BaseV4Addresses.BASE_MAINNET_CHAIN_ID);
        Fixture memory fixture = _deployFixture(true, true, true, true);

        PrepareBaseSepoliaTinyMoonUsdcRehearsal script =
            new PrepareBaseSepoliaTinyMoonUsdcRehearsal();

        vm.expectRevert(
            abi.encodeWithSelector(
                PrepareBaseSepoliaTinyMoonUsdcRehearsal.BaseMainnetNotAllowed.selector,
                BaseV4Addresses.BASE_MAINNET_CHAIN_ID
            )
        );
        script.prepare(_planConfig(fixture, false, 3000));
    }

    function _assertBaseSepoliaRequiresExplicitConfirmation() private {
        vm.chainId(BaseV4Addresses.BASE_SEPOLIA_CHAIN_ID);
        Fixture memory fixture = _deployFixture(true, true, true, true);

        PrepareBaseSepoliaTinyMoonUsdcRehearsal script =
            new PrepareBaseSepoliaTinyMoonUsdcRehearsal();

        vm.expectRevert(
            abi.encodeWithSelector(
                PrepareBaseSepoliaTinyMoonUsdcRehearsal.BaseSepoliaRunNotConfirmed.selector,
                BaseV4Addresses.BASE_SEPOLIA_CHAIN_ID
            )
        );
        script.prepare(_planConfig(fixture, false, 3000));
    }

    function _assertRejectsMinUsdcAboveDirectFeeAmount() private {
        vm.chainId(31_337);
        Fixture memory fixture = _deployFixture(true, true, true, true);

        PrepareBaseSepoliaTinyMoonUsdcRehearsal script =
            new PrepareBaseSepoliaTinyMoonUsdcRehearsal();

        vm.expectRevert(
            abi.encodeWithSelector(
                PrepareBaseSepoliaTinyMoonUsdcRehearsal.InvalidMinUsdcOut.selector, 3001, 3000
            )
        );
        script.prepare(_planConfig(fixture, false, 3001));
    }

    function _deployFixture(
        bool initializePool,
        bool allowPool,
        bool bindAdapter,
        bool bindSunCurve
    ) private returns (Fixture memory fixture) {
        fixture.poolManager = new PoolManager(hookOwner);
        fixture.stateView = new StateView(IPoolManager(address(fixture.poolManager)));
        fixture.positionManager = address(new DummyTarget());
        fixture.universalRouter = address(new DummyTarget());
        fixture.permit2 = new MockPermit2();
        fixture.usdc = new MockUSDT("Base Sepolia USDC", "USDC", 6);
        fixture.moon = new MoonToken("MOON", "MOON", hookOwner);
        SunToken sunToken = new SunToken("SUN", "SUN", hookOwner);
        fixture.sunCurve = new SunCurve(sunToken, fixture.usdc, protocolBudget, 10_000e6, hookOwner);
        fixture.adapter =
            new TestnetUsdcAdapter(IERC20(address(fixture.usdc)), hookOwner, hookOwner);

        address hookAddress = _nextPermissionedHookAddress();
        BaseMoonAmmFeeV4Hook implementation = new BaseMoonAmmFeeV4Hook(
            IPoolManager(address(fixture.poolManager)),
            address(fixture.moon),
            IERC20(address(fixture.usdc)),
            fixture.sunCurve,
            protocolBudget,
            IMoonAmmSwapAdapter(address(fixture.adapter)),
            hookOwner
        );
        vm.etch(hookAddress, address(implementation).code);
        fixture.hook = BaseMoonAmmFeeV4Hook(hookAddress);
        fixture.poolKey =
            _poolKey(address(fixture.moon), address(fixture.usdc), IHooks(hookAddress));
        fixture.poolId = PoolId.unwrap(fixture.poolKey.toId());

        vm.startPrank(hookOwner);
        fixture.hook.setProtocolBudget(protocolBudget);
        fixture.hook.setSwapAdapter(address(fixture.adapter));
        vm.stopPrank();

        if (bindAdapter) {
            vm.prank(hookOwner);
            fixture.adapter.setAuthorizedHook(hookAddress);
        }
        if (bindSunCurve) {
            vm.prank(hookOwner);
            fixture.sunCurve.setMoonAMM(hookAddress);
        }
        if (allowPool) {
            vm.prank(hookOwner);
            fixture.hook.setAllowedMoonPool(fixture.poolId, true);
        }
        if (initializePool) {
            fixture.poolManager
                .initialize(fixture.poolKey, 79_133_045_881_256_921_541_446_514_419_412_387);
        }
    }

    function _fundAndApproveActor(Fixture memory fixture) private {
        fixture.usdc.mint(rehearsalActor, 3_000_000);
        vm.prank(hookOwner);
        fixture.moon.setMinter(address(this));
        fixture.moon.mint(rehearsalActor, 2 ether);

        vm.startPrank(rehearsalActor);
        fixture.usdc.approve(address(fixture.permit2), type(uint256).max);
        fixture.moon.approve(address(fixture.permit2), type(uint256).max);
        fixture.permit2
            .approve(
                address(fixture.usdc), fixture.positionManager, type(uint160).max, type(uint48).max
            );
        fixture.permit2
            .approve(
                address(fixture.moon), fixture.positionManager, type(uint160).max, type(uint48).max
            );
        fixture.permit2
            .approve(
                address(fixture.usdc), fixture.universalRouter, type(uint160).max, type(uint48).max
            );
        vm.stopPrank();
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

    function _planConfig(
        Fixture memory fixture,
        bool baseSepoliaConfirmed,
        uint256 swapMinUsdcToCurve
    )
        private
        view
        returns (PrepareBaseSepoliaTinyMoonUsdcRehearsal.TinyRehearsalConfig memory config)
    {
        config = PrepareBaseSepoliaTinyMoonUsdcRehearsal.TinyRehearsalConfig({
            baseSepoliaConfirmed: baseSepoliaConfirmed,
            rehearsalActor: rehearsalActor,
            poolManager: address(fixture.poolManager),
            stateView: address(fixture.stateView),
            positionManager: fixture.positionManager,
            universalRouter: fixture.universalRouter,
            permit2: address(fixture.permit2),
            hook: address(fixture.hook),
            adapter: address(fixture.adapter),
            sunCurve: address(fixture.sunCurve),
            moonToken: address(fixture.moon),
            usdcToken: address(fixture.usdc),
            fee: 3000,
            tickSpacing: 60,
            liquidityUsdcAmount: 1_000_000,
            liquidityMoonAmount: 1 ether,
            swapUsdcIn: 100_000,
            swapMinUsdcToCurve: swapMinUsdcToCurve
        });
    }
}
