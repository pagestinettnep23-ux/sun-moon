// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { Test } from "forge-std/Test.sol";
import { BaseV4Addresses } from "../../../contracts/hooks/base/BaseV4Addresses.sol";
import { MockUSDT } from "../../../contracts/mocks/MockUSDT.sol";
import {
    PrepareBaseMainnetCoreDeployDryRun
} from "../../../script/PrepareBaseMainnetCoreDeployDryRun.s.sol";

contract BaseMainnetCoreDeployDryRunPreparationTest is Test {
    address internal mainnetDeployer = 0xC0b399aE61d3Fb14EFE865A0304f0FC4b52b7B7b;
    address internal mainnetAdminWallet = 0xD37BDC458EdCe7006dDd3ce03eEBF29d629B2D6B;
    address internal protocolBudgetWallet = 0x215F1F09b765C0e893E8D7A40d51Bceb40B733F4;
    address internal create2DeployerOwner = 0xf28020011C5e35329A78Cc4bCb34b2cA20958380;

    function testLocalSimulationDeploysCoreWithMockUsdcAndPredictsCreateAddresses() public {
        vm.chainId(31_337);
        vm.setNonce(mainnetDeployer, 42);

        PrepareBaseMainnetCoreDeployDryRun script = new PrepareBaseMainnetCoreDeployDryRun();
        PrepareBaseMainnetCoreDeployDryRun.CoreDeployPlan memory plan =
            script.prepare(_config(address(0), 3600, false, false));

        assertEq(plan.chainId, 31_337);
        assertTrue(plan.simulationOnly);
        assertEq(plan.transactionsPlanned, 12);
        assertEq(plan.mainnetDeployer, mainnetDeployer);
        assertEq(plan.mainnetDeployerNonce, 42);
        assertEq(plan.mainnetAdminWallet, mainnetAdminWallet);
        assertEq(plan.protocolBudgetWallet, protocolBudgetWallet);
        assertEq(plan.create2DeployerOwner, create2DeployerOwner);
        assertEq(plan.usdcToken, address(plan.mockUsdc));
        assertEq(plan.usdcDecimals, 6);
        assertEq(plan.moonLaunchTime, block.timestamp + 3600);

        _assertPredictedAddresses(plan, 42);
        _assertSimulation(plan);
    }

    function testLocalSimulationCanUseConfiguredUsdc() public {
        vm.chainId(31_337);
        MockUSDT usdc = new MockUSDT("Configured USDC", "USDC", 6);

        PrepareBaseMainnetCoreDeployDryRun script = new PrepareBaseMainnetCoreDeployDryRun();
        PrepareBaseMainnetCoreDeployDryRun.CoreDeployPlan memory plan =
            script.prepare(_config(address(usdc), 0, false, false));

        assertEq(plan.usdcToken, address(usdc));
        assertEq(address(plan.mockUsdc), address(0));
        _assertSimulation(plan);
    }

    function testRunLoadsPublicMainnetRoleEnvWithoutBroadcast() public {
        vm.chainId(31_337);
        vm.setNonce(mainnetDeployer, 7);
        _setRunEnv(address(0), "0", "0");

        PrepareBaseMainnetCoreDeployDryRun script = new PrepareBaseMainnetCoreDeployDryRun();
        PrepareBaseMainnetCoreDeployDryRun.CoreDeployPlan memory plan = script.run();

        assertEq(plan.mainnetDeployer, mainnetDeployer);
        assertEq(plan.mainnetAdminWallet, mainnetAdminWallet);
        assertEq(plan.protocolBudgetWallet, protocolBudgetWallet);
        assertEq(plan.create2DeployerOwner, create2DeployerOwner);
        assertEq(plan.mainnetDeployerNonce, 7);
        _assertPredictedAddresses(plan, 7);
        _assertSimulation(plan);
    }

    function testBaseMainnetDryRunUsesOfficialUsdcWhenConfirmed() public {
        vm.chainId(BaseV4Addresses.BASE_MAINNET_CHAIN_ID);
        _etchMockUsdcAt(BaseV4Addresses.BASE_MAINNET_USDC, 6);
        vm.setNonce(mainnetDeployer, 11);

        PrepareBaseMainnetCoreDeployDryRun script = new PrepareBaseMainnetCoreDeployDryRun();
        PrepareBaseMainnetCoreDeployDryRun.CoreDeployPlan memory plan =
            script.prepare(_config(address(0), 0, true, false));

        assertEq(plan.chainId, BaseV4Addresses.BASE_MAINNET_CHAIN_ID);
        assertTrue(plan.baseMainnetConfirmed);
        assertEq(plan.usdcToken, BaseV4Addresses.BASE_MAINNET_USDC);
        assertEq(plan.usdcDecimals, 6);
        _assertPredictedAddresses(plan, 11);
        _assertSimulation(plan);
    }

    function testRejectsBaseMainnetWithoutExplicitDryRunConfirmation() public {
        vm.chainId(BaseV4Addresses.BASE_MAINNET_CHAIN_ID);

        PrepareBaseMainnetCoreDeployDryRun script = new PrepareBaseMainnetCoreDeployDryRun();

        vm.expectRevert(
            abi.encodeWithSelector(
                PrepareBaseMainnetCoreDeployDryRun.BaseMainnetCoreDryRunNotConfirmed.selector,
                BaseV4Addresses.BASE_MAINNET_CHAIN_ID
            )
        );
        script.prepare(_config(address(0), 0, false, false));
    }

    function testRejectsBroadcastFlag() public {
        vm.chainId(31_337);

        PrepareBaseMainnetCoreDeployDryRun script = new PrepareBaseMainnetCoreDeployDryRun();

        vm.expectRevert(PrepareBaseMainnetCoreDeployDryRun.BroadcastNotAllowed.selector);
        script.prepare(_config(address(0), 0, false, true));
    }

    function testRejectsWrongBaseMainnetUsdc() public {
        vm.chainId(BaseV4Addresses.BASE_MAINNET_CHAIN_ID);
        MockUSDT wrongUsdc = new MockUSDT("Wrong USDC", "wUSDC", 6);

        PrepareBaseMainnetCoreDeployDryRun script = new PrepareBaseMainnetCoreDeployDryRun();

        vm.expectRevert(
            abi.encodeWithSelector(
                PrepareBaseMainnetCoreDeployDryRun.BaseMainnetUnexpectedAddress.selector,
                bytes32("USDC_TOKEN"),
                BaseV4Addresses.BASE_MAINNET_USDC,
                address(wrongUsdc)
            )
        );
        script.prepare(_config(address(wrongUsdc), 0, true, false));
    }

    function testRejectsUsdcWithWrongDecimals() public {
        vm.chainId(31_337);
        MockUSDT wrongDecimals = new MockUSDT("Wrong Decimals", "wUSDC", 18);

        PrepareBaseMainnetCoreDeployDryRun script = new PrepareBaseMainnetCoreDeployDryRun();

        vm.expectRevert(
            abi.encodeWithSelector(
                PrepareBaseMainnetCoreDeployDryRun.UsdcDecimalsMismatch.selector, 6, 18
            )
        );
        script.prepare(_config(address(wrongDecimals), 0, false, false));
    }

    function testRejectsDuplicateRoleWallets() public {
        vm.chainId(31_337);

        PrepareBaseMainnetCoreDeployDryRun.CoreDeployConfig memory config =
            _config(address(0), 0, false, false);
        config.protocolBudgetWallet = mainnetAdminWallet;

        PrepareBaseMainnetCoreDeployDryRun script = new PrepareBaseMainnetCoreDeployDryRun();

        vm.expectRevert(
            abi.encodeWithSelector(
                PrepareBaseMainnetCoreDeployDryRun.DuplicateAddress.selector,
                bytes32("MAINNET_ADMIN_WALLET"),
                bytes32("PROTOCOL_BUDGET_WALLET"),
                mainnetAdminWallet
            )
        );
        script.prepare(config);
    }

    function testRejectsUnsupportedChain() public {
        vm.chainId(BaseV4Addresses.BASE_SEPOLIA_CHAIN_ID);

        PrepareBaseMainnetCoreDeployDryRun script = new PrepareBaseMainnetCoreDeployDryRun();

        vm.expectRevert(
            abi.encodeWithSelector(
                PrepareBaseMainnetCoreDeployDryRun.UnsupportedChain.selector,
                BaseV4Addresses.BASE_SEPOLIA_CHAIN_ID
            )
        );
        script.prepare(_config(address(0), 0, false, false));
    }

    function testRejectsPredictedAddressWithExistingCode() public {
        vm.chainId(31_337);
        vm.setNonce(mainnetDeployer, 3);
        address predictedSunToken = vm.computeCreateAddress(mainnetDeployer, 3);
        vm.etch(predictedSunToken, hex"01");

        PrepareBaseMainnetCoreDeployDryRun script = new PrepareBaseMainnetCoreDeployDryRun();

        vm.expectRevert(
            abi.encodeWithSelector(
                PrepareBaseMainnetCoreDeployDryRun.PredictedAddressAlreadyUsed.selector,
                bytes32("PREDICTED_SUN_TOKEN"),
                predictedSunToken
            )
        );
        script.prepare(_config(address(0), 0, false, false));
    }

    function _config(
        address usdc,
        uint256 moonLaunchDelay,
        bool baseMainnetConfirmed,
        bool broadcastRequested
    ) private view returns (PrepareBaseMainnetCoreDeployDryRun.CoreDeployConfig memory config) {
        config = PrepareBaseMainnetCoreDeployDryRun.CoreDeployConfig({
            mainnetDeployer: mainnetDeployer,
            mainnetAdminWallet: mainnetAdminWallet,
            protocolBudgetWallet: protocolBudgetWallet,
            create2DeployerOwner: create2DeployerOwner,
            usdcToken: usdc,
            moonLaunchDelay: moonLaunchDelay,
            baseMainnetConfirmed: baseMainnetConfirmed,
            broadcastRequested: broadcastRequested
        });
    }

    function _assertPredictedAddresses(
        PrepareBaseMainnetCoreDeployDryRun.CoreDeployPlan memory plan,
        uint256 nonce
    ) private view {
        assertEq(plan.predictedSunToken, vm.computeCreateAddress(mainnetDeployer, nonce));
        assertEq(plan.predictedSunCurve, vm.computeCreateAddress(mainnetDeployer, nonce + 1));
        assertEq(plan.predictedMoonToken, vm.computeCreateAddress(mainnetDeployer, nonce + 2));
        assertEq(plan.predictedMoonCurve, vm.computeCreateAddress(mainnetDeployer, nonce + 3));
        assertEq(
            plan.predictedCreate2HookDeployer, vm.computeCreateAddress(mainnetDeployer, nonce + 4)
        );
    }

    function _assertSimulation(PrepareBaseMainnetCoreDeployDryRun.CoreDeployPlan memory plan)
        private
        view
    {
        assertEq(plan.sunTokenSimulation.owner(), mainnetAdminWallet);
        assertEq(plan.sunCurveSimulation.owner(), mainnetAdminWallet);
        assertEq(plan.moonTokenSimulation.owner(), mainnetAdminWallet);
        assertEq(plan.moonCurveSimulation.owner(), mainnetAdminWallet);
        assertEq(plan.sunTokenSimulation.minter(), address(plan.sunCurveSimulation));
        assertTrue(plan.sunTokenSimulation.minterLocked());
        assertEq(plan.moonTokenSimulation.minter(), address(plan.moonCurveSimulation));
        assertTrue(plan.moonTokenSimulation.minterLocked());
        assertEq(plan.sunCurveSimulation.moonCurve(), address(plan.moonCurveSimulation));
        assertEq(plan.sunCurveSimulation.moonAMM(), address(0));
        assertEq(address(plan.sunCurveSimulation.usdt()), plan.usdcToken);
        assertEq(plan.sunCurveSimulation.protocolBudget(), protocolBudgetWallet);
        assertEq(plan.moonCurveSimulation.protocolBudget(), protocolBudgetWallet);
        assertEq(plan.create2HookDeployerSimulation.owner(), create2DeployerOwner);
    }

    function _setRunEnv(address usdc, string memory confirm, string memory broadcast) private {
        vm.setEnv("MAINNET_DEPLOYER", vm.toString(mainnetDeployer));
        vm.setEnv("MAINNET_ADMIN_WALLET", vm.toString(mainnetAdminWallet));
        vm.setEnv("PROTOCOL_BUDGET_WALLET", vm.toString(protocolBudgetWallet));
        vm.setEnv("CREATE2_DEPLOYER_OWNER", vm.toString(create2DeployerOwner));
        vm.setEnv("USDC_TOKEN", usdc == address(0) ? "" : vm.toString(usdc));
        vm.setEnv("MOON_LAUNCH_DELAY", "0");
        vm.setEnv("CONFIRM_BASE_MAINNET_CORE_DRY_RUN", confirm);
        vm.setEnv("EXECUTE_BASE_MAINNET_BROADCAST", broadcast);
    }

    function _etchMockUsdcAt(address target, uint8 decimals_) private {
        MockUSDT mockUsdc = new MockUSDT("Mock Base Mainnet USDC", "USDC", decimals_);
        vm.etch(target, address(mockUsdc).code);
    }
}
