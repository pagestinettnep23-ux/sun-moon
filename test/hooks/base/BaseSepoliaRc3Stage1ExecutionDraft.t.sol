// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { Test } from "forge-std/Test.sol";
import { BaseV4Addresses } from "../../../contracts/hooks/base/BaseV4Addresses.sol";
import { Create2HookDeployer } from "../../../contracts/hooks/base/Create2HookDeployer.sol";
import { MockUSDT } from "../../../contracts/mocks/MockUSDT.sol";
import { MoonCurve } from "../../../contracts/MoonCurve.sol";
import { MoonToken } from "../../../contracts/MoonToken.sol";
import { SunCurve } from "../../../contracts/SunCurve.sol";
import { SunToken } from "../../../contracts/SunToken.sol";
import {
    PrepareBaseSepoliaRc3Stage1ExecutionDraft
} from "../../../script/PrepareBaseSepoliaRc3Stage1ExecutionDraft.s.sol";

contract BaseSepoliaRc3Stage1ExecutionDraftTest is Test {
    address internal sepoliaDeployer = makeAddr("sepoliaDeployer");
    address internal sepoliaAdminWallet = makeAddr("sepoliaAdminWallet");
    address internal sepoliaProtocolBudgetWallet = makeAddr("sepoliaProtocolBudgetWallet");
    address internal sepoliaCreate2Owner = makeAddr("sepoliaCreate2Owner");

    MockUSDT internal usdc;

    function setUp() public {
        usdc = new MockUSDT("Mock USDC", "USDC", 6);
    }

    function testLocalDefaultBuildsBlockedStage1PlanWithoutDeploying() public {
        vm.chainId(31_337);
        PrepareBaseSepoliaRc3Stage1ExecutionDraft script =
            new PrepareBaseSepoliaRc3Stage1ExecutionDraft();

        PrepareBaseSepoliaRc3Stage1ExecutionDraft.Stage1ExecutionPlan memory plan =
            script.prepare(_config(false, false, false, address(usdc)));

        assertEq(plan.chainId, 31_337);
        assertFalse(plan.stage1ExecutionConfirmed);
        assertFalse(plan.executeRequested);
        assertFalse(plan.privateKeyPresent);
        assertFalse(plan.broadcastAllowed);
        assertTrue(plan.executionBlocked);
        assertTrue(plan.simulationOnly);
        assertEq(plan.stage1TransactionsPlanned, 12);
        assertEq(plan.stage1CoreDeployer, sepoliaDeployer);
        assertEq(plan.stage1AdminWallet, sepoliaAdminWallet);
        assertEq(plan.stage1ProtocolBudgetWallet, sepoliaProtocolBudgetWallet);
        assertEq(plan.stage1Create2DeployerOwner, sepoliaCreate2Owner);
        assertEq(plan.usdcDecimals, 6);
        assertNotEq(plan.predictedSunToken, address(0));
        assertNotEq(plan.predictedSunCurve, address(0));
        assertNotEq(plan.predictedMoonToken, address(0));
        assertNotEq(plan.predictedMoonCurve, address(0));
        assertNotEq(plan.predictedCreate2HookDeployer, address(0));
        assertFalse(plan.stage1AddressCollision);
        assertEq(plan.deployedSunToken, address(0));
        assertEq(plan.deployedSunCurve, address(0));
        assertEq(plan.deployedMoonToken, address(0));
        assertEq(plan.deployedMoonCurve, address(0));
        assertEq(plan.deployedCreate2HookDeployer, address(0));
    }

    function testLocalConfirmedExecutionDeploysOnlyStage1Contracts() public {
        vm.chainId(31_337);
        PrepareBaseSepoliaRc3Stage1ExecutionDraft script =
            new PrepareBaseSepoliaRc3Stage1ExecutionDraft();

        PrepareBaseSepoliaRc3Stage1ExecutionDraft.Stage1ExecutionPlan memory plan =
            script.prepare(_config(true, true, false, address(usdc)));

        assertTrue(plan.stage1ExecutionConfirmed);
        assertTrue(plan.executeRequested);
        assertTrue(plan.broadcastAllowed);
        assertFalse(plan.executionBlocked);
        assertFalse(plan.simulationOnly);
        assertEq(plan.stage1TransactionsPlanned, 12);

        assertEq(plan.deployedSunToken, plan.predictedSunToken);
        assertEq(plan.deployedSunCurve, plan.predictedSunCurve);
        assertEq(plan.deployedMoonToken, plan.predictedMoonToken);
        assertEq(plan.deployedMoonCurve, plan.predictedMoonCurve);
        assertEq(plan.deployedCreate2HookDeployer, plan.predictedCreate2HookDeployer);

        SunToken sunToken = SunToken(plan.deployedSunToken);
        SunCurve sunCurve = SunCurve(plan.deployedSunCurve);
        MoonToken moonToken = MoonToken(plan.deployedMoonToken);
        MoonCurve moonCurve = MoonCurve(plan.deployedMoonCurve);
        Create2HookDeployer create2Deployer = Create2HookDeployer(plan.deployedCreate2HookDeployer);

        assertEq(sunToken.minter(), plan.deployedSunCurve);
        assertEq(sunCurve.moonCurve(), plan.deployedMoonCurve);
        assertEq(moonToken.minter(), plan.deployedMoonCurve);
        assertEq(sunToken.owner(), sepoliaAdminWallet);
        assertEq(sunCurve.owner(), sepoliaAdminWallet);
        assertEq(moonToken.owner(), sepoliaAdminWallet);
        assertEq(moonCurve.owner(), sepoliaAdminWallet);
        assertEq(create2Deployer.owner(), sepoliaCreate2Owner);
    }

    function testRejectsExecutionWithoutStage1Confirmation() public {
        vm.chainId(31_337);
        PrepareBaseSepoliaRc3Stage1ExecutionDraft script =
            new PrepareBaseSepoliaRc3Stage1ExecutionDraft();

        vm.expectRevert(
            PrepareBaseSepoliaRc3Stage1ExecutionDraft.Stage1ExecutionNotConfirmed.selector
        );
        script.prepare(_config(false, true, false, address(usdc)));
    }

    function testRejectsPrivateKeyPresence() public {
        vm.chainId(31_337);
        PrepareBaseSepoliaRc3Stage1ExecutionDraft script =
            new PrepareBaseSepoliaRc3Stage1ExecutionDraft();

        vm.expectRevert(PrepareBaseSepoliaRc3Stage1ExecutionDraft.PrivateKeyEnvNotAllowed.selector);
        script.prepare(_config(true, false, true, address(usdc)));
    }

    function testRejectsBaseMainnet() public {
        vm.chainId(BaseV4Addresses.BASE_MAINNET_CHAIN_ID);
        PrepareBaseSepoliaRc3Stage1ExecutionDraft script =
            new PrepareBaseSepoliaRc3Stage1ExecutionDraft();

        vm.expectRevert(
            abi.encodeWithSelector(
                PrepareBaseSepoliaRc3Stage1ExecutionDraft.BaseMainnetNotAllowed.selector,
                BaseV4Addresses.BASE_MAINNET_CHAIN_ID
            )
        );
        script.prepare(_config(false, false, false, address(usdc)));
    }

    function testBaseSepoliaRequiresExplicitConfirmation() public {
        vm.chainId(BaseV4Addresses.BASE_SEPOLIA_CHAIN_ID);
        _etchBaseSepoliaUsdc();
        PrepareBaseSepoliaRc3Stage1ExecutionDraft script =
            new PrepareBaseSepoliaRc3Stage1ExecutionDraft();

        vm.expectRevert(
            abi.encodeWithSelector(
                PrepareBaseSepoliaRc3Stage1ExecutionDraft.BaseSepoliaStage1ExecutionNotConfirmed
                .selector,
                BaseV4Addresses.BASE_SEPOLIA_CHAIN_ID
            )
        );
        script.prepare(_config(false, false, false, BaseV4Addresses.BASE_SEPOLIA_USDC));
    }

    function testBaseSepoliaConfirmedUsesOfficialUsdcAndRemainsBlockedWhenExecuteFalse() public {
        vm.chainId(BaseV4Addresses.BASE_SEPOLIA_CHAIN_ID);
        _etchBaseSepoliaUsdc();
        PrepareBaseSepoliaRc3Stage1ExecutionDraft script =
            new PrepareBaseSepoliaRc3Stage1ExecutionDraft();

        PrepareBaseSepoliaRc3Stage1ExecutionDraft.Stage1ExecutionPlan memory plan =
            script.prepare(_config(true, false, false, BaseV4Addresses.BASE_SEPOLIA_USDC));

        assertEq(plan.chainId, BaseV4Addresses.BASE_SEPOLIA_CHAIN_ID);
        assertTrue(plan.stage1ExecutionConfirmed);
        assertFalse(plan.executeRequested);
        assertFalse(plan.broadcastAllowed);
        assertTrue(plan.executionBlocked);
        assertTrue(plan.simulationOnly);
        assertEq(plan.usdcToken, BaseV4Addresses.BASE_SEPOLIA_USDC);
        assertEq(plan.usdcDecimals, 6);
        assertEq(plan.stage1TransactionsPlanned, 12);
    }

    function _config(
        bool confirmed,
        bool executeRequested,
        bool privateKeyPresent,
        address usdcToken
    )
        private
        view
        returns (PrepareBaseSepoliaRc3Stage1ExecutionDraft.Stage1ExecutionConfig memory config)
    {
        config = PrepareBaseSepoliaRc3Stage1ExecutionDraft.Stage1ExecutionConfig({
            sepoliaDeployer: sepoliaDeployer,
            sepoliaAdminWallet: sepoliaAdminWallet,
            sepoliaProtocolBudgetWallet: sepoliaProtocolBudgetWallet,
            sepoliaCreate2DeployerOwner: sepoliaCreate2Owner,
            usdcToken: usdcToken,
            moonLaunchDelay: 0,
            stage1ExecutionConfirmed: confirmed,
            executeRequested: executeRequested,
            privateKeyPresent: privateKeyPresent
        });
    }

    function _etchBaseSepoliaUsdc() private {
        deployCodeTo(
            "MockUSDT.sol:MockUSDT",
            abi.encode("Mock Base Sepolia USDC", "USDC", 6),
            BaseV4Addresses.BASE_SEPOLIA_USDC
        );
    }
}
