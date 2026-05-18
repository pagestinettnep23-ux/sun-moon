# Base Sepolia rc3 Stage 1/2/3 总闸门清单 - 2026-05-18

本文是 rc3 测试网分阶段广播前后的最终人工闸门清单。

它的作用不是批准广播，而是防止把“草案、预测地址、只读检查”误当成“已经可以执行”。

固定边界：

```text
不广播 Base 主网
不使用真实资金
不索要私钥
不把测试网成功当成主网安全结论
不把预测地址当成已部署地址
```

## 1. 当前状态

截至本文创建时：

```text
Base 主网广播=false
Base Sepolia 测试网广播=false
真实资金=false
私钥请求=false
Stage 1=草案已准备，未广播
Stage 2=草案已准备，未广播
Stage 3=草案已准备，未广播
```

小白理解：

```text
我们现在只是把路线、清单、停止条件准备好。
真正测试网广播必须以后单独批准。
Stage 1 批准不等于 Stage 2/3 也批准。
测试网批准不等于主网批准。
```

## 2. 已准备的文档

| 用途 | 文档 |
| --- | --- |
| 分阶段总复核 | `docs/Base-Sepolia-rc3-分阶段广播人工复核表-2026-05-18.md` |
| Stage 1 广播草案 | `docs/Base-Sepolia-rc3-Stage1-测试网广播草案-2026-05-18.md` |
| Stage 1 广播前最终确认 | `docs/Base-Sepolia-rc3-Stage1-广播前最终确认单-2026-05-18.md` |
| Stage 1 广播后复核 | `docs/Base-Sepolia-rc3-Stage1-广播后复核清单草案-2026-05-18.md` |
| Stage 2 广播草案 | `docs/Base-Sepolia-rc3-Stage2-测试网广播草案-2026-05-18.md` |
| Stage 2 广播后复核 | `docs/Base-Sepolia-rc3-Stage2-广播后复核清单草案-2026-05-18.md` |
| Stage 3 广播草案 | `docs/Base-Sepolia-rc3-Stage3-测试网广播草案-2026-05-18.md` |
| Stage 3 广播后复核 | `docs/Base-Sepolia-rc3-Stage3-广播后复核清单草案-2026-05-18.md` |

人工复核：

- [ ] 确认上面 8 份文档都能打开。
- [ ] 确认这些文档都是测试网 rc3 准备资料，不是主网计划。
- [ ] 确认任何真实广播前都必须重新跑只读检查。

## 3. 固定测试网参数

| 项目 | 值 |
| --- | --- |
| 网络 | Base Sepolia |
| chain-id | `84532` |
| PoolManager | `0x05E73354cFDd6745C338b50BcFDfA3Aa6fA03408` |
| StateView | `0x571291b572ed32ce6751a2Cb2486EbEe8DEfB9B4` |
| USDC | `0x036CbD53842c5426634e7929541eC2318f3dCF7e` |

人工复核：

- [ ] 确认链是 Base Sepolia，不是 Base 主网。
- [ ] 确认 `chain-id=84532`。
- [ ] 确认任何命令没有指向 Base 主网 RPC。
- [ ] 确认本文里的地址不是私钥，只是公开地址或公开合约地址。

## 4. 三阶段总览

| 阶段 | 预计交易数 | 执行钱包公开地址 | 作用 | 是否自动进入下一阶段 |
| --- | ---: | --- | --- | --- |
| Stage 1 | 12 | `0x2F6E887c6058deE520f9468a1022E3480A6334D3` | 部署测试版 SUN/MOON 核心合约和基础配置 | 否 |
| Stage 2 | 6 | `0x6E22b2e6fFAA30Fe75B71d53d1eC469b4e97A986` | 部署 Hook、绑定 SunCurve、白名单两个池、初始化两个池 | 否 |
| Stage 3 | 1 | `0x6E22b2e6fFAA30Fe75B71d53d1eC469b4e97A986` | 放弃 Hook owner | 否 |

合计：

```text
totalTransactionsPlanned=19
```

人工复核：

- [ ] 确认必须按 Stage 1 -> Stage 2 -> Stage 3 顺序执行。
- [ ] 确认 Stage 3 只能最后执行。
- [ ] 确认 Stage 1 成功后也不能自动进入 Stage 2。
- [ ] 确认 Stage 2 成功后也不能自动进入 Stage 3。

## 5. 当前 fork 只读检查输出

这些是最近一次 Base Sepolia fork 只读检查输出，不是已部署地址。

```text
chainId=84532
broadcastAllowed=false
executionBlocked=true
simulationOnly=true
executeRequested=false
privateKeyPresent=false
totalTransactionsPlanned=19
stage1AddressCollision=false
stage2HookCollision=false
```

预测核心地址：

```text
PREDICTED_SUN_TOKEN=0xb5287fBbAD0e25B12f18497209fDac7e0ACf7293
PREDICTED_SUN_CURVE=0xe8D048aB83727419b00F4e30F4898C6B3bB91aD4
PREDICTED_MOON_TOKEN=0x92dC3B8056cA62A7dbc5c1C339891B45463bEe71
PREDICTED_MOON_CURVE=0x095c91aB279121300Ac16c57D1ecebB9ceEa1cd8
PREDICTED_CREATE2_HOOK_DEPLOYER=0x6E34D98e1925eaf6680941213E49741b8764DdfE
```

预测 Hook 和池：

```text
HOOK_SALT=0x0000000000000000000000000000000000000000000000000000000000002a9c
PREDICTED_HOOK=0x675D7a468d4d3b8d02d530539867F9e5feEFc0cc
SUN_USDC_POOL_ID=0xdbf2bf05916b4f79d43e3ee74fa48b36301e8e8c13805335e186648b792451dc
MOON_USDC_POOL_ID=0x5b2a79878be8e421c919a9acb8d853731d6d61b8053aa25bd32e0c994130bdfd
```

人工复核：

- [ ] 确认这些只是预测值，不是链上已部署结果。
- [ ] 确认任何真实测试网广播前必须重新生成并复核。
- [ ] 确认如果钱包 nonce 变化，预测核心地址可能变化。
- [ ] 确认如果 Stage 1 实际地址变化，Stage 2/3 的 Hook、poolId、清单都必须更新。

## 6. 项目支持的两个 v4 Hook 池

| 池 | 初始价格 | LP fee | tickSpacing | Hook fee |
| --- | --- | ---: | ---: | --- |
| SUN/USDC | `1 SUN = 1 USDC` | 0.3% | 60 | 2% USDC |
| MOON/USDC | `1 MOON = 0.24 USDC` | 0.3% | 60 | 5% USDC |

初始化参数：

```text
SUN_USDC_INITIAL_TICK=276324
SUN_USDC_SQRT_PRICE_X96=79228162514264337593543950336000000
MOON_USDC_INITIAL_TICK=290595
MOON_USDC_SQRT_PRICE_X96=161723809515207654377831473576838109
```

人工复核：

- [ ] 确认 `LP fee=0.3%` 是 Uniswap LP 手续费。
- [ ] 确认 `Hook fee=2%/5%` 是项目 Hook 费用。
- [ ] 确认 Stage 2 只初始化池，不添加流动性。
- [ ] 确认 SUN/MOON 仍然自由转账，市场可以自行创建其他池；项目只对上面两个 v4 Hook 池提供费用逻辑。

## 7. Stage 1 前闸门

只有全部通过，才可以考虑让 owner 单独批准测试网 Stage 1。

- [ ] 已重新跑 Base Sepolia fork 只读分阶段草案检查。
- [ ] `chain-id=84532`。
- [ ] `broadcastAllowed=false`。
- [ ] `executionBlocked=true`。
- [ ] `privateKeyPresent=false`。
- [ ] Stage 1 预测地址没有代码冲突。
- [ ] Stage 1 执行钱包公开地址正确。
- [ ] Stage 1 文档已读完：`docs/Base-Sepolia-rc3-Stage1-测试网广播草案-2026-05-18.md`。
- [ ] Stage 1 广播前最终确认单已读完：`docs/Base-Sepolia-rc3-Stage1-广播前最终确认单-2026-05-18.md`。
- [ ] owner 明确知道 Stage 1 只部署核心合约，不部署 Hook、不建池、不加流动性、不 swap、不 renounce。
- [ ] owner 只批准“Base Sepolia 测试网 Stage 1”，不批准 Stage 2/3，不批准主网。

Stage 1 前任一项不过：

```text
停止，不广播。
```

## 8. Stage 1 后闸门

Stage 1 如果未来真的广播成功，必须先完成下面复核，才能考虑 Stage 2。

- [ ] 已填写 Stage 1 的 12 笔交易哈希。
- [ ] 12 笔交易 receipt status 都是 `1`。
- [ ] 12 笔交易都发生在 Base Sepolia。
- [ ] 5 个核心合约 code 都不是 `0x`。
- [ ] SUN/MOON token name、symbol 正确。
- [ ] SUN/MOON minter、owner、minterLocked 正确。
- [ ] SunCurve owner、USDC、protocolBudget、moonCurve、moonAMM 正确。
- [ ] MoonCurve owner、token 地址、k/s、launchTime、timeUntilLaunch 正确。
- [ ] Create2HookDeployer owner 正确。
- [ ] Stage 1 后仍未部署 Hook。
- [ ] Stage 1 后仍未创建或初始化池。
- [ ] Stage 1 后仍未添加流动性。
- [ ] Stage 1 后仍未执行 swap。
- [ ] Stage 1 后仍未 renounce Hook owner。

必须使用：

```text
docs/Base-Sepolia-rc3-Stage1-广播后复核清单草案-2026-05-18.md
```

Stage 1 后任一项不过：

```text
停止，不进入 Stage 2。
```

## 9. Stage 2 前闸门

只有 Stage 1 后复核全部通过，才可以考虑让 owner 单独批准测试网 Stage 2。

- [ ] Stage 1 广播后复核清单全部通过。
- [ ] 已把 Stage 1 实际地址填入 Stage 2 使用的参数。
- [ ] 已重新计算 Hook salt、Hook 预测地址和两个 poolId。
- [ ] Hook 预测地址 low 14 bits 等于 `204`。
- [ ] Stage 2 Hook 地址没有代码冲突。
- [ ] Stage 2 执行钱包公开地址正确。
- [ ] Stage 2 文档已读完：`docs/Base-Sepolia-rc3-Stage2-测试网广播草案-2026-05-18.md`。
- [ ] owner 明确知道 Stage 2 只部署 Hook、绑定、白名单、初始化池。
- [ ] owner 明确知道 Stage 2 不添加流动性、不 swap、不 renounce。
- [ ] owner 只批准“Base Sepolia 测试网 Stage 2”，不批准 Stage 3，不批准主网。

Stage 2 前任一项不过：

```text
停止，不广播 Stage 2。
```

## 10. Stage 2 后闸门

Stage 2 如果未来真的广播成功，必须先完成下面复核，才能考虑 Stage 3。

- [ ] 已填写 Stage 2 的 6 笔交易哈希。
- [ ] 6 笔交易 receipt status 都是 `1`。
- [ ] Hook code 不是 `0x`。
- [ ] Hook owner 仍是测试网管理员钱包。
- [ ] Hook poolManager、sunToken、moonToken、usdc、sunCurve、protocolBudget、paused、expectedHookMask 全部正确。
- [ ] `SunCurve.moonAMM` 等于 Hook。
- [ ] `allowedSunUsdcPools(SUN_USDC_POOL_ID)=true`。
- [ ] `allowedMoonUsdcPools(MOON_USDC_POOL_ID)=true`。
- [ ] SUN/USDC slot0 符合预期。
- [ ] MOON/USDC slot0 符合预期。
- [ ] 两个池 `liquidity=0`。
- [ ] Stage 2 后仍未添加流动性。
- [ ] Stage 2 后仍未执行 swap。
- [ ] Stage 2 后仍未 renounce Hook owner。

必须使用：

```text
docs/Base-Sepolia-rc3-Stage2-广播后复核清单草案-2026-05-18.md
```

Stage 2 后任一项不过：

```text
停止，不进入 Stage 3。
```

## 11. Stage 3 前闸门

Stage 3 是不可逆的 owner 放弃动作。只有 Stage 2 后复核全部通过，且确认不再需要修改 Hook 参数，才可以考虑让 owner 单独批准测试网 Stage 3。

- [ ] Stage 1 后复核清单全部通过。
- [ ] Stage 2 后复核清单全部通过。
- [ ] Hook owner 仍是测试网管理员钱包。
- [ ] Hook protocolBudget 正确。
- [ ] Hook paused 是 `false`。
- [ ] 两个白名单都是 `true`。
- [ ] 两个池 slot0 正确。
- [ ] 两个池 liquidity 仍是 `0`。
- [ ] 确认不再需要新增或删除任何 poolId 白名单。
- [ ] 确认不再需要修改 protocolBudget。
- [ ] 确认不再需要修改 paused。
- [ ] Stage 3 文档已读完：`docs/Base-Sepolia-rc3-Stage3-测试网广播草案-2026-05-18.md`。
- [ ] owner 明确知道 Stage 3 后管理员也不能再改 Hook。
- [ ] owner 只批准“Base Sepolia 测试网 Stage 3”，不批准主网。

Stage 3 前任一项不过：

```text
停止，不广播 Stage 3。
```

## 12. Stage 3 后闸门

Stage 3 如果未来真的广播成功，必须完成下面复核，才能把测试网 rc3 分阶段广播记录为完成。

- [ ] 已填写 Stage 3 的 1 笔交易哈希。
- [ ] 交易 receipt status 是 `1`。
- [ ] 交易发生在 Base Sepolia。
- [ ] Hook code 不是 `0x`。
- [ ] `Hook.owner=0x0000000000000000000000000000000000000000`。
- [ ] Hook 关键配置保持不变。
- [ ] `SunCurve.moonAMM` 仍等于 Hook。
- [ ] 两个白名单仍是 `true`。
- [ ] 两个池 slot0 仍符合预期。
- [ ] 两个池 liquidity 仍是 `0`。
- [ ] 只读模拟确认 owner-only 函数已经不能再改参数。

必须使用：

```text
docs/Base-Sepolia-rc3-Stage3-广播后复核清单草案-2026-05-18.md
```

Stage 3 后任一项不过：

```text
停止，把测试网 rc3 记录为异常，不进入主网讨论。
```

## 13. 绝对停止条件

出现任一情况，立即停止：

```text
命令指向 Base 主网
有人要求广播 Base 主网
有人要求使用真实资金
有人要求提供私钥、助记词或恢复词
有人把预测地址说成已部署地址
有人把测试网成功说成主网可以直接部署
Stage 1/2/3 顺序被打乱
Stage 1 后复核未通过就准备 Stage 2
Stage 2 后复核未通过就准备 Stage 3
Hook owner 已经不是预期地址却准备继续
任何白名单、poolId、slot0、liquidity 与预期不一致
```

## 14. Owner 最终确认区

当前不填写，因为现在没有批准任何广播。

| 阶段 | owner 是否单独批准 | 日期 | 备注 |
| --- | --- | --- | --- |
| Stage 1 Base Sepolia 广播 | 待填 | 待填 | 只批准 Stage 1，不包含 Stage 2/3 |
| Stage 2 Base Sepolia 广播 | 待填 | 待填 | 只批准 Stage 2，不包含 Stage 3 |
| Stage 3 Base Sepolia 广播 | 待填 | 待填 | 只批准 Stage 3，不包含主网 |

人工复核：

- [ ] 没有 owner 单独批准时，不广播。
- [ ] 任何批准都必须写清楚是 Base Sepolia，不是 Base 主网。
- [ ] 任何批准都不能包含私钥、助记词或恢复词。

## 15. 下一步建议

下一步仍然不是广播。

建议下一步只做：

```text
Stage 1 广播前最终确认单已经准备完成：
docs/Base-Sepolia-rc3-Stage1-广播前最终确认单-2026-05-18.md

等待 owner 人工阅读总闸门清单和 Stage 1 广播前最终确认单
如果 owner 后续想继续，也应先重新跑 Base Sepolia fork 只读检查
然后再单独讨论是否允许测试网 Stage 1 广播
主网仍然不进入
```
