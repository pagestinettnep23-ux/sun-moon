// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import { Test } from "forge-std/Test.sol";
import { IPoolManager } from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import { IMoonAmmSwapAdapter } from "../../../contracts/hooks/MoonAmmFeeHook.sol";
import { TestnetUsdcAdapter } from "../../../contracts/hooks/TestnetUsdcAdapter.sol";
import { BaseMoonAmmFeeV4Hook } from "../../../contracts/hooks/base/BaseMoonAmmFeeV4Hook.sol";
import { BaseV4Addresses } from "../../../contracts/hooks/base/BaseV4Addresses.sol";
import { BaseV4HookAddressMiner } from "../../../contracts/hooks/base/BaseV4HookAddressMiner.sol";
import { Create2HookDeployer } from "../../../contracts/hooks/base/Create2HookDeployer.sol";
import { MockUSDT } from "../../../contracts/mocks/MockUSDT.sol";
import { SunCurve } from "../../../contracts/SunCurve.sol";
import { SunToken } from "../../../contracts/SunToken.sol";
import { PrepareBaseSepoliaHookBinding } from "../../../script/PrepareBaseSepoliaHookBinding.s.sol";

contract BaseSepoliaHookBindingPreparationTest is Test {
    address internal hookOwner = 0x6E22b2e6fFAA30Fe75B71d53d1eC469b4e97A986;
    address internal protocolBudget = 0x277ba3Cf597CdAaF958C301db3cF6a631F793039;
    address internal moonToken = 0x6E7FF34C7a7a518981BF6324e5FCC6599FcBC59D;

    struct Fixture {
        Create2HookDeployer create2Deployer;
        BaseMoonAmmFeeV4Hook hook;
        TestnetUsdcAdapter adapter;
        SunCurve sunCurve;
    }

    function testHookBindingPreparationGuardsAndBinds() public {
        _assertLocalSimulationBindsAdapterAndSunCurve();
        _assertIdempotentWhenAlreadyBound();
        _assertBaseMainnetIsRejected();
        _assertBaseSepoliaRequiresExplicitConfirmation();
        _assertRejectsWrongHookOwner();
        _assertRejectsWrongHookAdapter();
    }

    function _assertLocalSimulationBindsAdapterAndSunCurve() private {
        vm.chainId(31_337);
        Fixture memory fixture = _deployFixture(hookOwner, hookOwner, false);
        _setBindingEnv(fixture, hookOwner);

        PrepareBaseSepoliaHookBinding script = new PrepareBaseSepoliaHookBinding();
        PrepareBaseSepoliaHookBinding.Binding memory binding = script.run();

        assertEq(binding.chainId, 31_337);
        assertFalse(binding.baseSepoliaConfirmed);
        assertEq(binding.hookOwner, hookOwner);
        assertEq(address(binding.hook), address(fixture.hook));
        assertEq(address(binding.adapter), address(fixture.adapter));
        assertEq(address(binding.sunCurve), address(fixture.sunCurve));
        assertEq(binding.adapterAuthorizedHookBefore, hookOwner);
        assertEq(binding.sunCurveMoonAMMBefore, address(0));
        assertFalse(binding.adapterAlreadyBound);
        assertFalse(binding.sunCurveAlreadyBound);
        assertEq(binding.transactionsPlanned, 2);
        assertEq(fixture.adapter.authorizedHook(), address(fixture.hook));
        assertEq(fixture.sunCurve.moonAMM(), address(fixture.hook));
    }

    function _assertIdempotentWhenAlreadyBound() private {
        vm.chainId(31_337);
        Fixture memory fixture = _deployFixture(hookOwner, hookOwner, true);
        _setBindingEnv(fixture, hookOwner);

        PrepareBaseSepoliaHookBinding script = new PrepareBaseSepoliaHookBinding();
        PrepareBaseSepoliaHookBinding.Binding memory binding = script.run();

        assertTrue(binding.adapterAlreadyBound);
        assertTrue(binding.sunCurveAlreadyBound);
        assertEq(binding.transactionsPlanned, 0);
        assertEq(fixture.adapter.authorizedHook(), address(fixture.hook));
        assertEq(fixture.sunCurve.moonAMM(), address(fixture.hook));
    }

    function _assertBaseMainnetIsRejected() private {
        vm.chainId(BaseV4Addresses.BASE_MAINNET_CHAIN_ID);
        Fixture memory fixture = _deployFixture(hookOwner, hookOwner, false);
        _setBindingEnv(fixture, hookOwner);

        PrepareBaseSepoliaHookBinding script = new PrepareBaseSepoliaHookBinding();

        vm.expectRevert(
            abi.encodeWithSelector(
                PrepareBaseSepoliaHookBinding.BaseMainnetNotAllowed.selector,
                BaseV4Addresses.BASE_MAINNET_CHAIN_ID
            )
        );
        script.run();
    }

    function _assertBaseSepoliaRequiresExplicitConfirmation() private {
        vm.chainId(BaseV4Addresses.BASE_SEPOLIA_CHAIN_ID);
        Fixture memory fixture = _deployFixture(hookOwner, hookOwner, false);
        _setBindingEnv(fixture, hookOwner);
        vm.setEnv("CONFIRM_BASE_SEPOLIA_HOOK_BINDING_RUN", "0");

        PrepareBaseSepoliaHookBinding script = new PrepareBaseSepoliaHookBinding();

        vm.expectRevert(
            abi.encodeWithSelector(
                PrepareBaseSepoliaHookBinding.BaseSepoliaRunNotConfirmed.selector,
                BaseV4Addresses.BASE_SEPOLIA_CHAIN_ID
            )
        );
        script.run();
    }

    function _assertRejectsWrongHookOwner() private {
        vm.chainId(31_337);
        address wrongHookOwner = makeAddr("wrongHookOwner");
        Fixture memory fixture = _deployFixture(wrongHookOwner, hookOwner, false);
        _setBindingEnv(fixture, hookOwner);

        PrepareBaseSepoliaHookBinding script = new PrepareBaseSepoliaHookBinding();

        vm.expectRevert(
            abi.encodeWithSelector(
                PrepareBaseSepoliaHookBinding.UnexpectedOwner.selector,
                bytes32("HOOK"),
                hookOwner,
                wrongHookOwner
            )
        );
        script.run();
    }

    function _assertRejectsWrongHookAdapter() private {
        vm.chainId(31_337);
        Fixture memory fixture = _deployFixture(hookOwner, hookOwner, false);
        TestnetUsdcAdapter differentAdapter = new TestnetUsdcAdapter(
            IERC20(address(new MockUSDT("USDC", "USDC", 6))), hookOwner, hookOwner
        );
        Fixture memory wrongFixture = _deployFixtureWithAdapter(hookOwner, differentAdapter);
        _setBindingEnv(
            Fixture({
                create2Deployer: wrongFixture.create2Deployer,
                hook: wrongFixture.hook,
                adapter: fixture.adapter,
                sunCurve: wrongFixture.sunCurve
            }),
            hookOwner
        );

        PrepareBaseSepoliaHookBinding script = new PrepareBaseSepoliaHookBinding();

        vm.expectRevert(
            abi.encodeWithSelector(
                PrepareBaseSepoliaHookBinding.UnexpectedParameter.selector,
                bytes32("SWAP_ADAPTER"),
                address(fixture.adapter),
                address(differentAdapter)
            )
        );
        script.run();
    }

    function _deployFixture(address hookConstructorOwner, address contractOwner, bool prebound)
        private
        returns (Fixture memory fixture)
    {
        MockUSDT usdc = new MockUSDT("Base Sepolia USDC", "USDC", 6);
        SunToken sunToken = new SunToken("SUN", "SUN", contractOwner);
        fixture.sunCurve = new SunCurve(
            sunToken, IERC20Metadata(address(usdc)), protocolBudget, 10_000e6, contractOwner
        );
        fixture.adapter =
            new TestnetUsdcAdapter(IERC20(address(usdc)), contractOwner, contractOwner);
        fixture = _deployHook(fixture, hookConstructorOwner);

        if (prebound) {
            vm.startPrank(contractOwner);
            fixture.adapter.setAuthorizedHook(address(fixture.hook));
            fixture.sunCurve.setMoonAMM(address(fixture.hook));
            vm.stopPrank();
        }
    }

    function _deployFixtureWithAdapter(address hookConstructorOwner, TestnetUsdcAdapter adapter)
        private
        returns (Fixture memory fixture)
    {
        MockUSDT usdc = new MockUSDT("Base Sepolia USDC", "USDC", 6);
        SunToken sunToken = new SunToken("SUN", "SUN", hookOwner);
        fixture.sunCurve = new SunCurve(
            sunToken, IERC20Metadata(address(usdc)), protocolBudget, 10_000e6, hookOwner
        );
        fixture.adapter = adapter;
        fixture = _deployHook(fixture, hookConstructorOwner);
    }

    function _deployHook(Fixture memory fixture, address hookConstructorOwner)
        private
        returns (Fixture memory)
    {
        fixture.create2Deployer = new Create2HookDeployer(hookOwner);
        bytes memory initCode = _baseMoonHookInitCode(
            address(fixture.adapter), address(fixture.sunCurve), hookConstructorOwner
        );
        bytes32 initCodeHash = keccak256(initCode);
        bool found;
        bytes32 hookSalt;
        address predictedHook;
        (hookSalt, predictedHook, found) = BaseV4HookAddressMiner.mineSalt(
            address(fixture.create2Deployer),
            initCodeHash,
            BaseV4HookAddressMiner.BASE_MOON_AMM_FEE_V4_HOOK_MASK,
            0,
            200_000
        );
        assertTrue(found);

        vm.prank(hookOwner);
        address deployedHook = fixture.create2Deployer
            .deployHook(hookSalt, initCode, BaseV4HookAddressMiner.BASE_MOON_AMM_FEE_V4_HOOK_MASK);
        assertEq(deployedHook, predictedHook);

        fixture.hook = BaseMoonAmmFeeV4Hook(deployedHook);
        return fixture;
    }

    function _setBindingEnv(Fixture memory fixture, address expectedHookOwner) private {
        vm.setEnv("HOOK_OWNER", vm.toString(expectedHookOwner));
        vm.setEnv("HOOK_ADDRESS", vm.toString(address(fixture.hook)));
        vm.setEnv("SWAP_ADAPTER", vm.toString(address(fixture.adapter)));
        vm.setEnv("SUN_CURVE", vm.toString(address(fixture.sunCurve)));
        vm.setEnv("CONFIRM_BASE_SEPOLIA_HOOK_BINDING_RUN", "0");
    }

    function _baseMoonHookInitCode(address adapter, address sunCurve, address hookConstructorOwner)
        private
        view
        returns (bytes memory)
    {
        return abi.encodePacked(
            type(BaseMoonAmmFeeV4Hook).creationCode,
            abi.encode(
                IPoolManager(BaseV4Addresses.BASE_SEPOLIA_POOL_MANAGER),
                moonToken,
                IERC20(BaseV4Addresses.BASE_SEPOLIA_USDC),
                SunCurve(sunCurve),
                protocolBudget,
                IMoonAmmSwapAdapter(adapter),
                hookConstructorOwner
            )
        );
    }
}
