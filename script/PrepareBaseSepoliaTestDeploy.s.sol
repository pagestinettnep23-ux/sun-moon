// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import { Script, console2 } from "forge-std/Script.sol";
import { BaseV4Addresses } from "../contracts/hooks/base/BaseV4Addresses.sol";
import { TestnetUsdcAdapter } from "../contracts/hooks/TestnetUsdcAdapter.sol";
import { MockUSDT } from "../contracts/mocks/MockUSDT.sol";
import { MoonCurve } from "../contracts/MoonCurve.sol";
import { MoonToken } from "../contracts/MoonToken.sol";
import { SunCurve } from "../contracts/SunCurve.sol";
import { SunToken } from "../contracts/SunToken.sol";

contract PrepareBaseSepoliaTestDeploy is Script {
    uint256 internal constant USDC_ONE = 1e6;
    uint256 internal constant TOKEN_ONE = 1e18;
    uint256 internal constant SUN_MAX_MINT_USDC = 10_000 * USDC_ONE;
    uint256 internal constant MOON_MAX_MINT_USDC_EQUIV = 10_000 * USDC_ONE;
    uint256 internal constant MOON_K = 5_000_000 * TOKEN_ONE;
    uint256 internal constant MOON_S = 1_200_000 * TOKEN_ONE;

    struct Deployment {
        address deployer;
        address owner;
        address protocolBudget;
        address temporaryAuthorizedHook;
        uint256 chainId;
        uint256 moonLaunchTime;
        bool useMockUsdc;
        bool baseSepoliaConfirmed;
        IERC20Metadata usdc;
        MockUSDT mockUsdc;
        SunToken sunToken;
        SunCurve sunCurve;
        MoonToken moonToken;
        MoonCurve moonCurve;
        TestnetUsdcAdapter adapter;
    }

    struct DeployConfig {
        address deployer;
        address owner;
        address protocolBudget;
        address temporaryAuthorizedHook;
        uint256 moonLaunchDelay;
        bool useMockUsdc;
        bool baseSepoliaConfirmed;
        address usdcToken;
    }

    error BaseMainnetNotAllowed(uint256 chainId);
    error BaseSepoliaMockUsdcNotAllowed();
    error BaseSepoliaRunNotConfirmed(uint256 chainId);
    error BaseSepoliaUnexpectedUsdc(address expected, address actual);
    error InvalidBoolEnv(string key, string value);
    error InvalidAddress();
    error UnexpectedDeployer(address expected, address actual);

    function run() external returns (Deployment memory deployment) {
        uint256 deployerPrivateKey = vm.envOr("PRIVATE_KEY", uint256(0));
        deployment.deployer = _deployer(deployerPrivateKey);
        _validateDeployer(deployment.deployer);

        deployment.owner = vm.envOr("HOOK_OWNER", deployment.deployer);
        deployment.protocolBudget = vm.envOr("PROTOCOL_BUDGET_ADDRESS", deployment.deployer);
        deployment.temporaryAuthorizedHook = vm.envOr("TEMP_AUTHORIZED_HOOK", deployment.owner);
        uint256 moonLaunchDelay = vm.envOr("MOON_LAUNCH_DELAY", uint256(0));
        deployment.moonLaunchTime = block.timestamp + moonLaunchDelay;
        deployment.useMockUsdc = _envBoolOrDefault("USE_MOCK_USDC", true);
        deployment.chainId = block.chainid;
        deployment.baseSepoliaConfirmed =
            vm.envOr("CONFIRM_BASE_SEPOLIA_TEST_DEPLOY_RUN", uint256(0)) == 1;

        if (!deployment.useMockUsdc) {
            deployment.usdc =
                IERC20Metadata(vm.envOr("USDC_TOKEN", BaseV4Addresses.BASE_SEPOLIA_USDC));
        }

        deployment = _deploy(deployment, deployerPrivateKey);
    }

    function deploy(DeployConfig memory config) external returns (Deployment memory deployment) {
        deployment.deployer = config.deployer == address(0) ? msg.sender : config.deployer;
        deployment.owner = config.owner;
        deployment.protocolBudget = config.protocolBudget;
        deployment.temporaryAuthorizedHook = config.temporaryAuthorizedHook;
        deployment.moonLaunchTime = block.timestamp + config.moonLaunchDelay;
        deployment.useMockUsdc = config.useMockUsdc;
        deployment.chainId = block.chainid;
        deployment.baseSepoliaConfirmed = config.baseSepoliaConfirmed;
        if (!deployment.useMockUsdc) deployment.usdc = IERC20Metadata(config.usdcToken);

        deployment = _deploy(deployment, 0);
    }

    function _deploy(Deployment memory deployment, uint256 deployerPrivateKey)
        private
        returns (Deployment memory)
    {
        _validateRun(deployment);

        address configuredUsdcAddress = address(deployment.usdc);
        if (!deployment.useMockUsdc) {
            if (configuredUsdcAddress == address(0)) {
                configuredUsdcAddress = BaseV4Addresses.BASE_SEPOLIA_USDC;
            }
            _validateUsdc(deployment.chainId, configuredUsdcAddress);
        }

        if (deployerPrivateKey == 0) {
            vm.startBroadcast(deployment.deployer);
        } else {
            vm.startBroadcast(deployerPrivateKey);
        }

        if (deployment.useMockUsdc) {
            deployment.mockUsdc = new MockUSDT("Mock Base Sepolia USDC", "mUSDC", 6);
            deployment.usdc = IERC20Metadata(address(deployment.mockUsdc));
        } else {
            deployment.usdc = IERC20Metadata(configuredUsdcAddress);
        }

        address temporaryOwner = deployment.deployer;

        deployment.sunToken = new SunToken("SUN", "SUN", temporaryOwner);
        deployment.sunCurve = new SunCurve(
            deployment.sunToken,
            deployment.usdc,
            deployment.protocolBudget,
            SUN_MAX_MINT_USDC,
            temporaryOwner
        );
        deployment.moonToken = new MoonToken("MOON", "MOON", temporaryOwner);
        deployment.moonCurve = new MoonCurve(
            deployment.moonToken,
            deployment.sunToken,
            deployment.sunCurve,
            deployment.protocolBudget,
            MOON_K,
            MOON_S,
            deployment.moonLaunchTime,
            MOON_MAX_MINT_USDC_EQUIV,
            temporaryOwner
        );
        deployment.adapter = new TestnetUsdcAdapter(
            IERC20(address(deployment.usdc)), deployment.temporaryAuthorizedHook, temporaryOwner
        );

        deployment.sunToken.setMinter(address(deployment.sunCurve));
        deployment.sunCurve.setMoonCurve(address(deployment.moonCurve));
        deployment.moonToken.setMinter(address(deployment.moonCurve));
        _transferOwnershipToFinalOwner(deployment, temporaryOwner);

        vm.stopBroadcast();

        _validateDeployment(deployment);
        _logDeployment(deployment);
        return deployment;
    }

    function _deployer(uint256 deployerPrivateKey) private view returns (address deployer) {
        if (deployerPrivateKey != 0) {
            return vm.addr(deployerPrivateKey);
        }

        deployer = _envAddressOrZero("DEPLOYER_ADDRESS");
        if (deployer == address(0)) {
            deployer = msg.sender;
        }
    }

    function _envAddressOrZero(string memory key) private view returns (address value) {
        string memory rawValue = vm.envOr(key, string(""));
        if (bytes(rawValue).length == 0) {
            return address(0);
        }

        value = vm.parseAddress(rawValue);
    }

    function _envBoolOrDefault(string memory key, bool defaultValue) private view returns (bool) {
        string memory rawValue = vm.envOr(key, string(""));
        if (bytes(rawValue).length == 0) {
            return defaultValue;
        }

        bytes32 valueHash = keccak256(bytes(rawValue));
        if (
            valueHash == keccak256(bytes("1")) || valueHash == keccak256(bytes("true"))
                || valueHash == keccak256(bytes("TRUE"))
        ) {
            return true;
        }
        if (
            valueHash == keccak256(bytes("0")) || valueHash == keccak256(bytes("false"))
                || valueHash == keccak256(bytes("FALSE"))
        ) {
            return false;
        }

        revert InvalidBoolEnv(key, rawValue);
    }

    function _validateDeployer(address deployer) private view {
        address expectedDeployer = _envAddressOrZero("DEPLOYER_ADDRESS");
        if (expectedDeployer != address(0) && deployer != expectedDeployer) {
            revert UnexpectedDeployer(expectedDeployer, deployer);
        }
    }

    function _validateRun(Deployment memory deployment) private pure {
        if (
            deployment.owner == address(0) || deployment.protocolBudget == address(0)
                || deployment.temporaryAuthorizedHook == address(0)
        ) {
            revert InvalidAddress();
        }
        if (deployment.chainId == BaseV4Addresses.BASE_MAINNET_CHAIN_ID) {
            revert BaseMainnetNotAllowed(deployment.chainId);
        }
        if (deployment.chainId == BaseV4Addresses.BASE_SEPOLIA_CHAIN_ID) {
            if (!deployment.baseSepoliaConfirmed) {
                revert BaseSepoliaRunNotConfirmed(deployment.chainId);
            }
            if (deployment.useMockUsdc) {
                revert BaseSepoliaMockUsdcNotAllowed();
            }
        }
    }

    function _validateUsdc(uint256 chainId, address usdcAddress) private pure {
        if (usdcAddress == address(0)) revert InvalidAddress();
        if (
            chainId == BaseV4Addresses.BASE_SEPOLIA_CHAIN_ID
                && usdcAddress != BaseV4Addresses.BASE_SEPOLIA_USDC
        ) {
            revert BaseSepoliaUnexpectedUsdc(BaseV4Addresses.BASE_SEPOLIA_USDC, usdcAddress);
        }
    }

    function _transferOwnershipToFinalOwner(Deployment memory deployment, address temporaryOwner)
        private
    {
        if (deployment.owner == temporaryOwner) {
            return;
        }

        deployment.sunToken.transferOwnership(deployment.owner);
        deployment.sunCurve.transferOwnership(deployment.owner);
        deployment.moonToken.transferOwnership(deployment.owner);
        deployment.moonCurve.transferOwnership(deployment.owner);
        deployment.adapter.transferOwnership(deployment.owner);
    }

    function _validateDeployment(Deployment memory deployment) private view {
        require(deployment.usdc.decimals() == 6, "USDC decimals mismatch");
        require(deployment.sunToken.owner() == deployment.owner, "SUN owner mismatch");
        require(deployment.moonToken.owner() == deployment.owner, "MOON owner mismatch");
        require(deployment.sunCurve.owner() == deployment.owner, "SunCurve owner mismatch");
        require(deployment.moonCurve.owner() == deployment.owner, "MoonCurve owner mismatch");
        require(deployment.adapter.owner() == deployment.owner, "adapter owner mismatch");
        require(deployment.sunToken.minter() == address(deployment.sunCurve), "SUN minter mismatch");
        require(
            deployment.moonToken.minter() == address(deployment.moonCurve), "MOON minter mismatch"
        );
        require(
            deployment.sunCurve.moonCurve() == address(deployment.moonCurve),
            "MoonCurve link mismatch"
        );
        require(deployment.sunCurve.moonAMM() == address(0), "MoonAMM should not be set yet");
        require(
            deployment.sunCurve.protocolBudget() == deployment.protocolBudget,
            "SunCurve budget mismatch"
        );
        require(
            deployment.moonCurve.protocolBudget() == deployment.protocolBudget,
            "MoonCurve budget mismatch"
        );
        require(
            deployment.moonCurve.launchTime() == deployment.moonLaunchTime,
            "MOON launch time mismatch"
        );
        require(deployment.sunCurve.maxMintUsdt() == SUN_MAX_MINT_USDC, "SUN max mint mismatch");
        require(
            deployment.moonCurve.maxMintUsdtEquiv() == MOON_MAX_MINT_USDC_EQUIV,
            "MOON max mint mismatch"
        );
        require(
            deployment.adapter.authorizedHook() == deployment.temporaryAuthorizedHook,
            "temporary hook mismatch"
        );
        require(address(deployment.adapter) != deployment.protocolBudget, "adapter budget clash");
        require(deployment.sunCurve.moonAMM() == address(0), "MoonAMM must remain unset");
    }

    function _logDeployment(Deployment memory deployment) private pure {
        console2.log("Base Sepolia minimal test deployment preparation");
        console2.log("simulationOnly:", "do not add --broadcast without explicit approval");
        console2.log("chainId:", deployment.chainId);
        console2.log("baseSepoliaConfirmed:", deployment.baseSepoliaConfirmed);
        console2.log("useMockUsdc:", deployment.useMockUsdc);
        console2.log("deployer:", deployment.deployer);
        console2.log("owner:", deployment.owner);
        console2.log("protocolBudget:", deployment.protocolBudget);
        console2.log("temporaryAuthorizedHook:", deployment.temporaryAuthorizedHook);
        console2.log("moonLaunchTime:", deployment.moonLaunchTime);
        console2.log("USDC:", address(deployment.usdc));
        console2.log("MockUSDC:", address(deployment.mockUsdc));
        console2.log("SunToken:", address(deployment.sunToken));
        console2.log("SunCurve:", address(deployment.sunCurve));
        console2.log("MoonToken:", address(deployment.moonToken));
        console2.log("MoonCurve:", address(deployment.moonCurve));
        console2.log("TestnetUsdcAdapter:", address(deployment.adapter));
        console2.log("Next env values for CREATE2 precheck:");
        console2.log("MOON_TOKEN:", address(deployment.moonToken));
        console2.log("SUN_CURVE:", address(deployment.sunCurve));
        console2.log("SWAP_ADAPTER:", address(deployment.adapter));
        console2.log("HOOK_OWNER:", deployment.owner);
        console2.log("PROTOCOL_BUDGET_ADDRESS:", deployment.protocolBudget);
        console2.log("Stop before broadcast until CREATE2 salt and predicted hook are checked.");
    }
}
