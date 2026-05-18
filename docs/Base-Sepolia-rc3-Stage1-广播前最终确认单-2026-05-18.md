# Base Sepolia rc3 Stage 1 广播前最终确认单 - 2026-05-18

本文是给 owner 在未来决定是否进入 Base Sepolia 测试网 Stage 1 前看的最终确认单。

它不是广播批准，也不是主网计划。

固定边界：

```text
不广播 Base 主网
不使用真实资金
不索要私钥
不把预测地址当成已部署地址
不把 Stage 1 批准当成 Stage 2/3 批准
```

## 1. 当前结论

截至本文创建时：

```text
Stage 1=未广播
Stage 2=未广播
Stage 3=未广播
Base 主网广播=false
真实资金=false
私钥请求=false
```

小白理解：

```text
现在只是准备确认单。
你还没有批准测试网 Stage 1。
更没有批准 Stage 2、Stage 3 或主网。
```

## 2. Stage 1 到底做什么

Stage 1 只做测试版核心合约部署和基础配置。

预计 12 笔测试网交易：

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

人工确认：

- [ ] 我理解 Stage 1 是测试网核心合约部署。
- [ ] 我理解 Stage 1 预计 12 笔交易。
- [ ] 我理解 Stage 1 成功后，rc3 测试网演练仍未完成。

## 3. Stage 1 明确不会做什么

Stage 1 不包含：

```text
不部署 Hook
不绑定 SunCurve.moonAMM
不设置 SUN/USDC 白名单
不设置 MOON/USDC 白名单
不创建项目支持池
不初始化项目支持池
不添加流动性
不 swap
不 renounce Hook owner
不碰 Base 主网
```

人工确认：

- [ ] 我理解 Stage 1 不部署 Hook。
- [ ] 我理解 Stage 1 不建池、不初始化池、不加流动性。
- [ ] 我理解 Stage 1 不 swap。
- [ ] 我理解 Stage 1 不 renounce。
- [ ] 我理解 Stage 1 不碰 Base 主网。

## 4. 测试网公开地址确认

这些是公开地址，可以写进文档，不是私钥。

| 项目 | 地址 |
| --- | --- |
| Stage 1 测试网部署钱包 | `0x2F6E887c6058deE520f9468a1022E3480A6334D3` |
| 测试网临时管理员钱包 | `0x6E22b2e6fFAA30Fe75B71d53d1eC469b4e97A986` |
| 测试网协议经费收款钱包 | `0x277ba3Cf597CdAaF958C301db3cF6a631F793039` |
| 测试网 CREATE2 deployer owner | `0x6E22b2e6fFAA30Fe75B71d53d1eC469b4e97A986` |
| Base Sepolia USDC | `0x036CbD53842c5426634e7929541eC2318f3dCF7e` |

人工确认：

- [ ] 我确认这些是 Base Sepolia 测试网公开地址。
- [ ] 我确认这些不是 Base 主网地址。
- [ ] 我确认不会在聊天或文档里提供私钥、助记词或恢复词。

## 5. 最近一次只读检查结果

最近一次 Base Sepolia fork 只读复查结果：

```text
script_result=Script ran successfully
chainId=84532
broadcastAllowed=false
executionBlocked=true
simulationOnly=true
executeRequested=false
privateKeyPresent=false
stage1CoreDeploymentTxs=12
stage2HookAndPoolTxs=6
stage3RenounceTxs=1
totalTransactionsPlanned=19
stage1AddressCollision=false
stage2HookCollision=false
```

人工确认：

- [ ] 我确认最近一次只读检查通过。
- [ ] 我确认只读检查没有广播。
- [ ] 我确认 `privateKeyPresent=false`。
- [ ] 我确认 `executionBlocked=true`。

## 6. 当前预测地址

这些是预测地址，不是已经部署地址。

| 合约 | 当前预测地址 |
| --- | --- |
| `SunToken` | `0xb5287fBbAD0e25B12f18497209fDac7e0ACf7293` |
| `SunCurve` | `0xe8D048aB83727419b00F4e30F4898C6B3bB91aD4` |
| `MoonToken` | `0x92dC3B8056cA62A7dbc5c1C339891B45463bEe71` |
| `MoonCurve` | `0x095c91aB279121300Ac16c57D1ecebB9ceEa1cd8` |
| `Create2HookDeployer` | `0x6E34D98e1925eaf6680941213E49741b8764DdfE` |

预测前提：

```text
Stage 1 部署钱包 nonce=16
Stage 1 第一笔交易前，部署钱包不能先发其他交易
如果 nonce 变化，上面预测地址可能变化
```

人工确认：

- [ ] 我确认这些地址只是预测地址。
- [ ] 我确认 Stage 1 前必须再次检查部署钱包 nonce。
- [ ] 我确认如果 nonce 变化，必须停止并更新预测地址。
- [ ] 我确认不能把预测地址宣传成已部署地址。

## 7. Stage 1 前最后必须再跑的只读检查

未来如果 owner 想进入 Stage 1，必须先重新跑：

```powershell
$env:CONFIRM_BASE_SEPOLIA_RC3_STAGED_BROADCAST_DRAFT="1"
$env:BASE_SEPOLIA_RC3_BROADCAST_STAGE="0"
$env:EXECUTE_BASE_SEPOLIA_RC3_STAGE="0"
$env:PRIVATE_KEY=""
forge script script/PrepareBaseSepoliaRc3SunMoonUsdcStagedBroadcastDraft.s.sol --rpc-url https://sepolia.base.org --rpc-timeout 120 --slow
```

期望看到：

```text
Script ran successfully
chainId=84532
broadcastAllowed=false
executionBlocked=true
privateKeyPresent=false
stage1AddressCollision=false
```

人工确认：

- [ ] 我确认 Stage 1 前还要重新跑只读检查。
- [ ] 我确认这条检查命令不加 `--broadcast`。
- [ ] 我确认这条检查命令不需要私钥。

## 8. Stage 1 批准边界

如果未来 owner 批准，也只能批准这一句话：

```text
只允许 Base Sepolia 测试网 Stage 1 广播。
不允许 Stage 2。
不允许 Stage 3。
不允许 Base 主网。
不允许真实资金。
不在聊天里提供私钥。
```

人工确认：

- [ ] 我确认 Stage 1 批准不等于 Stage 2 批准。
- [ ] 我确认 Stage 1 批准不等于 Stage 3 批准。
- [ ] 我确认测试网批准不等于主网批准。
- [ ] 我确认真正广播只能由本地钱包/本地环境执行，不能把私钥发给任何人。

## 9. Stage 1 后必须做什么

如果未来 Stage 1 真的广播成功，下一步不是 Stage 2。

下一步必须先做：

```text
Stage 1 广播后复核
```

使用这份文档：

```text
docs/Base-Sepolia-rc3-Stage1-广播后复核清单草案-2026-05-18.md
```

人工确认：

- [ ] 我确认 Stage 1 成功后必须先复核 12 笔交易。
- [ ] 我确认 Stage 1 成功后不能直接进入 Stage 2。
- [ ] 我确认如果任一复核项不通过，必须停止。

## 10. 绝对停止条件

出现任一情况，立即停止：

```text
命令指向 Base 主网
有人要求广播 Base 主网
有人要求使用真实资金
有人要求提供私钥、助记词或恢复词
有人把预测地址说成已部署地址
部署钱包 nonce 已变化但文档没有更新
只读检查不是 chainId=84532
只读检查出现 privateKeyPresent=true
只读检查出现 stage1AddressCollision=true
有人要求跳过 Stage 1 后复核直接进入 Stage 2
```

## 11. Owner 最终签字区

当前不填写，因为现在没有批准广播。

| 项目 | 结果 |
| --- | --- |
| 是否批准 Base Sepolia Stage 1 广播 | 待填 |
| 是否明确不批准 Stage 2 | 待填 |
| 是否明确不批准 Stage 3 | 待填 |
| 是否明确不批准 Base 主网 | 待填 |
| 日期 | 待填 |
| 备注 | 待填 |

## 12. 下一步建议

下一步仍然不是广播。

建议下一步只做：

```text
Stage 1 操作员执行说明草案已经准备完成：
docs/Base-Sepolia-rc3-Stage1-操作员执行说明草案-2026-05-18.md

owner 人工阅读本确认单和操作员执行说明草案
如果仍想继续，再重新跑 Base Sepolia fork 只读检查
然后再单独讨论是否需要准备 Stage 1 广播指令草案
```
