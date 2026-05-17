// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { Test } from "forge-std/Test.sol";
import { BaseV4Addresses } from "../../../contracts/hooks/base/BaseV4Addresses.sol";
import { MockUSDT } from "../../../contracts/mocks/MockUSDT.sol";
import { PrepareBaseSepoliaTestDeploy } from "../../../script/PrepareBaseSepoliaTestDeploy.s.sol";

contract BaseSepoliaTestDeployPreparationTest is Test {
    address internal hookOwner = 0x6E22b2e6fFAA30Fe75B71d53d1eC469b4e97A986;
    address internal protocolBudget = 0x277ba3Cf597CdAaF958C301db3cF6a631F793039;

    function testLocalSimulationDeploysCurveCoreAndAdapterWithMockUsdc() public {
        _assertLocalSimulationDeploysCurveCoreAndAdapterWithMockUsdc();
    }

    function testBaseMainnetIsRejected() public {
        _assertBaseMainnetIsRejected();
    }

    function testBaseSepoliaRequiresExplicitConfirmation() public {
        _assertBaseSepoliaRequiresExplicitConfirmation();
    }

    function testBaseSepoliaRejectsMockUsdc() public {
        _assertBaseSepoliaRejectsMockUsdc();
    }

    function testBaseSepoliaRejectsWrongUsdc() public {
        _assertBaseSepoliaRejectsWrongUsdc();
    }

    function testBaseSepoliaUsesOfficialUsdcWhenConfirmed() public {
        _assertBaseSepoliaUsesOfficialUsdcWhenConfirmed();
    }

    function _assertLocalSimulationDeploysCurveCoreAndAdapterWithMockUsdc() private {
        vm.chainId(31_337);

        PrepareBaseSepoliaTestDeploy script = new PrepareBaseSepoliaTestDeploy();
        PrepareBaseSepoliaTestDeploy.Deployment memory deployment =
            script.deploy(_deployConfig(true, false, address(0)));

        assertEq(deployment.owner, hookOwner);
        assertEq(deployment.protocolBudget, protocolBudget);
        assertEq(deployment.temporaryAuthorizedHook, hookOwner);
        assertEq(deployment.chainId, 31_337);
        assertTrue(deployment.useMockUsdc);
        assertFalse(deployment.baseSepoliaConfirmed);
        assertEq(address(deployment.usdc), address(deployment.mockUsdc));
        assertEq(deployment.sunToken.owner(), hookOwner);
        assertEq(deployment.moonToken.owner(), hookOwner);
        assertEq(deployment.sunCurve.owner(), hookOwner);
        assertEq(deployment.moonCurve.owner(), hookOwner);
        assertEq(deployment.adapter.owner(), hookOwner);
        assertEq(deployment.adapter.authorizedHook(), hookOwner);
        assertEq(deployment.sunToken.minter(), address(deployment.sunCurve));
        assertEq(deployment.moonToken.minter(), address(deployment.moonCurve));
        assertEq(deployment.sunCurve.moonCurve(), address(deployment.moonCurve));
        assertEq(deployment.sunCurve.moonAMM(), address(0));
    }

    function _assertBaseMainnetIsRejected() private {
        vm.chainId(BaseV4Addresses.BASE_MAINNET_CHAIN_ID);

        PrepareBaseSepoliaTestDeploy script = new PrepareBaseSepoliaTestDeploy();

        vm.expectRevert(
            abi.encodeWithSelector(
                PrepareBaseSepoliaTestDeploy.BaseMainnetNotAllowed.selector,
                BaseV4Addresses.BASE_MAINNET_CHAIN_ID
            )
        );
        script.deploy(_deployConfig(true, false, address(0)));
    }

    function _assertBaseSepoliaRequiresExplicitConfirmation() private {
        vm.chainId(BaseV4Addresses.BASE_SEPOLIA_CHAIN_ID);

        PrepareBaseSepoliaTestDeploy script = new PrepareBaseSepoliaTestDeploy();

        vm.expectRevert(
            abi.encodeWithSelector(
                PrepareBaseSepoliaTestDeploy.BaseSepoliaRunNotConfirmed.selector,
                BaseV4Addresses.BASE_SEPOLIA_CHAIN_ID
            )
        );
        script.deploy(_deployConfig(false, false, BaseV4Addresses.BASE_SEPOLIA_USDC));
    }

    function _assertBaseSepoliaRejectsMockUsdc() private {
        vm.chainId(BaseV4Addresses.BASE_SEPOLIA_CHAIN_ID);

        PrepareBaseSepoliaTestDeploy script = new PrepareBaseSepoliaTestDeploy();

        vm.expectRevert(PrepareBaseSepoliaTestDeploy.BaseSepoliaMockUsdcNotAllowed.selector);
        script.deploy(_deployConfig(true, true, address(0)));
    }

    function _assertBaseSepoliaRejectsWrongUsdc() private {
        vm.chainId(BaseV4Addresses.BASE_SEPOLIA_CHAIN_ID);

        PrepareBaseSepoliaTestDeploy script = new PrepareBaseSepoliaTestDeploy();

        vm.expectRevert(
            abi.encodeWithSelector(
                PrepareBaseSepoliaTestDeploy.BaseSepoliaUnexpectedUsdc.selector,
                BaseV4Addresses.BASE_SEPOLIA_USDC,
                address(0x1234)
            )
        );
        script.deploy(_deployConfig(false, true, address(0x1234)));
    }

    function _assertBaseSepoliaUsesOfficialUsdcWhenConfirmed() private {
        vm.chainId(BaseV4Addresses.BASE_SEPOLIA_CHAIN_ID);
        _etchMockUsdcAtBaseSepoliaUsdc();

        PrepareBaseSepoliaTestDeploy script = new PrepareBaseSepoliaTestDeploy();
        PrepareBaseSepoliaTestDeploy.Deployment memory deployment =
            script.deploy(_deployConfig(false, true, BaseV4Addresses.BASE_SEPOLIA_USDC));

        assertTrue(deployment.baseSepoliaConfirmed);
        assertFalse(deployment.useMockUsdc);
        assertEq(address(deployment.usdc), BaseV4Addresses.BASE_SEPOLIA_USDC);
        assertEq(address(deployment.mockUsdc), address(0));
        assertEq(deployment.adapter.authorizedHook(), hookOwner);
        assertEq(deployment.sunCurve.moonAMM(), address(0));
    }

    function _deployConfig(bool useMockUsdc, bool baseSepoliaConfirmed, address usdcToken)
        private
        view
        returns (PrepareBaseSepoliaTestDeploy.DeployConfig memory config)
    {
        config = PrepareBaseSepoliaTestDeploy.DeployConfig({
            deployer: address(0),
            owner: hookOwner,
            protocolBudget: protocolBudget,
            temporaryAuthorizedHook: hookOwner,
            moonLaunchDelay: 0,
            useMockUsdc: useMockUsdc,
            baseSepoliaConfirmed: baseSepoliaConfirmed,
            usdcToken: usdcToken
        });
    }

    function _etchMockUsdcAtBaseSepoliaUsdc() private {
        MockUSDT mockUsdc = new MockUSDT("Mock Base Sepolia USDC", "mUSDC", 6);
        vm.etch(BaseV4Addresses.BASE_SEPOLIA_USDC, address(mockUsdc).code);
    }
}
