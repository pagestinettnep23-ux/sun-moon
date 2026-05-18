# Base Sepolia rc3 Stage 1 最终广播前人工批准表 - 2026-05-18

本文是 owner 在未来决定是否批准 Base Sepolia 测试网 Stage 1 前看的人工批准表。

当前不填写批准，当前不广播，当前不需要私钥。

固定边界：

```text
不广播 Base 主网
不使用真实资金
不索要私钥、助记词或恢复词
不执行 Stage 2 或 Stage 3
不部署 Hook
不建池
不加流动性
不 swap
不 renounce
```

小白理解：

```text
这张表不是按钮。
这张表不是命令。
这张表只是让你在未来按下任何测试网广播按钮前，逐项确认自己到底批准了什么、没有批准什么。
```

## 1. 当前状态

```text
Base Sepolia Stage 1 广播批准=待填
Base Sepolia Stage 1 广播执行=false
Base 主网广播=false
真实资金=false
私钥请求=false
当前文档类型=人工批准表，不执行
```

最近一次只读复查结果：

```text
Script ran successfully
chainId=84532
selectedStage=0
selectedStageTxs=19
totalTransactionsPlanned=19
SEPOLIA_DEPLOYER nonce=16
broadcastAllowed=false
executionBlocked=true
simulationOnly=true
executeRequested=false
privateKeyPresent=false
stage1AddressCollision=false
stage2HookCollision=false
```

## 2. 必读文档确认

owner 在任何批准前，必须人工读完：

| 确认 | 文档 |
| --- | --- |
| [ ] | `docs/Base-Sepolia-rc3-Stage1-广播前最终确认单-2026-05-18.md` |
| [ ] | `docs/Base-Sepolia-rc3-Stage1-操作员执行说明草案-2026-05-18.md` |
| [ ] | `docs/Base-Sepolia-rc3-Stage1-测试网广播草案-2026-05-18.md` |
| [ ] | `docs/Base-Sepolia-rc3-Stage1-广播指令草案-非执行版-2026-05-18.md` |
| [ ] | `docs/Base-Sepolia-rc3-Stage1-最终广播指令草案-审阅版-2026-05-18.md` |
| [ ] | `docs/Base-Sepolia-rc3-Stage1-广播后复核清单草案-2026-05-18.md` |
| [ ] | `docs/Base-Sepolia-rc3-Stage1-2-3-总闸门清单-2026-05-18.md` |

任一份没读完：

```text
停止。
不批准。
```

## 3. 网络和钱包确认

| 确认项 | 值 | owner 确认 |
| --- | --- | --- |
| 网络只能是 Base Sepolia | `chainId=84532` | [ ] |
| 不是 Base 主网 | `Base mainnet=false` | [ ] |
| Stage 1 执行钱包公开地址 | `0x2F6E887c6058deE520f9468a1022E3480A6334D3`，仅 Base Sepolia 测试网，不是主网地址 | [ ] |
| 测试网管理员公开地址 | `0x6E22b2e6fFAA30Fe75B71d53d1eC469b4e97A986`，仅 Base Sepolia 测试网，不是主网地址 | [ ] |
| 测试网协议经费公开地址 | `0x277ba3Cf597CdAaF958C301db3cF6a631F793039`，仅 Base Sepolia 测试网，不是主网地址 | [ ] |
| 私钥不出现在聊天、文档或代码里 | `privateKeyPresent=false` | [ ] |

特别确认：

- [ ] 我确认上面 3 个钱包地址都只是 Base Sepolia 测试网地址，不是 Base 主网正式地址。
- [ ] 我确认主网正式地址必须另看 `MAINNET_DEPLOYER`、`MAINNET_ADMIN_WALLET`、`PROTOCOL_BUDGET_WALLET`、`CREATE2_DEPLOYER_OWNER` 那组公开参数。

## 4. Stage 1 允许范围确认

如果未来批准 Stage 1，只允许 12 笔 Base Sepolia 测试网交易：

| 顺序 | 操作 | owner 确认 |
| ---: | --- | --- |
| 1 | Deploy `SunToken` | [ ] |
| 2 | Deploy `SunCurve` | [ ] |
| 3 | Deploy `MoonToken` | [ ] |
| 4 | Deploy `MoonCurve` | [ ] |
| 5 | Deploy `Create2HookDeployer` | [ ] |
| 6 | `SunToken.setMinter(SunCurve)` | [ ] |
| 7 | `SunCurve.setMoonCurve(MoonCurve)` | [ ] |
| 8 | `MoonToken.setMinter(MoonCurve)` | [ ] |
| 9 | `SunToken.transferOwnership(admin)` | [ ] |
| 10 | `SunCurve.transferOwnership(admin)` | [ ] |
| 11 | `MoonToken.transferOwnership(admin)` | [ ] |
| 12 | `MoonCurve.transferOwnership(admin)` | [ ] |

owner 必须确认：

- [ ] 我理解 Stage 1 只部署测试版核心合约和基础配置。
- [ ] 我理解 Stage 1 预计 12 笔测试网交易。
- [ ] 我理解 Stage 1 成功后，rc3 测试网演练仍未完成。

## 5. Stage 1 明确不批准的内容

owner 必须逐项确认不批准：

- [ ] 不批准 Stage 2。
- [ ] 不批准 Stage 3。
- [ ] 不批准 Base 主网。
- [ ] 不批准真实资金。
- [ ] 不批准部署 Hook。
- [ ] 不批准绑定 `SunCurve.moonAMM`。
- [ ] 不批准设置 `SUN/USDC` 白名单。
- [ ] 不批准设置 `MOON/USDC` 白名单。
- [ ] 不批准建池或初始化池。
- [ ] 不批准添加流动性。
- [ ] 不批准 swap。
- [ ] 不批准 renounce Hook owner。
- [ ] 不批准任何人索要私钥、助记词或恢复词。

任一项不能确认：

```text
停止。
不批准。
```

## 6. 预测地址确认

这些是预测地址，不是已部署地址。

```text
PREDICTED_SUN_TOKEN=0xb5287fBbAD0e25B12f18497209fDac7e0ACf7293
PREDICTED_SUN_CURVE=0xe8D048aB83727419b00F4e30F4898C6B3bB91aD4
PREDICTED_MOON_TOKEN=0x92dC3B8056cA62A7dbc5c1C339891B45463bEe71
PREDICTED_MOON_CURVE=0x095c91aB279121300Ac16c57D1ecebB9ceEa1cd8
PREDICTED_CREATE2_HOOK_DEPLOYER=0x6E34D98e1925eaf6680941213E49741b8764DdfE
```

owner 确认：

- [ ] 我理解这些是预测地址，不是已部署地址。
- [ ] 我理解如果 `SEPOLIA_DEPLOYER nonce` 变化，预测地址可能变化。
- [ ] 我确认最近一次只读复查显示 `SEPOLIA_DEPLOYER nonce=16`。
- [ ] 我确认最近一次只读复查显示 `stage1AddressCollision=false`。

## 7. 批准语句填写区

当前保持待填。

| 项目 | 填写 |
| --- | --- |
| owner 是否批准 Base Sepolia rc3 Stage 1 | 待填 |
| owner 是否明确不批准 Stage 2 | 待填 |
| owner 是否明确不批准 Stage 3 | 待填 |
| owner 是否明确不批准 Base 主网 | 待填 |
| owner 是否明确不批准真实资金操作 | 待填 |
| owner 是否确认不会提供私钥、助记词或恢复词 | 待填 |
| 日期 | 待填 |
| 备注 | 待填 |

如果未来 owner 决定批准，批准语句必须清楚写成：

```text
我只批准 Base Sepolia 测试网 rc3 Stage 1。
我不批准 Stage 2。
我不批准 Stage 3。
我不批准 Base 主网。
我不批准真实资金操作。
我不会在聊天或文档里提供私钥、助记词或恢复词。
```

当前没有填写上面语句，所以当前不是批准。

## 8. 操作员执行前必须再次检查

即使本表未来被 owner 填写，也不能直接执行。

执行前必须再次完成：

- [ ] 重新跑 Base Sepolia fork 只读检查。
- [ ] 确认 `Script ran successfully`。
- [ ] 确认 `chainId=84532`。
- [ ] 确认 `privateKeyPresent=false`。
- [ ] 确认 `stage1AddressCollision=false`。
- [ ] 确认部署钱包 nonce 与预测地址一致。
- [ ] 确认当前 commit 已记录。
- [ ] 确认当前没有未解释的合约或脚本改动。
- [ ] 确认 Stage 1 广播后复核清单已经准备好。

任一项不满足：

```text
停止。
不进入执行版。
```

## 9. Stage 1 如果未来成功，必须先复核

Stage 1 如果未来真的广播成功，下一步不是 Stage 2。

必须先做：

```text
填写 12 笔交易哈希
检查 12 笔交易 receipt status
执行 Stage 1 广播后复核清单
```

必须使用：

```text
docs/Base-Sepolia-rc3-Stage1-广播后复核清单草案-2026-05-18.md
```

Stage 1 后复核没有全部通过：

```text
停止。
不能准备 Stage 2。
```

## 10. 绝对停止条件

出现任一情况立即停止：

```text
有人要求广播 Base 主网
有人要求使用真实资金
有人要求提供私钥、助记词或恢复词
有人要求跳过只读复查
有人要求跳过本批准表
有人要求把 Stage 1 批准当成 Stage 2/3 批准
有人要求 Stage 1 后不复核直接进入 Stage 2
预测地址和当前 nonce 不匹配
stage1AddressCollision=true
privateKeyPresent=true
```

## 11. 当前结论

```text
Stage 1 最终广播前人工批准表已准备
当前批准=待填
当前不是执行版
当前没有广播
当前没有部署
当前没有使用私钥
当前没有使用真实资金
```

## 12. 下一步建议

下一步仍然不是广播。

建议下一步只做：

```text
owner 人工阅读本批准表
如果 owner 想继续，再决定是否填写批准区
```
