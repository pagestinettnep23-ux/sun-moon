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
import { Create2HookDeployer } from "../../../contracts/hooks/base/Create2HookDeployer.sol";
import {
    PrepareBaseMainnetSunMoonUsdcForkDryRun
} from "../../../script/PrepareBaseMainnetSunMoonUsdcForkDryRun.s.sol";

contract BaseMainnetSunMoonUsdcForkDryRunPreparationTest is Test {
    using PoolIdLibrary for PoolKey;

    address internal mainnetDeployer = makeAddr("mainnetDeployer");
    address internal mainnetAdminWallet = makeAddr("mainnetAdminWallet");
    address internal protocolBudgetWallet = makeAddr("protocolBudgetWallet");
    address internal create2Owner = makeAddr("create2Owner");
    address internal positionManager = address(0x1002);
    address internal quoter = address(0x1004);
    address internal universalRouter = address(0x1005);
    address internal permit2 = address(0x1006);
    address internal sunToken = address(0x2001);
    address internal moonToken = address(0x2002);
    address internal sunCurve = address(0x2004);

    struct Fixture {
        MockUSDT usdc;
        PoolManager poolManager;
        StateView stateView;
        Create2HookDeployer create2Deployer;
    }

    function testLocalForkDryRunSimulatesHookPoolIdsInitializationAllowlistAndRenounce() public {
        vm.chainId(31_337);
        Fixture memory fixture = _deployFixture(6);

        PrepareBaseMainnetSunMoonUsdcForkDryRun script =
            new PrepareBaseMainnetSunMoonUsdcForkDryRun();
        PrepareBaseMainnetSunMoonUsdcForkDryRun.ForkDryRunPlan memory plan = script.prepare(
            _config(
                address(fixture.poolManager),
                address(fixture.stateView),
                address(fixture.usdc),
                address(fixture.create2Deployer),
                false,
                false
            )
        );

        assertTrue(plan.simulationOnly);
        assertEq(plan.transactionsPlanned, 6);
        assertFalse(plan.baseMainnetConfirmed);
        assertFalse(plan.broadcastRequested);
        assertFalse(plan.create2DeployerSimulated);
        assertEq(plan.chainId, 31_337);
        assertEq(plan.usdcDecimals, 6);
        assertEq(plan.mainnetAdminWallet, mainnetAdminWallet);
        assertEq(plan.protocolBudgetWallet, protocolBudgetWallet);
        assertEq(plan.create2DeployerOwner, create2Owner);
        assertEq(plan.create2HookDeployer, address(fixture.create2Deployer));

        assertEq(plan.expectedHookMask, BaseV4HookAddressMiner.BASE_SUN_MOON_USDC_FEE_V4_HOOK_MASK);
        assertEq(plan.actualHookMask, plan.expectedHookMask);
        assertEq(plan.predictedHook, plan.deployedHookSimulation);
        assertGt(plan.deployedHookSimulation.code.length, 0);

        assertEq(address(plan.sunUsdcPoolKey.hooks), plan.predictedHook);
        assertEq(plan.sunUsdcPoolKey.fee, 3000);
        assertEq(plan.sunUsdcPoolKey.tickSpacing, 60);
        assertEq(plan.sunUsdcPoolId, PoolId.unwrap(plan.sunUsdcPoolKey.toId()));
        assertEq(plan.sunUsdcInitialTokenAmount, 1e18);
        assertEq(plan.sunUsdcInitialUsdcAmount, 1e6);
        assertEq(plan.sunUsdcSqrtPriceAfter, plan.sunUsdcSqrtPriceX96);
        assertEq(plan.sunUsdcTickAfter, plan.sunUsdcInitialTick);
        assertFalse(plan.sunUsdcAlreadyInitialized);

        assertEq(address(plan.moonUsdcPoolKey.hooks), plan.predictedHook);
        assertEq(plan.moonUsdcPoolKey.fee, 3000);
        assertEq(plan.moonUsdcPoolKey.tickSpacing, 60);
        assertEq(plan.moonUsdcPoolId, PoolId.unwrap(plan.moonUsdcPoolKey.toId()));
        assertEq(plan.moonUsdcInitialTokenAmount, 1e18);
        assertEq(plan.moonUsdcInitialUsdcAmount, 240_000);
        assertEq(plan.moonUsdcSqrtPriceAfter, plan.moonUsdcSqrtPriceX96);
        assertEq(plan.moonUsdcTickAfter, plan.moonUsdcInitialTick);
        assertFalse(plan.moonUsdcAlreadyInitialized);

        assertNotEq(plan.sunUsdcPoolId, plan.moonUsdcPoolId);
        assertTrue(_contains(plan.sunUsdcPoolKey, sunToken));
        assertTrue(_contains(plan.sunUsdcPoolKey, address(fixture.usdc)));
        assertTrue(_contains(plan.moonUsdcPoolKey, moonToken));
        assertTrue(_contains(plan.moonUsdcPoolKey, address(fixture.usdc)));

        assertFalse(plan.sunUsdcAllowedBefore);
        assertFalse(plan.moonUsdcAllowedBefore);
        assertTrue(plan.sunUsdcAllowedAfter);
        assertTrue(plan.moonUsdcAllowedAfter);
        assertEq(plan.ownerBeforeRenounce, mainnetAdminWallet);
        assertEq(plan.ownerAfterRenounce, address(0));
        assertTrue(plan.renounceBlocksSunAllowlist);
        assertTrue(plan.renounceBlocksMoonAllowlist);
        assertTrue(plan.renounceBlocksProtocolBudget);
    }

    function testLocalForkDryRunCanSimulatePredictedCreate2DeployerCode() public {
        vm.chainId(31_337);
        Fixture memory fixture = _deployFixture(6);
        address predictedCreate2Deployer = makeAddr("predictedCreate2Deployer");

        PrepareBaseMainnetSunMoonUsdcForkDryRun script =
            new PrepareBaseMainnetSunMoonUsdcForkDryRun();
        PrepareBaseMainnetSunMoonUsdcForkDryRun.ForkDryRunPlan memory plan = script.prepare(
            _config(
                address(fixture.poolManager),
                address(fixture.stateView),
                address(fixture.usdc),
                predictedCreate2Deployer,
                false,
                false
            )
        );

        assertTrue(plan.create2DeployerSimulated);
        assertEq(plan.create2HookDeployer, predictedCreate2Deployer);
        assertEq(Create2HookDeployer(predictedCreate2Deployer).owner(), create2Owner);
        assertEq(plan.predictedHook, plan.deployedHookSimulation);
        assertEq(plan.sunUsdcSqrtPriceAfter, plan.sunUsdcSqrtPriceX96);
        assertEq(plan.moonUsdcSqrtPriceAfter, plan.moonUsdcSqrtPriceX96);
    }

    function testRunLoadsEnvironmentButStillDoesNotBroadcast() public {
        vm.chainId(31_337);
        Fixture memory fixture = _deployFixture(6);
        _setEnv(
            address(fixture.poolManager),
            address(fixture.stateView),
            address(fixture.usdc),
            address(fixture.create2Deployer),
            false,
            false
        );

        PrepareBaseMainnetSunMoonUsdcForkDryRun script =
            new PrepareBaseMainnetSunMoonUsdcForkDryRun();
        PrepareBaseMainnetSunMoonUsdcForkDryRun.ForkDryRunPlan memory plan = script.run();

        assertTrue(plan.simulationOnly);
        assertEq(plan.transactionsPlanned, 6);
        assertFalse(plan.broadcastRequested);
        assertEq(plan.mainnetAdminWallet, mainnetAdminWallet);
        assertEq(plan.protocolBudgetWallet, protocolBudgetWallet);
        assertEq(plan.usdcToken, address(fixture.usdc));
    }

    function testBaseMainnetForkDryRunUsesOfficialInfrastructureWhenConfirmed() public {
        vm.chainId(BaseV4Addresses.BASE_MAINNET_CHAIN_ID);
        _etchBaseMainnetDependencies();
        Create2HookDeployer create2Deployer = new Create2HookDeployer(create2Owner);

        PrepareBaseMainnetSunMoonUsdcForkDryRun script =
            new PrepareBaseMainnetSunMoonUsdcForkDryRun();
        PrepareBaseMainnetSunMoonUsdcForkDryRun.ForkDryRunPlan memory plan = script.prepare(
            _baseMainnetConfig(
                BaseV4Addresses.BASE_MAINNET_USDC, address(create2Deployer), true, false
            )
        );

        assertEq(plan.chainId, BaseV4Addresses.BASE_MAINNET_CHAIN_ID);
        assertTrue(plan.baseMainnetConfirmed);
        assertFalse(plan.broadcastRequested);
        assertEq(plan.poolManager, BaseV4Addresses.BASE_MAINNET_POOL_MANAGER);
        assertEq(plan.stateView, BaseV4Addresses.BASE_MAINNET_STATE_VIEW);
        assertEq(plan.usdcToken, BaseV4Addresses.BASE_MAINNET_USDC);
        assertEq(plan.usdcDecimals, 6);
        assertEq(plan.actualHookMask, plan.expectedHookMask);
        assertEq(plan.sunUsdcSqrtPriceAfter, plan.sunUsdcSqrtPriceX96);
        assertEq(plan.moonUsdcSqrtPriceAfter, plan.moonUsdcSqrtPriceX96);
        assertEq(plan.ownerAfterRenounce, address(0));
    }

    function testBaseMainnetRequiresExplicitForkDryRunConfirmation() public {
        vm.chainId(BaseV4Addresses.BASE_MAINNET_CHAIN_ID);
        _etchBaseMainnetDependencies();
        Create2HookDeployer create2Deployer = new Create2HookDeployer(create2Owner);

        PrepareBaseMainnetSunMoonUsdcForkDryRun script =
            new PrepareBaseMainnetSunMoonUsdcForkDryRun();

        vm.expectRevert(
            abi.encodeWithSelector(
                PrepareBaseMainnetSunMoonUsdcForkDryRun.BaseMainnetForkDryRunNotConfirmed.selector,
                BaseV4Addresses.BASE_MAINNET_CHAIN_ID
            )
        );
        script.prepare(
            _baseMainnetConfig(
                BaseV4Addresses.BASE_MAINNET_USDC, address(create2Deployer), false, false
            )
        );
    }

    function testRejectsBroadcastFlag() public {
        vm.chainId(31_337);
        Fixture memory fixture = _deployFixture(6);

        PrepareBaseMainnetSunMoonUsdcForkDryRun script =
            new PrepareBaseMainnetSunMoonUsdcForkDryRun();

        vm.expectRevert(PrepareBaseMainnetSunMoonUsdcForkDryRun.BroadcastNotAllowed.selector);
        script.prepare(
            _config(
                address(fixture.poolManager),
                address(fixture.stateView),
                address(fixture.usdc),
                address(fixture.create2Deployer),
                false,
                true
            )
        );
    }

    function testRejectsMissingWalletAddress() public {
        vm.chainId(31_337);
        Fixture memory fixture = _deployFixture(6);
        PrepareBaseMainnetSunMoonUsdcForkDryRun.ForkDryRunConfig memory config = _config(
            address(fixture.poolManager),
            address(fixture.stateView),
            address(fixture.usdc),
            address(fixture.create2Deployer),
            false,
            false
        );
        config.mainnetAdminWallet = address(0);

        PrepareBaseMainnetSunMoonUsdcForkDryRun script =
            new PrepareBaseMainnetSunMoonUsdcForkDryRun();

        vm.expectRevert(
            abi.encodeWithSelector(
                PrepareBaseMainnetSunMoonUsdcForkDryRun.InvalidAddress.selector,
                bytes32("MAINNET_ADMIN_WALLET")
            )
        );
        script.prepare(config);
    }

    function testRejectsProtocolBudgetWalletAsAdminWallet() public {
        vm.chainId(31_337);
        Fixture memory fixture = _deployFixture(6);
        PrepareBaseMainnetSunMoonUsdcForkDryRun.ForkDryRunConfig memory config = _config(
            address(fixture.poolManager),
            address(fixture.stateView),
            address(fixture.usdc),
            address(fixture.create2Deployer),
            false,
            false
        );
        config.protocolBudgetWallet = config.mainnetAdminWallet;

        PrepareBaseMainnetSunMoonUsdcForkDryRun script =
            new PrepareBaseMainnetSunMoonUsdcForkDryRun();

        vm.expectRevert(
            abi.encodeWithSelector(
                PrepareBaseMainnetSunMoonUsdcForkDryRun.DuplicateAddress.selector,
                bytes32("PROTOCOL_BUDGET_WALLET"),
                bytes32("MAINNET_ADMIN_WALLET"),
                config.mainnetAdminWallet
            )
        );
        script.prepare(config);
    }

    function testRejectsWrongCreate2Owner() public {
        vm.chainId(31_337);
        Fixture memory fixture = _deployFixture(6);
        address wrongOwner = makeAddr("wrongOwner");
        PrepareBaseMainnetSunMoonUsdcForkDryRun.ForkDryRunConfig memory config = _config(
            address(fixture.poolManager),
            address(fixture.stateView),
            address(fixture.usdc),
            address(fixture.create2Deployer),
            false,
            false
        );
        config.create2DeployerOwner = wrongOwner;

        PrepareBaseMainnetSunMoonUsdcForkDryRun script =
            new PrepareBaseMainnetSunMoonUsdcForkDryRun();

        vm.expectRevert(
            abi.encodeWithSelector(
                PrepareBaseMainnetSunMoonUsdcForkDryRun.Create2OwnerMismatch.selector,
                wrongOwner,
                create2Owner
            )
        );
        script.prepare(config);
    }

    function testRejectsInvalidPoolConfig() public {
        vm.chainId(31_337);
        Fixture memory fixture = _deployFixture(6);
        PrepareBaseMainnetSunMoonUsdcForkDryRun.ForkDryRunConfig memory config = _config(
            address(fixture.poolManager),
            address(fixture.stateView),
            address(fixture.usdc),
            address(fixture.create2Deployer),
            false,
            false
        );
        config.sunUsdcFee = 500;

        PrepareBaseMainnetSunMoonUsdcForkDryRun script =
            new PrepareBaseMainnetSunMoonUsdcForkDryRun();

        vm.expectRevert(
            abi.encodeWithSelector(
                PrepareBaseMainnetSunMoonUsdcForkDryRun.InvalidPoolConfig.selector,
                bytes32("SUN_USDC_POOL"),
                uint24(500),
                int24(60)
            )
        );
        script.prepare(config);
    }

    function testRejectsInvalidInitialPrice() public {
        vm.chainId(31_337);
        Fixture memory fixture = _deployFixture(6);
        PrepareBaseMainnetSunMoonUsdcForkDryRun.ForkDryRunConfig memory config = _config(
            address(fixture.poolManager),
            address(fixture.stateView),
            address(fixture.usdc),
            address(fixture.create2Deployer),
            false,
            false
        );
        config.moonUsdcInitialUsdcAmount = 0;

        PrepareBaseMainnetSunMoonUsdcForkDryRun script =
            new PrepareBaseMainnetSunMoonUsdcForkDryRun();

        vm.expectRevert(
            abi.encodeWithSelector(
                PrepareBaseMainnetSunMoonUsdcForkDryRun.InvalidInitialPrice.selector,
                bytes32("MOON_USDC_INITIAL_PRICE"),
                uint256(1e18),
                uint256(0)
            )
        );
        script.prepare(config);
    }

    function testRejectsUnexpectedPoolId() public {
        vm.chainId(31_337);
        Fixture memory fixture = _deployFixture(6);
        PrepareBaseMainnetSunMoonUsdcForkDryRun.ForkDryRunConfig memory config = _config(
            address(fixture.poolManager),
            address(fixture.stateView),
            address(fixture.usdc),
            address(fixture.create2Deployer),
            false,
            false
        );
        config.expectedSunUsdcPoolId = bytes32(uint256(123));

        PrepareBaseMainnetSunMoonUsdcForkDryRun script =
            new PrepareBaseMainnetSunMoonUsdcForkDryRun();

        vm.expectRevert();
        script.prepare(config);
    }

    function testRejectsUnsupportedChain() public {
        vm.chainId(BaseV4Addresses.BASE_SEPOLIA_CHAIN_ID);
        Fixture memory fixture = _deployFixture(6);

        PrepareBaseMainnetSunMoonUsdcForkDryRun script =
            new PrepareBaseMainnetSunMoonUsdcForkDryRun();

        vm.expectRevert(
            abi.encodeWithSelector(
                PrepareBaseMainnetSunMoonUsdcForkDryRun.UnsupportedChain.selector,
                BaseV4Addresses.BASE_SEPOLIA_CHAIN_ID
            )
        );
        script.prepare(
            _config(
                address(fixture.poolManager),
                address(fixture.stateView),
                address(fixture.usdc),
                address(fixture.create2Deployer),
                false,
                false
            )
        );
    }

    function testBaseMainnetRejectsWrongUsdc() public {
        vm.chainId(BaseV4Addresses.BASE_MAINNET_CHAIN_ID);
        _etchBaseMainnetDependencies();
        MockUSDT wrongUsdc = new MockUSDT("Wrong USDC", "wUSDC", 6);
        Create2HookDeployer create2Deployer = new Create2HookDeployer(create2Owner);

        PrepareBaseMainnetSunMoonUsdcForkDryRun script =
            new PrepareBaseMainnetSunMoonUsdcForkDryRun();

        vm.expectRevert(
            abi.encodeWithSelector(
                PrepareBaseMainnetSunMoonUsdcForkDryRun.BaseMainnetUnexpectedAddress.selector,
                bytes32("USDC_TOKEN"),
                BaseV4Addresses.BASE_MAINNET_USDC,
                address(wrongUsdc)
            )
        );
        script.prepare(
            _baseMainnetConfig(address(wrongUsdc), address(create2Deployer), true, false)
        );
    }

    function testRejectsUsdcWithWrongDecimals() public {
        vm.chainId(31_337);
        Fixture memory fixture = _deployFixture(18);

        PrepareBaseMainnetSunMoonUsdcForkDryRun script =
            new PrepareBaseMainnetSunMoonUsdcForkDryRun();

        vm.expectRevert(
            abi.encodeWithSelector(
                PrepareBaseMainnetSunMoonUsdcForkDryRun.UsdcDecimalsMismatch.selector, 6, 18
            )
        );
        script.prepare(
            _config(
                address(fixture.poolManager),
                address(fixture.stateView),
                address(fixture.usdc),
                address(fixture.create2Deployer),
                false,
                false
            )
        );
    }

    function _deployFixture(uint8 usdcDecimals) private returns (Fixture memory fixture) {
        fixture.usdc = new MockUSDT("Mock USDC", "USDC", usdcDecimals);
        fixture.poolManager = new PoolManager(mainnetAdminWallet);
        fixture.stateView = new StateView(IPoolManager(address(fixture.poolManager)));
        fixture.create2Deployer = new Create2HookDeployer(create2Owner);
    }

    function _config(
        address poolManager_,
        address stateView_,
        address usdc,
        address create2HookDeployer,
        bool confirmed,
        bool broadcast
    )
        private
        view
        returns (PrepareBaseMainnetSunMoonUsdcForkDryRun.ForkDryRunConfig memory config)
    {
        config = PrepareBaseMainnetSunMoonUsdcForkDryRun.ForkDryRunConfig({
                mainnetDeployer: mainnetDeployer,
                mainnetAdminWallet: mainnetAdminWallet,
                protocolBudgetWallet: protocolBudgetWallet,
                create2DeployerOwner: create2Owner,
                create2HookDeployer: create2HookDeployer,
                poolManager: poolManager_,
                positionManager: positionManager,
                stateView: stateView_,
                quoter: quoter,
                universalRouter: universalRouter,
                permit2: permit2,
                sunToken: sunToken,
                moonToken: moonToken,
                usdcToken: usdc,
                sunCurve: sunCurve,
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
                baseMainnetConfirmed: confirmed,
                broadcastRequested: broadcast
            });
    }

    function _baseMainnetConfig(
        address usdc,
        address create2HookDeployer,
        bool confirmed,
        bool broadcast
    )
        private
        view
        returns (PrepareBaseMainnetSunMoonUsdcForkDryRun.ForkDryRunConfig memory config)
    {
        config =
            _config(
                BaseV4Addresses.BASE_MAINNET_POOL_MANAGER,
                BaseV4Addresses.BASE_MAINNET_STATE_VIEW,
                usdc,
                create2HookDeployer,
                confirmed,
                broadcast
            );
        config.positionManager = BaseV4Addresses.BASE_MAINNET_POSITION_MANAGER;
        config.quoter = BaseV4Addresses.BASE_MAINNET_QUOTER;
        config.universalRouter = BaseV4Addresses.BASE_MAINNET_UNIVERSAL_ROUTER;
        config.permit2 = BaseV4Addresses.PERMIT2;
    }

    function _setEnv(
        address poolManager_,
        address stateView_,
        address usdc,
        address create2HookDeployer,
        bool confirmed,
        bool broadcast
    ) private {
        vm.setEnv("MAINNET_DEPLOYER", vm.toString(mainnetDeployer));
        vm.setEnv("MAINNET_ADMIN_WALLET", vm.toString(mainnetAdminWallet));
        vm.setEnv("PROTOCOL_BUDGET_WALLET", vm.toString(protocolBudgetWallet));
        vm.setEnv("CREATE2_DEPLOYER_OWNER", vm.toString(create2Owner));
        vm.setEnv("CREATE2_HOOK_DEPLOYER", vm.toString(create2HookDeployer));
        vm.setEnv("POOL_MANAGER", vm.toString(poolManager_));
        vm.setEnv("POSITION_MANAGER", vm.toString(positionManager));
        vm.setEnv("STATE_VIEW", vm.toString(stateView_));
        vm.setEnv("QUOTER", vm.toString(quoter));
        vm.setEnv("UNIVERSAL_ROUTER", vm.toString(universalRouter));
        vm.setEnv("PERMIT2", vm.toString(permit2));
        vm.setEnv("SUN_TOKEN", vm.toString(sunToken));
        vm.setEnv("MOON_TOKEN", vm.toString(moonToken));
        vm.setEnv("USDC_TOKEN", vm.toString(usdc));
        vm.setEnv("SUN_CURVE", vm.toString(sunCurve));
        vm.setEnv("SUN_USDC_POOL_FEE", "3000");
        vm.setEnv("SUN_USDC_POOL_TICK_SPACING", "60");
        vm.setEnv("SUN_USDC_INITIAL_TOKEN_AMOUNT", "1000000000000000000");
        vm.setEnv("SUN_USDC_INITIAL_USDC_AMOUNT", "1000000");
        vm.setEnv("MOON_USDC_POOL_FEE", "3000");
        vm.setEnv("MOON_USDC_POOL_TICK_SPACING", "60");
        vm.setEnv("MOON_USDC_INITIAL_TOKEN_AMOUNT", "1000000000000000000");
        vm.setEnv("MOON_USDC_INITIAL_USDC_AMOUNT", "240000");
        vm.setEnv("HOOK_SALT_START", "0");
        vm.setEnv("HOOK_MAX_SALT_SEARCH", "300000");
        vm.setEnv("CONFIRM_BASE_MAINNET_SUN_MOON_FORK_DRY_RUN", confirmed ? "1" : "0");
        vm.setEnv("EXECUTE_BASE_MAINNET_BROADCAST", broadcast ? "1" : "0");
    }

    function _contains(PoolKey memory key, address token) private pure returns (bool) {
        return Currency.unwrap(key.currency0) == token || Currency.unwrap(key.currency1) == token;
    }

    function _etchBaseMainnetDependencies() private {
        deployCodeTo(
            "PoolManager.sol:PoolManager",
            abi.encode(mainnetAdminWallet),
            BaseV4Addresses.BASE_MAINNET_POOL_MANAGER
        );
        deployCodeTo(
            "StateView.sol:StateView",
            abi.encode(IPoolManager(BaseV4Addresses.BASE_MAINNET_POOL_MANAGER)),
            BaseV4Addresses.BASE_MAINNET_STATE_VIEW
        );
        _etchMockUsdcAt(BaseV4Addresses.BASE_MAINNET_USDC);
        vm.etch(BaseV4Addresses.BASE_MAINNET_POSITION_MANAGER, hex"01");
        vm.etch(BaseV4Addresses.BASE_MAINNET_QUOTER, hex"01");
        vm.etch(BaseV4Addresses.BASE_MAINNET_UNIVERSAL_ROUTER, hex"01");
        vm.etch(BaseV4Addresses.PERMIT2, hex"01");
    }

    function _etchMockUsdcAt(address target) private {
        deployCodeTo(
            "MockUSDT.sol:MockUSDT", abi.encode("Mock Base Mainnet USDC", "USDC", 6), target
        );
    }
}
