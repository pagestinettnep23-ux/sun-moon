// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { Hooks } from "@uniswap/v4-core/src/libraries/Hooks.sol";

library BaseV4HookAddressMiner {
    uint160 internal constant V4_ALL_HOOK_MASK = uint160((1 << 14) - 1);

    uint160 internal constant BASE_MOON_AMM_FEE_V4_HOOK_MASK = Hooks.BEFORE_SWAP_FLAG
        | Hooks.AFTER_SWAP_FLAG | Hooks.BEFORE_SWAP_RETURNS_DELTA_FLAG
        | Hooks.AFTER_SWAP_RETURNS_DELTA_FLAG;

    uint160 internal constant BASE_SUN_MOON_USDC_FEE_V4_HOOK_MASK = BASE_MOON_AMM_FEE_V4_HOOK_MASK;

    function computeCreate2Address(address deployer, bytes32 salt, bytes32 initCodeHash)
        internal
        pure
        returns (address predicted)
    {
        predicted = address(
            uint160(
                uint256(keccak256(abi.encodePacked(bytes1(0xff), deployer, salt, initCodeHash)))
            )
        );
    }

    function matchesHookMask(address hookAddress, uint160 expectedMask)
        internal
        pure
        returns (bool)
    {
        return uint160(hookAddress) & V4_ALL_HOOK_MASK == expectedMask;
    }

    function mineSalt(
        address deployer,
        bytes32 initCodeHash,
        uint160 expectedMask,
        uint256 startSalt,
        uint256 maxIterations
    ) internal pure returns (bytes32 salt, address hookAddress, bool found) {
        for (uint256 i = 0; i < maxIterations; i++) {
            salt = bytes32(startSalt + i);
            hookAddress = computeCreate2Address(deployer, salt, initCodeHash);

            if (matchesHookMask(hookAddress, expectedMask)) {
                return (salt, hookAddress, true);
            }
        }

        return (bytes32(0), address(0), false);
    }
}
