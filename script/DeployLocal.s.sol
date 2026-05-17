// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { Script, console2 } from "forge-std/Script.sol";
import { MockUSDT } from "../contracts/mocks/MockUSDT.sol";
import { MoonCurve } from "../contracts/MoonCurve.sol";
import { MoonToken } from "../contracts/MoonToken.sol";
import { SunCurve } from "../contracts/SunCurve.sol";
import { SunToken } from "../contracts/SunToken.sol";

contract DeployLocal is Script {
    uint256 internal constant USDT_ONE = 1e6;
    uint256 internal constant TOKEN_ONE = 1e18;

    uint256 internal constant SUN_MAX_MINT_USDT = 10_000 * USDT_ONE;
    uint256 internal constant MOON_MAX_MINT_USDT_EQUIV = 10_000 * USDT_ONE;
    uint256 internal constant MOON_K = 5_000_000 * TOKEN_ONE;
    uint256 internal constant MOON_S = 1_200_000 * TOKEN_ONE;

    struct Deployment {
        MockUSDT usdt;
        SunToken sunToken;
        SunCurve sunCurve;
        MoonToken moonToken;
        MoonCurve moonCurve;
    }

    function run() external returns (Deployment memory deployment) {
        uint256 deployerPrivateKey = vm.envOr("PRIVATE_KEY", uint256(0));
        address deployer = deployerPrivateKey == 0 ? msg.sender : vm.addr(deployerPrivateKey);
        address protocolBudget = vm.envOr("PROTOCOL_BUDGET_ADDRESS", deployer);
        address moonAMM = vm.envOr("MOON_AMM_ADDRESS", deployer);
        uint256 moonLaunchDelay = vm.envOr("MOON_LAUNCH_DELAY", uint256(0));
        uint256 moonLaunchTime = block.timestamp + moonLaunchDelay;

        if (deployerPrivateKey == 0) {
            vm.startBroadcast();
        } else {
            vm.startBroadcast(deployerPrivateKey);
        }

        deployment.usdt = new MockUSDT("Mock USDT", "USDT", 6);
        deployment.sunToken = new SunToken("SUN", "SUN", deployer);
        deployment.sunCurve = new SunCurve(
            deployment.sunToken, deployment.usdt, protocolBudget, SUN_MAX_MINT_USDT, deployer
        );
        deployment.moonToken = new MoonToken("MOON", "MOON", deployer);
        deployment.moonCurve = new MoonCurve(
            deployment.moonToken,
            deployment.sunToken,
            deployment.sunCurve,
            protocolBudget,
            MOON_K,
            MOON_S,
            moonLaunchTime,
            MOON_MAX_MINT_USDT_EQUIV,
            deployer
        );

        deployment.sunToken.setMinter(address(deployment.sunCurve));
        deployment.sunCurve.setMoonCurve(address(deployment.moonCurve));
        deployment.sunCurve.setMoonAMM(moonAMM);
        deployment.moonToken.setMinter(address(deployment.moonCurve));

        vm.stopBroadcast();

        _validateDeployment(deployment, deployer, protocolBudget, moonAMM, moonLaunchTime);
        _logDeployment(deployment, deployer, protocolBudget, moonAMM, moonLaunchTime);
    }

    function _validateDeployment(
        Deployment memory deployment,
        address deployer,
        address protocolBudget,
        address moonAMM,
        uint256 moonLaunchTime
    ) private view {
        require(deployment.sunToken.owner() == deployer, "SUN owner mismatch");
        require(deployment.moonToken.owner() == deployer, "MOON owner mismatch");
        require(deployment.sunCurve.owner() == deployer, "SunCurve owner mismatch");
        require(deployment.moonCurve.owner() == deployer, "MoonCurve owner mismatch");
        require(deployment.sunToken.minter() == address(deployment.sunCurve), "SUN minter mismatch");
        require(
            deployment.moonToken.minter() == address(deployment.moonCurve), "MOON minter mismatch"
        );
        require(
            deployment.sunCurve.moonCurve() == address(deployment.moonCurve),
            "MoonCurve link mismatch"
        );
        require(deployment.sunCurve.moonAMM() == moonAMM, "MoonAMM link mismatch");
        require(deployment.sunCurve.protocolBudget() == protocolBudget, "SunCurve budget mismatch");
        require(
            deployment.moonCurve.protocolBudget() == protocolBudget, "MoonCurve budget mismatch"
        );
        require(deployment.moonCurve.launchTime() == moonLaunchTime, "MOON launch time mismatch");
        require(deployment.sunCurve.maxMintUsdt() == SUN_MAX_MINT_USDT, "SUN max mint mismatch");
        require(
            deployment.moonCurve.maxMintUsdtEquiv() == MOON_MAX_MINT_USDT_EQUIV,
            "MOON max mint mismatch"
        );
    }

    function _logDeployment(
        Deployment memory deployment,
        address deployer,
        address protocolBudget,
        address moonAMM,
        uint256 moonLaunchTime
    ) private pure {
        console2.log("SUN + MOON local deployment");
        console2.log("deployer:", deployer);
        console2.log("protocolBudget:", protocolBudget);
        console2.log("moonAMM:", moonAMM);
        console2.log("moonLaunchTime:", moonLaunchTime);
        console2.log("MockUSDT:", address(deployment.usdt));
        console2.log("SunToken:", address(deployment.sunToken));
        console2.log("SunCurve:", address(deployment.sunCurve));
        console2.log("MoonToken:", address(deployment.moonToken));
        console2.log("MoonCurve:", address(deployment.moonCurve));
    }
}
