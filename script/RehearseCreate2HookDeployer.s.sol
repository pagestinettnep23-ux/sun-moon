// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Script, console2 } from "forge-std/Script.sol";
import { IPoolManager } from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import { IMoonAmmSwapAdapter } from "../contracts/hooks/MoonAmmFeeHook.sol";
import { BaseMoonAmmFeeV4Hook } from "../contracts/hooks/base/BaseMoonAmmFeeV4Hook.sol";
import { BaseV4HookAddressMiner } from "../contracts/hooks/base/BaseV4HookAddressMiner.sol";
import { Create2HookDeployer } from "../contracts/hooks/base/Create2HookDeployer.sol";
import { SunCurve } from "../contracts/SunCurve.sol";

// DEPRECATED / LEGACY BaseMoonAmmFeeV4Hook path.
// Old local rehearsal helper; do not use for rc4 or Base mainnet.
// Current rc4/mainnet path uses BaseSunMoonUsdcFeeV4Hook.
contract RehearseCreate2HookDeployer is Script {
    struct Rehearsal {
        Create2HookDeployer create2Deployer;
        bytes32 initCodeHash;
        bytes32 hookSalt;
        address predictedHook;
        BaseMoonAmmFeeV4Hook hook;
    }

    function run() external returns (Rehearsal memory rehearsal) {
        console2.log("DEPRECATED LEGACY SCRIPT: old BaseMoonAmmFeeV4Hook path; not for rc4/mainnet");

        address create2Owner = vm.envOr("CREATE2_DEPLOYER_OWNER", address(0));
        address hookOwner = vm.envOr("HOOK_OWNER", msg.sender);
        if (create2Owner == address(0)) {
            create2Owner = hookOwner;
        }

        uint256 startSalt = vm.envOr("HOOK_SALT_START", uint256(0));
        uint256 maxIterations = vm.envOr("HOOK_MAX_SALT_SEARCH", uint256(200_000));

        require(create2Owner != address(0), "create2Owner is zero");
        require(hookOwner != address(0), "hookOwner is zero");
        require(maxIterations != 0, "maxIterations is zero");

        rehearsal.create2Deployer = new Create2HookDeployer(create2Owner);

        bytes memory initCode = _baseMoonHookInitCode(hookOwner);
        rehearsal.initCodeHash = keccak256(initCode);

        bool found;
        (rehearsal.hookSalt, rehearsal.predictedHook, found) = BaseV4HookAddressMiner.mineSalt(
            address(rehearsal.create2Deployer),
            rehearsal.initCodeHash,
            BaseV4HookAddressMiner.BASE_MOON_AMM_FEE_V4_HOOK_MASK,
            startSalt,
            maxIterations
        );
        require(found, "salt not found in search range");

        require(
            rehearsal.create2Deployer.computeAddress(rehearsal.hookSalt, rehearsal.initCodeHash)
                == rehearsal.predictedHook,
            "predicted hook mismatch"
        );

        vm.prank(create2Owner);
        address deployedHook = rehearsal.create2Deployer
            .deployHook(
                rehearsal.hookSalt, initCode, BaseV4HookAddressMiner.BASE_MOON_AMM_FEE_V4_HOOK_MASK
            );

        require(deployedHook == rehearsal.predictedHook, "deployed hook mismatch");
        require(deployedHook.code.length != 0, "hook code missing");
        require(
            BaseMoonAmmFeeV4Hook(deployedHook).expectedHookMask()
                == BaseV4HookAddressMiner.BASE_MOON_AMM_FEE_V4_HOOK_MASK,
            "hook mask mismatch"
        );

        rehearsal.hook = BaseMoonAmmFeeV4Hook(deployedHook);

        console2.log("Create2HookDeployer local rehearsal passed");
        console2.log("simulationOnly:", "do not add --broadcast");
        console2.log("create2Deployer:", address(rehearsal.create2Deployer));
        console2.log("create2Owner:", create2Owner);
        console2.log("hookOwner:", hookOwner);
        console2.log("initCodeHash:");
        console2.logBytes32(rehearsal.initCodeHash);
        console2.log("hookSalt:");
        console2.logBytes32(rehearsal.hookSalt);
        console2.log("predictedHook:", rehearsal.predictedHook);
        console2.log("deployedHook:", deployedHook);
        console2.log("expectedMask:", BaseV4HookAddressMiner.BASE_MOON_AMM_FEE_V4_HOOK_MASK);
        console2.log(
            "actualLow14Bits:", uint160(deployedHook) & BaseV4HookAddressMiner.V4_ALL_HOOK_MASK
        );
    }

    function _baseMoonHookInitCode(address hookOwner) private view returns (bytes memory) {
        address poolManager = vm.envOr("POOL_MANAGER", address(0x1001));
        address moonToken = vm.envOr("MOON_TOKEN", address(0x1002));
        address usdc = vm.envOr("USDC_TOKEN", address(0x1003));
        address sunCurve = vm.envOr("SUN_CURVE", address(0x1004));
        address protocolBudget = vm.envOr("PROTOCOL_BUDGET_ADDRESS", address(0x1005));
        address swapAdapter = vm.envOr("SWAP_ADAPTER", address(0x1006));

        return abi.encodePacked(
            type(BaseMoonAmmFeeV4Hook).creationCode,
            abi.encode(
                IPoolManager(poolManager),
                moonToken,
                IERC20(usdc),
                SunCurve(sunCurve),
                protocolBudget,
                IMoonAmmSwapAdapter(swapAdapter),
                hookOwner
            )
        );
    }
}
