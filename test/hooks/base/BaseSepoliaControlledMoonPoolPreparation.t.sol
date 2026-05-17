// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import { Test } from "forge-std/Test.sol";
import { IHooks } from "@uniswap/v4-core/src/interfaces/IHooks.sol";
import { IPoolManager } from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import { Currency } from "@uniswap/v4-core/src/types/Currency.sol";
import { PoolId, PoolIdLibrary } from "@uniswap/v4-core/src/types/PoolId.sol";
import { PoolKey } from "@uniswap/v4-core/src/types/PoolKey.sol";
import { IMoonAmmSwapAdapter } from "../../../contracts/hooks/MoonAmmFeeHook.sol";
import { TestnetUsdcAdapter } from "../../../contracts/hooks/TestnetUsdcAdapter.sol";
import { BaseMoonAmmFeeV4Hook } from "../../../contracts/hooks/base/BaseMoonAmmFeeV4Hook.sol";
import { BaseV4Addresses } from "../../../contracts/hooks/base/BaseV4Addresses.sol";
import { BaseV4HookAddressMiner } from "../../../contracts/hooks/base/BaseV4HookAddressMiner.sol";
import { MockUSDT } from "../../../contracts/mocks/MockUSDT.sol";
import { MoonToken } from "../../../contracts/MoonToken.sol";
import { SunCurve } from "../../../contracts/SunCurve.sol";
import { SunToken } from "../../../contracts/SunToken.sol";
import {
    PrepareBaseSepoliaControlledMoonPool
} from "../../../script/PrepareBaseSepoliaControlledMoonPool.s.sol";

contract BaseSepoliaControlledMoonPoolPreparationTest is Test {
    using PoolIdLibrary for PoolKey;

    address internal hookOwner = 0x6E22b2e6fFAA30Fe75B71d53d1eC469b4e97A986;
    address internal protocolBudget = 0x277ba3Cf597CdAaF958C301db3cF6a631F793039;
    uint160 internal nextHookHighBits = 1;

    struct Fixture {
        BaseMoonAmmFeeV4Hook hook;
        MoonToken moon;
        MockUSDT usdc;
        bytes32 poolId;
    }

    function testLocalSimulationComputesAndAllowsMoonUsdcPool() public {
        _assertLocalSimulationComputesAndAllowsMoonUsdcPool();
    }

    function testIdempotentWhenPoolAlreadyAllowed() public {
        _assertIdempotentWhenPoolAlreadyAllowed();
    }

    function testBaseMainnetIsRejected() public {
        _assertBaseMainnetIsRejected();
    }

    function testBaseSepoliaRequiresExplicitConfirmation() public {
        _assertBaseSepoliaRequiresExplicitConfirmation();
    }

    function testRejectsWrongMoonToken() public {
        _assertRejectsWrongMoonToken();
    }

    function testRejectsInvalidPoolConfig() public {
        _assertRejectsInvalidPoolConfig();
    }

    function _assertLocalSimulationComputesAndAllowsMoonUsdcPool() private {
        vm.chainId(31_337);
        Fixture memory fixture = _deployFixture(false);

        PrepareBaseSepoliaControlledMoonPool script = new PrepareBaseSepoliaControlledMoonPool();
        PrepareBaseSepoliaControlledMoonPool.ControlledPool memory pool =
            script.prepare(_poolConfig(fixture, false));

        assertEq(pool.chainId, 31_337);
        assertFalse(pool.baseSepoliaConfirmed);
        assertEq(pool.hookOwner, hookOwner);
        assertEq(address(pool.hook), address(fixture.hook));
        assertEq(pool.moonToken, address(fixture.moon));
        assertEq(pool.usdcToken, address(fixture.usdc));
        assertEq(pool.fee, 3000);
        assertEq(pool.tickSpacing, 60);
        assertEq(pool.poolId, fixture.poolId);
        assertFalse(pool.alreadyAllowed);
        assertEq(pool.transactionsPlanned, 1);
        assertTrue(fixture.hook.allowedMoonPools(fixture.poolId));
    }

    function _assertIdempotentWhenPoolAlreadyAllowed() private {
        vm.chainId(31_337);
        Fixture memory fixture = _deployFixture(true);

        PrepareBaseSepoliaControlledMoonPool script = new PrepareBaseSepoliaControlledMoonPool();
        PrepareBaseSepoliaControlledMoonPool.ControlledPool memory pool =
            script.prepare(_poolConfig(fixture, false));

        assertTrue(pool.alreadyAllowed);
        assertEq(pool.transactionsPlanned, 0);
        assertEq(pool.poolId, fixture.poolId);
        assertTrue(fixture.hook.allowedMoonPools(fixture.poolId));
    }

    function _assertBaseMainnetIsRejected() private {
        vm.chainId(BaseV4Addresses.BASE_MAINNET_CHAIN_ID);
        Fixture memory fixture = _deployFixture(false);

        PrepareBaseSepoliaControlledMoonPool script = new PrepareBaseSepoliaControlledMoonPool();

        vm.expectRevert(
            abi.encodeWithSelector(
                PrepareBaseSepoliaControlledMoonPool.BaseMainnetNotAllowed.selector,
                BaseV4Addresses.BASE_MAINNET_CHAIN_ID
            )
        );
        script.prepare(_poolConfig(fixture, false));
    }

    function _assertBaseSepoliaRequiresExplicitConfirmation() private {
        vm.chainId(BaseV4Addresses.BASE_SEPOLIA_CHAIN_ID);
        Fixture memory fixture = _deployFixture(false);

        PrepareBaseSepoliaControlledMoonPool script = new PrepareBaseSepoliaControlledMoonPool();

        vm.expectRevert(
            abi.encodeWithSelector(
                PrepareBaseSepoliaControlledMoonPool.BaseSepoliaRunNotConfirmed.selector,
                BaseV4Addresses.BASE_SEPOLIA_CHAIN_ID
            )
        );
        script.prepare(_poolConfig(fixture, false));
    }

    function _assertRejectsWrongMoonToken() private {
        vm.chainId(31_337);
        Fixture memory fixture = _deployFixture(false);
        MoonToken wrongMoon = new MoonToken("Wrong MOON", "WMOON", hookOwner);
        PrepareBaseSepoliaControlledMoonPool.ControlledPoolConfig memory config =
            _poolConfig(fixture, false);
        config.moonToken = address(wrongMoon);

        PrepareBaseSepoliaControlledMoonPool script = new PrepareBaseSepoliaControlledMoonPool();

        vm.expectRevert(
            abi.encodeWithSelector(
                PrepareBaseSepoliaControlledMoonPool.UnexpectedParameter.selector,
                bytes32("MOON_TOKEN"),
                address(wrongMoon),
                address(fixture.moon)
            )
        );
        script.prepare(config);
    }

    function _assertRejectsInvalidPoolConfig() private {
        vm.chainId(31_337);
        Fixture memory fixture = _deployFixture(false);
        PrepareBaseSepoliaControlledMoonPool.ControlledPoolConfig memory config =
            _poolConfig(fixture, false);
        config.fee = 0;

        PrepareBaseSepoliaControlledMoonPool script = new PrepareBaseSepoliaControlledMoonPool();

        vm.expectRevert(
            abi.encodeWithSelector(
                PrepareBaseSepoliaControlledMoonPool.InvalidPoolConfig.selector,
                uint24(0),
                int24(60)
            )
        );
        script.prepare(config);
    }

    function _deployFixture(bool preAllowed) private returns (Fixture memory fixture) {
        fixture.usdc = new MockUSDT("Base Sepolia USDC", "USDC", 6);
        fixture.moon = new MoonToken("MOON", "MOON", hookOwner);
        SunToken sunToken = new SunToken("SUN", "SUN", hookOwner);
        SunCurve sunCurve = new SunCurve(
            sunToken, IERC20Metadata(address(fixture.usdc)), protocolBudget, 10_000e6, hookOwner
        );
        TestnetUsdcAdapter adapter =
            new TestnetUsdcAdapter(IERC20(address(fixture.usdc)), hookOwner, hookOwner);
        address hookAddress = _nextPermissionedHookAddress();

        BaseMoonAmmFeeV4Hook implementation = new BaseMoonAmmFeeV4Hook(
            IPoolManager(BaseV4Addresses.BASE_SEPOLIA_POOL_MANAGER),
            address(fixture.moon),
            IERC20(address(fixture.usdc)),
            sunCurve,
            protocolBudget,
            IMoonAmmSwapAdapter(address(adapter)),
            hookOwner
        );
        vm.etch(hookAddress, address(implementation).code);
        fixture.hook = BaseMoonAmmFeeV4Hook(hookAddress);

        PoolKey memory key =
            _poolKey(address(fixture.moon), address(fixture.usdc), IHooks(hookAddress));
        fixture.poolId = PoolId.unwrap(key.toId());

        if (preAllowed) {
            vm.prank(hookOwner);
            fixture.hook.setAllowedMoonPool(fixture.poolId, true);
        }
    }

    function _nextPermissionedHookAddress() private returns (address hookAddress) {
        hookAddress = address(
            uint160(BaseV4HookAddressMiner.BASE_MOON_AMM_FEE_V4_HOOK_MASK)
                | (nextHookHighBits << 14)
        );
        nextHookHighBits++;
    }

    function _poolKey(address tokenA, address tokenB, IHooks hook)
        private
        pure
        returns (PoolKey memory key)
    {
        (Currency currency0, Currency currency1) = tokenA < tokenB
            ? (Currency.wrap(tokenA), Currency.wrap(tokenB))
            : (Currency.wrap(tokenB), Currency.wrap(tokenA));
        key = PoolKey({
            currency0: currency0, currency1: currency1, fee: 3000, tickSpacing: 60, hooks: hook
        });
    }

    function _poolConfig(Fixture memory fixture, bool baseSepoliaConfirmed)
        private
        view
        returns (PrepareBaseSepoliaControlledMoonPool.ControlledPoolConfig memory config)
    {
        config = PrepareBaseSepoliaControlledMoonPool.ControlledPoolConfig({
            baseSepoliaConfirmed: baseSepoliaConfirmed,
            hookOwner: hookOwner,
            hook: address(fixture.hook),
            moonToken: address(fixture.moon),
            usdcToken: address(fixture.usdc),
            fee: 3000,
            tickSpacing: 60
        });
    }
}
