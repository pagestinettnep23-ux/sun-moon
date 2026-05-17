# 合约目录

这里后续放 Solidity 合约。

建议开发顺序：

1. `SunToken.sol`
2. `MoonToken.sol`
3. `SunCurve.sol` 或 `SunCurveHook.sol`
4. `MoonCurve.sol` 或 `MoonCurveHook.sol`
5. `MoonAMMHook.sol`
6. `PriceOracle.sol`

第一步不要急着接 Hook，建议先把 SUN 和 MOON 的曲线数学用普通合约验证清楚。

