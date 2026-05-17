// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { Test } from "forge-std/Test.sol";
import { BaseV4Addresses } from "../../../contracts/hooks/base/BaseV4Addresses.sol";
import { BaseV4HookAddressMiner } from "../../../contracts/hooks/base/BaseV4HookAddressMiner.sol";
import { MockUSDT } from "../../../contracts/mocks/MockUSDT.sol";
import {
    ComputeBaseMainnetSunMoonUsdcHookSalt
} from "../../../script/ComputeBaseMainnetSunMoonUsdcHookSalt.s.sol";

contract BaseMainnetSunMoonUsdcHookSaltPreparationTest is Test {
    address internal mainnetAdminWallet = 0xD37BDC458EdCe7006dDd3ce03eEBF29d629B2D6B;
    address internal protocolBudgetWallet = 0x215F1F09b765C0e893E8D7A40d51Bceb40B733F4;
    address internal predictedSunToken = 0xbA010450885AadcDA402358d04be881Bd53E482b;
    address internal predictedSunCurve = 0x4104250C9C2E19CCe8625D0c2972c5EaE035D83a;
    address internal predictedMoonToken = 0xf3Bff3b498369022313aD55138ea41B236B61EBf;
    address internal predictedCreate2HookDeployer = 0xFdc4c4FC0200ee27345B179E52348bA4a4aC97c0;

    function testLocalSimulationComputesHookSaltForPredictedCoreAddresses() public {
        vm.chainId(31_337);

        ComputeBaseMainnetSunMoonUsdcHookSalt script = new ComputeBaseMainnetSunMoonUsdcHookSalt();
        ComputeBaseMainnetSunMoonUsdcHookSalt.HookSaltPlan memory plan =
            script.prepare(_config(BaseV4Addresses.BASE_MAINNET_USDC, false, false));

        assertEq(plan.chainId, 31_337);
        assertTrue(plan.simulationOnly);
        assertEq(plan.create2HookDeployer, predictedCreate2HookDeployer);
        assertEq(plan.sunToken, predictedSunToken);
        assertEq(plan.moonToken, predictedMoonToken);
        assertEq(plan.sunCurve, predictedSunCurve);
        assertEq(plan.usdcDecimals, 6);
        assertEq(plan.expectedHookMask, BaseV4HookAddressMiner.BASE_SUN_MOON_USDC_FEE_V4_HOOK_MASK);
        assertEq(plan.actualHookMask, plan.expectedHookMask);
        assertEq(
            BaseV4HookAddressMiner.computeCreate2Address(
                predictedCreate2HookDeployer, plan.hookSalt, plan.initCodeHash
            ),
            plan.predictedHook
        );
    }

    function testRunLoadsEnvironmentAndComputesHookSalt() public {
        vm.chainId(31_337);
        _setRunEnv(BaseV4Addresses.BASE_MAINNET_USDC, "0", "0");

        ComputeBaseMainnetSunMoonUsdcHookSalt script = new ComputeBaseMainnetSunMoonUsdcHookSalt();
        ComputeBaseMainnetSunMoonUsdcHookSalt.HookSaltPlan memory plan = script.run();

        assertEq(plan.mainnetAdminWallet, mainnetAdminWallet);
        assertEq(plan.protocolBudgetWallet, protocolBudgetWallet);
        assertEq(plan.actualHookMask, plan.expectedHookMask);
        assertEq(plan.usdcDecimals, 6);
    }

    function testBaseMainnetDryRunUsesOfficialUsdcWhenConfirmed() public {
        vm.chainId(BaseV4Addresses.BASE_MAINNET_CHAIN_ID);
        _etchBaseMainnetDependencies(6);

        ComputeBaseMainnetSunMoonUsdcHookSalt script = new ComputeBaseMainnetSunMoonUsdcHookSalt();
        ComputeBaseMainnetSunMoonUsdcHookSalt.HookSaltPlan memory plan =
            script.prepare(_config(BaseV4Addresses.BASE_MAINNET_USDC, true, false));

        assertEq(plan.chainId, BaseV4Addresses.BASE_MAINNET_CHAIN_ID);
        assertTrue(plan.baseMainnetConfirmed);
        assertEq(plan.usdcToken, BaseV4Addresses.BASE_MAINNET_USDC);
        assertEq(plan.usdcDecimals, 6);
        assertEq(plan.actualHookMask, plan.expectedHookMask);
    }

    function testRejectsBaseMainnetWithoutExplicitConfirmation() public {
        vm.chainId(BaseV4Addresses.BASE_MAINNET_CHAIN_ID);
        _etchBaseMainnetDependencies(6);

        ComputeBaseMainnetSunMoonUsdcHookSalt script = new ComputeBaseMainnetSunMoonUsdcHookSalt();

        vm.expectRevert(
            abi.encodeWithSelector(
                ComputeBaseMainnetSunMoonUsdcHookSalt.BaseMainnetHookSaltDryRunNotConfirmed
                .selector,
                BaseV4Addresses.BASE_MAINNET_CHAIN_ID
            )
        );
        script.prepare(_config(BaseV4Addresses.BASE_MAINNET_USDC, false, false));
    }

    function testRejectsBroadcastFlag() public {
        vm.chainId(31_337);

        ComputeBaseMainnetSunMoonUsdcHookSalt script = new ComputeBaseMainnetSunMoonUsdcHookSalt();

        vm.expectRevert(ComputeBaseMainnetSunMoonUsdcHookSalt.BroadcastNotAllowed.selector);
        script.prepare(_config(BaseV4Addresses.BASE_MAINNET_USDC, false, true));
    }

    function testRejectsWrongBaseMainnetUsdc() public {
        vm.chainId(BaseV4Addresses.BASE_MAINNET_CHAIN_ID);
        _etchBaseMainnetDependencies(6);
        MockUSDT wrongUsdc = new MockUSDT("Wrong USDC", "wUSDC", 6);

        ComputeBaseMainnetSunMoonUsdcHookSalt script = new ComputeBaseMainnetSunMoonUsdcHookSalt();

        vm.expectRevert(
            abi.encodeWithSelector(
                ComputeBaseMainnetSunMoonUsdcHookSalt.BaseMainnetUnexpectedAddress.selector,
                bytes32("USDC_TOKEN"),
                BaseV4Addresses.BASE_MAINNET_USDC,
                address(wrongUsdc)
            )
        );
        script.prepare(_config(address(wrongUsdc), true, false));
    }

    function testRejectsOfficialUsdcWithWrongDecimals() public {
        vm.chainId(BaseV4Addresses.BASE_MAINNET_CHAIN_ID);
        _etchBaseMainnetDependencies(18);

        ComputeBaseMainnetSunMoonUsdcHookSalt script = new ComputeBaseMainnetSunMoonUsdcHookSalt();

        vm.expectRevert(
            abi.encodeWithSelector(
                ComputeBaseMainnetSunMoonUsdcHookSalt.UsdcDecimalsMismatch.selector, 6, 18
            )
        );
        script.prepare(_config(BaseV4Addresses.BASE_MAINNET_USDC, true, false));
    }

    function testRejectsDuplicateTokenAddress() public {
        vm.chainId(31_337);
        ComputeBaseMainnetSunMoonUsdcHookSalt.HookSaltConfig memory config =
            _config(BaseV4Addresses.BASE_MAINNET_USDC, false, false);
        config.moonToken = predictedSunToken;

        ComputeBaseMainnetSunMoonUsdcHookSalt script = new ComputeBaseMainnetSunMoonUsdcHookSalt();

        vm.expectRevert(
            abi.encodeWithSelector(
                ComputeBaseMainnetSunMoonUsdcHookSalt.DuplicateAddress.selector,
                bytes32("SUN_TOKEN"),
                bytes32("MOON_TOKEN"),
                predictedSunToken
            )
        );
        script.prepare(config);
    }

    function testRejectsZeroSaltSearchRange() public {
        vm.chainId(31_337);
        ComputeBaseMainnetSunMoonUsdcHookSalt.HookSaltConfig memory config =
            _config(BaseV4Addresses.BASE_MAINNET_USDC, false, false);
        config.hookMaxSaltSearch = 0;

        ComputeBaseMainnetSunMoonUsdcHookSalt script = new ComputeBaseMainnetSunMoonUsdcHookSalt();

        vm.expectRevert(
            abi.encodeWithSelector(
                ComputeBaseMainnetSunMoonUsdcHookSalt.SaltNotFound.selector, 0, 0
            )
        );
        script.prepare(config);
    }

    function testRejectsUnsupportedChain() public {
        vm.chainId(BaseV4Addresses.BASE_SEPOLIA_CHAIN_ID);

        ComputeBaseMainnetSunMoonUsdcHookSalt script = new ComputeBaseMainnetSunMoonUsdcHookSalt();

        vm.expectRevert(
            abi.encodeWithSelector(
                ComputeBaseMainnetSunMoonUsdcHookSalt.UnsupportedChain.selector,
                BaseV4Addresses.BASE_SEPOLIA_CHAIN_ID
            )
        );
        script.prepare(_config(BaseV4Addresses.BASE_MAINNET_USDC, false, false));
    }

    function _config(address usdc, bool baseMainnetConfirmed, bool broadcastRequested)
        private
        view
        returns (ComputeBaseMainnetSunMoonUsdcHookSalt.HookSaltConfig memory config)
    {
        config = ComputeBaseMainnetSunMoonUsdcHookSalt.HookSaltConfig({
            mainnetAdminWallet: mainnetAdminWallet,
            protocolBudgetWallet: protocolBudgetWallet,
            create2HookDeployer: predictedCreate2HookDeployer,
            poolManager: BaseV4Addresses.BASE_MAINNET_POOL_MANAGER,
            sunToken: predictedSunToken,
            moonToken: predictedMoonToken,
            usdcToken: usdc,
            sunCurve: predictedSunCurve,
            hookSaltStart: 0,
            hookMaxSaltSearch: 200_000,
            baseMainnetConfirmed: baseMainnetConfirmed,
            broadcastRequested: broadcastRequested
        });
    }

    function _setRunEnv(address usdc, string memory confirm, string memory broadcast) private {
        vm.setEnv("MAINNET_ADMIN_WALLET", vm.toString(mainnetAdminWallet));
        vm.setEnv("PROTOCOL_BUDGET_WALLET", vm.toString(protocolBudgetWallet));
        vm.setEnv("CREATE2_HOOK_DEPLOYER", vm.toString(predictedCreate2HookDeployer));
        vm.setEnv("POOL_MANAGER", vm.toString(BaseV4Addresses.BASE_MAINNET_POOL_MANAGER));
        vm.setEnv("SUN_TOKEN", vm.toString(predictedSunToken));
        vm.setEnv("MOON_TOKEN", vm.toString(predictedMoonToken));
        vm.setEnv("USDC_TOKEN", vm.toString(usdc));
        vm.setEnv("SUN_CURVE", vm.toString(predictedSunCurve));
        vm.setEnv("HOOK_SALT_START", "0");
        vm.setEnv("HOOK_MAX_SALT_SEARCH", "200000");
        vm.setEnv("CONFIRM_BASE_MAINNET_HOOK_SALT_DRY_RUN", confirm);
        vm.setEnv("EXECUTE_BASE_MAINNET_BROADCAST", broadcast);
    }

    function _etchBaseMainnetDependencies(uint8 usdcDecimals) private {
        vm.etch(BaseV4Addresses.BASE_MAINNET_POOL_MANAGER, hex"01");
        MockUSDT mockUsdc = new MockUSDT("Mock Base Mainnet USDC", "USDC", usdcDecimals);
        vm.etch(BaseV4Addresses.BASE_MAINNET_USDC, address(mockUsdc).code);
    }
}
