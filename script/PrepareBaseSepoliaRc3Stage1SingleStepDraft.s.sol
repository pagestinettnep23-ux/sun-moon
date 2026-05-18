// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import { Script, console2 } from "forge-std/Script.sol";
import { BaseV4Addresses } from "../contracts/hooks/base/BaseV4Addresses.sol";
import { Create2HookDeployer } from "../contracts/hooks/base/Create2HookDeployer.sol";
import { MoonCurve } from "../contracts/MoonCurve.sol";
import { MoonToken } from "../contracts/MoonToken.sol";
import { SunCurve } from "../contracts/SunCurve.sol";
import { SunToken } from "../contracts/SunToken.sol";

contract PrepareBaseSepoliaRc3Stage1SingleStepDraft is Script {
    bytes32 internal constant LABEL_SEPOLIA_DEPLOYER = "SEPOLIA_DEPLOYER";
    bytes32 internal constant LABEL_SEPOLIA_ADMIN_WALLET = "SEPOLIA_ADMIN_WALLET";
    bytes32 internal constant LABEL_SEPOLIA_PROTOCOL_BUDGET_WALLET =
        "SEPOLIA_PROTOCOL_BUDGET_WALLET";
    bytes32 internal constant LABEL_SEPOLIA_CREATE2_DEPLOYER_OWNER =
        "SEPOLIA_CREATE2_DEPLOYER_OWNER";
    bytes32 internal constant LABEL_USDC_TOKEN = "USDC_TOKEN";
    bytes32 internal constant LABEL_SUN_TOKEN = "SUN_TOKEN";
    bytes32 internal constant LABEL_SUN_CURVE = "SUN_CURVE";
    bytes32 internal constant LABEL_MOON_TOKEN = "MOON_TOKEN";
    bytes32 internal constant LABEL_MOON_CURVE = "MOON_CURVE";
    bytes32 internal constant LABEL_CREATE2_HOOK_DEPLOYER = "CREATE2_HOOK_DEPLOYER";

    uint256 internal constant LOCAL_SIMULATION_CHAIN_ID = 31_337;
    uint256 internal constant USDC_ONE = 1e6;
    uint256 internal constant TOKEN_ONE = 1e18;
    uint256 internal constant MOON_MAX_MINT_USDC_EQUIV = 10_000 * USDC_ONE;
    uint256 internal constant MOON_K = 5_000_000 * TOKEN_ONE;
    uint256 internal constant MOON_S = 1_200_000 * TOKEN_ONE;
    uint256 internal constant FIRST_SINGLE_STEP_NONCE = 19;
    uint256 internal constant SINGLE_STEP_COUNT = 9;

    address internal constant DEFAULT_SEPOLIA_DEPLOYER = 0x2F6E887c6058deE520f9468a1022E3480A6334D3;
    address internal constant DEFAULT_SEPOLIA_ADMIN = 0x6E22b2e6fFAA30Fe75B71d53d1eC469b4e97A986;
    address internal constant DEFAULT_SEPOLIA_PROTOCOL_BUDGET =
        0x277ba3Cf597CdAaF958C301db3cF6a631F793039;
    address internal constant DEFAULT_SUN_TOKEN = 0xb5287fBbAD0e25B12f18497209fDac7e0ACf7293;
    address internal constant DEFAULT_SUN_CURVE = 0xe8D048aB83727419b00F4e30F4898C6B3bB91aD4;
    address internal constant DEFAULT_MOON_TOKEN = 0x92dC3B8056cA62A7dbc5c1C339891B45463bEe71;
    address internal constant DEFAULT_MOON_CURVE = 0x095c91aB279121300Ac16c57D1ecebB9ceEa1cd8;
    address internal constant DEFAULT_CREATE2_HOOK_DEPLOYER =
        0x6E34D98e1925eaf6680941213E49741b8764DdfE;

    struct SingleStepConfig {
        uint256 step;
        address sepoliaDeployer;
        address sepoliaAdminWallet;
        address sepoliaProtocolBudgetWallet;
        address sepoliaCreate2DeployerOwner;
        address usdcToken;
        address sunToken;
        address sunCurve;
        address moonToken;
        address moonCurve;
        address create2HookDeployer;
        uint256 expectedNonce;
        uint256 moonLaunchDelay;
        bool stepConfirmed;
        bool executeRequested;
        bool privateKeyPresent;
    }

    struct SingleStepPlan {
        uint256 chainId;
        uint256 step;
        bool stepConfirmed;
        bool executeRequested;
        bool privateKeyPresent;
        bool broadcastAllowed;
        bool executionBlocked;
        bool simulationOnly;
        address stage1CoreDeployer;
        uint64 stage1CoreDeployerNonce;
        uint256 expectedNonce;
        bool nonceMatches;
        address stage1AdminWallet;
        address stage1ProtocolBudgetWallet;
        address stage1Create2DeployerOwner;
        address usdcToken;
        uint8 usdcDecimals;
        address sunToken;
        address sunCurve;
        address moonToken;
        address moonCurve;
        address create2HookDeployer;
        bool moonCurveHasCode;
        bool create2HookDeployerHasCode;
        address sunTokenOwner;
        address sunCurveOwner;
        address moonTokenOwner;
        address moonCurveOwner;
        address create2HookDeployerOwner;
        address sunTokenMinter;
        address sunCurveMoonCurve;
        address moonTokenMinter;
        uint256 moonLaunchTime;
        bool ready;
    }

    error BaseMainnetNotAllowed(uint256 chainId);
    error BaseSepoliaSingleStepNotConfirmed(uint256 chainId);
    error DependencyCodeMissing(bytes32 label, address target);
    error InvalidAddress(bytes32 label);
    error InvalidStep(uint256 step);
    error NonceMismatch(uint256 expected, uint256 actual);
    error PrivateKeyEnvNotAllowed();
    error SingleStepNotConfirmed();
    error StateMismatch(bytes32 label, address expected, address actual);
    error TargetAlreadyDeployed(bytes32 label, address target);
    error UnsupportedChain(uint256 chainId);
    error UsdcDecimalsMismatch(uint8 expected, uint8 actual);

    function run() external returns (SingleStepPlan memory plan) {
        plan = prepare(_loadConfig());
    }

    function prepare(SingleStepConfig memory config) public returns (SingleStepPlan memory plan) {
        _validateConfig(config);

        plan = _buildPlan(config);
        _validateStepPreconditions(plan);

        if (config.executeRequested) {
            _executeSingleStep(config);
            _validateStepPostconditions(config);
        }

        _logPlan(plan);
    }

    function _loadConfig() private view returns (SingleStepConfig memory config) {
        uint256 step = vm.envOr("BASE_SEPOLIA_RC3_STAGE1_SINGLE_STEP", uint256(0));
        uint256 defaultNonce =
            step == 0 ? FIRST_SINGLE_STEP_NONCE : FIRST_SINGLE_STEP_NONCE + step - 1;

        config = SingleStepConfig({
            step: step,
            sepoliaDeployer: vm.envOr("SEPOLIA_DEPLOYER", DEFAULT_SEPOLIA_DEPLOYER),
            sepoliaAdminWallet: vm.envOr("SEPOLIA_ADMIN_WALLET", DEFAULT_SEPOLIA_ADMIN),
            sepoliaProtocolBudgetWallet: vm.envOr(
                "SEPOLIA_PROTOCOL_BUDGET_WALLET", DEFAULT_SEPOLIA_PROTOCOL_BUDGET
            ),
            sepoliaCreate2DeployerOwner: vm.envOr(
                "SEPOLIA_CREATE2_DEPLOYER_OWNER", DEFAULT_SEPOLIA_ADMIN
            ),
            usdcToken: vm.envOr("USDC_TOKEN", BaseV4Addresses.BASE_SEPOLIA_USDC),
            sunToken: vm.envOr("SUN_TOKEN", DEFAULT_SUN_TOKEN),
            sunCurve: vm.envOr("SUN_CURVE", DEFAULT_SUN_CURVE),
            moonToken: vm.envOr("MOON_TOKEN", DEFAULT_MOON_TOKEN),
            moonCurve: vm.envOr("MOON_CURVE", DEFAULT_MOON_CURVE),
            create2HookDeployer: vm.envOr("CREATE2_HOOK_DEPLOYER", DEFAULT_CREATE2_HOOK_DEPLOYER),
            expectedNonce: vm.envOr(
                "BASE_SEPOLIA_RC3_STAGE1_SINGLE_STEP_EXPECTED_NONCE", defaultNonce
            ),
            moonLaunchDelay: vm.envOr("MOON_LAUNCH_DELAY", uint256(0)),
            stepConfirmed: vm.envOr("CONFIRM_BASE_SEPOLIA_RC3_STAGE1_SINGLE_STEP", uint256(0)) == 1,
            executeRequested: vm.envOr("EXECUTE_BASE_SEPOLIA_RC3_STAGE1_SINGLE_STEP", uint256(0))
                == 1,
            privateKeyPresent: bytes(vm.envOr("PRIVATE_KEY", string(""))).length != 0
        });
    }

    function _validateConfig(SingleStepConfig memory config) private view {
        if (config.step == 0 || config.step > SINGLE_STEP_COUNT) revert InvalidStep(config.step);
        if (config.privateKeyPresent) revert PrivateKeyEnvNotAllowed();
        if (block.chainid == BaseV4Addresses.BASE_MAINNET_CHAIN_ID) {
            revert BaseMainnetNotAllowed(block.chainid);
        }
        if (
            block.chainid != LOCAL_SIMULATION_CHAIN_ID
                && block.chainid != BaseV4Addresses.BASE_SEPOLIA_CHAIN_ID
        ) {
            revert UnsupportedChain(block.chainid);
        }
        if (block.chainid == BaseV4Addresses.BASE_SEPOLIA_CHAIN_ID) {
            if (!config.stepConfirmed) revert BaseSepoliaSingleStepNotConfirmed(block.chainid);
            if (config.usdcToken != BaseV4Addresses.BASE_SEPOLIA_USDC) {
                revert InvalidAddress(LABEL_USDC_TOKEN);
            }
        }
        if (config.executeRequested && !config.stepConfirmed) revert SingleStepNotConfirmed();

        _requireAddress(config.sepoliaDeployer, LABEL_SEPOLIA_DEPLOYER);
        _requireAddress(config.sepoliaAdminWallet, LABEL_SEPOLIA_ADMIN_WALLET);
        _requireAddress(config.sepoliaProtocolBudgetWallet, LABEL_SEPOLIA_PROTOCOL_BUDGET_WALLET);
        _requireAddress(config.sepoliaCreate2DeployerOwner, LABEL_SEPOLIA_CREATE2_DEPLOYER_OWNER);
        _requireAddress(config.usdcToken, LABEL_USDC_TOKEN);
        _requireAddress(config.sunToken, LABEL_SUN_TOKEN);
        _requireAddress(config.sunCurve, LABEL_SUN_CURVE);
        _requireAddress(config.moonToken, LABEL_MOON_TOKEN);
        _requireAddress(config.moonCurve, LABEL_MOON_CURVE);
        _requireAddress(config.create2HookDeployer, LABEL_CREATE2_HOOK_DEPLOYER);
        _requireCode(config.usdcToken, LABEL_USDC_TOKEN);
        _requireCode(config.sunToken, LABEL_SUN_TOKEN);
        _requireCode(config.sunCurve, LABEL_SUN_CURVE);
        _requireCode(config.moonToken, LABEL_MOON_TOKEN);
    }

    function _buildPlan(SingleStepConfig memory config)
        private
        view
        returns (SingleStepPlan memory plan)
    {
        plan.chainId = block.chainid;
        plan.step = config.step;
        plan.stepConfirmed = config.stepConfirmed;
        plan.executeRequested = config.executeRequested;
        plan.privateKeyPresent = config.privateKeyPresent;
        plan.broadcastAllowed = config.executeRequested && config.stepConfirmed;
        plan.executionBlocked = !plan.broadcastAllowed;
        plan.simulationOnly = !plan.broadcastAllowed;
        plan.stage1CoreDeployer = config.sepoliaDeployer;
        plan.stage1CoreDeployerNonce = vm.getNonce(config.sepoliaDeployer);
        plan.expectedNonce = config.expectedNonce;
        plan.nonceMatches = plan.stage1CoreDeployerNonce == config.expectedNonce;
        plan.stage1AdminWallet = config.sepoliaAdminWallet;
        plan.stage1ProtocolBudgetWallet = config.sepoliaProtocolBudgetWallet;
        plan.stage1Create2DeployerOwner = config.sepoliaCreate2DeployerOwner;
        plan.usdcToken = config.usdcToken;
        plan.usdcDecimals = IERC20Metadata(config.usdcToken).decimals();
        if (plan.usdcDecimals != 6) revert UsdcDecimalsMismatch(6, plan.usdcDecimals);
        plan.sunToken = config.sunToken;
        plan.sunCurve = config.sunCurve;
        plan.moonToken = config.moonToken;
        plan.moonCurve = config.moonCurve;
        plan.create2HookDeployer = config.create2HookDeployer;
        plan.moonCurveHasCode = config.moonCurve.code.length != 0;
        plan.create2HookDeployerHasCode = config.create2HookDeployer.code.length != 0;
        plan.sunTokenOwner = SunToken(config.sunToken).owner();
        plan.sunCurveOwner = SunCurve(config.sunCurve).owner();
        plan.moonTokenOwner = MoonToken(config.moonToken).owner();
        plan.moonCurveOwner =
            plan.moonCurveHasCode ? MoonCurve(config.moonCurve).owner() : address(0);
        plan.create2HookDeployerOwner = plan.create2HookDeployerHasCode
            ? Create2HookDeployer(config.create2HookDeployer).owner()
            : address(0);
        plan.sunTokenMinter = SunToken(config.sunToken).minter();
        plan.sunCurveMoonCurve = SunCurve(config.sunCurve).moonCurve();
        plan.moonTokenMinter = MoonToken(config.moonToken).minter();
        plan.moonLaunchTime = block.timestamp + config.moonLaunchDelay;
        plan.ready = _isReady(plan);
    }

    function _isReady(SingleStepPlan memory plan) private pure returns (bool ready) {
        ready = plan.nonceMatches;
        if (plan.step == 1) {
            return ready && !plan.moonCurveHasCode;
        }
        if (plan.step == 2) {
            return ready && plan.moonCurveHasCode && !plan.create2HookDeployerHasCode;
        }
        if (plan.step == 3) {
            return ready && plan.moonCurveHasCode && plan.create2HookDeployerHasCode
                && plan.sunTokenMinter == address(0);
        }
        if (plan.step == 4) {
            return ready && plan.moonCurveHasCode && plan.create2HookDeployerHasCode
                && plan.sunTokenMinter == plan.sunCurve && plan.sunCurveMoonCurve == address(0);
        }
        if (plan.step == 5) {
            return ready && plan.moonCurveHasCode && plan.create2HookDeployerHasCode
                && plan.sunCurveMoonCurve == plan.moonCurve && plan.moonTokenMinter == address(0);
        }
        if (plan.step == 6) {
            return ready && plan.moonCurveHasCode && plan.create2HookDeployerHasCode
                && plan.moonTokenMinter == plan.moonCurve;
        }
        if (plan.step == 7) {
            return ready && plan.moonCurveHasCode && plan.create2HookDeployerHasCode
                && plan.sunTokenOwner == plan.stage1AdminWallet;
        }
        if (plan.step == 8) {
            return ready && plan.moonCurveHasCode && plan.create2HookDeployerHasCode
                && plan.sunCurveOwner == plan.stage1AdminWallet;
        }
        return ready && plan.moonCurveHasCode && plan.create2HookDeployerHasCode
            && plan.moonTokenOwner == plan.stage1AdminWallet;
    }

    function _validateStepPreconditions(SingleStepPlan memory plan) private pure {
        if (!plan.nonceMatches) {
            revert NonceMismatch(plan.expectedNonce, plan.stage1CoreDeployerNonce);
        }

        if (plan.step == 1) {
            _expect(
                plan.moonCurveHasCode ? plan.moonCurve : address(0), address(0), LABEL_MOON_CURVE
            );
            _expect(plan.sunTokenOwner, plan.stage1CoreDeployer, LABEL_SUN_TOKEN);
            _expect(plan.sunCurveOwner, plan.stage1CoreDeployer, LABEL_SUN_CURVE);
            _expect(plan.moonTokenOwner, plan.stage1CoreDeployer, LABEL_MOON_TOKEN);
            _expect(plan.sunTokenMinter, address(0), LABEL_SUN_TOKEN);
            _expect(plan.sunCurveMoonCurve, address(0), LABEL_SUN_CURVE);
            _expect(plan.moonTokenMinter, address(0), LABEL_MOON_TOKEN);
        } else if (plan.step == 2) {
            if (!plan.moonCurveHasCode) {
                revert DependencyCodeMissing(LABEL_MOON_CURVE, plan.moonCurve);
            }
            if (plan.create2HookDeployerHasCode) {
                revert TargetAlreadyDeployed(LABEL_CREATE2_HOOK_DEPLOYER, plan.create2HookDeployer);
            }
            _expect(plan.moonCurveOwner, plan.stage1CoreDeployer, LABEL_MOON_CURVE);
        } else if (plan.step == 3) {
            _requireConfiguredDeployments(plan);
            _expect(plan.sunTokenOwner, plan.stage1CoreDeployer, LABEL_SUN_TOKEN);
            _expect(plan.sunTokenMinter, address(0), LABEL_SUN_TOKEN);
        } else if (plan.step == 4) {
            _requireConfiguredDeployments(plan);
            _expect(plan.sunCurveOwner, plan.stage1CoreDeployer, LABEL_SUN_CURVE);
            _expect(plan.sunTokenMinter, plan.sunCurve, LABEL_SUN_TOKEN);
            _expect(plan.sunCurveMoonCurve, address(0), LABEL_SUN_CURVE);
        } else if (plan.step == 5) {
            _requireConfiguredDeployments(plan);
            _expect(plan.moonTokenOwner, plan.stage1CoreDeployer, LABEL_MOON_TOKEN);
            _expect(plan.sunCurveMoonCurve, plan.moonCurve, LABEL_SUN_CURVE);
            _expect(plan.moonTokenMinter, address(0), LABEL_MOON_TOKEN);
        } else if (plan.step == 6) {
            _requireConfiguredDeployments(plan);
            _expect(plan.sunTokenOwner, plan.stage1CoreDeployer, LABEL_SUN_TOKEN);
            _expect(plan.moonTokenMinter, plan.moonCurve, LABEL_MOON_TOKEN);
        } else if (plan.step == 7) {
            _requireConfiguredDeployments(plan);
            _expect(plan.sunTokenOwner, plan.stage1AdminWallet, LABEL_SUN_TOKEN);
            _expect(plan.sunCurveOwner, plan.stage1CoreDeployer, LABEL_SUN_CURVE);
        } else if (plan.step == 8) {
            _requireConfiguredDeployments(plan);
            _expect(plan.sunCurveOwner, plan.stage1AdminWallet, LABEL_SUN_CURVE);
            _expect(plan.moonTokenOwner, plan.stage1CoreDeployer, LABEL_MOON_TOKEN);
        } else if (plan.step == 9) {
            _requireConfiguredDeployments(plan);
            _expect(plan.moonTokenOwner, plan.stage1AdminWallet, LABEL_MOON_TOKEN);
            _expect(plan.moonCurveOwner, plan.stage1CoreDeployer, LABEL_MOON_CURVE);
        }
    }

    function _executeSingleStep(SingleStepConfig memory config) private {
        SunToken sunToken = SunToken(config.sunToken);
        SunCurve sunCurve = SunCurve(config.sunCurve);
        MoonToken moonToken = MoonToken(config.moonToken);

        if (config.step == 1) {
            vm.broadcast(config.sepoliaDeployer);
            new MoonCurve(
                moonToken,
                sunToken,
                sunCurve,
                config.sepoliaProtocolBudgetWallet,
                MOON_K,
                MOON_S,
                block.timestamp + config.moonLaunchDelay,
                MOON_MAX_MINT_USDC_EQUIV,
                config.sepoliaDeployer
            );
        } else if (config.step == 2) {
            vm.broadcast(config.sepoliaDeployer);
            new Create2HookDeployer(config.sepoliaCreate2DeployerOwner);
        } else if (config.step == 3) {
            vm.broadcast(config.sepoliaDeployer);
            sunToken.setMinter(config.sunCurve);
        } else if (config.step == 4) {
            vm.broadcast(config.sepoliaDeployer);
            sunCurve.setMoonCurve(config.moonCurve);
        } else if (config.step == 5) {
            vm.broadcast(config.sepoliaDeployer);
            moonToken.setMinter(config.moonCurve);
        } else if (config.step == 6) {
            vm.broadcast(config.sepoliaDeployer);
            sunToken.transferOwnership(config.sepoliaAdminWallet);
        } else if (config.step == 7) {
            vm.broadcast(config.sepoliaDeployer);
            sunCurve.transferOwnership(config.sepoliaAdminWallet);
        } else if (config.step == 8) {
            vm.broadcast(config.sepoliaDeployer);
            moonToken.transferOwnership(config.sepoliaAdminWallet);
        } else if (config.step == 9) {
            vm.broadcast(config.sepoliaDeployer);
            MoonCurve(config.moonCurve).transferOwnership(config.sepoliaAdminWallet);
        }
    }

    function _validateStepPostconditions(SingleStepConfig memory config) private view {
        if (config.step == 1) {
            _requireCode(config.moonCurve, LABEL_MOON_CURVE);
            _expect(MoonCurve(config.moonCurve).owner(), config.sepoliaDeployer, LABEL_MOON_CURVE);
        } else if (config.step == 2) {
            _requireCode(config.create2HookDeployer, LABEL_CREATE2_HOOK_DEPLOYER);
            _expect(
                Create2HookDeployer(config.create2HookDeployer).owner(),
                config.sepoliaCreate2DeployerOwner,
                LABEL_CREATE2_HOOK_DEPLOYER
            );
        } else if (config.step == 3) {
            _expect(SunToken(config.sunToken).minter(), config.sunCurve, LABEL_SUN_TOKEN);
        } else if (config.step == 4) {
            _expect(SunCurve(config.sunCurve).moonCurve(), config.moonCurve, LABEL_SUN_CURVE);
        } else if (config.step == 5) {
            _expect(MoonToken(config.moonToken).minter(), config.moonCurve, LABEL_MOON_TOKEN);
        } else if (config.step == 6) {
            _expect(SunToken(config.sunToken).owner(), config.sepoliaAdminWallet, LABEL_SUN_TOKEN);
        } else if (config.step == 7) {
            _expect(SunCurve(config.sunCurve).owner(), config.sepoliaAdminWallet, LABEL_SUN_CURVE);
        } else if (config.step == 8) {
            _expect(
                MoonToken(config.moonToken).owner(), config.sepoliaAdminWallet, LABEL_MOON_TOKEN
            );
        } else if (config.step == 9) {
            _expect(
                MoonCurve(config.moonCurve).owner(), config.sepoliaAdminWallet, LABEL_MOON_CURVE
            );
        }
    }

    function _requireConfiguredDeployments(SingleStepPlan memory plan) private pure {
        if (!plan.moonCurveHasCode) revert DependencyCodeMissing(LABEL_MOON_CURVE, plan.moonCurve);
        if (!plan.create2HookDeployerHasCode) {
            revert DependencyCodeMissing(LABEL_CREATE2_HOOK_DEPLOYER, plan.create2HookDeployer);
        }
    }

    function _requireAddress(address value, bytes32 label) private pure {
        if (value == address(0)) revert InvalidAddress(label);
    }

    function _requireCode(address target, bytes32 label) private view {
        if (target.code.length == 0) revert DependencyCodeMissing(label, target);
    }

    function _expect(address actual, address expected, bytes32 label) private pure {
        if (actual != expected) revert StateMismatch(label, expected, actual);
    }

    function _logPlan(SingleStepPlan memory plan) private pure {
        console2.log("Base Sepolia rc3 Stage 1 single-step draft");
        console2.log("chainId:", plan.chainId);
        console2.log("step:", plan.step);
        console2.log("stepConfirmed:", plan.stepConfirmed);
        console2.log("executeRequested:", plan.executeRequested);
        console2.log("privateKeyPresent:", plan.privateKeyPresent);
        console2.log("broadcastAllowed:", plan.broadcastAllowed);
        console2.log("executionBlocked:", plan.executionBlocked);
        console2.log("simulationOnly:", plan.simulationOnly);
        console2.log("stage1CoreDeployer:", plan.stage1CoreDeployer);
        console2.log("stage1CoreDeployerNonce:", plan.stage1CoreDeployerNonce);
        console2.log("expectedNonce:", plan.expectedNonce);
        console2.log("nonceMatches:", plan.nonceMatches);
        console2.log("ready:", plan.ready);
        console2.log("SUN_TOKEN:", plan.sunToken);
        console2.log("SUN_CURVE:", plan.sunCurve);
        console2.log("MOON_TOKEN:", plan.moonToken);
        console2.log("MOON_CURVE:", plan.moonCurve);
        console2.log("CREATE2_HOOK_DEPLOYER:", plan.create2HookDeployer);
        console2.log(
            "Next step:", "run exactly one wallet signature only if owner approves this step"
        );
    }
}
