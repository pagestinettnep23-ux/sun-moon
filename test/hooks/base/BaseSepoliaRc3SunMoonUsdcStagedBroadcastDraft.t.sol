// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { Test } from "forge-std/Test.sol";
import { IPoolManager } from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import { PoolManager } from "@uniswap/v4-core/src/PoolManager.sol";
import { StateView } from "@uniswap/v4-periphery/src/lens/StateView.sol";
import { MockUSDT } from "../../../contracts/mocks/MockUSDT.sol";
import { BaseV4Addresses } from "../../../contracts/hooks/base/BaseV4Addresses.sol";
import {
    PrepareBaseSepoliaRc3SunMoonUsdcBroadcastDraft
} from "../../../script/PrepareBaseSepoliaRc3SunMoonUsdcBroadcastDraft.s.sol";
import {
    PrepareBaseSepoliaRc3SunMoonUsdcDryRun
} from "../../../script/PrepareBaseSepoliaRc3SunMoonUsdcDryRun.s.sol";
import {
    PrepareBaseSepoliaRc3SunMoonUsdcStagedBroadcastDraft
} from "../../../script/PrepareBaseSepoliaRc3SunMoonUsdcStagedBroadcastDraft.s.sol";

contract BaseSepoliaRc3SunMoonUsdcStagedBroadcastDraftTest is Test {
    address internal sepoliaDeployer = makeAddr("sepoliaDeployer");
    address internal sepoliaAdminWallet = makeAddr("sepoliaAdminWallet");
    address internal sepoliaProtocolBudgetWallet = makeAddr("sepoliaProtocolBudgetWallet");
    address internal sepoliaCreate2Owner = makeAddr("sepoliaCreate2Owner");

    struct Fixture {
        MockUSDT usdc;
        PoolManager poolManager;
        StateView stateView;
    }

    function testLocalStageZeroBuildsBlockedPlanWithoutBroadcast() public {
        vm.chainId(31_337);
        Fixture memory fixture = _deployFixture(6);

        PrepareBaseSepoliaRc3SunMoonUsdcStagedBroadcastDraft script =
            new PrepareBaseSepoliaRc3SunMoonUsdcStagedBroadcastDraft();
        PrepareBaseSepoliaRc3SunMoonUsdcStagedBroadcastDraft.StagedBroadcastPlan memory plan =
            script.prepare(
                _stagedConfig(
                    address(fixture.poolManager),
                    address(fixture.stateView),
                    address(fixture.usdc),
                    false,
                    0,
                    false,
                    false
                )
            );

        assertEq(plan.chainId, 31_337);
        assertFalse(plan.stagedDraftConfirmed);
        assertEq(plan.selectedStage, 0);
        assertFalse(plan.executeRequested);
        assertFalse(plan.privateKeyPresent);
        assertFalse(plan.broadcastAllowed);
        assertTrue(plan.executionBlocked);
        assertTrue(plan.simulationOnly);
        assertEq(plan.stage1CoreDeployer, sepoliaDeployer);
        assertEq(plan.stage2HookDeployer, sepoliaCreate2Owner);
        assertEq(plan.stage2AdminWallet, sepoliaAdminWallet);
        assertEq(plan.stage3RenounceOwner, sepoliaAdminWallet);
        assertEq(plan.stage1CoreDeploymentTxs, 12);
        assertEq(plan.stage2HookAndPoolTxs, 6);
        assertEq(plan.stage3RenounceTxs, 1);
        assertEq(plan.selectedStageTxs, 19);
        assertEq(plan.totalTransactionsPlanned, 19);
        assertNotEq(plan.predictedSunToken, address(0));
        assertNotEq(plan.predictedHook, address(0));
        assertNotEq(plan.sunUsdcPoolId, bytes32(0));
        assertNotEq(plan.moonUsdcPoolId, bytes32(0));
        assertFalse(plan.stage1AddressCollision);
        assertFalse(plan.stage2HookCollision);
    }

    function testSelectedStagesExposeExpectedTransactionCounts() public {
        vm.chainId(31_337);
        Fixture memory fixture = _deployFixture(6);
        PrepareBaseSepoliaRc3SunMoonUsdcStagedBroadcastDraft script =
            new PrepareBaseSepoliaRc3SunMoonUsdcStagedBroadcastDraft();

        assertEq(
            script.prepare(
                _stagedConfig(
                    address(fixture.poolManager),
                    address(fixture.stateView),
                    address(fixture.usdc),
                    false,
                    1,
                    false,
                    false
                )
            )
            .selectedStageTxs,
            12
        );
        assertEq(
            script.prepare(
                _stagedConfig(
                    address(fixture.poolManager),
                    address(fixture.stateView),
                    address(fixture.usdc),
                    false,
                    2,
                    false,
                    false
                )
            )
            .selectedStageTxs,
            6
        );
        assertEq(
            script.prepare(
                _stagedConfig(
                    address(fixture.poolManager),
                    address(fixture.stateView),
                    address(fixture.usdc),
                    false,
                    3,
                    false,
                    false
                )
            )
            .selectedStageTxs,
            1
        );
    }

    function testRejectsInvalidStage() public {
        vm.chainId(31_337);
        Fixture memory fixture = _deployFixture(6);
        PrepareBaseSepoliaRc3SunMoonUsdcStagedBroadcastDraft script =
            new PrepareBaseSepoliaRc3SunMoonUsdcStagedBroadcastDraft();

        vm.expectRevert(
            abi.encodeWithSelector(
                PrepareBaseSepoliaRc3SunMoonUsdcStagedBroadcastDraft.InvalidStage.selector, uint8(4)
            )
        );
        script.prepare(
            _stagedConfig(
                address(fixture.poolManager),
                address(fixture.stateView),
                address(fixture.usdc),
                false,
                4,
                false,
                false
            )
        );
    }

    function testRejectsExecutionFlag() public {
        vm.chainId(31_337);
        Fixture memory fixture = _deployFixture(6);
        PrepareBaseSepoliaRc3SunMoonUsdcStagedBroadcastDraft script =
            new PrepareBaseSepoliaRc3SunMoonUsdcStagedBroadcastDraft();

        vm.expectRevert(
            PrepareBaseSepoliaRc3SunMoonUsdcStagedBroadcastDraft.BroadcastExecutionNotAllowed
            .selector
        );
        script.prepare(
            _stagedConfig(
                address(fixture.poolManager),
                address(fixture.stateView),
                address(fixture.usdc),
                false,
                1,
                true,
                false
            )
        );
    }

    function testRejectsPrivateKeyPresence() public {
        vm.chainId(31_337);
        Fixture memory fixture = _deployFixture(6);
        PrepareBaseSepoliaRc3SunMoonUsdcStagedBroadcastDraft script =
            new PrepareBaseSepoliaRc3SunMoonUsdcStagedBroadcastDraft();

        vm.expectRevert(
            PrepareBaseSepoliaRc3SunMoonUsdcStagedBroadcastDraft.PrivateKeyEnvNotAllowed.selector
        );
        script.prepare(
            _stagedConfig(
                address(fixture.poolManager),
                address(fixture.stateView),
                address(fixture.usdc),
                false,
                1,
                false,
                true
            )
        );
    }

    function testBaseSepoliaRequiresExplicitConfirmation() public {
        vm.chainId(BaseV4Addresses.BASE_SEPOLIA_CHAIN_ID);
        _etchBaseSepoliaDependencies();
        PrepareBaseSepoliaRc3SunMoonUsdcStagedBroadcastDraft script =
            new PrepareBaseSepoliaRc3SunMoonUsdcStagedBroadcastDraft();

        vm.expectRevert(
            abi.encodeWithSelector(
                PrepareBaseSepoliaRc3SunMoonUsdcStagedBroadcastDraft.BaseSepoliaStagedBroadcastDraftNotConfirmed
                    .selector,
                BaseV4Addresses.BASE_SEPOLIA_CHAIN_ID
            )
        );
        script.prepare(_baseSepoliaStagedConfig(BaseV4Addresses.BASE_SEPOLIA_USDC, false, 0));
    }

    function testBaseSepoliaConfirmedUsesOfficialInfrastructure() public {
        vm.chainId(BaseV4Addresses.BASE_SEPOLIA_CHAIN_ID);
        _etchBaseSepoliaDependencies();
        PrepareBaseSepoliaRc3SunMoonUsdcStagedBroadcastDraft script =
            new PrepareBaseSepoliaRc3SunMoonUsdcStagedBroadcastDraft();

        PrepareBaseSepoliaRc3SunMoonUsdcStagedBroadcastDraft.StagedBroadcastPlan memory plan =
            script.prepare(_baseSepoliaStagedConfig(BaseV4Addresses.BASE_SEPOLIA_USDC, true, 0));

        assertEq(plan.chainId, BaseV4Addresses.BASE_SEPOLIA_CHAIN_ID);
        assertTrue(plan.stagedDraftConfirmed);
        assertFalse(plan.broadcastAllowed);
        assertTrue(plan.executionBlocked);
        assertEq(plan.totalTransactionsPlanned, 19);
        assertFalse(plan.stage1AddressCollision);
        assertFalse(plan.stage2HookCollision);
    }

    function testRejectsBaseMainnet() public {
        vm.chainId(BaseV4Addresses.BASE_MAINNET_CHAIN_ID);
        PrepareBaseSepoliaRc3SunMoonUsdcStagedBroadcastDraft script =
            new PrepareBaseSepoliaRc3SunMoonUsdcStagedBroadcastDraft();

        vm.expectRevert(
            abi.encodeWithSelector(
                PrepareBaseSepoliaRc3SunMoonUsdcStagedBroadcastDraft.BaseMainnetNotAllowed.selector,
                BaseV4Addresses.BASE_MAINNET_CHAIN_ID
            )
        );
        script.prepare(_stagedConfig(address(0), address(0), address(0), false, 0, false, false));
    }

    function _deployFixture(uint8 usdcDecimals) private returns (Fixture memory fixture) {
        fixture.usdc = new MockUSDT("Mock USDC", "USDC", usdcDecimals);
        fixture.poolManager = new PoolManager(sepoliaAdminWallet);
        fixture.stateView = new StateView(IPoolManager(address(fixture.poolManager)));
    }

    function _stagedConfig(
        address poolManager,
        address stateView,
        address usdc,
        bool confirmed,
        uint8 selectedStage,
        bool executeRequested,
        bool privateKeyPresent
    )
        private
        view
        returns (PrepareBaseSepoliaRc3SunMoonUsdcStagedBroadcastDraft
                    .StagedBroadcastConfig memory config)
    {
        config = PrepareBaseSepoliaRc3SunMoonUsdcStagedBroadcastDraft.StagedBroadcastConfig({
                draftConfig: PrepareBaseSepoliaRc3SunMoonUsdcBroadcastDraft.Rc3BroadcastDraftConfig({
                    dryRunConfig: PrepareBaseSepoliaRc3SunMoonUsdcDryRun.Rc3DryRunConfig({
                        sepoliaDeployer: sepoliaDeployer,
                        sepoliaAdminWallet: sepoliaAdminWallet,
                        sepoliaProtocolBudgetWallet: sepoliaProtocolBudgetWallet,
                        sepoliaCreate2DeployerOwner: sepoliaCreate2Owner,
                        poolManager: poolManager,
                        stateView: stateView,
                        usdcToken: usdc,
                        moonLaunchDelay: 0,
                        sunUsdcFee: 3000,
                        sunUsdcTickSpacing: 60,
                        sunUsdcInitialTokenAmount: 1e18,
                        sunUsdcInitialUsdcAmount: 1e6,
                        expectedSunUsdcPoolId: bytes32(0),
                        moonUsdcFee: 3000,
                        moonUsdcTickSpacing: 60,
                        moonUsdcInitialTokenAmount: 1e18,
                        moonUsdcInitialUsdcAmount: 240_000,
                        expectedMoonUsdcPoolId: bytes32(0),
                        hookSaltStart: 0,
                        hookMaxSaltSearch: 300_000,
                        baseSepoliaConfirmed: confirmed,
                        broadcastRequested: false
                    }),
                    baseSepoliaDraftConfirmed: confirmed,
                    executeRequested: false,
                    privateKeyPresent: false
                }),
                stagedDraftConfirmed: confirmed,
                selectedStage: selectedStage,
                executeRequested: executeRequested,
                privateKeyPresent: privateKeyPresent
            });
    }

    function _baseSepoliaStagedConfig(address usdc, bool confirmed, uint8 selectedStage)
        private
        view
        returns (PrepareBaseSepoliaRc3SunMoonUsdcStagedBroadcastDraft
                    .StagedBroadcastConfig memory config)
    {
        config = _stagedConfig(
            BaseV4Addresses.BASE_SEPOLIA_POOL_MANAGER,
            BaseV4Addresses.BASE_SEPOLIA_STATE_VIEW,
            usdc,
            confirmed,
            selectedStage,
            false,
            false
        );
    }

    function _etchBaseSepoliaDependencies() private {
        deployCodeTo(
            "PoolManager.sol:PoolManager",
            abi.encode(sepoliaAdminWallet),
            BaseV4Addresses.BASE_SEPOLIA_POOL_MANAGER
        );
        deployCodeTo(
            "StateView.sol:StateView",
            abi.encode(IPoolManager(BaseV4Addresses.BASE_SEPOLIA_POOL_MANAGER)),
            BaseV4Addresses.BASE_SEPOLIA_STATE_VIEW
        );
        deployCodeTo(
            "MockUSDT.sol:MockUSDT",
            abi.encode("Mock Base Sepolia USDC", "USDC", 6),
            BaseV4Addresses.BASE_SEPOLIA_USDC
        );
    }
}
