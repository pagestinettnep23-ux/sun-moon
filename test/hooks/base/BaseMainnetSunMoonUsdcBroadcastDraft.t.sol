// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { Test } from "forge-std/Test.sol";
import { IPoolManager } from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import { PoolManager } from "@uniswap/v4-core/src/PoolManager.sol";
import { StateView } from "@uniswap/v4-periphery/src/lens/StateView.sol";
import { MockUSDT } from "../../../contracts/mocks/MockUSDT.sol";
import { SunCurve } from "../../../contracts/SunCurve.sol";
import {
    BaseSunMoonUsdcFeeV4Hook
} from "../../../contracts/hooks/base/BaseSunMoonUsdcFeeV4Hook.sol";
import { BaseV4Addresses } from "../../../contracts/hooks/base/BaseV4Addresses.sol";
import {
    PrepareBaseMainnetSunMoonUsdcBroadcastDraft
} from "../../../script/PrepareBaseMainnetSunMoonUsdcBroadcastDraft.s.sol";

contract BaseMainnetSunMoonUsdcBroadcastDraftTest is Test {
    address internal mainnetDeployer = makeAddr("mainnetDeployer");
    address internal mainnetAdminWallet = makeAddr("mainnetAdminWallet");
    address internal protocolBudgetWallet = makeAddr("protocolBudgetWallet");
    address internal create2DeployerOwner = makeAddr("create2DeployerOwner");
    address internal positionManager = makeAddr("positionManager");
    address internal quoter = makeAddr("quoter");
    address internal universalRouter = makeAddr("universalRouter");
    address internal permit2 = makeAddr("permit2");

    struct Fixture {
        MockUSDT usdc;
        PoolManager poolManager;
        StateView stateView;
    }

    function testLocalDraftBuildsBlockedNineteenTxPlanWithMoonAmmBinding() public {
        vm.chainId(31_337);
        Fixture memory fixture = _deployFixture(6);

        PrepareBaseMainnetSunMoonUsdcBroadcastDraft script =
            new PrepareBaseMainnetSunMoonUsdcBroadcastDraft();
        PrepareBaseMainnetSunMoonUsdcBroadcastDraft.MainnetBroadcastDraftPlan memory plan =
            script.prepare(
                _draftConfig(
                    address(fixture.poolManager),
                    address(fixture.stateView),
                    address(fixture.usdc),
                    false,
                    false,
                    false
                )
            );

        assertEq(plan.chainId, 31_337);
        assertFalse(plan.baseMainnetDraftConfirmed);
        assertFalse(plan.executeRequested);
        assertFalse(plan.privateKeyPresent);
        assertFalse(plan.broadcastAllowed);
        assertTrue(plan.executionBlocked);
        assertTrue(plan.simulationOnly);
        assertTrue(plan.moonAmmBindingTxIncluded);
        assertEq(plan.coreTxs, 12);
        assertEq(plan.hookDeployTxs, 1);
        assertEq(plan.hookAllowlistTxs, 2);
        assertEq(plan.hookBindTxs, 1);
        assertEq(plan.poolInitializeTxs, 2);
        assertEq(plan.hookRenounceTxs, 1);
        assertEq(plan.forkDryRunTxsWithoutMoonAmmBinding, 6);
        assertEq(plan.totalTransactionsPlanned, 19);
        assertEq(plan.txFrom.length, 19);
        assertEq(plan.txTo.length, 19);
        assertEq(plan.txDataHash.length, 19);
        assertEq(plan.txLabel.length, 19);

        assertEq(plan.txLabel[12], bytes32("TX13_HOOK_DEPLOY"));
        assertEq(plan.txFrom[12], create2DeployerOwner);
        assertEq(plan.txTo[12], plan.predictedCreate2HookDeployer);
        assertEq(plan.txLabel[13], bytes32("TX14_ALLOW_SUN"));
        assertEq(plan.txTo[13], plan.predictedHook);
        assertEq(plan.txLabel[14], bytes32("TX15_ALLOW_MOON"));
        assertEq(plan.txTo[14], plan.predictedHook);

        assertEq(plan.txLabel[15], bytes32("TX16_BIND_AMM"));
        assertEq(plan.txFrom[15], mainnetAdminWallet);
        assertEq(plan.txTo[15], plan.predictedSunCurve);
        assertEq(
            plan.txDataHash[15],
            keccak256(abi.encodeCall(SunCurve.setMoonAMM, (plan.predictedHook)))
        );

        assertEq(plan.txLabel[18], bytes32("TX19_RENOUNCE"));
        assertEq(plan.txFrom[18], mainnetAdminWallet);
        assertEq(plan.txTo[18], plan.predictedHook);
        assertEq(
            plan.txDataHash[18],
            keccak256(abi.encodeCall(BaseSunMoonUsdcFeeV4Hook.renounceOwnership, ()))
        );
        assertTrue(plan.sunUsdcAllowedAfterDryRun);
        assertTrue(plan.moonUsdcAllowedAfterDryRun);
        assertTrue(plan.renounceBlocksSunAllowlist);
        assertTrue(plan.renounceBlocksMoonAllowlist);
        assertTrue(plan.renounceBlocksProtocolBudget);
    }

    function testRejectsExecutionFlag() public {
        vm.chainId(31_337);
        Fixture memory fixture = _deployFixture(6);

        PrepareBaseMainnetSunMoonUsdcBroadcastDraft script =
            new PrepareBaseMainnetSunMoonUsdcBroadcastDraft();

        vm.expectRevert(
            PrepareBaseMainnetSunMoonUsdcBroadcastDraft.BroadcastExecutionNotAllowed.selector
        );
        script.prepare(
            _draftConfig(
                address(fixture.poolManager),
                address(fixture.stateView),
                address(fixture.usdc),
                false,
                true,
                false
            )
        );
    }

    function testRejectsPrivateKeyPresence() public {
        vm.chainId(31_337);
        Fixture memory fixture = _deployFixture(6);

        PrepareBaseMainnetSunMoonUsdcBroadcastDraft script =
            new PrepareBaseMainnetSunMoonUsdcBroadcastDraft();

        vm.expectRevert(
            PrepareBaseMainnetSunMoonUsdcBroadcastDraft.PrivateKeyEnvNotAllowed.selector
        );
        script.prepare(
            _draftConfig(
                address(fixture.poolManager),
                address(fixture.stateView),
                address(fixture.usdc),
                false,
                false,
                true
            )
        );
    }

    function testRunRejectsPrivateKeyEnvBeforeAnyPlanning() public {
        vm.chainId(31_337);
        vm.setEnv("PRIVATE_KEY", "0x1234");

        PrepareBaseMainnetSunMoonUsdcBroadcastDraft script =
            new PrepareBaseMainnetSunMoonUsdcBroadcastDraft();

        vm.expectRevert(
            PrepareBaseMainnetSunMoonUsdcBroadcastDraft.PrivateKeyEnvNotAllowed.selector
        );
        script.run();

        vm.setEnv("PRIVATE_KEY", "");
    }

    function testBaseMainnetRequiresExplicitDraftConfirmation() public {
        vm.chainId(BaseV4Addresses.BASE_MAINNET_CHAIN_ID);

        PrepareBaseMainnetSunMoonUsdcBroadcastDraft script =
            new PrepareBaseMainnetSunMoonUsdcBroadcastDraft();

        vm.expectRevert(
            abi.encodeWithSelector(
                PrepareBaseMainnetSunMoonUsdcBroadcastDraft.BaseMainnetBroadcastDraftNotConfirmed
                .selector,
                BaseV4Addresses.BASE_MAINNET_CHAIN_ID
            )
        );
        script.prepare(
            _draftConfig(
                BaseV4Addresses.BASE_MAINNET_POOL_MANAGER,
                BaseV4Addresses.BASE_MAINNET_STATE_VIEW,
                BaseV4Addresses.BASE_MAINNET_USDC,
                false,
                false,
                false
            )
        );
    }

    function testRejectsBaseSepoliaAsUnsupportedForMainnetDraft() public {
        vm.chainId(BaseV4Addresses.BASE_SEPOLIA_CHAIN_ID);
        Fixture memory fixture = _deployFixture(6);

        PrepareBaseMainnetSunMoonUsdcBroadcastDraft script =
            new PrepareBaseMainnetSunMoonUsdcBroadcastDraft();

        vm.expectRevert(
            abi.encodeWithSelector(
                PrepareBaseMainnetSunMoonUsdcBroadcastDraft.UnsupportedChain.selector,
                BaseV4Addresses.BASE_SEPOLIA_CHAIN_ID
            )
        );
        script.prepare(
            _draftConfig(
                address(fixture.poolManager),
                address(fixture.stateView),
                address(fixture.usdc),
                false,
                false,
                false
            )
        );
    }

    function _deployFixture(uint8 usdcDecimals) private returns (Fixture memory fixture) {
        fixture.usdc = new MockUSDT("Mock USDC", "USDC", usdcDecimals);
        fixture.poolManager = new PoolManager(mainnetAdminWallet);
        fixture.stateView = new StateView(IPoolManager(address(fixture.poolManager)));
    }

    function _draftConfig(
        address poolManager,
        address stateView,
        address usdc,
        bool draftConfirmed,
        bool executeRequested,
        bool privateKeyPresent
    )
        private
        view
        returns (PrepareBaseMainnetSunMoonUsdcBroadcastDraft
                    .MainnetBroadcastDraftConfig memory config)
    {
        config = PrepareBaseMainnetSunMoonUsdcBroadcastDraft.MainnetBroadcastDraftConfig({
                mainnetDeployer: mainnetDeployer,
                mainnetAdminWallet: mainnetAdminWallet,
                protocolBudgetWallet: protocolBudgetWallet,
                create2DeployerOwner: create2DeployerOwner,
                poolManager: poolManager,
                positionManager: positionManager,
                stateView: stateView,
                quoter: quoter,
                universalRouter: universalRouter,
                permit2: permit2,
                usdcToken: usdc,
                moonLaunchDelay: 0,
                sunUsdcFee: 3000,
                sunUsdcTickSpacing: 60,
                sunUsdcInitialTokenAmount: 1e18,
                sunUsdcInitialUsdcAmount: 1e6,
                moonUsdcFee: 3000,
                moonUsdcTickSpacing: 60,
                moonUsdcInitialTokenAmount: 1e18,
                moonUsdcInitialUsdcAmount: 240_000,
                hookSaltStart: 0,
                hookMaxSaltSearch: 300_000,
                expectedSunToken: address(0),
                expectedSunCurve: address(0),
                expectedMoonToken: address(0),
                expectedMoonCurve: address(0),
                expectedCreate2HookDeployer: address(0),
                expectedHookSalt: bytes32(0),
                expectedHook: address(0),
                expectedSunUsdcPoolId: bytes32(0),
                expectedMoonUsdcPoolId: bytes32(0),
                baseMainnetDraftConfirmed: draftConfirmed,
                executeRequested: executeRequested,
                privateKeyPresent: privateKeyPresent
            });
    }
}
