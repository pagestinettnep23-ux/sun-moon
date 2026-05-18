# Base Sepolia rc3 Stage 1 最终广播指令草案（审阅版，不执行） - 2026-05-18

本文是给 owner 和未来操作员看的“最终广播指令草案审阅版”。

它不是广播批准，不是执行版命令，也不能直接复制到终端运行。

固定边界：

```text
不广播 Base 主网
不使用真实资金
不索要私钥、助记词或恢复词
不在聊天、文档或代码里记录私钥
不执行 Stage 2 或 Stage 3
不建池、不加流动性、不 swap
```

小白理解：

```text
这份文档是在真正广播前，让你先看清楚“未来如果执行，最多只能做什么、不能做什么”。
现在仍然不发交易。
现在仍然不需要任何私钥。
```

## 1. 当前状态

```text
Base Sepolia 测试网广播=false
Base 主网广播=false
真实资金=false
私钥请求=false
当前文档类型=审阅版，不执行
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

## 2. 这份审阅版不提供什么

本文不提供可直接执行的命令。

本文不会提供：

```text
完整 forge broadcast 命令
cast send 命令
PRIVATE_KEY 非空写法
助记词写法
主网 RPC
真实资金操作
```

如果有人把本文当成执行命令：

```text
停止。
重新回到人工复核。
```

## 3. Stage 1 未来如果执行，只能做什么

Stage 1 未来如果被 owner 单独批准，只能做测试版核心合约部署和基础配置。

预计 12 笔 Base Sepolia 测试网交易：

| 顺序 | 操作 | 小白解释 |
| ---: | --- | --- |
| 1 | Deploy `SunToken` | 部署 SUN 测试版代币 |
| 2 | Deploy `SunCurve` | 部署 SUN 曲线 |
| 3 | Deploy `MoonToken` | 部署 MOON 测试版代币 |
| 4 | Deploy `MoonCurve` | 部署 MOON 曲线 |
| 5 | Deploy `Create2HookDeployer` | 部署以后用来部署 Hook 的工具 |
| 6 | `SunToken.setMinter(SunCurve)` | 允许 SunCurve 铸造 SUN |
| 7 | `SunCurve.setMoonCurve(MoonCurve)` | 让 SunCurve 认识 MoonCurve |
| 8 | `MoonToken.setMinter(MoonCurve)` | 允许 MoonCurve 铸造 MOON |
| 9 | `SunToken.transferOwnership(admin)` | 把 SUN 管理权交给测试网管理员 |
| 10 | `SunCurve.transferOwnership(admin)` | 把 SunCurve 管理权交给测试网管理员 |
| 11 | `MoonToken.transferOwnership(admin)` | 把 MOON 管理权交给测试网管理员 |
| 12 | `MoonCurve.transferOwnership(admin)` | 把 MoonCurve 管理权交给测试网管理员 |

Stage 1 完成后仍然没有完成 rc3 全流程。

## 4. Stage 1 明确不能做什么

即使未来 owner 批准 Stage 1，也不能做下面这些事：

```text
不能部署 Hook
不能绑定 SunCurve.moonAMM
不能设置 SUN/USDC 白名单
不能设置 MOON/USDC 白名单
不能创建项目支持池
不能初始化项目支持池
不能添加流动性
不能 swap
不能 renounce Hook owner
不能执行 Stage 2
不能执行 Stage 3
不能碰 Base 主网
不能使用真实资金
不能要求 owner 提供私钥
```

## 5. 公开参数

这些是公开地址，可以写进文档，不是私钥。

| 项目 | 值 |
| --- | --- |
| 网络 | Base Sepolia |
| chain-id | `84532` |
| Stage 1 执行钱包公开地址 | `0x2F6E887c6058deE520f9468a1022E3480A6334D3` |
| 测试网管理员公开地址 | `0x6E22b2e6fFAA30Fe75B71d53d1eC469b4e97A986` |
| 测试网协议经费公开地址 | `0x277ba3Cf597CdAaF958C301db3cF6a631F793039` |
| Base Sepolia PoolManager | `0x05E73354cFDd6745C338b50BcFDfA3Aa6fA03408` |
| Base Sepolia StateView | `0x571291b572ed32ce6751a2Cb2486EbEe8DEfB9B4` |
| Base Sepolia USDC | `0x036CbD53842c5426634e7929541eC2318f3dCF7e` |

预测地址：

```text
PREDICTED_SUN_TOKEN=0xb5287fBbAD0e25B12f18497209fDac7e0ACf7293
PREDICTED_SUN_CURVE=0xe8D048aB83727419b00F4e30F4898C6B3bB91aD4
PREDICTED_MOON_TOKEN=0x92dC3B8056cA62A7dbc5c1C339891B45463bEe71
PREDICTED_MOON_CURVE=0x095c91aB279121300Ac16c57D1ecebB9ceEa1cd8
PREDICTED_CREATE2_HOOK_DEPLOYER=0x6E34D98e1925eaf6680941213E49741b8764DdfE
```

重要提醒：

```text
上面是预测地址，不是已部署地址。
如果部署钱包 nonce 变化，预测地址可能变化。
```

## 6. 真正执行版出现前，必须重新确认

未来如果 owner 想从审阅版进入真正执行版，必须先重新跑只读检查。

必须同时满足：

- [ ] `Script ran successfully`。
- [ ] `chainId=84532`。
- [ ] `SEPOLIA_DEPLOYER nonce=16`，或文档已按新 nonce 更新。
- [ ] `broadcastAllowed=false`。
- [ ] `executionBlocked=true`。
- [ ] `privateKeyPresent=false`。
- [ ] `stage1AddressCollision=false`。
- [ ] `stage2HookCollision=false`。
- [ ] 当前 git commit 已记录。
- [ ] `git status` 没有未解释的合约或脚本改动。

任一项不满足：

```text
停止。
不能准备执行版。
```

## 7. Owner 批准语句必须单独填写

当前不填写批准，因为现在没有广播。

未来如果 owner 决定批准测试网 Stage 1，批准语句必须单独、清楚、完整：

```text
我只批准 Base Sepolia 测试网 rc3 Stage 1。
我不批准 Stage 2。
我不批准 Stage 3。
我不批准 Base 主网。
我不批准真实资金操作。
我不会在聊天或文档里提供私钥、助记词或恢复词。
```

如果批准语句不完整：

```text
停止。
不能准备执行版。
```

## 8. 操作员本地签名边界

未来如果真的进入执行版，签名只能发生在 owner 或操作员自己的本地钱包环境里。

Codex 不能做：

```text
不能索要私钥
不能读取私钥
不能保存私钥
不能把私钥写进 .env
不能把私钥写进命令
不能让 owner 把助记词发到聊天里
```

如果任何工具、网站、人员要求你提供私钥、助记词或恢复词：

```text
立即停止。
不要继续。
```

## 9. 未来执行版必须包含的记录区

执行版如果未来被单独准备，必须包含下面这些待填项：

| 项目 | 记录 |
| --- | --- |
| owner 是否批准 Base Sepolia Stage 1 | 待填 |
| owner 是否明确不批准 Stage 2 | 待填 |
| owner 是否明确不批准 Stage 3 | 待填 |
| owner 是否明确不批准 Base 主网 | 待填 |
| 操作员 | 待填 |
| 当前 commit | 待填 |
| 执行日期 | 待填 |
| Stage 1 交易 1 hash | 待填 |
| Stage 1 交易 2 hash | 待填 |
| Stage 1 交易 3 hash | 待填 |
| Stage 1 交易 4 hash | 待填 |
| Stage 1 交易 5 hash | 待填 |
| Stage 1 交易 6 hash | 待填 |
| Stage 1 交易 7 hash | 待填 |
| Stage 1 交易 8 hash | 待填 |
| Stage 1 交易 9 hash | 待填 |
| Stage 1 交易 10 hash | 待填 |
| Stage 1 交易 11 hash | 待填 |
| Stage 1 交易 12 hash | 待填 |

## 10. Stage 1 成功后第一件事

如果未来 Stage 1 真的广播成功，第一件事不是进入 Stage 2。

第一件事必须是：

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

## 11. 绝对停止条件

出现任一情况，立即停止：

```text
有人要求广播 Base 主网
有人要求使用真实资金
有人要求提供私钥、助记词或恢复词
有人要求跳过只读复查
有人要求跳过 owner 批准语句
有人要求把 Stage 1 批准当成 Stage 2/3 批准
有人要求 Stage 1 后不复核直接进入 Stage 2
预测地址和当前 nonce 不匹配
stage1AddressCollision=true
privateKeyPresent=true
```

## 12. 当前结论

```text
Stage 1 最终广播指令草案（审阅版，不执行）已准备
当前不是执行版
当前没有广播
当前没有部署
当前没有使用私钥
当前没有使用真实资金
```

## 13. 下一步建议

下一步仍然不是广播。

建议下一步只做：

```text
owner 人工阅读本审阅版
如果仍想继续，再决定是否准备 Stage 1 最终广播前人工批准表
```
