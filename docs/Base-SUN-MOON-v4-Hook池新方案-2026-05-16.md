# Base SUN/MOON v4 Hook 池新方案 - 2026-05-16

本文档记录 2026-05-16 确认的新方向。当前仍然不部署 Base 主网，不接真实资金，不收集私钥。

## 一句话结论

SUN 和 MOON 都保持自由转账，不再试图从合约层禁止市场自行创建 AMM 池。

项目只对自己明确支持的 Uniswap v4 Hook 池提供费用逻辑：

```text
SUN/USDC v4 Hook 池：swap 收 2% USDC
MOON/USDC v4 Hook 池：swap 收 5% USDC
```

第三方自己创建的 SUN 或 MOON 交易池属于市场自发路径，不代表协议价格，也不保证触发项目费用和 SUN 曲线回灌。

## 为什么改方向

如果 SUN/MOON 是自由转账 ERC20，链上无法同时做到“任何人永远不能添加 AMM 流动性”。添加流动性的底层动作本质上也是把 token 转给 AMM 合约。

因此旧方向里的绝对表述需要废弃：

```text
不再说：任何人都不能给 SUN/MOON 加池
改为：SUN/MOON 自由转账；协议只支持指定 v4 Hook 池的收费路径
```

## SUN 上涨逻辑

SUN 的协议价格来自 `SunCurve` 账本，而不是 AMM 市场价格：

```text
SUN price = SunCurve.curveReserve / SunToken.totalSupply
```

SUN 价格上升来自两类动作：

1. `SunCurve` 储备增加，但 SUN 供应没有同比增加。
2. SUN 被销毁，但 `SunCurve` 储备没有同比减少。

因此 AMM 池里的市场价格不能替代 SUN 协议价格。前端和文档必须区分：

```text
SunCurve price = 协议价格
AMM price = 市场价格
```

## 项目支持的 v4 Hook 池

### SUN/USDC v4 Hook 池

目标：让 SUN 的市场 swap 也能给 SUN 曲线增加储备。

建议费用：

```text
swap fee = 2% USDC
1.5% USDC -> SunCurve.injectUSDT()
0.5% USDC -> PROTOCOL_BUDGET_WALLET
```

这与 `SunCurve` mint/burn 的 2% 总费率保持一致。

### MOON/USDC v4 Hook 池

目标：让 MOON 的市场 swap 继续推动 SUN 曲线飞轮。

建议费用：

```text
swap fee = 5% USDC
3% USDC -> SunCurve.injectUSDT()
2% USDC -> PROTOCOL_BUDGET_WALLET
```

这与当前 MOON AMM 费用方向一致。

## 第三方池边界

任何人可能创建：

```text
SUN/ETH
SUN/USDC
MOON/ETH
MOON/USDC
MOON/其他 token
```

如果这些池没有使用项目指定的 Hook，协议不保证：

- 收取项目费用。
- 注入 `SunCurve` 储备。
- 价格等于协议价格。
- 流动性安全。
- 前端展示或路由支持。

## 合约设计建议

主网前建议从当前 `BaseMoonAmmFeeV4Hook` 演进为统一 Hook，例如：

```text
BaseSunMoonUsdcFeeV4Hook
```

它只处理项目确认的 USDC 计费池：

```text
allowedSunUsdcPools[poolId] = true
allowedMoonUsdcPools[poolId] = true
```

规则：

```text
SUN/USDC pool -> 2% USDC fee
MOON/USDC pool -> 5% USDC fee
其他池 -> 不作为项目支持路径
```

`SunCurve.moonAMM` 命名后续可考虑改为更通用的 `feeInjector` 或 `authorizedAmmHook`。如果暂不改名，也必须在文档中说明它代表“授权注入 USDC 的 Hook”，不只限 MOON。

## 测试方向

后续测试应覆盖：

- SUN 可以自由转账。
- MOON 可以自由转账。
- `SUN/USDC` v4 Hook 池 swap 收 2% USDC。
- `MOON/USDC` v4 Hook 池 swap 收 5% USDC。
- SUN/USDC 费用中的 1.5% 注入 `SunCurve`，0.5% 进入协议经费地址。
- MOON/USDC 费用中的 3% 注入 `SunCurve`，2% 进入协议经费地址。
- 第三方未白名单池不应被描述为协议支持路径。
- owner 放弃后不能新增或修改支持池。

## 2026-05-17 实现进展

已完成：

- `BaseSunMoonUsdcFeeV4Hook` 本地实现：统一支持 `SUN/USDC` 2% USDC 和 `MOON/USDC` 5% USDC。
- `RehearseBaseSunMoonUsdcFeeV4Hook` 本地 CREATE2 预演：验证新版 Hook 可部署到正确 v4 权限地址。
- `ComputeBaseSunMoonUsdcPoolIds` 本地 poolId 计算：只计算新版 `SUN/USDC` 和 `MOON/USDC` 的 `PoolKey -> poolId`，不广播、不授权、不需要私钥。
- `PrepareBaseMainnetCoreDeployDryRun`：已在 Base mainnet fork 里只模拟预测核心合约地址，不广播、不部署。
- `ComputeBaseMainnetSunMoonUsdcHookSalt`：已在 Base mainnet fork 里只计算 Hook salt 和预测 Hook，不广播、不部署。
- `PrepareBaseMainnetSunMoonUsdcForkDryRun`：已在 Base mainnet fork 里只模拟 CREATE2 Hook、两个池白名单、两个池初始化、slot0 复核和 renounce 锁定检查。
- 全量 Foundry 测试通过：`forge test --threads 1 --isolate`，296 passed，0 failed。

仍未完成：

- 外部审计或安全 review。
- 审计问题修复后的最终测试和最终 mainnet fork dry-run 复核。
- owner 人工逐项确认上线前清单。
- 真实 Base 主网部署和池创建。

## 当前执行限制

当前阶段只做本地、Mock、fork、Base Sepolia 测试准备。仍然：

- 不部署 Base 主网。
- 不广播主网交易。
- 不接真实资金。
- 不收集私钥。
- 不把测试网地址当主网地址。
