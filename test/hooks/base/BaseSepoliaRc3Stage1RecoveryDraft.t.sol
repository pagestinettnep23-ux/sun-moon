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
    PrepareBaseSepoliaRc3Stage1RecoveryDraft
} from "../../../script/PrepareBaseSepoliaRc3Stage1RecoveryDraft.s.sol";

contract BaseSepoliaRc3Stage1RecoveryDraftTest is Test {
    uint256 internal constant SUN_MAX_MINT_USDC = 10_000e6;
    uint64 internal constant RECOVERY_NONCE = 2;

    address internal sepoliaDeployer = makeAddr("sepoliaDeployer");
    address internal sepoliaAdminWallet = makeAddr("sepoliaAdminWallet");
    address internal sepoliaProtocolBudgetWallet = makeAddr("sepoliaProtocolBudgetWallet");
    address internal sepoliaCreate2Owner = makeAddr("sepoliaCreate2Owner");

    MockUSDT internal usdc;

    function setUp() public {
        usdc = new MockUSDT("Mock USDC", "USDC", 6);
    }

    function testLocalBuildsBlockedRecoveryPlanFromPartialState() public {
        vm.chainId(31_337);
        (address partialSunToken, address partialSunCurve) = _deployPartialState();
        PrepareBaseSepoliaRc3Stage1RecoveryDraft script =
            new PrepareBaseSepoliaRc3Stage1RecoveryDraft();

        PrepareBaseSepoliaRc3Stage1RecoveryDraft.Stage1RecoveryPlan memory plan = script.prepare(
            _config(false, false, false, address(usdc), partialSunToken, partialSunCurve)
        );

        assertEq(plan.chainId, 31_337);
        assertFalse(plan.recoveryConfirmed);
        assertFalse(plan.executeRequested);
        assertFalse(plan.privateKeyPresent);
        assertFalse(plan.broadcastAllowed);
        assertTrue(plan.executionBlocked);
        assertTrue(plan.simulationOnly);
        assertEq(plan.remainingTransactionsPlanned, 10);
        assertEq(plan.stage1CoreDeployerNonce, RECOVERY_NONCE);
        assertTrue(plan.recoveryNonceMatches);
        assertEq(plan.partialSunToken, partialSunToken);
        assertEq(plan.partialSunCurve, partialSunCurve);
        assertEq(plan.partialSunTokenOwner, sepoliaDeployer);
        assertEq(plan.partialSunCurveOwner, sepoliaDeployer);
        assertEq(plan.partialSunTokenMinter, address(0));
        assertEq(plan.partialSunCurveMoonCurve, address(0));
        assertTrue(plan.partialStateReady);
        assertNotEq(plan.predictedMoonToken, address(0));
        assertNotEq(plan.predictedMoonCurve, address(0));
        assertNotEq(plan.predictedCreate2HookDeployer, address(0));
        assertFalse(plan.remainingAddressCollision);
    }

    function testLocalConfirmedRecoveryExecutesOnlyRemainingStage1Actions() public {
        vm.chainId(31_337);
        (address partialSunToken, address partialSunCurve) = _deployPartialState();
        PrepareBaseSepoliaRc3Stage1RecoveryDraft script =
            new PrepareBaseSepoliaRc3Stage1RecoveryDraft();

        PrepareBaseSepoliaRc3Stage1RecoveryDraft.Stage1RecoveryPlan memory plan = script.prepare(
            _config(true, true, false, address(usdc), partialSunToken, partialSunCurve)
        );

        assertTrue(plan.recoveryConfirmed);
        assertTrue(plan.executeRequested);
        assertTrue(plan.broadcastAllowed);
        assertFalse(plan.executionBlocked);
        assertFalse(plan.simulationOnly);
        assertEq(plan.remainingTransactionsPlanned, 10);

        assertEq(plan.deployedMoonToken, plan.predictedMoonToken);
        assertEq(plan.deployedMoonCurve, plan.predictedMoonCurve);
        assertEq(plan.deployedCreate2HookDeployer, plan.predictedCreate2HookDeployer);

        SunToken sunToken = SunToken(partialSunToken);
        SunCurve sunCurve = SunCurve(partialSunCurve);
        MoonToken moonToken = MoonToken(plan.deployedMoonToken);
        MoonCurve moonCurve = MoonCurve(plan.deployedMoonCurve);
        Create2HookDeployer create2Deployer = Create2HookDeployer(plan.deployedCreate2HookDeployer);

        assertEq(sunToken.minter(), partialSunCurve);
        assertEq(sunCurve.moonCurve(), plan.deployedMoonCurve);
        assertEq(moonToken.minter(), plan.deployedMoonCurve);
        assertEq(sunToken.owner(), sepoliaAdminWallet);
        assertEq(sunCurve.owner(), sepoliaAdminWallet);
        assertEq(moonToken.owner(), sepoliaAdminWallet);
        assertEq(moonCurve.owner(), sepoliaAdminWallet);
        assertEq(create2Deployer.owner(), sepoliaCreate2Owner);
    }

    function testRejectsPrivateKeyPresence() public {
        vm.chainId(31_337);
        (address partialSunToken, address partialSunCurve) = _deployPartialState();
        PrepareBaseSepoliaRc3Stage1RecoveryDraft script =
            new PrepareBaseSepoliaRc3Stage1RecoveryDraft();

        vm.expectRevert(PrepareBaseSepoliaRc3Stage1RecoveryDraft.PrivateKeyEnvNotAllowed.selector);
        script.prepare(_config(true, false, true, address(usdc), partialSunToken, partialSunCurve));
    }

    function testRejectsRecoveryNonceMismatch() public {
        vm.chainId(31_337);
        (address partialSunToken, address partialSunCurve) = _deployPartialState();
        vm.setNonce(sepoliaDeployer, RECOVERY_NONCE + 1);
        PrepareBaseSepoliaRc3Stage1RecoveryDraft script =
            new PrepareBaseSepoliaRc3Stage1RecoveryDraft();

        vm.expectRevert(
            abi.encodeWithSelector(
                PrepareBaseSepoliaRc3Stage1RecoveryDraft.RecoveryNonceMismatch.selector,
                RECOVERY_NONCE,
                RECOVERY_NONCE + 1
            )
        );
        script.prepare(_config(true, false, false, address(usdc), partialSunToken, partialSunCurve));
    }

    function testRejectsBaseMainnet() public {
        vm.chainId(BaseV4Addresses.BASE_MAINNET_CHAIN_ID);
        (address partialSunToken, address partialSunCurve) = _deployPartialState();
        PrepareBaseSepoliaRc3Stage1RecoveryDraft script =
            new PrepareBaseSepoliaRc3Stage1RecoveryDraft();

        vm.expectRevert(
            abi.encodeWithSelector(
                PrepareBaseSepoliaRc3Stage1RecoveryDraft.BaseMainnetNotAllowed.selector,
                BaseV4Addresses.BASE_MAINNET_CHAIN_ID
            )
        );
        script.prepare(
            _config(false, false, false, address(usdc), partialSunToken, partialSunCurve)
        );
    }

    function _deployPartialState()
        private
        returns (address partialSunToken, address partialSunCurve)
    {
        partialSunToken = vm.computeCreateAddress(sepoliaDeployer, 0);
        partialSunCurve = vm.computeCreateAddress(sepoliaDeployer, 1);

        deployCodeTo(
            "SunToken.sol:SunToken", abi.encode("SUN", "SUN", sepoliaDeployer), partialSunToken
        );
        deployCodeTo(
            "SunCurve.sol:SunCurve",
            abi.encode(
                SunToken(partialSunToken),
                usdc,
                sepoliaProtocolBudgetWallet,
                SUN_MAX_MINT_USDC,
                sepoliaDeployer
            ),
            partialSunCurve
        );
        vm.setNonce(sepoliaDeployer, RECOVERY_NONCE);
    }

    function _config(
        bool confirmed,
        bool executeRequested,
        bool privateKeyPresent,
        address usdcToken,
        address partialSunToken,
        address partialSunCurve
    )
        private
        view
        returns (PrepareBaseSepoliaRc3Stage1RecoveryDraft.Stage1RecoveryConfig memory config)
    {
        config = PrepareBaseSepoliaRc3Stage1RecoveryDraft.Stage1RecoveryConfig({
            sepoliaDeployer: sepoliaDeployer,
            sepoliaAdminWallet: sepoliaAdminWallet,
            sepoliaProtocolBudgetWallet: sepoliaProtocolBudgetWallet,
            sepoliaCreate2DeployerOwner: sepoliaCreate2Owner,
            usdcToken: usdcToken,
            partialSunToken: partialSunToken,
            partialSunCurve: partialSunCurve,
            expectedRecoveryNonce: RECOVERY_NONCE,
            moonLaunchDelay: 0,
            recoveryConfirmed: confirmed,
            executeRequested: executeRequested,
            privateKeyPresent: privateKeyPresent
        });
    }
}
