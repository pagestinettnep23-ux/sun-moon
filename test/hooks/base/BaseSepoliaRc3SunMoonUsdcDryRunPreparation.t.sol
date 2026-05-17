// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { Test } from "forge-std/Test.sol";
import { IPoolManager } from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import { PoolManager } from "@uniswap/v4-core/src/PoolManager.sol";
import { Currency } from "@uniswap/v4-core/src/types/Currency.sol";
import { PoolId, PoolIdLibrary } from "@uniswap/v4-core/src/types/PoolId.sol";
import { PoolKey } from "@uniswap/v4-core/src/types/PoolKey.sol";
import { StateView } from "@uniswap/v4-periphery/src/lens/StateView.sol";
import { MockUSDT } from "../../../contracts/mocks/MockUSDT.sol";
import { BaseV4Addresses } from "../../../contracts/hooks/base/BaseV4Addresses.sol";
import { BaseV4HookAddressMiner } from "../../../contracts/hooks/base/BaseV4HookAddressMiner.sol";
import {
    PrepareBaseSepoliaRc3SunMoonUsdcDryRun
} from "../../../script/PrepareBaseSepoliaRc3SunMoonUsdcDryRun.s.sol";

contract BaseSepoliaRc3SunMoonUsdcDryRunPreparationTest is Test {
    using PoolIdLibrary for PoolKey;

    address internal sepoliaDeployer = makeAddr("sepoliaDeployer");
    address internal sepoliaAdminWallet = makeAddr("sepoliaAdminWallet");
    address internal sepoliaProtocolBudgetWallet = makeAddr("sepoliaProtocolBudgetWallet");
    address internal sepoliaCreate2Owner = makeAddr("sepoliaCreate2Owner");

    struct Fixture {
        MockUSDT usdc;
        PoolManager poolManager;
        StateView stateView;
    }

    function testLocalRc3DryRunDeploysUnifiedHookPoolsAndRenounces() public {
        vm.chainId(31_337);
        Fixture memory fixture = _deployFixture(6);

        PrepareBaseSepoliaRc3SunMoonUsdcDryRun script = new PrepareBaseSepoliaRc3SunMoonUsdcDryRun();
        PrepareBaseSepoliaRc3SunMoonUsdcDryRun.Rc3DryRunPlan memory plan = script.prepare(
            _config(
                address(fixture.poolManager),
                address(fixture.stateView),
                address(fixture.usdc),
                false,
                false
            )
        );

        assertTrue(plan.simulationOnly);
        assertEq(plan.simulatedActionsPlanned, 19);
        assertEq(plan.chainId, 31_337);
        assertFalse(plan.baseSepoliaConfirmed);
        assertFalse(plan.broadcastRequested);
        assertEq(plan.sepoliaDeployer, sepoliaDeployer);
        assertEq(plan.sepoliaAdminWallet, sepoliaAdminWallet);
        assertEq(plan.sepoliaProtocolBudgetWallet, sepoliaProtocolBudgetWallet);
        assertEq(plan.sepoliaCreate2DeployerOwner, sepoliaCreate2Owner);
        assertEq(plan.usdcToken, address(fixture.usdc));
        assertEq(plan.usdcDecimals, 6);

        assertGt(plan.sunTokenSimulation.code.length, 0);
        assertGt(plan.sunCurveSimulation.code.length, 0);
        assertGt(plan.moonTokenSimulation.code.length, 0);
        assertGt(plan.moonCurveSimulation.code.length, 0);
        assertGt(plan.create2HookDeployerSimulation.code.length, 0);
        assertGt(plan.deployedHookSimulation.code.length, 0);

        assertEq(plan.expectedHookMask, BaseV4HookAddressMiner.BASE_SUN_MOON_USDC_FEE_V4_HOOK_MASK);
        assertEq(plan.actualHookMask, plan.expectedHookMask);
        assertEq(plan.predictedHook, plan.deployedHookSimulation);

        assertEq(address(plan.sunUsdcPoolKey.hooks), plan.predictedHook);
        assertEq(plan.sunUsdcPoolKey.fee, 3000);
        assertEq(plan.sunUsdcPoolKey.tickSpacing, 60);
        assertEq(plan.sunUsdcPoolId, PoolId.unwrap(plan.sunUsdcPoolKey.toId()));
        assertEq(plan.sunUsdcInitialTokenAmount, 1e18);
        assertEq(plan.sunUsdcInitialUsdcAmount, 1e6);
        assertEq(plan.sunUsdcSqrtPriceBefore, 0);
        assertEq(plan.sunUsdcSqrtPriceAfter, plan.sunUsdcSqrtPriceX96);

        assertEq(address(plan.moonUsdcPoolKey.hooks), plan.predictedHook);
        assertEq(plan.moonUsdcPoolKey.fee, 3000);
        assertEq(plan.moonUsdcPoolKey.tickSpacing, 60);
        assertEq(plan.moonUsdcPoolId, PoolId.unwrap(plan.moonUsdcPoolKey.toId()));
        assertEq(plan.moonUsdcInitialTokenAmount, 1e18);
        assertEq(plan.moonUsdcInitialUsdcAmount, 240_000);
        assertEq(plan.moonUsdcSqrtPriceBefore, 0);
        assertEq(plan.moonUsdcSqrtPriceAfter, plan.moonUsdcSqrtPriceX96);

        assertNotEq(plan.sunUsdcPoolId, plan.moonUsdcPoolId);
        assertTrue(_contains(plan.sunUsdcPoolKey, plan.sunTokenSimulation));
        assertTrue(_contains(plan.sunUsdcPoolKey, address(fixture.usdc)));
        assertTrue(_contains(plan.moonUsdcPoolKey, plan.moonTokenSimulation));
        assertTrue(_contains(plan.moonUsdcPoolKey, address(fixture.usdc)));

        assertTrue(plan.sunUsdcAllowedAfter);
        assertTrue(plan.moonUsdcAllowedAfter);
        assertEq(plan.ownerBeforeRenounce, sepoliaAdminWallet);
        assertEq(plan.ownerAfterRenounce, address(0));
        assertTrue(plan.renounceBlocksSunAllowlist);
        assertTrue(plan.renounceBlocksMoonAllowlist);
        assertTrue(plan.renounceBlocksProtocolBudget);
    }

    function testRunCanUseLocalDefaultsWithoutBroadcast() public {
        vm.chainId(31_337);

        PrepareBaseSepoliaRc3SunMoonUsdcDryRun script = new PrepareBaseSepoliaRc3SunMoonUsdcDryRun();
        PrepareBaseSepoliaRc3SunMoonUsdcDryRun.Rc3DryRunPlan memory plan = script.run();

        assertTrue(plan.simulationOnly);
        assertFalse(plan.broadcastRequested);
        assertEq(plan.chainId, 31_337);
        assertGt(plan.poolManager.code.length, 0);
        assertGt(plan.stateView.code.length, 0);
        assertGt(plan.usdcToken.code.length, 0);
        assertEq(plan.usdcDecimals, 6);
        assertEq(plan.sunUsdcSqrtPriceAfter, plan.sunUsdcSqrtPriceX96);
        assertEq(plan.moonUsdcSqrtPriceAfter, plan.moonUsdcSqrtPriceX96);
    }

    function testLocalRunReplacesStaleOfficialAddressEnvWithoutCode() public {
        vm.chainId(31_337);
        vm.setEnv("POOL_MANAGER", vm.toString(BaseV4Addresses.BASE_SEPOLIA_POOL_MANAGER));
        vm.setEnv("STATE_VIEW", vm.toString(BaseV4Addresses.BASE_SEPOLIA_STATE_VIEW));
        vm.setEnv("USDC_TOKEN", vm.toString(BaseV4Addresses.BASE_SEPOLIA_USDC));

        PrepareBaseSepoliaRc3SunMoonUsdcDryRun script = new PrepareBaseSepoliaRc3SunMoonUsdcDryRun();
        PrepareBaseSepoliaRc3SunMoonUsdcDryRun.Rc3DryRunPlan memory plan = script.run();

        assertTrue(plan.simulationOnly);
        assertNotEq(plan.poolManager, BaseV4Addresses.BASE_SEPOLIA_POOL_MANAGER);
        assertNotEq(plan.stateView, BaseV4Addresses.BASE_SEPOLIA_STATE_VIEW);
        assertNotEq(plan.usdcToken, BaseV4Addresses.BASE_SEPOLIA_USDC);
        assertGt(plan.poolManager.code.length, 0);
        assertGt(plan.stateView.code.length, 0);
        assertGt(plan.usdcToken.code.length, 0);
        assertEq(plan.sunUsdcSqrtPriceAfter, plan.sunUsdcSqrtPriceX96);
        assertEq(plan.moonUsdcSqrtPriceAfter, plan.moonUsdcSqrtPriceX96);
    }

    function testBaseSepoliaUsesOfficialInfrastructureWhenConfirmed() public {
        vm.chainId(BaseV4Addresses.BASE_SEPOLIA_CHAIN_ID);
        _etchBaseSepoliaDependencies();

        PrepareBaseSepoliaRc3SunMoonUsdcDryRun script = new PrepareBaseSepoliaRc3SunMoonUsdcDryRun();
        PrepareBaseSepoliaRc3SunMoonUsdcDryRun.Rc3DryRunPlan memory plan =
            script.prepare(_baseSepoliaConfig(BaseV4Addresses.BASE_SEPOLIA_USDC, true, false));

        assertEq(plan.chainId, BaseV4Addresses.BASE_SEPOLIA_CHAIN_ID);
        assertTrue(plan.baseSepoliaConfirmed);
        assertFalse(plan.broadcastRequested);
        assertEq(plan.poolManager, BaseV4Addresses.BASE_SEPOLIA_POOL_MANAGER);
        assertEq(plan.stateView, BaseV4Addresses.BASE_SEPOLIA_STATE_VIEW);
        assertEq(plan.usdcToken, BaseV4Addresses.BASE_SEPOLIA_USDC);
        assertEq(plan.usdcDecimals, 6);
        assertEq(plan.actualHookMask, plan.expectedHookMask);
        assertEq(plan.sunUsdcSqrtPriceAfter, plan.sunUsdcSqrtPriceX96);
        assertEq(plan.moonUsdcSqrtPriceAfter, plan.moonUsdcSqrtPriceX96);
        assertEq(plan.ownerAfterRenounce, address(0));
    }

    function testBaseSepoliaRequiresExplicitConfirmation() public {
        vm.chainId(BaseV4Addresses.BASE_SEPOLIA_CHAIN_ID);
        _etchBaseSepoliaDependencies();

        PrepareBaseSepoliaRc3SunMoonUsdcDryRun script = new PrepareBaseSepoliaRc3SunMoonUsdcDryRun();

        vm.expectRevert(
            abi.encodeWithSelector(
                PrepareBaseSepoliaRc3SunMoonUsdcDryRun.BaseSepoliaRc3DryRunNotConfirmed.selector,
                BaseV4Addresses.BASE_SEPOLIA_CHAIN_ID
            )
        );
        script.prepare(_baseSepoliaConfig(BaseV4Addresses.BASE_SEPOLIA_USDC, false, false));
    }

    function testRejectsBaseMainnet() public {
        vm.chainId(BaseV4Addresses.BASE_MAINNET_CHAIN_ID);

        PrepareBaseSepoliaRc3SunMoonUsdcDryRun script = new PrepareBaseSepoliaRc3SunMoonUsdcDryRun();

        vm.expectRevert(
            abi.encodeWithSelector(
                PrepareBaseSepoliaRc3SunMoonUsdcDryRun.BaseMainnetNotAllowed.selector,
                BaseV4Addresses.BASE_MAINNET_CHAIN_ID
            )
        );
        script.prepare(_config(address(0), address(0), address(0), false, false));
    }

    function testRejectsBroadcastFlag() public {
        vm.chainId(31_337);
        Fixture memory fixture = _deployFixture(6);

        PrepareBaseSepoliaRc3SunMoonUsdcDryRun script = new PrepareBaseSepoliaRc3SunMoonUsdcDryRun();

        vm.expectRevert(PrepareBaseSepoliaRc3SunMoonUsdcDryRun.BroadcastNotAllowed.selector);
        script.prepare(
            _config(
                address(fixture.poolManager),
                address(fixture.stateView),
                address(fixture.usdc),
                false,
                true
            )
        );
    }

    function testBaseSepoliaRejectsWrongUsdc() public {
        vm.chainId(BaseV4Addresses.BASE_SEPOLIA_CHAIN_ID);
        _etchBaseSepoliaDependencies();
        MockUSDT wrongUsdc = new MockUSDT("Wrong USDC", "wUSDC", 6);

        PrepareBaseSepoliaRc3SunMoonUsdcDryRun script = new PrepareBaseSepoliaRc3SunMoonUsdcDryRun();

        vm.expectRevert(
            abi.encodeWithSelector(
                PrepareBaseSepoliaRc3SunMoonUsdcDryRun.BaseSepoliaUnexpectedAddress.selector,
                bytes32("USDC_TOKEN"),
                BaseV4Addresses.BASE_SEPOLIA_USDC,
                address(wrongUsdc)
            )
        );
        script.prepare(_baseSepoliaConfig(address(wrongUsdc), true, false));
    }

    function testRejectsInvalidPoolConfig() public {
        vm.chainId(31_337);
        Fixture memory fixture = _deployFixture(6);
        PrepareBaseSepoliaRc3SunMoonUsdcDryRun.Rc3DryRunConfig memory config = _config(
            address(fixture.poolManager),
            address(fixture.stateView),
            address(fixture.usdc),
            false,
            false
        );
        config.sunUsdcFee = 500;

        PrepareBaseSepoliaRc3SunMoonUsdcDryRun script = new PrepareBaseSepoliaRc3SunMoonUsdcDryRun();

        vm.expectRevert(
            abi.encodeWithSelector(
                PrepareBaseSepoliaRc3SunMoonUsdcDryRun.InvalidPoolConfig.selector,
                bytes32("SUN_USDC_POOL"),
                uint24(500),
                int24(60)
            )
        );
        script.prepare(config);
    }

    function testRejectsUsdcWithWrongDecimals() public {
        vm.chainId(31_337);
        Fixture memory fixture = _deployFixture(18);

        PrepareBaseSepoliaRc3SunMoonUsdcDryRun script = new PrepareBaseSepoliaRc3SunMoonUsdcDryRun();

        vm.expectRevert(
            abi.encodeWithSelector(
                PrepareBaseSepoliaRc3SunMoonUsdcDryRun.UsdcDecimalsMismatch.selector, 6, 18
            )
        );
        script.prepare(
            _config(
                address(fixture.poolManager),
                address(fixture.stateView),
                address(fixture.usdc),
                false,
                false
            )
        );
    }

    function _deployFixture(uint8 usdcDecimals) private returns (Fixture memory fixture) {
        fixture.usdc = new MockUSDT("Mock USDC", "USDC", usdcDecimals);
        fixture.poolManager = new PoolManager(sepoliaAdminWallet);
        fixture.stateView = new StateView(IPoolManager(address(fixture.poolManager)));
    }

    function _config(
        address poolManager,
        address stateView,
        address usdc,
        bool confirmed,
        bool broadcast
    ) private view returns (PrepareBaseSepoliaRc3SunMoonUsdcDryRun.Rc3DryRunConfig memory config) {
        config = PrepareBaseSepoliaRc3SunMoonUsdcDryRun.Rc3DryRunConfig({
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
            broadcastRequested: broadcast
        });
    }

    function _baseSepoliaConfig(address usdc, bool confirmed, bool broadcast)
        private
        view
        returns (PrepareBaseSepoliaRc3SunMoonUsdcDryRun.Rc3DryRunConfig memory config)
    {
        config = _config(
            BaseV4Addresses.BASE_SEPOLIA_POOL_MANAGER,
            BaseV4Addresses.BASE_SEPOLIA_STATE_VIEW,
            usdc,
            confirmed,
            broadcast
        );
    }

    function _contains(PoolKey memory key, address token) private pure returns (bool) {
        return Currency.unwrap(key.currency0) == token || Currency.unwrap(key.currency1) == token;
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
