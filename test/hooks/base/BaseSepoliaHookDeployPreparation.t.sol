// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Test } from "forge-std/Test.sol";
import { IPoolManager } from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import { IMoonAmmSwapAdapter } from "../../../contracts/hooks/MoonAmmFeeHook.sol";
import { BaseMoonAmmFeeV4Hook } from "../../../contracts/hooks/base/BaseMoonAmmFeeV4Hook.sol";
import { BaseV4Addresses } from "../../../contracts/hooks/base/BaseV4Addresses.sol";
import { BaseV4HookAddressMiner } from "../../../contracts/hooks/base/BaseV4HookAddressMiner.sol";
import { Create2HookDeployer } from "../../../contracts/hooks/base/Create2HookDeployer.sol";
import { SunCurve } from "../../../contracts/SunCurve.sol";
import { PrepareBaseSepoliaHookDeploy } from "../../../script/PrepareBaseSepoliaHookDeploy.s.sol";

contract BaseSepoliaHookDeployPreparationTest is Test {
    address internal hookOwner = 0x6E22b2e6fFAA30Fe75B71d53d1eC469b4e97A986;
    address internal protocolBudget = 0x277ba3Cf597CdAaF958C301db3cF6a631F793039;
    address internal moonToken = 0x6E7FF34C7a7a518981BF6324e5FCC6599FcBC59D;
    address internal sunCurve = 0x00F49621977e5219093A988879F07936F2155c07;
    address internal swapAdapter = 0x50f232d1B40D9EF523cc53f958f8C80766aF35a7;

    function testHookBroadcastPreparationGuardsAndDeploys() public {
        _assertLocalSimulationDeploysHookAtPredictedAddress();
        _assertBaseMainnetIsRejected();
        _assertBaseSepoliaRequiresExplicitConfirmation();
        _assertBaseSepoliaRejectsWrongPredictedHook();
        _assertBaseSepoliaRejectsWrongCreate2Owner();
        _assertBaseSepoliaRejectsOccupiedPredictedHook();
    }

    function _assertLocalSimulationDeploysHookAtPredictedAddress() private {
        vm.chainId(31_337);
        Create2HookDeployer create2Deployer = new Create2HookDeployer(hookOwner);
        (bytes32 hookSalt, address predictedHook) = _setHookDeployEnv(create2Deployer, hookOwner);
        _etchDeploymentDependencies();

        PrepareBaseSepoliaHookDeploy script = new PrepareBaseSepoliaHookDeploy();
        PrepareBaseSepoliaHookDeploy.Deployment memory deployment = script.run();

        assertFalse(deployment.baseSepoliaConfirmed);
        assertEq(deployment.chainId, 31_337);
        assertEq(address(deployment.create2Deployer), address(create2Deployer));
        assertEq(deployment.hookOwner, hookOwner);
        assertEq(deployment.hookSalt, hookSalt);
        assertEq(deployment.predictedHook, predictedHook);
        assertEq(deployment.deployedHook, predictedHook);
        assertGt(deployment.deployedHook.code.length, 0);
        assertEq(deployment.expectedHookMask, BaseV4HookAddressMiner.BASE_MOON_AMM_FEE_V4_HOOK_MASK);
        assertEq(deployment.actualHookMask, BaseV4HookAddressMiner.BASE_MOON_AMM_FEE_V4_HOOK_MASK);

        BaseMoonAmmFeeV4Hook hook = BaseMoonAmmFeeV4Hook(deployment.deployedHook);
        assertEq(address(hook.poolManager()), BaseV4Addresses.BASE_SEPOLIA_POOL_MANAGER);
        assertEq(hook.moonToken(), moonToken);
        assertEq(address(hook.usdt()), BaseV4Addresses.BASE_SEPOLIA_USDC);
        assertEq(address(hook.sunCurve()), sunCurve);
        assertEq(hook.protocolBudget(), protocolBudget);
        assertEq(address(hook.swapAdapter()), swapAdapter);
        assertEq(hook.owner(), hookOwner);
    }

    function _assertBaseMainnetIsRejected() private {
        vm.chainId(BaseV4Addresses.BASE_MAINNET_CHAIN_ID);
        Create2HookDeployer create2Deployer = new Create2HookDeployer(hookOwner);
        _setHookDeployEnv(create2Deployer, hookOwner);

        PrepareBaseSepoliaHookDeploy script = new PrepareBaseSepoliaHookDeploy();

        vm.expectRevert(
            abi.encodeWithSelector(
                PrepareBaseSepoliaHookDeploy.BaseMainnetNotAllowed.selector,
                BaseV4Addresses.BASE_MAINNET_CHAIN_ID
            )
        );
        script.run();
    }

    function _assertBaseSepoliaRequiresExplicitConfirmation() private {
        vm.chainId(BaseV4Addresses.BASE_SEPOLIA_CHAIN_ID);
        Create2HookDeployer create2Deployer = new Create2HookDeployer(hookOwner);
        _setHookDeployEnv(create2Deployer, hookOwner);
        _etchDeploymentDependencies();
        vm.setEnv("CONFIRM_BASE_SEPOLIA_HOOK_DEPLOY_RUN", "0");

        PrepareBaseSepoliaHookDeploy script = new PrepareBaseSepoliaHookDeploy();

        vm.expectRevert(
            abi.encodeWithSelector(
                PrepareBaseSepoliaHookDeploy.BaseSepoliaRunNotConfirmed.selector,
                BaseV4Addresses.BASE_SEPOLIA_CHAIN_ID
            )
        );
        script.run();
    }

    function _assertBaseSepoliaRejectsWrongPredictedHook() private {
        vm.chainId(BaseV4Addresses.BASE_SEPOLIA_CHAIN_ID);
        Create2HookDeployer create2Deployer = new Create2HookDeployer(hookOwner);
        (, address predictedHook) = _setHookDeployEnv(create2Deployer, hookOwner);
        address wrongPredictedHook = address(uint160(predictedHook) + uint160(1 << 14));
        vm.setEnv("PREDICTED_HOOK", vm.toString(wrongPredictedHook));
        vm.setEnv("CONFIRM_BASE_SEPOLIA_HOOK_DEPLOY_RUN", "1");
        _etchDeploymentDependencies();

        PrepareBaseSepoliaHookDeploy script = new PrepareBaseSepoliaHookDeploy();

        vm.expectRevert(
            abi.encodeWithSelector(
                PrepareBaseSepoliaHookDeploy.UnexpectedPredictedHook.selector,
                wrongPredictedHook,
                predictedHook
            )
        );
        script.run();
    }

    function _assertBaseSepoliaRejectsWrongCreate2Owner() private {
        vm.chainId(BaseV4Addresses.BASE_SEPOLIA_CHAIN_ID);
        address wrongOwner = makeAddr("wrongOwner");
        Create2HookDeployer create2Deployer = new Create2HookDeployer(wrongOwner);
        _setHookDeployEnv(create2Deployer, hookOwner);
        vm.setEnv("CONFIRM_BASE_SEPOLIA_HOOK_DEPLOY_RUN", "1");
        _etchDeploymentDependencies();

        PrepareBaseSepoliaHookDeploy script = new PrepareBaseSepoliaHookDeploy();

        vm.expectRevert(
            abi.encodeWithSelector(
                PrepareBaseSepoliaHookDeploy.Create2DeployerOwnerMismatch.selector,
                hookOwner,
                wrongOwner
            )
        );
        script.run();
    }

    function _assertBaseSepoliaRejectsOccupiedPredictedHook() private {
        vm.chainId(BaseV4Addresses.BASE_SEPOLIA_CHAIN_ID);
        Create2HookDeployer create2Deployer = new Create2HookDeployer(hookOwner);
        (, address predictedHook) = _setHookDeployEnv(create2Deployer, hookOwner);
        vm.setEnv("CONFIRM_BASE_SEPOLIA_HOOK_DEPLOY_RUN", "1");
        _etchDeploymentDependencies();
        vm.etch(predictedHook, hex"01");

        PrepareBaseSepoliaHookDeploy script = new PrepareBaseSepoliaHookDeploy();

        vm.expectRevert(
            abi.encodeWithSelector(
                PrepareBaseSepoliaHookDeploy.PredictedHookAlreadyDeployed.selector, predictedHook
            )
        );
        script.run();
    }

    function _setHookDeployEnv(Create2HookDeployer create2Deployer, address expectedHookOwner)
        private
        returns (bytes32 hookSalt, address predictedHook)
    {
        bytes memory initCode = _baseMoonHookInitCode(expectedHookOwner);
        bytes32 initCodeHash = keccak256(initCode);
        bool found;
        (hookSalt, predictedHook, found) = BaseV4HookAddressMiner.mineSalt(
            address(create2Deployer),
            initCodeHash,
            BaseV4HookAddressMiner.BASE_MOON_AMM_FEE_V4_HOOK_MASK,
            0,
            200_000
        );
        assertTrue(found);

        vm.setEnv("CREATE2_DEPLOYER", vm.toString(address(create2Deployer)));
        vm.setEnv("HOOK_OWNER", vm.toString(expectedHookOwner));
        vm.setEnv("POOL_MANAGER", vm.toString(BaseV4Addresses.BASE_SEPOLIA_POOL_MANAGER));
        vm.setEnv("POSITION_MANAGER", vm.toString(BaseV4Addresses.BASE_SEPOLIA_POSITION_MANAGER));
        vm.setEnv("UNIVERSAL_ROUTER", vm.toString(BaseV4Addresses.BASE_SEPOLIA_UNIVERSAL_ROUTER));
        vm.setEnv("USDC_TOKEN", vm.toString(BaseV4Addresses.BASE_SEPOLIA_USDC));
        vm.setEnv("MOON_TOKEN", vm.toString(moonToken));
        vm.setEnv("SUN_CURVE", vm.toString(sunCurve));
        vm.setEnv("PROTOCOL_BUDGET_ADDRESS", vm.toString(protocolBudget));
        vm.setEnv("SWAP_ADAPTER", vm.toString(swapAdapter));
        vm.setEnv("HOOK_SALT", vm.toString(hookSalt));
        vm.setEnv("PREDICTED_HOOK", vm.toString(predictedHook));
        vm.setEnv("CONFIRM_BASE_SEPOLIA_HOOK_DEPLOY_RUN", "0");
    }

    function _etchDeploymentDependencies() private {
        _etchCode(BaseV4Addresses.BASE_SEPOLIA_POOL_MANAGER);
        _etchCode(BaseV4Addresses.BASE_SEPOLIA_POSITION_MANAGER);
        _etchCode(BaseV4Addresses.BASE_SEPOLIA_UNIVERSAL_ROUTER);
        _etchCode(BaseV4Addresses.BASE_SEPOLIA_USDC);
        _etchCode(moonToken);
        _etchCode(sunCurve);
        _etchCode(swapAdapter);
    }

    function _etchCode(address target) private {
        vm.etch(target, hex"6000");
    }

    function _baseMoonHookInitCode(address expectedHookOwner) private view returns (bytes memory) {
        return abi.encodePacked(
            type(BaseMoonAmmFeeV4Hook).creationCode,
            abi.encode(
                IPoolManager(BaseV4Addresses.BASE_SEPOLIA_POOL_MANAGER),
                moonToken,
                IERC20(BaseV4Addresses.BASE_SEPOLIA_USDC),
                SunCurve(sunCurve),
                protocolBudget,
                IMoonAmmSwapAdapter(swapAdapter),
                expectedHookOwner
            )
        );
    }
}
