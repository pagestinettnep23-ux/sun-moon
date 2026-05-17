// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Script, console2 } from "forge-std/Script.sol";
import { IAllowanceTransfer } from "permit2/src/interfaces/IAllowanceTransfer.sol";
import { BaseV4Addresses } from "../contracts/hooks/base/BaseV4Addresses.sol";
import { MoonCurve } from "../contracts/MoonCurve.sol";
import { MoonToken } from "../contracts/MoonToken.sol";
import { MoonCurveMath } from "../contracts/libraries/MoonCurveMath.sol";
import { SunCurve } from "../contracts/SunCurve.sol";
import { SunToken } from "../contracts/SunToken.sol";

contract PrepareBaseSepoliaTinyRehearsalAssets is Script {
    uint256 internal constant BPS = 10_000;
    uint256 internal constant SUN_FEE_TO_CURVE_BPS = 150;
    uint256 internal constant SUN_FEE_TO_PROTOCOL_BPS = 50;
    uint256 internal constant MOON_FEE_TO_SUN_CURVE_BPS = 300;
    uint256 internal constant MOON_FEE_TO_PROTOCOL_BPS = 200;

    uint256 internal constant DEFAULT_TINY_LIQUIDITY_USDC_AMOUNT = 1_000_000;
    uint256 internal constant DEFAULT_TINY_LIQUIDITY_MOON_AMOUNT = 1 ether;
    uint256 internal constant DEFAULT_TINY_SWAP_USDC_IN = 100_000;
    uint256 internal constant DEFAULT_SUN_MINT_USDC_AMOUNT = 500_000;
    uint256 internal constant DEFAULT_MOON_MINT_SUN_AMOUNT = 0.3 ether;

    address internal constant DEFAULT_BASE_SEPOLIA_SUN_TOKEN =
        0xDa5a62F1c2c54AB79c974eE41b9a5B83Dd307e41;
    address internal constant DEFAULT_BASE_SEPOLIA_SUN_CURVE =
        0x00F49621977e5219093A988879F07936F2155c07;
    address internal constant DEFAULT_BASE_SEPOLIA_MOON_TOKEN =
        0x6E7FF34C7a7a518981BF6324e5FCC6599FcBC59D;
    address internal constant DEFAULT_BASE_SEPOLIA_MOON_CURVE =
        0x7f4296686917Be97E826DC790c367d93585A32c3;

    bytes32 internal constant LABEL_REHEARSAL_ACTOR = "REHEARSAL_ACTOR";
    bytes32 internal constant LABEL_USDC_TOKEN = "USDC_TOKEN";
    bytes32 internal constant LABEL_SUN_TOKEN = "SUN_TOKEN";
    bytes32 internal constant LABEL_SUN_CURVE = "SUN_CURVE";
    bytes32 internal constant LABEL_MOON_TOKEN = "MOON_TOKEN";
    bytes32 internal constant LABEL_MOON_CURVE = "MOON_CURVE";
    bytes32 internal constant LABEL_PERMIT2 = "PERMIT2";
    bytes32 internal constant LABEL_POSITION_MANAGER = "POSITION_MANAGER";
    bytes32 internal constant LABEL_UNIVERSAL_ROUTER = "UNIVERSAL_ROUTER";

    struct Permit2Allowance {
        uint160 amount;
        uint48 expiration;
        uint48 nonce;
    }

    struct AssetConfig {
        bool baseSepoliaConfirmed;
        bool execute;
        address rehearsalActor;
        address usdcToken;
        address sunToken;
        address sunCurve;
        address moonToken;
        address moonCurve;
        address permit2;
        address positionManager;
        address universalRouter;
        uint256 liquidityUsdcAmount;
        uint256 liquidityMoonAmount;
        uint256 swapUsdcIn;
        uint256 sunMintUsdcAmount;
        uint256 moonMintSunAmount;
        uint48 permit2Expiration;
    }

    struct AssetPlan {
        uint256 chainId;
        bool baseSepoliaConfirmed;
        bool execute;
        address rehearsalActor;
        address usdcToken;
        address sunToken;
        address sunCurve;
        address moonToken;
        address moonCurve;
        address permit2;
        address positionManager;
        address universalRouter;
        uint256 liquidityUsdcAmount;
        uint256 liquidityMoonAmount;
        uint256 swapUsdcIn;
        uint256 swapFeeToSunCurve;
        uint256 swapFeeToProtocol;
        uint256 swapUsdcGrossInputWithHookFee;
        uint256 requiredUsdcForRehearsal;
        uint256 sunMintUsdcAmount;
        uint256 moonMintSunAmount;
        uint48 permit2Expiration;
        uint256 moonLaunchSecondsRemaining;
        uint256 sunPrice;
        uint256 moonPriceInSun;
        uint256 moonPriceInUsdc;
        uint256 projectedSunOut;
        uint256 projectedMoonOut;
        uint256 actorUsdcBalance;
        uint256 actorSunBalance;
        uint256 actorMoonBalance;
        uint256 requiredUsdcBeforeAssetPrep;
        uint256 projectedUsdcBalanceAfterAssetPrep;
        uint256 projectedSunBalanceAfterAssetPrep;
        uint256 projectedMoonBalanceAfterAssetPrep;
        bool needsSunMint;
        bool needsMoonMint;
        bool hasSufficientUsdcForAssetPrep;
        bool hasSufficientProjectedSun;
        bool hasSufficientProjectedMoon;
        uint256 usdcAllowanceToSunCurve;
        uint256 sunAllowanceToMoonCurve;
        uint256 usdcAllowanceToPermit2;
        uint256 moonAllowanceToPermit2;
        Permit2Allowance usdcPermit2ToPositionManager;
        Permit2Allowance moonPermit2ToPositionManager;
        Permit2Allowance usdcPermit2ToUniversalRouter;
        bool hasUsdcPermit2TokenApproval;
        bool hasMoonPermit2TokenApproval;
        bool hasPositionManagerPermit2Allowances;
        bool hasUniversalRouterPermit2Allowance;
        bool canExecuteAssetPrep;
        uint256 transactionsPlanned;
        uint256 transactionsExecuted;
    }

    error BaseMainnetNotAllowed(uint256 chainId);
    error BaseSepoliaRunNotConfirmed(uint256 chainId);
    error CannotExecuteAssetPrep(bytes32 reason);
    error DependencyCodeMissing(bytes32 label, address target);
    error InvalidAddress(bytes32 label);
    error InvalidAmount(bytes32 label, uint256 amount);
    error UnexpectedParameter(bytes32 label, address expected, address actual);

    function run() external returns (AssetPlan memory plan) {
        AssetConfig memory config = _loadConfig();
        plan = _prepare(config);
    }

    function prepare(AssetConfig memory config) external returns (AssetPlan memory plan) {
        plan = _prepare(config);
    }

    function _prepare(AssetConfig memory config) private returns (AssetPlan memory plan) {
        plan = _loadPlan(config);
        _validatePlan(plan);
        _loadBalancesAndAllowances(plan);
        _buildPlan(plan);
        if (plan.execute) {
            _requireExecutable(plan);
            plan.transactionsExecuted = _execute(plan);
            _loadBalancesAndAllowances(plan);
            _buildPlan(plan);
        }
        _logPlan(plan);
    }

    function _loadConfig() private view returns (AssetConfig memory config) {
        config.baseSepoliaConfirmed =
            vm.envOr("CONFIRM_BASE_SEPOLIA_TINY_ASSET_APPROVALS_RUN", uint256(0)) == 1;
        config.execute = vm.envOr("EXECUTE_BASE_SEPOLIA_TINY_ASSET_APPROVALS", uint256(0)) == 1;
        config.rehearsalActor =
            _envAddressOr("REHEARSAL_ACTOR", "HOOK_OWNER", LABEL_REHEARSAL_ACTOR);
        config.usdcToken =
            _envAddressOrDefault("USDC_TOKEN", BaseV4Addresses.BASE_SEPOLIA_USDC, LABEL_USDC_TOKEN);
        config.sunToken =
            _envAddressOrDefault("SUN_TOKEN", DEFAULT_BASE_SEPOLIA_SUN_TOKEN, LABEL_SUN_TOKEN);
        config.sunCurve =
            _envAddressOrDefault("SUN_CURVE", DEFAULT_BASE_SEPOLIA_SUN_CURVE, LABEL_SUN_CURVE);
        config.moonToken =
            _envAddressOrDefault("MOON_TOKEN", DEFAULT_BASE_SEPOLIA_MOON_TOKEN, LABEL_MOON_TOKEN);
        config.moonCurve =
            _envAddressOrDefault("MOON_CURVE", DEFAULT_BASE_SEPOLIA_MOON_CURVE, LABEL_MOON_CURVE);
        config.permit2 = _envAddressOrDefault("PERMIT2", BaseV4Addresses.PERMIT2, LABEL_PERMIT2);
        config.positionManager = _envAddressOrDefault(
            "POSITION_MANAGER",
            BaseV4Addresses.BASE_SEPOLIA_POSITION_MANAGER,
            LABEL_POSITION_MANAGER
        );
        config.universalRouter = _envAddressOrDefault(
            "UNIVERSAL_ROUTER",
            BaseV4Addresses.BASE_SEPOLIA_UNIVERSAL_ROUTER,
            LABEL_UNIVERSAL_ROUTER
        );
        config.liquidityUsdcAmount =
            vm.envOr("TINY_LIQUIDITY_USDC_AMOUNT", DEFAULT_TINY_LIQUIDITY_USDC_AMOUNT);
        config.liquidityMoonAmount =
            vm.envOr("TINY_LIQUIDITY_MOON_AMOUNT", DEFAULT_TINY_LIQUIDITY_MOON_AMOUNT);
        config.swapUsdcIn = vm.envOr("TINY_SWAP_USDC_IN", DEFAULT_TINY_SWAP_USDC_IN);
        config.sunMintUsdcAmount =
            vm.envOr("ASSET_SUN_MINT_USDC_AMOUNT", DEFAULT_SUN_MINT_USDC_AMOUNT);
        config.moonMintSunAmount =
            vm.envOr("ASSET_MOON_MINT_SUN_AMOUNT", DEFAULT_MOON_MINT_SUN_AMOUNT);
        config.permit2Expiration =
            uint48(vm.envOr("ASSET_PERMIT2_EXPIRATION", uint256(type(uint48).max)));
    }

    function _loadPlan(AssetConfig memory config) private view returns (AssetPlan memory plan) {
        plan.chainId = block.chainid;
        plan.baseSepoliaConfirmed = config.baseSepoliaConfirmed;
        plan.execute = config.execute;
        plan.rehearsalActor = _requiredConfigAddress(config.rehearsalActor, LABEL_REHEARSAL_ACTOR);
        plan.usdcToken = _requiredConfigAddress(config.usdcToken, LABEL_USDC_TOKEN);
        plan.sunToken = _requiredConfigAddress(config.sunToken, LABEL_SUN_TOKEN);
        plan.sunCurve = _requiredConfigAddress(config.sunCurve, LABEL_SUN_CURVE);
        plan.moonToken = _requiredConfigAddress(config.moonToken, LABEL_MOON_TOKEN);
        plan.moonCurve = _requiredConfigAddress(config.moonCurve, LABEL_MOON_CURVE);
        plan.permit2 = _requiredConfigAddress(config.permit2, LABEL_PERMIT2);
        plan.positionManager =
            _requiredConfigAddress(config.positionManager, LABEL_POSITION_MANAGER);
        plan.universalRouter =
            _requiredConfigAddress(config.universalRouter, LABEL_UNIVERSAL_ROUTER);
        plan.liquidityUsdcAmount = config.liquidityUsdcAmount;
        plan.liquidityMoonAmount = config.liquidityMoonAmount;
        plan.swapUsdcIn = config.swapUsdcIn;
        plan.swapFeeToSunCurve = plan.swapUsdcIn * MOON_FEE_TO_SUN_CURVE_BPS / BPS;
        plan.swapFeeToProtocol = plan.swapUsdcIn * MOON_FEE_TO_PROTOCOL_BPS / BPS;
        plan.swapUsdcGrossInputWithHookFee =
            plan.swapUsdcIn + plan.swapFeeToSunCurve + plan.swapFeeToProtocol;
        plan.requiredUsdcForRehearsal =
            plan.liquidityUsdcAmount + plan.swapUsdcGrossInputWithHookFee;
        plan.sunMintUsdcAmount = config.sunMintUsdcAmount;
        plan.moonMintSunAmount = config.moonMintSunAmount;
        plan.permit2Expiration = config.permit2Expiration;
    }

    function _validatePlan(AssetPlan memory plan) private view {
        if (plan.chainId == BaseV4Addresses.BASE_MAINNET_CHAIN_ID) {
            revert BaseMainnetNotAllowed(plan.chainId);
        }
        if (plan.chainId == BaseV4Addresses.BASE_SEPOLIA_CHAIN_ID && !plan.baseSepoliaConfirmed) {
            revert BaseSepoliaRunNotConfirmed(plan.chainId);
        }
        if (plan.liquidityUsdcAmount == 0) {
            revert InvalidAmount("TINY_LIQUIDITY_USDC_AMOUNT", plan.liquidityUsdcAmount);
        }
        if (plan.liquidityMoonAmount == 0) {
            revert InvalidAmount("TINY_LIQUIDITY_MOON_AMOUNT", plan.liquidityMoonAmount);
        }
        if (plan.swapUsdcIn == 0) revert InvalidAmount("TINY_SWAP_USDC_IN", plan.swapUsdcIn);
        if (plan.sunMintUsdcAmount == 0) {
            revert InvalidAmount("ASSET_SUN_MINT_USDC_AMOUNT", plan.sunMintUsdcAmount);
        }
        if (plan.moonMintSunAmount == 0) {
            revert InvalidAmount("ASSET_MOON_MINT_SUN_AMOUNT", plan.moonMintSunAmount);
        }
        if (plan.permit2Expiration <= block.timestamp) {
            revert InvalidAmount("ASSET_PERMIT2_EXPIRATION", plan.permit2Expiration);
        }

        _requireCode(LABEL_USDC_TOKEN, plan.usdcToken);
        _requireCode(LABEL_SUN_TOKEN, plan.sunToken);
        _requireCode(LABEL_SUN_CURVE, plan.sunCurve);
        _requireCode(LABEL_MOON_TOKEN, plan.moonToken);
        _requireCode(LABEL_MOON_CURVE, plan.moonCurve);
        _requireCode(LABEL_PERMIT2, plan.permit2);
        _requireCode(LABEL_POSITION_MANAGER, plan.positionManager);
        _requireCode(LABEL_UNIVERSAL_ROUTER, plan.universalRouter);

        if (plan.chainId == BaseV4Addresses.BASE_SEPOLIA_CHAIN_ID) {
            _requireParameter(LABEL_USDC_TOKEN, BaseV4Addresses.BASE_SEPOLIA_USDC, plan.usdcToken);
        }

        SunCurve sunCurve = SunCurve(plan.sunCurve);
        MoonCurve moonCurve = MoonCurve(plan.moonCurve);
        _requireParameter(LABEL_SUN_TOKEN, plan.sunToken, address(sunCurve.sunToken()));
        _requireParameter(LABEL_USDC_TOKEN, plan.usdcToken, address(sunCurve.usdt()));
        _requireParameter(LABEL_MOON_CURVE, plan.moonCurve, sunCurve.moonCurve());
        _requireParameter(LABEL_MOON_TOKEN, plan.moonToken, address(moonCurve.moonToken()));
        _requireParameter(LABEL_SUN_TOKEN, plan.sunToken, address(moonCurve.sunToken()));
        _requireParameter(LABEL_SUN_CURVE, plan.sunCurve, address(moonCurve.sunCurve()));
        _requireParameter(LABEL_SUN_CURVE, plan.sunCurve, SunToken(plan.sunToken).minter());
        _requireParameter(LABEL_MOON_CURVE, plan.moonCurve, MoonToken(plan.moonToken).minter());
    }

    function _loadBalancesAndAllowances(AssetPlan memory plan) private view {
        IERC20 usdc = IERC20(plan.usdcToken);
        IERC20 sun = IERC20(plan.sunToken);
        IERC20 moon = IERC20(plan.moonToken);
        IAllowanceTransfer permit2 = IAllowanceTransfer(plan.permit2);

        plan.moonLaunchSecondsRemaining = MoonCurve(plan.moonCurve).timeUntilLaunch();
        plan.sunPrice = SunCurve(plan.sunCurve).getSunPrice();
        plan.moonPriceInSun = MoonCurve(plan.moonCurve).getMintPriceInSUN();
        plan.moonPriceInUsdc = MoonCurve(plan.moonCurve).getMintPriceInUSDT();
        plan.projectedSunOut = _quoteSunOut(plan.sunCurve, plan.sunMintUsdcAmount);
        MoonCurveMath.MintQuote memory moonQuote =
            MoonCurve(plan.moonCurve).quoteMint(plan.moonMintSunAmount);
        plan.projectedMoonOut = moonQuote.moonOut;

        plan.actorUsdcBalance = usdc.balanceOf(plan.rehearsalActor);
        plan.actorSunBalance = sun.balanceOf(plan.rehearsalActor);
        plan.actorMoonBalance = moon.balanceOf(plan.rehearsalActor);
        plan.usdcAllowanceToSunCurve = usdc.allowance(plan.rehearsalActor, plan.sunCurve);
        plan.sunAllowanceToMoonCurve = sun.allowance(plan.rehearsalActor, plan.moonCurve);
        plan.usdcAllowanceToPermit2 = usdc.allowance(plan.rehearsalActor, plan.permit2);
        plan.moonAllowanceToPermit2 = moon.allowance(plan.rehearsalActor, plan.permit2);
        plan.usdcPermit2ToPositionManager =
            _permit2Allowance(permit2, plan.rehearsalActor, plan.usdcToken, plan.positionManager);
        plan.moonPermit2ToPositionManager =
            _permit2Allowance(permit2, plan.rehearsalActor, plan.moonToken, plan.positionManager);
        plan.usdcPermit2ToUniversalRouter =
            _permit2Allowance(permit2, plan.rehearsalActor, plan.usdcToken, plan.universalRouter);
    }

    function _buildPlan(AssetPlan memory plan) private view {
        plan.needsMoonMint = plan.actorMoonBalance < plan.liquidityMoonAmount;
        plan.needsSunMint = plan.needsMoonMint && plan.actorSunBalance < plan.moonMintSunAmount;
        plan.requiredUsdcBeforeAssetPrep =
            plan.requiredUsdcForRehearsal + (plan.needsSunMint ? plan.sunMintUsdcAmount : 0);
        plan.projectedUsdcBalanceAfterAssetPrep = plan.actorUsdcBalance
            - _min(plan.actorUsdcBalance, plan.needsSunMint ? plan.sunMintUsdcAmount : 0);
        plan.projectedSunBalanceAfterAssetPrep = plan.actorSunBalance
            + (plan.needsSunMint ? plan.projectedSunOut : 0)
            - (plan.needsMoonMint
                    ? _min(plan.moonMintSunAmount, plan.actorSunBalance + plan.projectedSunOut)
                    : 0);
        plan.projectedMoonBalanceAfterAssetPrep =
            plan.actorMoonBalance + (plan.needsMoonMint ? plan.projectedMoonOut : 0);

        plan.hasSufficientUsdcForAssetPrep =
            plan.actorUsdcBalance >= plan.requiredUsdcBeforeAssetPrep;
        plan.hasSufficientProjectedSun = !plan.needsMoonMint
            || plan.actorSunBalance + (plan.needsSunMint ? plan.projectedSunOut : 0)
                >= plan.moonMintSunAmount;
        plan.hasSufficientProjectedMoon = !plan.needsMoonMint
            || plan.projectedMoonBalanceAfterAssetPrep >= plan.liquidityMoonAmount;

        plan.hasUsdcPermit2TokenApproval =
            plan.usdcAllowanceToPermit2 >= plan.requiredUsdcForRehearsal;
        plan.hasMoonPermit2TokenApproval = plan.moonAllowanceToPermit2 >= plan.liquidityMoonAmount;
        plan.hasPositionManagerPermit2Allowances = _permit2Ready(
            plan.usdcPermit2ToPositionManager, plan.liquidityUsdcAmount
        ) && _permit2Ready(plan.moonPermit2ToPositionManager, plan.liquidityMoonAmount);
        plan.hasUniversalRouterPermit2Allowance =
            _permit2Ready(plan.usdcPermit2ToUniversalRouter, plan.swapUsdcGrossInputWithHookFee);

        plan.canExecuteAssetPrep = plan.moonLaunchSecondsRemaining == 0
            && plan.hasSufficientUsdcForAssetPrep && plan.hasSufficientProjectedSun
            && plan.hasSufficientProjectedMoon;
        plan.transactionsPlanned = _countTransactions(plan);
    }

    function _countTransactions(AssetPlan memory plan) private view returns (uint256 count) {
        if (plan.needsSunMint) {
            count += _approvalTxCount(plan.usdcAllowanceToSunCurve, plan.sunMintUsdcAmount);
            count += 1;
        }
        if (plan.needsMoonMint) {
            count += _approvalTxCount(plan.sunAllowanceToMoonCurve, plan.moonMintSunAmount);
            count += 1;
        }
        count += _approvalTxCount(plan.usdcAllowanceToPermit2, plan.requiredUsdcForRehearsal);
        count += _approvalTxCount(plan.moonAllowanceToPermit2, plan.liquidityMoonAmount);
        if (!_permit2Ready(plan.usdcPermit2ToPositionManager, plan.liquidityUsdcAmount)) {
            count += 1;
        }
        if (!_permit2Ready(plan.moonPermit2ToPositionManager, plan.liquidityMoonAmount)) {
            count += 1;
        }
        if (!_permit2Ready(plan.usdcPermit2ToUniversalRouter, plan.swapUsdcGrossInputWithHookFee)) {
            count += 1;
        }
    }

    function _execute(AssetPlan memory plan) private returns (uint256 transactionsExecuted) {
        vm.startBroadcast(plan.rehearsalActor);

        if (plan.needsSunMint) {
            transactionsExecuted += _approveErc20IfNeeded(
                plan.usdcToken, plan.sunCurve, plan.usdcAllowanceToSunCurve, plan.sunMintUsdcAmount
            );
            SunCurve(plan.sunCurve).mintFor(plan.rehearsalActor, plan.sunMintUsdcAmount);
            transactionsExecuted++;
        }
        if (plan.needsMoonMint) {
            transactionsExecuted += _approveErc20IfNeeded(
                plan.sunToken, plan.moonCurve, plan.sunAllowanceToMoonCurve, plan.moonMintSunAmount
            );
            MoonCurve(plan.moonCurve).mintFor(plan.rehearsalActor, plan.moonMintSunAmount);
            transactionsExecuted++;
        }

        transactionsExecuted += _approveErc20IfNeeded(
            plan.usdcToken, plan.permit2, plan.usdcAllowanceToPermit2, plan.requiredUsdcForRehearsal
        );
        transactionsExecuted += _approveErc20IfNeeded(
            plan.moonToken, plan.permit2, plan.moonAllowanceToPermit2, plan.liquidityMoonAmount
        );
        if (!_permit2Ready(plan.usdcPermit2ToPositionManager, plan.liquidityUsdcAmount)) {
            IAllowanceTransfer(plan.permit2)
                .approve(
                    plan.usdcToken, plan.positionManager, type(uint160).max, plan.permit2Expiration
                );
            transactionsExecuted++;
        }
        if (!_permit2Ready(plan.moonPermit2ToPositionManager, plan.liquidityMoonAmount)) {
            IAllowanceTransfer(plan.permit2)
                .approve(
                    plan.moonToken, plan.positionManager, type(uint160).max, plan.permit2Expiration
                );
            transactionsExecuted++;
        }
        if (!_permit2Ready(plan.usdcPermit2ToUniversalRouter, plan.swapUsdcGrossInputWithHookFee)) {
            IAllowanceTransfer(plan.permit2)
                .approve(
                    plan.usdcToken, plan.universalRouter, type(uint160).max, plan.permit2Expiration
                );
            transactionsExecuted++;
        }

        vm.stopBroadcast();
    }

    function _requireExecutable(AssetPlan memory plan) private pure {
        if (plan.moonLaunchSecondsRemaining != 0) {
            revert CannotExecuteAssetPrep("MOON_NOT_LAUNCHED");
        }
        if (!plan.hasSufficientUsdcForAssetPrep) {
            revert CannotExecuteAssetPrep("INSUFFICIENT_USDC");
        }
        if (!plan.hasSufficientProjectedSun) {
            revert CannotExecuteAssetPrep("INSUFFICIENT_PROJECTED_SUN");
        }
        if (!plan.hasSufficientProjectedMoon) {
            revert CannotExecuteAssetPrep("INSUFFICIENT_PROJECTED_MOON");
        }
    }

    function _approveErc20IfNeeded(
        address token,
        address spender,
        uint256 currentAllowance,
        uint256 requiredAmount
    ) private returns (uint256 transactionsExecuted) {
        if (currentAllowance >= requiredAmount) return 0;
        if (currentAllowance != 0) {
            IERC20(token).approve(spender, 0);
            transactionsExecuted++;
        }
        IERC20(token).approve(spender, type(uint256).max);
        transactionsExecuted++;
    }

    function _approvalTxCount(uint256 currentAllowance, uint256 requiredAmount)
        private
        pure
        returns (uint256)
    {
        if (currentAllowance >= requiredAmount) return 0;
        return currentAllowance == 0 ? 1 : 2;
    }

    function _quoteSunOut(address sunCurveAddress, uint256 usdcIn)
        private
        view
        returns (uint256 sunOut)
    {
        SunCurve sunCurve = SunCurve(sunCurveAddress);
        uint256 reserveBefore = sunCurve.curveReserve();
        uint256 supplyBefore = sunCurve.sunToken().totalSupply();
        uint256 feeToCurve = usdcIn * SUN_FEE_TO_CURVE_BPS / BPS;
        uint256 feeToProtocol = usdcIn * SUN_FEE_TO_PROTOCOL_BPS / BPS;
        uint256 usdcNet = usdcIn - feeToCurve - feeToProtocol;

        if (supplyBefore == 0) return usdcNet * sunCurve.usdtTo18Scale();
        return supplyBefore * usdcNet / reserveBefore;
    }

    function _permit2Allowance(
        IAllowanceTransfer permit2,
        address owner,
        address token,
        address spender
    ) private view returns (Permit2Allowance memory allowance_) {
        (allowance_.amount, allowance_.expiration, allowance_.nonce) =
            permit2.allowance(owner, token, spender);
    }

    function _permit2Ready(Permit2Allowance memory allowance_, uint256 amount)
        private
        view
        returns (bool)
    {
        return uint256(allowance_.amount) >= amount && allowance_.expiration >= block.timestamp;
    }

    function _envAddressOr(string memory primaryKey, string memory fallbackKey, bytes32 label)
        private
        view
        returns (address value)
    {
        string memory rawValue = vm.envOr(primaryKey, string(""));
        if (bytes(rawValue).length == 0) rawValue = vm.envOr(fallbackKey, string(""));
        value = _parseRequiredAddress(rawValue, label);
    }

    function _envAddressOrDefault(string memory key, address defaultValue, bytes32 label)
        private
        view
        returns (address value)
    {
        string memory rawValue = vm.envOr(key, string(""));
        if (bytes(rawValue).length == 0) value = defaultValue;
        else value = vm.parseAddress(rawValue);
        if (value == address(0)) revert InvalidAddress(label);
    }

    function _parseRequiredAddress(string memory rawValue, bytes32 label)
        private
        pure
        returns (address value)
    {
        if (bytes(rawValue).length == 0) revert InvalidAddress(label);
        value = vm.parseAddress(rawValue);
        if (value == address(0)) revert InvalidAddress(label);
    }

    function _requiredConfigAddress(address value, bytes32 label) private pure returns (address) {
        if (value == address(0)) revert InvalidAddress(label);
        return value;
    }

    function _requireCode(bytes32 label, address target) private view {
        if (target.code.length == 0) revert DependencyCodeMissing(label, target);
    }

    function _requireParameter(bytes32 label, address expected, address actual) private pure {
        if (actual != expected) revert UnexpectedParameter(label, expected, actual);
    }

    function _min(uint256 a, uint256 b) private pure returns (uint256) {
        return a < b ? a : b;
    }

    function _logPlan(AssetPlan memory plan) private pure {
        console2.log("Base Sepolia tiny rehearsal asset and Permit2 approval preparation");
        console2.log(
            "simulationOnly:", "default read-only; execute requires explicit env and approval"
        );
        console2.log("chainId:", plan.chainId);
        console2.log("baseSepoliaConfirmed:", plan.baseSepoliaConfirmed);
        console2.log("execute:", plan.execute);
        console2.log("REHEARSAL_ACTOR:", plan.rehearsalActor);
        console2.log("USDC_TOKEN:", plan.usdcToken);
        console2.log("SUN_TOKEN:", plan.sunToken);
        console2.log("SUN_CURVE:", plan.sunCurve);
        console2.log("MOON_TOKEN:", plan.moonToken);
        console2.log("MOON_CURVE:", plan.moonCurve);
        console2.log("PERMIT2:", plan.permit2);
        console2.log("POSITION_MANAGER:", plan.positionManager);
        console2.log("UNIVERSAL_ROUTER:", plan.universalRouter);
        console2.log("moonLaunchSecondsRemaining:", plan.moonLaunchSecondsRemaining);
        console2.log("sunPrice:", plan.sunPrice);
        console2.log("moonPriceInSun:", plan.moonPriceInSun);
        console2.log("moonPriceInUsdc:", plan.moonPriceInUsdc);
        console2.log("liquidityUsdcAmount:", plan.liquidityUsdcAmount);
        console2.log("liquidityMoonAmount:", plan.liquidityMoonAmount);
        console2.log("swapUsdcIn:", plan.swapUsdcIn);
        console2.log("swapUsdcGrossInputWithHookFee:", plan.swapUsdcGrossInputWithHookFee);
        console2.log("requiredUsdcForRehearsal:", plan.requiredUsdcForRehearsal);
        console2.log("sunMintUsdcAmount:", plan.sunMintUsdcAmount);
        console2.log("moonMintSunAmount:", plan.moonMintSunAmount);
        console2.log("projectedSunOut:", plan.projectedSunOut);
        console2.log("projectedMoonOut:", plan.projectedMoonOut);
        console2.log("actorUsdcBalance:", plan.actorUsdcBalance);
        console2.log("actorSunBalance:", plan.actorSunBalance);
        console2.log("actorMoonBalance:", plan.actorMoonBalance);
        console2.log("requiredUsdcBeforeAssetPrep:", plan.requiredUsdcBeforeAssetPrep);
        console2.log("projectedUsdcBalanceAfterAssetPrep:", plan.projectedUsdcBalanceAfterAssetPrep);
        console2.log("projectedSunBalanceAfterAssetPrep:", plan.projectedSunBalanceAfterAssetPrep);
        console2.log("projectedMoonBalanceAfterAssetPrep:", plan.projectedMoonBalanceAfterAssetPrep);
        console2.log("needsSunMint:", plan.needsSunMint);
        console2.log("needsMoonMint:", plan.needsMoonMint);
        console2.log("hasSufficientUsdcForAssetPrep:", plan.hasSufficientUsdcForAssetPrep);
        console2.log("hasSufficientProjectedSun:", plan.hasSufficientProjectedSun);
        console2.log("hasSufficientProjectedMoon:", plan.hasSufficientProjectedMoon);
        console2.log("usdcAllowanceToSunCurve:", plan.usdcAllowanceToSunCurve);
        console2.log("sunAllowanceToMoonCurve:", plan.sunAllowanceToMoonCurve);
        console2.log("usdcAllowanceToPermit2:", plan.usdcAllowanceToPermit2);
        console2.log("moonAllowanceToPermit2:", plan.moonAllowanceToPermit2);
        console2.log("usdcPermit2ToPositionManager:", plan.usdcPermit2ToPositionManager.amount);
        console2.log("moonPermit2ToPositionManager:", plan.moonPermit2ToPositionManager.amount);
        console2.log("usdcPermit2ToUniversalRouter:", plan.usdcPermit2ToUniversalRouter.amount);
        console2.log("hasUsdcPermit2TokenApproval:", plan.hasUsdcPermit2TokenApproval);
        console2.log("hasMoonPermit2TokenApproval:", plan.hasMoonPermit2TokenApproval);
        console2.log(
            "hasPositionManagerPermit2Allowances:", plan.hasPositionManagerPermit2Allowances
        );
        console2.log("hasUniversalRouterPermit2Allowance:", plan.hasUniversalRouterPermit2Allowance);
        console2.log("canExecuteAssetPrep:", plan.canExecuteAssetPrep);
        console2.log("transactionsPlanned:", plan.transactionsPlanned);
        console2.log("transactionsExecuted:", plan.transactionsExecuted);
        console2.log("Private key prompt rule:");
        console2.log(
            "enter only the private key for REHEARSAL_ACTOR shown above; never paste it in chat"
        );
    }
}
