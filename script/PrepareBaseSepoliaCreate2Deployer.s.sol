// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { Script, console2 } from "forge-std/Script.sol";
import { BaseV4Addresses } from "../contracts/hooks/base/BaseV4Addresses.sol";
import { Create2HookDeployer } from "../contracts/hooks/base/Create2HookDeployer.sol";

contract PrepareBaseSepoliaCreate2Deployer is Script {
    struct Deployment {
        Create2HookDeployer create2Deployer;
        address deployer;
        address owner;
        uint256 chainId;
        bool baseSepoliaConfirmed;
    }

    error BaseMainnetNotAllowed(uint256 chainId);
    error BaseSepoliaRunNotConfirmed(uint256 chainId);
    error InvalidOwner();
    error UnexpectedDeployer(address expected, address actual);

    function run() external returns (Deployment memory deployment) {
        uint256 deployerPrivateKey = vm.envOr("PRIVATE_KEY", uint256(0));
        deployment.deployer = deployerPrivateKey == 0 ? msg.sender : vm.addr(deployerPrivateKey);
        _validateDeployer(deployment.deployer);
        deployment.owner = _create2Owner(deployment.deployer);
        deployment.chainId = block.chainid;
        deployment.baseSepoliaConfirmed =
            vm.envOr("CONFIRM_BASE_SEPOLIA_CREATE2_DEPLOYER_RUN", uint256(0)) == 1;

        _validateRun(deployment.owner, deployment.chainId, deployment.baseSepoliaConfirmed);

        if (deployerPrivateKey == 0) {
            vm.startBroadcast();
        } else {
            vm.startBroadcast(deployerPrivateKey);
        }

        deployment.create2Deployer = new Create2HookDeployer(deployment.owner);

        vm.stopBroadcast();

        _validateDeployment(deployment);
        _logDeployment(deployment);
    }

    function _create2Owner(address fallbackOwner) private view returns (address owner) {
        owner = _envAddressOrZero("CREATE2_DEPLOYER_OWNER");
        if (owner == address(0)) {
            owner = _envAddressOrZero("HOOK_OWNER");
            if (owner == address(0)) {
                owner = fallbackOwner;
            }
        }
    }

    function _envAddressOrZero(string memory key) private view returns (address value) {
        string memory rawValue = vm.envOr(key, string(""));
        if (bytes(rawValue).length == 0) {
            return address(0);
        }

        value = vm.parseAddress(rawValue);
    }

    function _validateDeployer(address deployer) private view {
        address expectedDeployer = _envAddressOrZero("DEPLOYER_ADDRESS");
        if (expectedDeployer != address(0) && deployer != expectedDeployer) {
            revert UnexpectedDeployer(expectedDeployer, deployer);
        }
    }

    function _validateRun(address owner, uint256 chainId, bool baseSepoliaConfirmed) private pure {
        if (owner == address(0)) revert InvalidOwner();
        if (chainId == BaseV4Addresses.BASE_MAINNET_CHAIN_ID) {
            revert BaseMainnetNotAllowed(chainId);
        }
        if (chainId == BaseV4Addresses.BASE_SEPOLIA_CHAIN_ID && !baseSepoliaConfirmed) {
            revert BaseSepoliaRunNotConfirmed(chainId);
        }
    }

    function _validateDeployment(Deployment memory deployment) private view {
        require(address(deployment.create2Deployer) != address(0), "CREATE2 deployer is zero");
        require(deployment.create2Deployer.owner() == deployment.owner, "owner mismatch");
    }

    function _logDeployment(Deployment memory deployment) private view {
        console2.log("Base Sepolia Create2HookDeployer preparation");
        console2.log("simulationOnly:", "do not add --broadcast without explicit approval");
        console2.log("chainId:", deployment.chainId);
        console2.log("baseSepoliaConfirmed:", deployment.baseSepoliaConfirmed);
        console2.log("deployer:", deployment.deployer);
        console2.log("create2Owner:", deployment.owner);
        console2.log("CREATE2_DEPLOYER:", address(deployment.create2Deployer));
        console2.log("CREATE2_DEPLOYER_OWNER:", deployment.create2Deployer.owner());
        console2.log("Next step after real Base Sepolia broadcast:");
        console2.log("record CREATE2_DEPLOYER before any Hook salt search");
    }
}
