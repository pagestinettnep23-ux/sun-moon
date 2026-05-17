// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { Test } from "forge-std/Test.sol";
import { IHooks } from "@uniswap/v4-core/src/interfaces/IHooks.sol";
import { Hooks } from "@uniswap/v4-core/src/libraries/Hooks.sol";
import { PoolManager } from "@uniswap/v4-core/src/PoolManager.sol";
import { PoolKey } from "@uniswap/v4-core/src/types/PoolKey.sol";
import { Currency } from "@uniswap/v4-core/src/types/Currency.sol";
import { BaseV4HookProbe } from "../../../contracts/hooks/base/BaseV4HookProbe.sol";

contract BaseV4PoolManagerProbeTest is Test {
    uint160 internal constant SQRT_PRICE_1_1 = 79_228_162_514_264_337_593_543_950_336;

    address internal owner = makeAddr("owner");

    PoolManager internal poolManager;

    function setUp() public {
        poolManager = new PoolManager(owner);
    }

    function testPoolManagerInitializesPoolThroughPermissionedHookAddress() public {
        address permissionedHook = address(
            uint160(
                Hooks.BEFORE_INITIALIZE_FLAG | Hooks.BEFORE_ADD_LIQUIDITY_FLAG
                    | Hooks.AFTER_SWAP_FLAG
            )
        );

        BaseV4HookProbe implementation = new BaseV4HookProbe(address(poolManager));
        vm.etch(permissionedHook, address(implementation).code);

        PoolKey memory key = PoolKey({
            currency0: Currency.wrap(address(0x1000)),
            currency1: Currency.wrap(address(0x2000)),
            fee: 3000,
            tickSpacing: 60,
            hooks: IHooks(permissionedHook)
        });

        int24 tick = poolManager.initialize(key, SQRT_PRICE_1_1);

        assertEq(tick, 0);
        assertGt(permissionedHook.code.length, 0);
    }

    function testPoolManagerRejectsHookAddressWithoutPermissionBits() public {
        BaseV4HookProbe implementation = new BaseV4HookProbe(address(poolManager));

        PoolKey memory key = PoolKey({
            currency0: Currency.wrap(address(0x1000)),
            currency1: Currency.wrap(address(0x2000)),
            fee: 3000,
            tickSpacing: 60,
            hooks: IHooks(address(implementation))
        });

        vm.expectRevert(abi.encodeWithSelector(Hooks.HookAddressNotValid.selector, implementation));
        poolManager.initialize(key, SQRT_PRICE_1_1);
    }
}
