// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

contract SunAmmGuardHook is Ownable {
    error InvalidAddress();
    error InvalidPoolId();
    error NotHookCaller();
    error HookPaused();
    error SunPoolNotAllowed(bytes32 poolId);
    error SunAmmLocked(address liquidityProvider);

    address public immutable sunToken;

    address public hookCaller;
    address public firstLiquidityProvider;
    bool public sunAmmUnlocked;
    bool public paused;

    mapping(bytes32 poolId => bool allowed) public allowedSunPools;

    event HookCallerSet(address indexed hookCaller);
    event FirstLiquidityProviderSet(address indexed firstLiquidityProvider);
    event SunPoolAllowedSet(bytes32 indexed poolId, bool allowed);
    event PausedSet(bool paused);
    event SunAmmUnlocked(bytes32 indexed poolId, address indexed liquidityProvider);

    constructor(
        address sunToken_,
        address firstLiquidityProvider_,
        address hookCaller_,
        address initialOwner
    ) Ownable(initialOwner) {
        if (sunToken_ == address(0)) revert InvalidAddress();
        if (firstLiquidityProvider_ == address(0)) revert InvalidAddress();
        if (hookCaller_ == address(0)) revert InvalidAddress();

        sunToken = sunToken_;
        firstLiquidityProvider = firstLiquidityProvider_;
        hookCaller = hookCaller_;

        emit FirstLiquidityProviderSet(firstLiquidityProvider_);
        emit HookCallerSet(hookCaller_);
    }

    function setHookCaller(address newHookCaller) external onlyOwner {
        if (newHookCaller == address(0)) revert InvalidAddress();

        hookCaller = newHookCaller;

        emit HookCallerSet(newHookCaller);
    }

    function setFirstLiquidityProvider(address newFirstLiquidityProvider) external onlyOwner {
        if (newFirstLiquidityProvider == address(0)) revert InvalidAddress();

        firstLiquidityProvider = newFirstLiquidityProvider;

        emit FirstLiquidityProviderSet(newFirstLiquidityProvider);
    }

    function setAllowedSunPool(bytes32 poolId, bool allowed) external onlyOwner {
        if (poolId == bytes32(0)) revert InvalidPoolId();

        allowedSunPools[poolId] = allowed;

        emit SunPoolAllowedSet(poolId, allowed);
    }

    function setPaused(bool newPaused) external onlyOwner {
        paused = newPaused;

        emit PausedSet(newPaused);
    }

    function beforeAddLiquidity(
        address liquidityProvider,
        bytes32 poolId,
        address token0,
        address token1
    ) external onlyHookCaller returns (bytes4) {
        if (paused) revert HookPaused();
        if (!isSunPair(token0, token1)) return this.beforeAddLiquidity.selector;
        if (!allowedSunPools[poolId]) revert SunPoolNotAllowed(poolId);

        if (!sunAmmUnlocked) {
            if (liquidityProvider != firstLiquidityProvider) {
                revert SunAmmLocked(liquidityProvider);
            }

            sunAmmUnlocked = true;
            emit SunAmmUnlocked(poolId, liquidityProvider);
        }

        return this.beforeAddLiquidity.selector;
    }

    function isSunPair(address token0, address token1) public view returns (bool) {
        return token0 == sunToken || token1 == sunToken;
    }

    modifier onlyHookCaller() {
        if (msg.sender != hookCaller) revert NotHookCaller();
        _;
    }
}
