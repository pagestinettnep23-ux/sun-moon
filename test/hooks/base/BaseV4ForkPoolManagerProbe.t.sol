// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { Test } from "forge-std/Test.sol";
import { IHooks } from "@uniswap/v4-core/src/interfaces/IHooks.sol";
import { Hooks } from "@uniswap/v4-core/src/libraries/Hooks.sol";
import { IPoolManager } from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import { PoolKey } from "@uniswap/v4-core/src/types/PoolKey.sol";
import { Currency } from "@uniswap/v4-core/src/types/Currency.sol";
import { BaseV4Addresses } from "../../../contracts/hooks/base/BaseV4Addresses.sol";
import { BaseV4HookProbe } from "../../../contracts/hooks/base/BaseV4HookProbe.sol";

contract BaseV4ForkPoolManagerProbeTest is Test {
    uint160 internal constant SQRT_PRICE_1_1 = 79_228_162_514_264_337_593_543_950_336;

    function testOfficialBasePoolManagerInitializesPoolThroughProbeHookOnFork() public {
        address poolManagerAddress = _activePoolManager();
        if (poolManagerAddress == address(0)) return;

        address permissionedHook = address(
            uint160(
                Hooks.BEFORE_INITIALIZE_FLAG | Hooks.BEFORE_ADD_LIQUIDITY_FLAG
                    | Hooks.AFTER_SWAP_FLAG
            )
        );

        BaseV4HookProbe implementation = new BaseV4HookProbe(poolManagerAddress);
        vm.etch(permissionedHook, address(implementation).code);

        PoolKey memory key = PoolKey({
            currency0: Currency.wrap(address(0x1000)),
            currency1: Currency.wrap(address(0x2000)),
            fee: 3000,
            tickSpacing: 60,
            hooks: IHooks(permissionedHook)
        });

        int24 tick = IPoolManager(poolManagerAddress).initialize(key, SQRT_PRICE_1_1);

        assertEq(tick, 0);
        assertGt(permissionedHook.code.length, 0);
    }

    function _activePoolManager() private view returns (address) {
        if (block.chainid == BaseV4Addresses.BASE_SEPOLIA_CHAIN_ID) {
            return BaseV4Addresses.BASE_SEPOLIA_POOL_MANAGER;
        }

        if (block.chainid == BaseV4Addresses.BASE_MAINNET_CHAIN_ID) {
            return BaseV4Addresses.BASE_MAINNET_POOL_MANAGER;
        }

        return address(0);
    }
}
