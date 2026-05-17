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

contract BaseSepoliaRc3SunMoonUsdcBroadcastDraftTest is Test {
    address internal sepoliaDeployer = makeAddr("sepoliaDeployer");
    address internal sepoliaAdminWallet = makeAddr("sepoliaAdminWallet");
    address internal sepoliaProtocolBudgetWallet = makeAddr("sepoliaProtocolBudgetWallet");
    address internal sepoliaCreate2Owner = makeAddr("sepoliaCreate2Owner");

    struct Fixture {
        MockUSDT usdc;
        PoolManager poolManager;
        StateView stateView;
    }

    function testLocalDraftBuildsPlanWithoutBroadcast() public {
        vm.chainId(31_337);
        Fixture memory fixture = _deployFixture(6);

        PrepareBaseSepoliaRc3SunMoonUsdcBroadcastDraft script =
            new PrepareBaseSepoliaRc3SunMoonUsdcBroadcastDraft();
        PrepareBaseSepoliaRc3SunMoonUsdcBroadcastDraft.Rc3BroadcastDraftPlan memory plan =
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
        assertFalse(plan.baseSepoliaDraftConfirmed);
        assertFalse(plan.executeRequested);
        assertFalse(plan.privateKeyPresent);
        assertFalse(plan.broadcastAllowed);
        assertTrue(plan.simulationOnly);
        assertEq(plan.stage1CoreDeployer, sepoliaDeployer);
        assertEq(plan.stage2HookDeployer, sepoliaCreate2Owner);
        assertEq(plan.stage2AdminWallet, sepoliaAdminWallet);
        assertEq(plan.stage3RenounceOwner, sepoliaAdminWallet);
        assertTrue(plan.requiresSeparateCoreAndAdminRuns);
        assertTrue(plan.requiresSeparateHookOwnerAndAdminRuns);
        assertEq(plan.stage1CoreDeploymentTxs, 12);
        assertEq(plan.stage2HookAndPoolTxs, 6);
        assertEq(plan.stage3RenounceTxs, 1);
        assertEq(plan.totalTransactionsPlanned, 19);
        assertNotEq(plan.predictedSunToken, address(0));
        assertNotEq(plan.predictedSunCurve, address(0));
        assertNotEq(plan.predictedMoonToken, address(0));
        assertNotEq(plan.predictedMoonCurve, address(0));
        assertNotEq(plan.predictedCreate2HookDeployer, address(0));
        assertNotEq(plan.predictedHook, address(0));
        assertNotEq(plan.sunUsdcPoolId, bytes32(0));
        assertNotEq(plan.moonUsdcPoolId, bytes32(0));
        assertNotEq(plan.sunUsdcPoolId, plan.moonUsdcPoolId);
        assertTrue(plan.sunUsdcAllowedAfterDryRun);
        assertTrue(plan.moonUsdcAllowedAfterDryRun);
        assertTrue(plan.renounceBlocksSunAllowlist);
        assertTrue(plan.renounceBlocksMoonAllowlist);
        assertTrue(plan.renounceBlocksProtocolBudget);
    }

    function testDraftUsesFewerStageOneTxsWhenDeployerIsAdmin() public {
        vm.chainId(31_337);
        Fixture memory fixture = _deployFixture(6);

        PrepareBaseSepoliaRc3SunMoonUsdcBroadcastDraft.Rc3BroadcastDraftConfig memory config =
            _draftConfig(
                address(fixture.poolManager),
                address(fixture.stateView),
                address(fixture.usdc),
                false,
                false,
                false
            );
        config.dryRunConfig.sepoliaDeployer = sepoliaAdminWallet;
        config.dryRunConfig.sepoliaCreate2DeployerOwner = sepoliaAdminWallet;

        PrepareBaseSepoliaRc3SunMoonUsdcBroadcastDraft script =
            new PrepareBaseSepoliaRc3SunMoonUsdcBroadcastDraft();
        PrepareBaseSepoliaRc3SunMoonUsdcBroadcastDraft.Rc3BroadcastDraftPlan memory plan =
            script.prepare(config);

        assertFalse(plan.requiresSeparateCoreAndAdminRuns);
        assertFalse(plan.requiresSeparateHookOwnerAndAdminRuns);
        assertEq(plan.stage1CoreDeploymentTxs, 8);
        assertEq(plan.stage2HookAndPoolTxs, 6);
        assertEq(plan.stage3RenounceTxs, 1);
        assertEq(plan.totalTransactionsPlanned, 15);
    }

    function testRejectsExecutionFlag() public {
        vm.chainId(31_337);
        Fixture memory fixture = _deployFixture(6);

        PrepareBaseSepoliaRc3SunMoonUsdcBroadcastDraft script =
            new PrepareBaseSepoliaRc3SunMoonUsdcBroadcastDraft();

        vm.expectRevert(
            PrepareBaseSepoliaRc3SunMoonUsdcBroadcastDraft.BroadcastExecutionNotAllowed.selector
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

        PrepareBaseSepoliaRc3SunMoonUsdcBroadcastDraft script =
            new PrepareBaseSepoliaRc3SunMoonUsdcBroadcastDraft();

        vm.expectRevert(
            PrepareBaseSepoliaRc3SunMoonUsdcBroadcastDraft.PrivateKeyEnvNotAllowed.selector
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

    function testRunRejectsPrivateKeyEnv() public {
        vm.chainId(31_337);
        vm.setEnv("PRIVATE_KEY", "0x1234");

        PrepareBaseSepoliaRc3SunMoonUsdcBroadcastDraft script =
            new PrepareBaseSepoliaRc3SunMoonUsdcBroadcastDraft();

        vm.expectRevert(
            PrepareBaseSepoliaRc3SunMoonUsdcBroadcastDraft.PrivateKeyEnvNotAllowed.selector
        );
        script.run();

        vm.setEnv("PRIVATE_KEY", "");
    }

    function testBaseSepoliaRequiresExplicitDraftConfirmation() public {
        vm.chainId(BaseV4Addresses.BASE_SEPOLIA_CHAIN_ID);
        _etchBaseSepoliaDependencies();

        PrepareBaseSepoliaRc3SunMoonUsdcBroadcastDraft script =
            new PrepareBaseSepoliaRc3SunMoonUsdcBroadcastDraft();

        vm.expectRevert(
            abi.encodeWithSelector(
                PrepareBaseSepoliaRc3SunMoonUsdcBroadcastDraft.BaseSepoliaRc3BroadcastDraftNotConfirmed
                    .selector,
                BaseV4Addresses.BASE_SEPOLIA_CHAIN_ID
            )
        );
        script.prepare(
            _baseSepoliaDraftConfig(BaseV4Addresses.BASE_SEPOLIA_USDC, false, false, false)
        );
    }

    function testBaseSepoliaUsesOfficialInfrastructureWhenConfirmed() public {
        vm.chainId(BaseV4Addresses.BASE_SEPOLIA_CHAIN_ID);
        _etchBaseSepoliaDependencies();

        PrepareBaseSepoliaRc3SunMoonUsdcBroadcastDraft script =
            new PrepareBaseSepoliaRc3SunMoonUsdcBroadcastDraft();
        PrepareBaseSepoliaRc3SunMoonUsdcBroadcastDraft.Rc3BroadcastDraftPlan memory plan =
            script.prepare(
                _baseSepoliaDraftConfig(BaseV4Addresses.BASE_SEPOLIA_USDC, true, false, false)
            );

        assertEq(plan.chainId, BaseV4Addresses.BASE_SEPOLIA_CHAIN_ID);
        assertTrue(plan.baseSepoliaDraftConfirmed);
        assertFalse(plan.executeRequested);
        assertFalse(plan.broadcastAllowed);
        assertTrue(plan.simulationOnly);
        assertEq(plan.stage1CoreDeploymentTxs, 12);
        assertEq(plan.stage2HookAndPoolTxs, 6);
        assertEq(plan.stage3RenounceTxs, 1);
        assertEq(plan.totalTransactionsPlanned, 19);
        assertTrue(plan.sunUsdcAllowedAfterDryRun);
        assertTrue(plan.moonUsdcAllowedAfterDryRun);
        assertTrue(plan.renounceBlocksSunAllowlist);
        assertTrue(plan.renounceBlocksMoonAllowlist);
        assertTrue(plan.renounceBlocksProtocolBudget);
    }

    function testRejectsBaseMainnet() public {
        vm.chainId(BaseV4Addresses.BASE_MAINNET_CHAIN_ID);

        PrepareBaseSepoliaRc3SunMoonUsdcBroadcastDraft script =
            new PrepareBaseSepoliaRc3SunMoonUsdcBroadcastDraft();

        vm.expectRevert(
            abi.encodeWithSelector(
                PrepareBaseSepoliaRc3SunMoonUsdcBroadcastDraft.BaseMainnetNotAllowed.selector,
                BaseV4Addresses.BASE_MAINNET_CHAIN_ID
            )
        );
        script.prepare(_draftConfig(address(0), address(0), address(0), false, false, false));
    }

    function testBaseSepoliaRejectsWrongUsdcThroughDryRunPrecheck() public {
        vm.chainId(BaseV4Addresses.BASE_SEPOLIA_CHAIN_ID);
        _etchBaseSepoliaDependencies();
        MockUSDT wrongUsdc = new MockUSDT("Wrong USDC", "wUSDC", 6);

        PrepareBaseSepoliaRc3SunMoonUsdcBroadcastDraft script =
            new PrepareBaseSepoliaRc3SunMoonUsdcBroadcastDraft();

        vm.expectRevert(
            abi.encodeWithSelector(
                PrepareBaseSepoliaRc3SunMoonUsdcDryRun.BaseSepoliaUnexpectedAddress.selector,
                bytes32("USDC_TOKEN"),
                BaseV4Addresses.BASE_SEPOLIA_USDC,
                address(wrongUsdc)
            )
        );
        script.prepare(_baseSepoliaDraftConfig(address(wrongUsdc), true, false, false));
    }

    function _deployFixture(uint8 usdcDecimals) private returns (Fixture memory fixture) {
        fixture.usdc = new MockUSDT("Mock USDC", "USDC", usdcDecimals);
        fixture.poolManager = new PoolManager(sepoliaAdminWallet);
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
        returns (PrepareBaseSepoliaRc3SunMoonUsdcBroadcastDraft
                    .Rc3BroadcastDraftConfig memory config)
    {
        config = PrepareBaseSepoliaRc3SunMoonUsdcBroadcastDraft.Rc3BroadcastDraftConfig({
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
                    baseSepoliaConfirmed: draftConfirmed,
                    broadcastRequested: false
                }),
                baseSepoliaDraftConfirmed: draftConfirmed,
                executeRequested: executeRequested,
                privateKeyPresent: privateKeyPresent
            });
    }

    function _baseSepoliaDraftConfig(
        address usdc,
        bool draftConfirmed,
        bool executeRequested,
        bool privateKeyPresent
    )
        private
        view
        returns (PrepareBaseSepoliaRc3SunMoonUsdcBroadcastDraft
                    .Rc3BroadcastDraftConfig memory config)
    {
        config = _draftConfig(
            BaseV4Addresses.BASE_SEPOLIA_POOL_MANAGER,
            BaseV4Addresses.BASE_SEPOLIA_STATE_VIEW,
            usdc,
            draftConfirmed,
            executeRequested,
            privateKeyPresent
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
