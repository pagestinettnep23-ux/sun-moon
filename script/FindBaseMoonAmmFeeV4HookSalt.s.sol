// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Script, console2 } from "forge-std/Script.sol";
import { IPoolManager } from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import { IMoonAmmSwapAdapter } from "../contracts/hooks/MoonAmmFeeHook.sol";
import { BaseMoonAmmFeeV4Hook } from "../contracts/hooks/base/BaseMoonAmmFeeV4Hook.sol";
import { BaseV4HookAddressMiner } from "../contracts/hooks/base/BaseV4HookAddressMiner.sol";
import { SunCurve } from "../contracts/SunCurve.sol";

// DEPRECATED / LEGACY BaseMoonAmmFeeV4Hook path.
// Old Base Sepolia-only salt helper; do not use for rc4 or Base mainnet.
// Current rc4/mainnet path uses BaseSunMoonUsdcFeeV4Hook.
contract FindBaseMoonAmmFeeV4HookSalt is Script {
    function run() external view returns (bytes32 salt, address hookAddress) {
        console2.log("DEPRECATED LEGACY SCRIPT: old BaseMoonAmmFeeV4Hook path; not for rc4/mainnet");

        address create2Deployer = vm.envOr("CREATE2_DEPLOYER", msg.sender);
        uint256 startSalt = vm.envOr("HOOK_SALT_START", uint256(0));
        uint256 maxIterations = vm.envOr("HOOK_MAX_SALT_SEARCH", uint256(200_000));

        bytes memory initCode = _baseMoonHookInitCode();
        bytes32 initCodeHash = keccak256(initCode);

        bool found;
        (salt, hookAddress, found) = BaseV4HookAddressMiner.mineSalt(
            create2Deployer,
            initCodeHash,
            BaseV4HookAddressMiner.BASE_MOON_AMM_FEE_V4_HOOK_MASK,
            startSalt,
            maxIterations
        );
        require(found, "salt not found in search range");

        console2.log("BaseMoonAmmFeeV4Hook CREATE2 precheck");
        console2.log("create2Deployer:", create2Deployer);
        console2.log("initCodeHash:");
        console2.logBytes32(initCodeHash);
        console2.log("salt:");
        console2.logBytes32(salt);
        console2.log("predictedHook:", hookAddress);
        console2.log("expectedMask:", BaseV4HookAddressMiner.BASE_MOON_AMM_FEE_V4_HOOK_MASK);
        console2.log(
            "actualLow14Bits:", uint160(hookAddress) & BaseV4HookAddressMiner.V4_ALL_HOOK_MASK
        );
    }

    function _baseMoonHookInitCode() private view returns (bytes memory) {
        address poolManager = vm.envOr("POOL_MANAGER", address(0x1001));
        address moonToken = vm.envOr("MOON_TOKEN", address(0x1002));
        address usdc = vm.envOr("USDC_TOKEN", address(0x1003));
        address sunCurve = vm.envOr("SUN_CURVE", address(0x1004));
        address protocolBudget = vm.envOr("PROTOCOL_BUDGET_ADDRESS", address(0x1005));
        address swapAdapter = vm.envOr("SWAP_ADAPTER", address(0x1006));
        address owner = vm.envOr("HOOK_OWNER", msg.sender);

        return abi.encodePacked(
            type(BaseMoonAmmFeeV4Hook).creationCode,
            abi.encode(
                IPoolManager(poolManager),
                moonToken,
                IERC20(usdc),
                SunCurve(sunCurve),
                protocolBudget,
                IMoonAmmSwapAdapter(swapAdapter),
                owner
            )
        );
    }
}
