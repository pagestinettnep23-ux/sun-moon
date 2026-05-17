// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { Test } from "forge-std/Test.sol";
import { BaseV4Addresses } from "../../../contracts/hooks/base/BaseV4Addresses.sol";
import {
    PrepareBaseSepoliaCreate2Deployer
} from "../../../script/PrepareBaseSepoliaCreate2Deployer.s.sol";

contract BaseSepoliaCreate2DeployerPreparationTest is Test {
    address internal hookOwner = 0x6E22b2e6fFAA30Fe75B71d53d1eC469b4e97A986;

    function setUp() public {
        vm.setEnv("HOOK_OWNER", vm.toString(hookOwner));
        vm.setEnv("DEPLOYER_ADDRESS", "");
        vm.setEnv("CREATE2_DEPLOYER_OWNER", "");
        vm.setEnv("CONFIRM_BASE_SEPOLIA_CREATE2_DEPLOYER_RUN", "0");
    }

    function testLocalSimulationDeploysCreate2DeployerWithHookOwner() public {
        PrepareBaseSepoliaCreate2Deployer script = new PrepareBaseSepoliaCreate2Deployer();
        PrepareBaseSepoliaCreate2Deployer.Deployment memory deployment = script.run();

        assertEq(deployment.owner, hookOwner);
        assertEq(deployment.chainId, block.chainid);
        assertFalse(deployment.baseSepoliaConfirmed);
        assertGt(address(deployment.create2Deployer).code.length, 0);
        assertEq(deployment.create2Deployer.owner(), hookOwner);
    }

    function testBaseSepoliaRunRequiresExplicitConfirmation() public {
        vm.chainId(BaseV4Addresses.BASE_SEPOLIA_CHAIN_ID);

        PrepareBaseSepoliaCreate2Deployer script = new PrepareBaseSepoliaCreate2Deployer();

        vm.expectRevert(
            abi.encodeWithSelector(
                PrepareBaseSepoliaCreate2Deployer.BaseSepoliaRunNotConfirmed.selector,
                BaseV4Addresses.BASE_SEPOLIA_CHAIN_ID
            )
        );
        script.run();
    }

    function testRejectsBaseMainnet() public {
        vm.chainId(BaseV4Addresses.BASE_MAINNET_CHAIN_ID);

        PrepareBaseSepoliaCreate2Deployer script = new PrepareBaseSepoliaCreate2Deployer();

        vm.expectRevert(
            abi.encodeWithSelector(
                PrepareBaseSepoliaCreate2Deployer.BaseMainnetNotAllowed.selector,
                BaseV4Addresses.BASE_MAINNET_CHAIN_ID
            )
        );
        script.run();
    }
}
