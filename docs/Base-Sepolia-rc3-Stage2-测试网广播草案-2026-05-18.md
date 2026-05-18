# Base Sepolia rc3 Stage 2 测试网广播草案 - 2026-05-18

本文只整理 Stage 2 的测试网广播草案，方便人工理解和复核。

这不是广播批准，也不是主网计划。

固定边界：

```text
不加 --broadcast
当前不部署测试网合约
不部署主网合约
不使用真实资金
不索要私钥
不把预测地址当成已部署地址
```

## 1. Stage 2 是什么

Stage 2 只做 Hook 和两个项目支持 v4 池的准备。

它会准备：

```text
部署 BaseSunMoonUsdcFeeV4Hook
绑定 SunCurve.moonAMM
白名单 SUN/USDC poolId
白名单 MOON/USDC poolId
初始化 SUN/USDC v4 池
初始化 MOON/USDC v4 池
```

它不会做：

```text
不会部署 SUN/MOON 核心合约
不会添加流动性
不会 swap
不会 renounce Hook owner
不会碰 Base 主网
不会使用真实资金
```

小白理解：

```text
Stage 2 是把 Hook 和两个项目支持的测试网 v4 池准备好。
Stage 2 初始化池，只是设定池子的初始价格。
Stage 2 不会往池子里放 SUN、MOON 或 USDC。
```

## 2. Stage 2 前置条件

Stage 2 只能在 Stage 1 完成并复核通过后考虑。

必须先确认：

- [ ] Stage 1 的 12 笔交易都成功。
- [ ] Stage 1 实际合约地址与广播前最后预测地址一致。
- [ ] `SunToken`、`SunCurve`、`MoonToken`、`MoonCurve`、`Create2HookDeployer` 都有 code。
- [ ] `SunToken.minter` 是 `SunCurve`。
- [ ] `MoonToken.minter` 是 `MoonCurve`。
- [ ] `SunCurve.moonCurve` 是 `MoonCurve`。
- [ ] `SunCurve.moonAMM` 仍是零地址。
- [ ] `Create2HookDeployer.owner` 是测试网 CREATE2 deployer owner。

如果任一项不通过，不能进入 Stage 2。

## 3. 当前 Stage 2 公开参数

这些都是公开地址，可以写进文档。

| 项目 | 地址 |
| --- | --- |
| Stage 2 Hook deployer owner | `0x6E22b2e6fFAA30Fe75B71d53d1eC469b4e97A986` |
| Stage 2 admin wallet | `0x6E22b2e6fFAA30Fe75B71d53d1eC469b4e97A986` |
| 测试网协议经费收款钱包 | `0x277ba3Cf597CdAaF958C301db3cF6a631F793039` |
| PoolManager | `0x05E73354cFDd6745C338b50BcFDfA3Aa6fA03408` |
| StateView | `0x571291b572ed32ce6751a2Cb2486EbEe8DEfB9B4` |
| Base Sepolia USDC | `0x036CbD53842c5426634e7929541eC2318f3dCF7e` |

说明：

```text
当前测试网草案里，Hook deployer owner 和 admin wallet 是同一个普通钱包。
这些是 Base Sepolia 测试网地址，不是 Base 主网地址。
```

## 4. Stage 2 的 6 笔交易

当前草案里，Stage 2 预计 6 笔交易。

| 顺序 | 操作 | 谁执行 | 小白解释 |
| ---: | --- | --- | --- |
| 1 | `Create2HookDeployer.deployHook(...)` | Stage 2 Hook deployer owner | 用 CREATE2 部署统一 Hook |
| 2 | `SunCurve.setMoonAMM(Hook)` | Stage 2 admin wallet | 允许 Hook 向 SunCurve 注入 USDC 费用 |
| 3 | `Hook.setAllowedSunUsdcPool(poolId, true)` | Stage 2 admin wallet | 允许 SUN/USDC 项目支持池走 Hook 费用逻辑 |
| 4 | `Hook.setAllowedMoonUsdcPool(poolId, true)` | Stage 2 admin wallet | 允许 MOON/USDC 项目支持池走 Hook 费用逻辑 |
| 5 | `PoolManager.initialize(SUN/USDC, sqrtPriceX96)` | Stage 2 admin wallet | 初始化 SUN/USDC v4 池价格 |
| 6 | `PoolManager.initialize(MOON/USDC, sqrtPriceX96)` | Stage 2 admin wallet | 初始化 MOON/USDC v4 池价格 |

Stage 2 完成后，应该看到：

```text
Hook 地址有 code
Hook.owner = Stage 2 admin wallet
SunCurve.moonAMM = Hook
allowedSunUsdcPools(SUN_USDC_POOL_ID) = true
allowedMoonUsdcPools(MOON_USDC_POOL_ID) = true
SUN/USDC slot0.sqrtPriceX96 不是 0
MOON/USDC slot0.sqrtPriceX96 不是 0
```

## 5. 当前预测地址和 Hook 参数

这些地址来自 2026-05-18 Base Sepolia fork 只读检查。

它们不是已经部署地址。

| 项目 | 预测地址 |
| --- | --- |
| `SunToken` | `0xb5287fBbAD0e25B12f18497209fDac7e0ACf7293` |
| `SunCurve` | `0xe8D048aB83727419b00F4e30F4898C6B3bB91aD4` |
| `MoonToken` | `0x92dC3B8056cA62A7dbc5c1C339891B45463bEe71` |
| `MoonCurve` | `0x095c91aB279121300Ac16c57D1ecebB9ceEa1cd8` |
| `Create2HookDeployer` | `0x6E34D98e1925eaf6680941213E49741b8764DdfE` |
| `BaseSunMoonUsdcFeeV4Hook` | `0x675D7a468d4d3b8d02d530539867F9e5feEFc0cc` |

Hook CREATE2 参数：

```text
HOOK_SALT=0x0000000000000000000000000000000000000000000000000000000000002a9c
expectedHookMask=204
actualLow14Bits=204
```

人工复核：

- [ ] 确认这些只是预测地址。
- [ ] 确认 Stage 1 实际地址如果变化，Stage 2 的 Hook、poolId 也必须重新计算。
- [ ] 确认真正测试网广播前必须重新跑 fork 只读检查。
- [ ] 确认 `stage2HookCollision=false`。

## 6. Hook 构造参数复核

Hook 部署时应使用：

```text
poolManager=0x05E73354cFDd6745C338b50BcFDfA3Aa6fA03408
sunToken=<Stage 1 SunToken 实际地址>
moonToken=<Stage 1 MoonToken 实际地址>
usdc=0x036CbD53842c5426634e7929541eC2318f3dCF7e
sunCurve=<Stage 1 SunCurve 实际地址>
protocolBudget=0x277ba3Cf597CdAaF958C301db3cF6a631F793039
owner=0x6E22b2e6fFAA30Fe75B71d53d1eC469b4e97A986
```

人工复核：

- [ ] Hook 的 `poolManager` 是 Base Sepolia 官方 PoolManager。
- [ ] Hook 的 `sunToken` 是 Stage 1 实际 SunToken。
- [ ] Hook 的 `moonToken` 是 Stage 1 实际 MoonToken。
- [ ] Hook 的 `usdc` 是 Base Sepolia USDC。
- [ ] Hook 的 `sunCurve` 是 Stage 1 实际 SunCurve。
- [ ] Hook 的 `protocolBudget` 是测试网协议经费收款钱包。
- [ ] Hook 的 `owner` 是 Stage 2 admin wallet。

## 7. 两个 v4 池参数

这些 poolId 是基于当前预测地址计算出的 fork 检查结果，不是已经部署池。

| 池 | currency0 | currency1 | fee | tickSpacing | Hook |
| --- | --- | --- | ---: | ---: | --- |
| SUN/USDC | Base Sepolia USDC | SUN | 3000 | 60 | `0x675D7a468d4d3b8d02d530539867F9e5feEFc0cc` |
| MOON/USDC | Base Sepolia USDC | MOON | 3000 | 60 | `0x675D7a468d4d3b8d02d530539867F9e5feEFc0cc` |

PoolId：

```text
SUN_USDC_POOL_ID=0xdbf2bf05916b4f79d43e3ee74fa48b36301e8e8c13805335e186648b792451dc
MOON_USDC_POOL_ID=0x5b2a79878be8e421c919a9acb8d853731d6d61b8053aa25bd32e0c994130bdfd
```

初始化价格：

```text
SUN/USDC: 1 SUN = 1 USDC
SUN_USDC_INITIAL_TICK=276324
SUN_USDC_SQRT_PRICE_X96=79228162514264337593543950336000000

MOON/USDC: 1 MOON = 0.24 USDC
MOON_USDC_INITIAL_TICK=290595
MOON_USDC_SQRT_PRICE_X96=161723809515207654377831473576838109
```

费用区别：

```text
Uniswap LP fee=0.3%
SUN/USDC Hook fee=2% USDC
MOON/USDC Hook fee=5% USDC
```

人工复核：

- [ ] 确认 `fee=3000` 表示 Uniswap LP fee 0.3%。
- [ ] 确认 `tickSpacing=60`。
- [ ] 确认 Hook 地址低 14 位权限匹配。
- [ ] 确认两个 poolId 是根据 Stage 1 实际地址和 Hook 地址重新计算后的结果。

## 8. Stage 2 完成后仍未完成的事

Stage 2 不包含这些内容：

```text
添加 SUN/USDC 流动性
添加 MOON/USDC 流动性
swap
renounce Hook owner
任何 Base 主网动作
```

这些必须后续再单独复核。

特别说明：

```text
PoolManager.initialize 只初始化池价格。
它不是添加流动性。
它不会往池里放入 SUN、MOON 或 USDC。
```

## 9. Stage 2 前必须重新检查

任何真实 Base Sepolia Stage 2 广播前，必须重新做：

- [ ] 重新跑 Base Sepolia fork 只读分阶段草案检查。
- [ ] 确认 `chainId=84532`。
- [ ] 确认 Stage 1 后复核清单全部通过。
- [ ] 确认 `stage2HookCollision=false`。
- [ ] 确认 `SunCurve.moonAMM` 仍是零地址。
- [ ] 确认两个 pool 在初始化前 `sqrtPriceX96=0`。
- [ ] 确认命令没有 `--broadcast`，除非 owner 单独明确批准测试网 Stage 2 广播。
- [ ] 确认没有把任何私钥、助记词、恢复词写进聊天或文档。
- [ ] 确认只使用 Base Sepolia 测试网，不触碰 Base 主网。

## 10. 绝对停止条件

出现任一情况，立即停止：

```text
命令指向 Base 主网
命令出现 --broadcast 但 owner 没有明确批准测试网 Stage 2 广播
有人要求提供私钥、助记词或恢复词
有人要求使用真实 ETH 或真实 USDC
Stage 1 实际地址和 Stage 2 草案地址不一致
Hook 预测地址已有 code 但不是预期部署结果
SUN/USDC 或 MOON/USDC poolId 与最新计算不一致
有人要求跳过 Stage 2 后复核，直接进入 Stage 3
```

## 11. 下一步建议

下一步仍然不是广播。

建议下一步只做：

```text
Stage 2 后复核清单草案
列出如果未来 Stage 2 真的广播成功后，要用 cast/code/owner/slot0 查询哪些结果
继续保持不广播、不索要私钥
```

Stage 2 后复核清单草案：

```text
docs/Base-Sepolia-rc3-Stage2-广播后复核清单草案-2026-05-18.md
```
