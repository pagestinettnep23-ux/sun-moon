// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import { Script, console2 } from "forge-std/Script.sol";
import { IPoolManager } from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import { SunCurve } from "../contracts/SunCurve.sol";
import { BaseSunMoonUsdcFeeV4Hook } from "../contracts/hooks/base/BaseSunMoonUsdcFeeV4Hook.sol";
import { BaseV4Addresses } from "../contracts/hooks/base/BaseV4Addresses.sol";
import { BaseV4HookAddressMiner } from "../contracts/hooks/base/BaseV4HookAddressMiner.sol";

contract ComputeBaseMainnetSunMoonUsdcHookSalt is Script {
    bytes32 internal constant LABEL_MAINNET_ADMIN_WALLET = "MAINNET_ADMIN_WALLET";
    bytes32 internal constant LABEL_PROTOCOL_BUDGET_WALLET = "PROTOCOL_BUDGET_WALLET";
    bytes32 internal constant LABEL_CREATE2_HOOK_DEPLOYER = "CREATE2_HOOK_DEPLOYER";
    bytes32 internal constant LABEL_POOL_MANAGER = "POOL_MANAGER";
    bytes32 internal constant LABEL_SUN_TOKEN = "SUN_TOKEN";
    bytes32 internal constant LABEL_MOON_TOKEN = "MOON_TOKEN";
    bytes32 internal constant LABEL_USDC_TOKEN = "USDC_TOKEN";
    bytes32 internal constant LABEL_SUN_CURVE = "SUN_CURVE";

    uint256 internal constant LOCAL_SIMULATION_CHAIN_ID = 31_337;

    struct HookSaltConfig {
        address mainnetAdminWallet;
        address protocolBudgetWallet;
        address create2HookDeployer;
        address poolManager;
        address sunToken;
        address moonToken;
        address usdcToken;
        address sunCurve;
        uint256 hookSaltStart;
        uint256 hookMaxSaltSearch;
        bool baseMainnetConfirmed;
        bool broadcastRequested;
    }

    struct HookSaltPlan {
        uint256 chainId;
        bool baseMainnetConfirmed;
        bool broadcastRequested;
        bool simulationOnly;
        address mainnetAdminWallet;
        address protocolBudgetWallet;
        address create2HookDeployer;
        address poolManager;
        address sunToken;
        address moonToken;
        address usdcToken;
        uint8 usdcDecimals;
        address sunCurve;
        uint256 hookSaltStart;
        uint256 hookMaxSaltSearch;
        bytes32 initCodeHash;
        uint160 expectedHookMask;
        bytes32 hookSalt;
        address predictedHook;
        uint160 actualHookMask;
    }

    error BaseMainnetHookSaltDryRunNotConfirmed(uint256 chainId);
    error BaseMainnetUnexpectedAddress(bytes32 label, address expected, address actual);
    error BroadcastNotAllowed();
    error DependencyCodeMissing(bytes32 label, address target);
    error DuplicateAddress(bytes32 leftLabel, bytes32 rightLabel, address value);
    error InvalidAddress(bytes32 label);
    error SaltNotFound(uint256 startSalt, uint256 maxIterations);
    error UnsupportedChain(uint256 chainId);
    error UsdcDecimalsMismatch(uint8 expected, uint8 actual);

    function run() external view returns (HookSaltPlan memory plan) {
        plan = _prepare(_loadConfig());
    }

    function prepare(HookSaltConfig memory config)
        external
        view
        returns (HookSaltPlan memory plan)
    {
        plan = _prepare(config);
    }

    function _loadConfig() private view returns (HookSaltConfig memory config) {
        config = HookSaltConfig({
            mainnetAdminWallet: _requiredEnvAddress(
                "MAINNET_ADMIN_WALLET", LABEL_MAINNET_ADMIN_WALLET
            ),
            protocolBudgetWallet: _requiredEnvAddress(
                "PROTOCOL_BUDGET_WALLET", LABEL_PROTOCOL_BUDGET_WALLET
            ),
            create2HookDeployer: _requiredEnvAddress(
                "CREATE2_HOOK_DEPLOYER", LABEL_CREATE2_HOOK_DEPLOYER
            ),
            poolManager: vm.envOr("POOL_MANAGER", BaseV4Addresses.BASE_MAINNET_POOL_MANAGER),
            sunToken: _requiredEnvAddress("SUN_TOKEN", LABEL_SUN_TOKEN),
            moonToken: _requiredEnvAddress("MOON_TOKEN", LABEL_MOON_TOKEN),
            usdcToken: vm.envOr("USDC_TOKEN", BaseV4Addresses.BASE_MAINNET_USDC),
            sunCurve: _requiredEnvAddress("SUN_CURVE", LABEL_SUN_CURVE),
            hookSaltStart: vm.envOr("HOOK_SALT_START", uint256(0)),
            hookMaxSaltSearch: vm.envOr("HOOK_MAX_SALT_SEARCH", uint256(200_000)),
            baseMainnetConfirmed: vm.envOr("CONFIRM_BASE_MAINNET_HOOK_SALT_DRY_RUN", uint256(0))
                == 1,
            broadcastRequested: vm.envOr("EXECUTE_BASE_MAINNET_BROADCAST", uint256(0)) == 1
        });
    }

    function _prepare(HookSaltConfig memory config)
        private
        view
        returns (HookSaltPlan memory plan)
    {
        _validateConfig(config);

        bytes memory initCode = abi.encodePacked(
            type(BaseSunMoonUsdcFeeV4Hook).creationCode,
            abi.encode(
                IPoolManager(config.poolManager),
                config.sunToken,
                config.moonToken,
                IERC20(config.usdcToken),
                SunCurve(config.sunCurve),
                config.protocolBudgetWallet,
                config.mainnetAdminWallet
            )
        );

        plan.chainId = block.chainid;
        plan.baseMainnetConfirmed = config.baseMainnetConfirmed;
        plan.broadcastRequested = config.broadcastRequested;
        plan.simulationOnly = true;
        plan.mainnetAdminWallet = config.mainnetAdminWallet;
        plan.protocolBudgetWallet = config.protocolBudgetWallet;
        plan.create2HookDeployer = config.create2HookDeployer;
        plan.poolManager = config.poolManager;
        plan.sunToken = config.sunToken;
        plan.moonToken = config.moonToken;
        plan.usdcToken = config.usdcToken;
        plan.usdcDecimals = _usdcDecimals(config);
        plan.sunCurve = config.sunCurve;
        plan.hookSaltStart = config.hookSaltStart;
        plan.hookMaxSaltSearch = config.hookMaxSaltSearch;
        plan.initCodeHash = keccak256(initCode);
        plan.expectedHookMask = BaseV4HookAddressMiner.BASE_SUN_MOON_USDC_FEE_V4_HOOK_MASK;

        bool found;
        (plan.hookSalt, plan.predictedHook, found) = BaseV4HookAddressMiner.mineSalt(
            config.create2HookDeployer,
            plan.initCodeHash,
            plan.expectedHookMask,
            config.hookSaltStart,
            config.hookMaxSaltSearch
        );
        if (!found) revert SaltNotFound(config.hookSaltStart, config.hookMaxSaltSearch);

        plan.actualHookMask = uint160(plan.predictedHook) & BaseV4HookAddressMiner.V4_ALL_HOOK_MASK;

        _logPlan(plan);
    }

    function _validateConfig(HookSaltConfig memory config) private view {
        if (config.broadcastRequested) revert BroadcastNotAllowed();

        _requireAddress(config.mainnetAdminWallet, LABEL_MAINNET_ADMIN_WALLET);
        _requireAddress(config.protocolBudgetWallet, LABEL_PROTOCOL_BUDGET_WALLET);
        _requireAddress(config.create2HookDeployer, LABEL_CREATE2_HOOK_DEPLOYER);
        _requireAddress(config.poolManager, LABEL_POOL_MANAGER);
        _requireAddress(config.sunToken, LABEL_SUN_TOKEN);
        _requireAddress(config.moonToken, LABEL_MOON_TOKEN);
        _requireAddress(config.usdcToken, LABEL_USDC_TOKEN);
        _requireAddress(config.sunCurve, LABEL_SUN_CURVE);

        _requireDistinct(
            config.mainnetAdminWallet,
            LABEL_MAINNET_ADMIN_WALLET,
            config.protocolBudgetWallet,
            LABEL_PROTOCOL_BUDGET_WALLET
        );
        _requireDistinct(config.sunToken, LABEL_SUN_TOKEN, config.moonToken, LABEL_MOON_TOKEN);
        _requireDistinct(config.sunToken, LABEL_SUN_TOKEN, config.usdcToken, LABEL_USDC_TOKEN);
        _requireDistinct(config.moonToken, LABEL_MOON_TOKEN, config.usdcToken, LABEL_USDC_TOKEN);
        _requireDistinct(config.sunToken, LABEL_SUN_TOKEN, config.sunCurve, LABEL_SUN_CURVE);
        _requireDistinct(config.moonToken, LABEL_MOON_TOKEN, config.sunCurve, LABEL_SUN_CURVE);

        if (config.hookMaxSaltSearch == 0) {
            revert SaltNotFound(config.hookSaltStart, config.hookMaxSaltSearch);
        }

        if (block.chainid == BaseV4Addresses.BASE_MAINNET_CHAIN_ID) {
            if (!config.baseMainnetConfirmed) {
                revert BaseMainnetHookSaltDryRunNotConfirmed(block.chainid);
            }
            _requireOfficialMainnetAddress(
                LABEL_POOL_MANAGER, BaseV4Addresses.BASE_MAINNET_POOL_MANAGER, config.poolManager
            );
            _requireOfficialMainnetAddress(
                LABEL_USDC_TOKEN, BaseV4Addresses.BASE_MAINNET_USDC, config.usdcToken
            );
            _requireCode(LABEL_POOL_MANAGER, config.poolManager);
            _requireCode(LABEL_USDC_TOKEN, config.usdcToken);
        } else if (block.chainid != LOCAL_SIMULATION_CHAIN_ID) {
            revert UnsupportedChain(block.chainid);
        }
    }

    function _usdcDecimals(HookSaltConfig memory config) private view returns (uint8 decimals_) {
        if (block.chainid == BaseV4Addresses.BASE_MAINNET_CHAIN_ID) {
            decimals_ = IERC20Metadata(config.usdcToken).decimals();
            if (decimals_ != 6) revert UsdcDecimalsMismatch(6, decimals_);
        } else {
            decimals_ = 6;
        }
    }

    function _requiredEnvAddress(string memory key, bytes32 label)
        private
        view
        returns (address value)
    {
        string memory rawValue = vm.envOr(key, string(""));
        if (bytes(rawValue).length == 0) revert InvalidAddress(label);

        value = vm.parseAddress(rawValue);
        if (value == address(0)) revert InvalidAddress(label);
    }

    function _requireAddress(address value, bytes32 label) private pure {
        if (value == address(0)) revert InvalidAddress(label);
    }

    function _requireDistinct(address left, bytes32 leftLabel, address right, bytes32 rightLabel)
        private
        pure
    {
        if (left == right) revert DuplicateAddress(leftLabel, rightLabel, left);
    }

    function _requireOfficialMainnetAddress(bytes32 label, address expected, address actual)
        private
        pure
    {
        if (actual != expected) {
            revert BaseMainnetUnexpectedAddress(label, expected, actual);
        }
    }

    function _requireCode(bytes32 label, address target) private view {
        if (target.code.length == 0) revert DependencyCodeMissing(label, target);
    }

    function _logPlan(HookSaltPlan memory plan) private pure {
        console2.log("Base mainnet SUN/MOON USDC Hook salt dry-run");
        console2.log("simulationOnly:", plan.simulationOnly);
        console2.log("chainId:", plan.chainId);
        console2.log("baseMainnetConfirmed:", plan.baseMainnetConfirmed);
        console2.log("broadcastRequested:", plan.broadcastRequested);
        console2.log("MAINNET_ADMIN_WALLET:", plan.mainnetAdminWallet);
        console2.log("PROTOCOL_BUDGET_WALLET:", plan.protocolBudgetWallet);
        console2.log("CREATE2_HOOK_DEPLOYER:", plan.create2HookDeployer);
        console2.log("POOL_MANAGER:", plan.poolManager);
        console2.log("SUN_TOKEN:", plan.sunToken);
        console2.log("MOON_TOKEN:", plan.moonToken);
        console2.log("USDC_TOKEN:", plan.usdcToken);
        console2.log("USDC decimals:", plan.usdcDecimals);
        console2.log("SUN_CURVE:", plan.sunCurve);
        console2.log("HOOK_SALT_START:", plan.hookSaltStart);
        console2.log("HOOK_MAX_SALT_SEARCH:", plan.hookMaxSaltSearch);
        console2.log("initCodeHash:");
        console2.logBytes32(plan.initCodeHash);
        console2.log("HOOK_SALT:");
        console2.logBytes32(plan.hookSalt);
        console2.log("PREDICTED_HOOK:", plan.predictedHook);
        console2.log("expectedHookMask:", plan.expectedHookMask);
        console2.log("actualLow14Bits:", plan.actualHookMask);
        console2.log("Next step:", "review PREDICTED_HOOK; still do not broadcast mainnet");
    }
}
