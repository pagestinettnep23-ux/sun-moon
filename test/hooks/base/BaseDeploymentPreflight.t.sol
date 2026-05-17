// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { Test } from "forge-std/Test.sol";
import { BaseDeploymentPreflight } from "../../../contracts/hooks/base/BaseDeploymentPreflight.sol";
import { BaseV4Addresses } from "../../../contracts/hooks/base/BaseV4Addresses.sol";
import { BaseV4HookAddressMiner } from "../../../contracts/hooks/base/BaseV4HookAddressMiner.sol";

contract BaseDeploymentPreflightHarness {
    function validateBaseSepoliaMoonV2Params(
        BaseDeploymentPreflight.BaseMoonV2DeploymentParams memory params
    ) external pure {
        BaseDeploymentPreflight.validateBaseSepoliaMoonV2Params(params);
    }
}

contract BaseDeploymentPreflightTest is Test {
    BaseDeploymentPreflightHarness internal harness = new BaseDeploymentPreflightHarness();

    function testValidBaseSepoliaMoonV2ParamsPass() public pure {
        BaseDeploymentPreflight.validateBaseSepoliaMoonV2Params(_validParams());
    }

    function testRejectsNonBaseSepoliaChainId() public {
        BaseDeploymentPreflight.BaseMoonV2DeploymentParams memory params = _validParams();
        params.chainId = BaseV4Addresses.BASE_MAINNET_CHAIN_ID;

        vm.expectRevert(
            abi.encodeWithSelector(
                BaseDeploymentPreflight.UnsupportedChainId.selector,
                BaseV4Addresses.BASE_MAINNET_CHAIN_ID
            )
        );
        harness.validateBaseSepoliaMoonV2Params(params);
    }

    function testRejectsWrongOfficialPoolManager() public {
        BaseDeploymentPreflight.BaseMoonV2DeploymentParams memory params = _validParams();
        params.poolManager = address(0x9999);

        vm.expectRevert(
            abi.encodeWithSelector(
                BaseDeploymentPreflight.UnexpectedAddress.selector,
                BaseDeploymentPreflight.LABEL_POOL_MANAGER,
                params.poolManager,
                BaseV4Addresses.BASE_SEPOLIA_POOL_MANAGER
            )
        );
        harness.validateBaseSepoliaMoonV2Params(params);
    }

    function testRejectsMissingProjectAddress() public {
        BaseDeploymentPreflight.BaseMoonV2DeploymentParams memory params = _validParams();
        params.swapAdapter = address(0);

        vm.expectRevert(
            abi.encodeWithSelector(
                BaseDeploymentPreflight.ZeroAddress.selector,
                BaseDeploymentPreflight.LABEL_SWAP_ADAPTER
            )
        );
        harness.validateBaseSepoliaMoonV2Params(params);
    }

    function testRejectsDuplicateCriticalProjectAddress() public {
        BaseDeploymentPreflight.BaseMoonV2DeploymentParams memory params = _validParams();
        params.protocolBudget = params.swapAdapter;

        vm.expectRevert(
            abi.encodeWithSelector(
                BaseDeploymentPreflight.SameAddress.selector,
                BaseDeploymentPreflight.LABEL_PROTOCOL_BUDGET,
                BaseDeploymentPreflight.LABEL_SWAP_ADAPTER,
                params.swapAdapter
            )
        );
        harness.validateBaseSepoliaMoonV2Params(params);
    }

    function testRejectsPredictedHookAddressWithWrongPermissionBits() public {
        BaseDeploymentPreflight.BaseMoonV2DeploymentParams memory params = _validParams();
        params.predictedHook = _hookAddressWithMask(0);

        vm.expectRevert(
            abi.encodeWithSelector(
                BaseDeploymentPreflight.BadHookPermissionBits.selector,
                params.predictedHook,
                uint160(0),
                BaseDeploymentPreflight.expectedMoonV2HookMask()
            )
        );
        harness.validateBaseSepoliaMoonV2Params(params);
    }

    function _validParams()
        private
        pure
        returns (BaseDeploymentPreflight.BaseMoonV2DeploymentParams memory params)
    {
        params = BaseDeploymentPreflight.BaseMoonV2DeploymentParams({
            chainId: BaseV4Addresses.BASE_SEPOLIA_CHAIN_ID,
            poolManager: BaseV4Addresses.BASE_SEPOLIA_POOL_MANAGER,
            positionManager: BaseV4Addresses.BASE_SEPOLIA_POSITION_MANAGER,
            universalRouter: BaseV4Addresses.BASE_SEPOLIA_UNIVERSAL_ROUTER,
            usdc: BaseV4Addresses.BASE_SEPOLIA_USDC,
            moonToken: address(0x1001),
            sunCurve: address(0x1002),
            protocolBudget: address(0x1003),
            swapAdapter: address(0x1004),
            hookOwner: address(0x1005),
            predictedHook: _hookAddressWithMask(BaseDeploymentPreflight.expectedMoonV2HookMask())
        });
    }

    function _hookAddressWithMask(uint160 mask) private pure returns (address) {
        uint160 highBits = uint160(uint256(keccak256("base moon hook")))
            & ~BaseV4HookAddressMiner.V4_ALL_HOOK_MASK;

        return address(highBits | mask);
    }
}
