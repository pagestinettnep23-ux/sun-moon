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
    PrepareBaseSepoliaRc3Stage1SingleStepDraft
} from "../../../script/PrepareBaseSepoliaRc3Stage1SingleStepDraft.s.sol";

contract BaseSepoliaRc3Stage1SingleStepDraftTest is Test {
    uint256 internal constant SUN_MAX_MINT_USDC = 10_000e6;
    uint64 internal constant FIRST_LOCAL_SINGLE_STEP_NONCE = 3;
    uint8 internal constant SINGLE_STEP_COUNT = 9;

    address internal sepoliaDeployer = makeAddr("sepoliaDeployer");
    address internal sepoliaAdminWallet = makeAddr("sepoliaAdminWallet");
    address internal sepoliaProtocolBudgetWallet = makeAddr("sepoliaProtocolBudgetWallet");
    address internal sepoliaCreate2Owner = makeAddr("sepoliaCreate2Owner");

    MockUSDT internal usdc;

    function setUp() public {
        usdc = new MockUSDT("Mock USDC", "USDC", 6);
    }

    function testLocalBuildsBlockedSingleStepPlanFromPartialState() public {
        vm.chainId(31_337);
        PartialState memory state = _deployPartialState();
        PrepareBaseSepoliaRc3Stage1SingleStepDraft script =
            new PrepareBaseSepoliaRc3Stage1SingleStepDraft();

        PrepareBaseSepoliaRc3Stage1SingleStepDraft.SingleStepPlan memory plan =
            script.prepare(_config(state, 1, FIRST_LOCAL_SINGLE_STEP_NONCE, false, false, false));

        assertEq(plan.chainId, 31_337);
        assertEq(plan.step, 1);
        assertFalse(plan.stepConfirmed);
        assertFalse(plan.executeRequested);
        assertFalse(plan.privateKeyPresent);
        assertFalse(plan.broadcastAllowed);
        assertTrue(plan.executionBlocked);
        assertTrue(plan.simulationOnly);
        assertEq(plan.stage1CoreDeployerNonce, FIRST_LOCAL_SINGLE_STEP_NONCE);
        assertEq(plan.expectedNonce, FIRST_LOCAL_SINGLE_STEP_NONCE);
        assertTrue(plan.nonceMatches);
        assertTrue(plan.ready);
        assertEq(plan.sunToken, state.sunToken);
        assertEq(plan.sunCurve, state.sunCurve);
        assertEq(plan.moonToken, state.moonToken);
        assertEq(plan.moonCurve, state.moonCurve);
        assertEq(plan.create2HookDeployer, state.create2HookDeployer);
        assertFalse(plan.moonCurveHasCode);
        assertFalse(plan.create2HookDeployerHasCode);
        assertEq(plan.sunTokenOwner, sepoliaDeployer);
        assertEq(plan.sunCurveOwner, sepoliaDeployer);
        assertEq(plan.moonTokenOwner, sepoliaDeployer);
        assertEq(plan.sunTokenMinter, address(0));
        assertEq(plan.sunCurveMoonCurve, address(0));
        assertEq(plan.moonTokenMinter, address(0));
    }

    function testLocalConfirmedStepsExecuteExactlyOneActionEach() public {
        vm.chainId(31_337);
        PartialState memory state = _deployPartialState();
        PrepareBaseSepoliaRc3Stage1SingleStepDraft script =
            new PrepareBaseSepoliaRc3Stage1SingleStepDraft();

        _executeStep(script, state, 1);
        assertEq(state.moonCurve.code.length > 0, true);
        assertEq(state.create2HookDeployer.code.length, 0);
        assertEq(MoonCurve(state.moonCurve).owner(), sepoliaDeployer);
        assertEq(SunToken(state.sunToken).minter(), address(0));

        _executeStep(script, state, 2);
        assertEq(state.create2HookDeployer.code.length > 0, true);
        assertEq(Create2HookDeployer(state.create2HookDeployer).owner(), sepoliaCreate2Owner);
        assertEq(SunToken(state.sunToken).minter(), address(0));

        _executeStep(script, state, 3);
        assertEq(SunToken(state.sunToken).minter(), state.sunCurve);
        assertEq(SunCurve(state.sunCurve).moonCurve(), address(0));

        _executeStep(script, state, 4);
        assertEq(SunCurve(state.sunCurve).moonCurve(), state.moonCurve);
        assertEq(MoonToken(state.moonToken).minter(), address(0));

        _executeStep(script, state, 5);
        assertEq(MoonToken(state.moonToken).minter(), state.moonCurve);
        assertEq(SunToken(state.sunToken).owner(), sepoliaDeployer);

        _executeStep(script, state, 6);
        assertEq(SunToken(state.sunToken).owner(), sepoliaAdminWallet);
        assertEq(SunCurve(state.sunCurve).owner(), sepoliaDeployer);

        _executeStep(script, state, 7);
        assertEq(SunCurve(state.sunCurve).owner(), sepoliaAdminWallet);
        assertEq(MoonToken(state.moonToken).owner(), sepoliaDeployer);

        _executeStep(script, state, 8);
        assertEq(MoonToken(state.moonToken).owner(), sepoliaAdminWallet);
        assertEq(MoonCurve(state.moonCurve).owner(), sepoliaDeployer);

        _executeStep(script, state, 9);
        assertEq(MoonCurve(state.moonCurve).owner(), sepoliaAdminWallet);
    }

    function testRejectsInvalidStepBeforeNonceDefaultCanUnderflow() public {
        vm.chainId(31_337);
        PartialState memory state = _deployPartialState();
        PrepareBaseSepoliaRc3Stage1SingleStepDraft script =
            new PrepareBaseSepoliaRc3Stage1SingleStepDraft();

        vm.expectRevert(
            abi.encodeWithSelector(
                PrepareBaseSepoliaRc3Stage1SingleStepDraft.InvalidStep.selector, 0
            )
        );
        script.prepare(_config(state, 0, FIRST_LOCAL_SINGLE_STEP_NONCE, false, false, false));

        vm.expectRevert(
            abi.encodeWithSelector(
                PrepareBaseSepoliaRc3Stage1SingleStepDraft.InvalidStep.selector, 10
            )
        );
        script.prepare(_config(state, 10, FIRST_LOCAL_SINGLE_STEP_NONCE, false, false, false));
    }

    function testRejectsPrivateKeyPresence() public {
        vm.chainId(31_337);
        PartialState memory state = _deployPartialState();
        PrepareBaseSepoliaRc3Stage1SingleStepDraft script =
            new PrepareBaseSepoliaRc3Stage1SingleStepDraft();

        vm.expectRevert(PrepareBaseSepoliaRc3Stage1SingleStepDraft.PrivateKeyEnvNotAllowed.selector);
        script.prepare(_config(state, 1, FIRST_LOCAL_SINGLE_STEP_NONCE, true, false, false));
    }

    function testRejectsNonceMismatch() public {
        vm.chainId(31_337);
        PartialState memory state = _deployPartialState();
        PrepareBaseSepoliaRc3Stage1SingleStepDraft script =
            new PrepareBaseSepoliaRc3Stage1SingleStepDraft();

        vm.expectRevert(
            abi.encodeWithSelector(
                PrepareBaseSepoliaRc3Stage1SingleStepDraft.NonceMismatch.selector,
                FIRST_LOCAL_SINGLE_STEP_NONCE + 1,
                FIRST_LOCAL_SINGLE_STEP_NONCE
            )
        );
        script.prepare(_config(state, 1, FIRST_LOCAL_SINGLE_STEP_NONCE + 1, false, false, false));
    }

    function testRejectsBaseMainnet() public {
        vm.chainId(BaseV4Addresses.BASE_MAINNET_CHAIN_ID);
        PartialState memory state = _deployPartialState();
        PrepareBaseSepoliaRc3Stage1SingleStepDraft script =
            new PrepareBaseSepoliaRc3Stage1SingleStepDraft();

        vm.expectRevert(
            abi.encodeWithSelector(
                PrepareBaseSepoliaRc3Stage1SingleStepDraft.BaseMainnetNotAllowed.selector,
                BaseV4Addresses.BASE_MAINNET_CHAIN_ID
            )
        );
        script.prepare(_config(state, 1, FIRST_LOCAL_SINGLE_STEP_NONCE, false, false, false));
    }

    struct PartialState {
        address sunToken;
        address sunCurve;
        address moonToken;
        address moonCurve;
        address create2HookDeployer;
    }

    function _deployPartialState() private returns (PartialState memory state) {
        state.sunToken = vm.computeCreateAddress(sepoliaDeployer, 0);
        state.sunCurve = vm.computeCreateAddress(sepoliaDeployer, 1);
        state.moonToken = vm.computeCreateAddress(sepoliaDeployer, 2);
        state.moonCurve = vm.computeCreateAddress(sepoliaDeployer, FIRST_LOCAL_SINGLE_STEP_NONCE);
        state.create2HookDeployer =
            vm.computeCreateAddress(sepoliaDeployer, FIRST_LOCAL_SINGLE_STEP_NONCE + 1);

        deployCodeTo(
            "SunToken.sol:SunToken", abi.encode("SUN", "SUN", sepoliaDeployer), state.sunToken
        );
        deployCodeTo(
            "SunCurve.sol:SunCurve",
            abi.encode(
                SunToken(state.sunToken),
                usdc,
                sepoliaProtocolBudgetWallet,
                SUN_MAX_MINT_USDC,
                sepoliaDeployer
            ),
            state.sunCurve
        );
        deployCodeTo(
            "MoonToken.sol:MoonToken", abi.encode("MOON", "MOON", sepoliaDeployer), state.moonToken
        );
        vm.setNonce(sepoliaDeployer, FIRST_LOCAL_SINGLE_STEP_NONCE);
    }

    function _executeStep(
        PrepareBaseSepoliaRc3Stage1SingleStepDraft script,
        PartialState memory state,
        uint8 step
    ) private {
        uint256 expectedNonce = FIRST_LOCAL_SINGLE_STEP_NONCE + step - 1;

        PrepareBaseSepoliaRc3Stage1SingleStepDraft.SingleStepPlan memory plan =
            script.prepare(_config(state, step, expectedNonce, false, true, true));

        assertEq(plan.step, step);
        assertTrue(plan.stepConfirmed);
        assertTrue(plan.executeRequested);
        assertTrue(plan.broadcastAllowed);
        assertFalse(plan.executionBlocked);
        assertFalse(plan.simulationOnly);
        assertTrue(plan.ready);

        if (step <= 2) {
            assertEq(vm.getNonce(sepoliaDeployer), expectedNonce + 1);
        } else {
            // Foundry's local broadcast simulation does not advance nonce for ordinary calls.
            // Base Sepolia will advance it because each step is one signed transaction.
            vm.setNonce(sepoliaDeployer, uint64(expectedNonce + 1));
        }
    }

    function _config(
        PartialState memory state,
        uint256 step,
        uint256 expectedNonce,
        bool privateKeyPresent,
        bool confirmed,
        bool executeRequested
    )
        private
        view
        returns (PrepareBaseSepoliaRc3Stage1SingleStepDraft.SingleStepConfig memory config)
    {
        config = PrepareBaseSepoliaRc3Stage1SingleStepDraft.SingleStepConfig({
            step: step,
            sepoliaDeployer: sepoliaDeployer,
            sepoliaAdminWallet: sepoliaAdminWallet,
            sepoliaProtocolBudgetWallet: sepoliaProtocolBudgetWallet,
            sepoliaCreate2DeployerOwner: sepoliaCreate2Owner,
            usdcToken: address(usdc),
            sunToken: state.sunToken,
            sunCurve: state.sunCurve,
            moonToken: state.moonToken,
            moonCurve: state.moonCurve,
            create2HookDeployer: state.create2HookDeployer,
            expectedNonce: expectedNonce,
            moonLaunchDelay: 0,
            stepConfirmed: confirmed,
            executeRequested: executeRequested,
            privateKeyPresent: privateKeyPresent
        });
    }
}
