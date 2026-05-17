// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { Test } from "forge-std/Test.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { BaseV4Addresses } from "../../../contracts/hooks/base/BaseV4Addresses.sol";
import { MockUSDT } from "../../../contracts/mocks/MockUSDT.sol";
import { MoonCurve } from "../../../contracts/MoonCurve.sol";
import { MoonToken } from "../../../contracts/MoonToken.sol";
import { SunCurve } from "../../../contracts/SunCurve.sol";
import { SunToken } from "../../../contracts/SunToken.sol";
import {
    PrepareBaseSepoliaTinyRehearsalAssets
} from "../../../script/PrepareBaseSepoliaTinyRehearsalAssets.s.sol";

contract TinyAssetsDummyTarget { }

contract TinyAssetsMockPermit2 {
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

contract BaseSepoliaTinyRehearsalAssetsPreparationTest is Test {
    address internal hookOwner = 0x6E22b2e6fFAA30Fe75B71d53d1eC469b4e97A986;
    address internal protocolBudget = 0x277ba3Cf597CdAaF958C301db3cF6a631F793039;
    address internal rehearsalActor = makeAddr("rehearsalActor");

    struct Fixture {
        MockUSDT usdc;
        SunToken sun;
        SunCurve sunCurve;
        MoonToken moon;
        MoonCurve moonCurve;
        TinyAssetsMockPermit2 permit2;
        address positionManager;
        address universalRouter;
    }

    function testTinyRehearsalAssetsPreparationPlansExecutesAndGuards() public {
        _assertPlansAssetPrepWhenActorNeedsEverything();
        _assertExecuteMintsAssetsAndApprovesPermit2();
        _assertReportsInsufficientUsdcWithoutExecution();
        _assertRejectsExecutionWithInsufficientUsdc();
        _assertRejectsBaseMainnet();
        _assertBaseSepoliaRequiresExplicitConfirmation();
    }

    function _assertPlansAssetPrepWhenActorNeedsEverything() private {
        vm.chainId(31_337);
        Fixture memory fixture = _deployFixture();
        fixture.usdc.mint(rehearsalActor, 2_000_000);

        PrepareBaseSepoliaTinyRehearsalAssets script = new PrepareBaseSepoliaTinyRehearsalAssets();
        PrepareBaseSepoliaTinyRehearsalAssets.AssetPlan memory plan =
            script.prepare(_assetConfig(fixture, false, false));

        assertEq(plan.chainId, 31_337);
        assertEq(plan.rehearsalActor, rehearsalActor);
        assertEq(plan.requiredUsdcForRehearsal, 1_105_000);
        assertEq(plan.sunMintUsdcAmount, 500_000);
        assertEq(plan.moonMintSunAmount, 0.3 ether);
        assertGt(plan.projectedSunOut, plan.moonMintSunAmount);
        assertGt(plan.projectedMoonOut, 1 ether);
        assertTrue(plan.needsSunMint);
        assertTrue(plan.needsMoonMint);
        assertTrue(plan.hasSufficientUsdcForAssetPrep);
        assertTrue(plan.hasSufficientProjectedSun);
        assertTrue(plan.hasSufficientProjectedMoon);
        assertTrue(plan.canExecuteAssetPrep);
        assertEq(plan.transactionsPlanned, 9);
        assertEq(plan.transactionsExecuted, 0);
    }

    function _assertExecuteMintsAssetsAndApprovesPermit2() private {
        vm.chainId(31_337);
        Fixture memory fixture = _deployFixture();
        fixture.usdc.mint(rehearsalActor, 2_000_000);

        PrepareBaseSepoliaTinyRehearsalAssets script = new PrepareBaseSepoliaTinyRehearsalAssets();
        PrepareBaseSepoliaTinyRehearsalAssets.AssetPlan memory plan =
            script.prepare(_assetConfig(fixture, false, true));

        assertEq(plan.transactionsExecuted, 9);
        assertEq(plan.transactionsPlanned, 0);
        assertEq(fixture.usdc.balanceOf(rehearsalActor), 1_500_000);
        assertGe(fixture.moon.balanceOf(rehearsalActor), 1 ether);
        assertGe(fixture.usdc.allowance(rehearsalActor, address(fixture.permit2)), 1_105_000);
        assertGe(fixture.moon.allowance(rehearsalActor, address(fixture.permit2)), 1 ether);

        (uint160 usdcPositionAllowance,,) = fixture.permit2
        .allowance(rehearsalActor, address(fixture.usdc), fixture.positionManager);
        (uint160 moonPositionAllowance,,) = fixture.permit2
        .allowance(rehearsalActor, address(fixture.moon), fixture.positionManager);
        (uint160 usdcRouterAllowance,,) = fixture.permit2
        .allowance(rehearsalActor, address(fixture.usdc), fixture.universalRouter);
        assertGe(uint256(usdcPositionAllowance), 1_000_000);
        assertGe(uint256(moonPositionAllowance), 1 ether);
        assertGe(uint256(usdcRouterAllowance), 105_000);
    }

    function _assertReportsInsufficientUsdcWithoutExecution() private {
        vm.chainId(31_337);
        Fixture memory fixture = _deployFixture();

        PrepareBaseSepoliaTinyRehearsalAssets script = new PrepareBaseSepoliaTinyRehearsalAssets();
        PrepareBaseSepoliaTinyRehearsalAssets.AssetPlan memory plan =
            script.prepare(_assetConfig(fixture, false, false));

        assertEq(plan.actorUsdcBalance, 0);
        assertFalse(plan.hasSufficientUsdcForAssetPrep);
        assertFalse(plan.canExecuteAssetPrep);
        assertEq(plan.transactionsExecuted, 0);
    }

    function _assertRejectsExecutionWithInsufficientUsdc() private {
        vm.chainId(31_337);
        Fixture memory fixture = _deployFixture();

        PrepareBaseSepoliaTinyRehearsalAssets script = new PrepareBaseSepoliaTinyRehearsalAssets();

        vm.expectRevert(
            abi.encodeWithSelector(
                PrepareBaseSepoliaTinyRehearsalAssets.CannotExecuteAssetPrep.selector,
                bytes32("INSUFFICIENT_USDC")
            )
        );
        script.prepare(_assetConfig(fixture, false, true));
    }

    function _assertRejectsBaseMainnet() private {
        vm.chainId(BaseV4Addresses.BASE_MAINNET_CHAIN_ID);
        Fixture memory fixture = _deployFixture();

        PrepareBaseSepoliaTinyRehearsalAssets script = new PrepareBaseSepoliaTinyRehearsalAssets();

        vm.expectRevert(
            abi.encodeWithSelector(
                PrepareBaseSepoliaTinyRehearsalAssets.BaseMainnetNotAllowed.selector,
                BaseV4Addresses.BASE_MAINNET_CHAIN_ID
            )
        );
        script.prepare(_assetConfig(fixture, false, false));
    }

    function _assertBaseSepoliaRequiresExplicitConfirmation() private {
        vm.chainId(BaseV4Addresses.BASE_SEPOLIA_CHAIN_ID);
        Fixture memory fixture = _deployFixture();

        PrepareBaseSepoliaTinyRehearsalAssets script = new PrepareBaseSepoliaTinyRehearsalAssets();

        vm.expectRevert(
            abi.encodeWithSelector(
                PrepareBaseSepoliaTinyRehearsalAssets.BaseSepoliaRunNotConfirmed.selector,
                BaseV4Addresses.BASE_SEPOLIA_CHAIN_ID
            )
        );
        script.prepare(_assetConfig(fixture, false, false));
    }

    function _deployFixture() private returns (Fixture memory fixture) {
        fixture.usdc = new MockUSDT("Base Sepolia USDC", "USDC", 6);
        fixture.sun = new SunToken("SUN", "SUN", hookOwner);
        fixture.moon = new MoonToken("MOON", "MOON", hookOwner);
        fixture.sunCurve =
            new SunCurve(fixture.sun, fixture.usdc, protocolBudget, 10_000e6, hookOwner);
        fixture.moonCurve = new MoonCurve(
            fixture.moon,
            fixture.sun,
            fixture.sunCurve,
            protocolBudget,
            5_000_000 ether,
            1_200_000 ether,
            block.timestamp,
            10_000e6,
            hookOwner
        );
        fixture.permit2 = new TinyAssetsMockPermit2();
        fixture.positionManager = address(new TinyAssetsDummyTarget());
        fixture.universalRouter = address(new TinyAssetsDummyTarget());

        vm.startPrank(hookOwner);
        fixture.sun.setMinter(address(fixture.sunCurve));
        fixture.sunCurve.setMoonCurve(address(fixture.moonCurve));
        fixture.moon.setMinter(address(fixture.moonCurve));
        vm.stopPrank();
    }

    function _assetConfig(Fixture memory fixture, bool baseSepoliaConfirmed, bool execute)
        private
        view
        returns (PrepareBaseSepoliaTinyRehearsalAssets.AssetConfig memory config)
    {
        config = PrepareBaseSepoliaTinyRehearsalAssets.AssetConfig({
            baseSepoliaConfirmed: baseSepoliaConfirmed,
            execute: execute,
            rehearsalActor: rehearsalActor,
            usdcToken: address(fixture.usdc),
            sunToken: address(fixture.sun),
            sunCurve: address(fixture.sunCurve),
            moonToken: address(fixture.moon),
            moonCurve: address(fixture.moonCurve),
            permit2: address(fixture.permit2),
            positionManager: fixture.positionManager,
            universalRouter: fixture.universalRouter,
            liquidityUsdcAmount: 1_000_000,
            liquidityMoonAmount: 1 ether,
            swapUsdcIn: 100_000,
            sunMintUsdcAmount: 500_000,
            moonMintSunAmount: 0.3 ether,
            permit2Expiration: type(uint48).max
        });
    }
}
