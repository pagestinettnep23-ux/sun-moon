# Base Sepolia rc3 Stage 1 广播指令草案（非执行版） - 2026-05-18

本文是 Stage 1 测试网广播指令的草案说明。

它不是广播批准，不是可复制执行的广播命令，也不是主网计划。

固定边界：

```text
不广播 Base 主网
不使用真实资金
不索要私钥
不把预测地址当成已部署地址
不从本文直接执行 Stage 1 广播
```

## 1. 当前状态

截至本文创建时：

```text
Stage 1=未广播
Stage 2=未广播
Stage 3=未广播
Base 主网广播=false
真实资金=false
私钥请求=false
```

当前分阶段脚本状态：

```text
broadcastAllowed=false
executionBlocked=true
```

小白理解：

```text
现在还没有真正的广播命令。
现在只有“如果未来要广播，必须满足哪些条件”的草案。
这份文档不能拿去直接发交易。
```

## 2. 为什么叫非执行版

因为当前脚本仍然是安全锁住的草案。

当前脚本只允许生成计划和做只读检查：

```text
可以检查 chainId
可以检查预测地址
可以检查 nonce
可以检查 stage1AddressCollision
不允许真正广播
```

本文不会提供：

```text
不提供 forge script ... --broadcast 命令
不提供 cast send 命令
不提供 PRIVATE_KEY 非空写法
不提供任何主网命令
```

## 3. Stage 1 未来如果广播，会做什么

Stage 1 未来如果被 owner 单独批准，只能做 12 笔 Base Sepolia 测试网交易：

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

Stage 1 不能包含：

```text
不能部署 Hook
不能建池
不能初始化池
不能添加流动性
不能 swap
不能 renounce Hook owner
不能进入 Stage 2
不能进入 Stage 3
不能触碰 Base 主网
```

## 4. 广播前必须满足的条件

未来只有全部满足，才可以准备真正的 Stage 1 广播指令。

- [ ] owner 已人工阅读 `docs/Base-Sepolia-rc3-Stage1-广播前最终确认单-2026-05-18.md`。
- [ ] owner 已人工阅读 `docs/Base-Sepolia-rc3-Stage1-操作员执行说明草案-2026-05-18.md`。
- [ ] owner 明确只批准 Base Sepolia 测试网 Stage 1。
- [ ] owner 明确不批准 Stage 2。
- [ ] owner 明确不批准 Stage 3。
- [ ] owner 明确不批准 Base 主网。
- [ ] 已重新跑 Base Sepolia fork 只读检查。
- [ ] `chainId=84532`。
- [ ] `privateKeyPresent=false`。
- [ ] `stage1AddressCollision=false`。
- [ ] `SEPOLIA_DEPLOYER nonce=16`，或文档已按新 nonce 全部更新。
- [ ] 当前 git 工作区没有未提交的合约或脚本改动。
- [ ] Stage 1 广播后复核清单已准备好。

任一项不满足：

```text
停止。
不能准备最终广播指令。
```

## 5. 广播前只读检查命令

当前仍只允许执行下面的只读检查：

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
stage1CoreDeploymentTxs=12
stage1AddressCollision=false
```

## 6. 当前预测地址

最近一次只读检查结果：

```text
SEPOLIA_DEPLOYER nonce=16
PREDICTED_SUN_TOKEN=0xb5287fBbAD0e25B12f18497209fDac7e0ACf7293
PREDICTED_SUN_CURVE=0xe8D048aB83727419b00F4e30F4898C6B3bB91aD4
PREDICTED_MOON_TOKEN=0x92dC3B8056cA62A7dbc5c1C339891B45463bEe71
PREDICTED_MOON_CURVE=0x095c91aB279121300Ac16c57D1ecebB9ceEa1cd8
PREDICTED_CREATE2_HOOK_DEPLOYER=0x6E34D98e1925eaf6680941213E49741b8764DdfE
```

说明：

```text
这些仍然只是预测地址。
它们不是已经部署地址。
如果部署钱包 nonce 变化，预测地址可能变化。
```

## 7. 未来最终广播指令必须另写

如果 owner 未来明确批准 Stage 1，下一步不是直接使用本文广播。

必须另写一份：

```text
Base Sepolia rc3 Stage 1 最终广播指令
```

那份最终指令必须至少包含：

```text
明确 owner 批准语句
明确只允许 Base Sepolia Stage 1
明确不允许 Stage 2/3
明确不允许 Base 主网
明确不收集、不展示、不记录私钥
明确操作员本地签名方式
明确 12 笔交易执行顺序
明确每笔交易哈希记录位置
明确广播后第一步是 Stage 1 后复核
```

## 8. 最终指令不能包含什么

未来最终指令也不能包含：

```text
不能包含私钥
不能包含助记词
不能包含恢复词
不能包含 Base 主网 RPC
不能包含真实资金操作
不能包含 Stage 2 或 Stage 3 交易
不能包含添加流动性或 swap
```

## 9. 广播后必须立即做什么

如果未来 Stage 1 真的广播成功，第一件事不是进入 Stage 2。

第一件事是使用：

```text
docs/Base-Sepolia-rc3-Stage1-广播后复核清单草案-2026-05-18.md
```

必须记录：

```text
12 笔交易哈希
每笔 receipt status
5 个核心合约 code
owner/minter/曲线配置
Stage 1 后仍未部署 Hook
Stage 1 后仍未建池、未加流动性、未 swap、未 renounce
```

## 10. 绝对停止条件

出现任一情况，立即停止：

```text
有人要求提供私钥、助记词或恢复词
有人要求使用真实资金
命令指向 Base 主网
命令包含 Stage 2 或 Stage 3
命令包含添加流动性或 swap
没有 owner 单独批准 Stage 1
只读检查不是 chainId=84532
privateKeyPresent=true
stage1AddressCollision=true
SEPOLIA_DEPLOYER nonce 与文档不一致且未更新
有人把预测地址说成已经部署地址
```

## 11. 非执行版后只读复查

2026-05-18 已按本文要求重新跑 Base Sepolia fork 只读检查。

复查结果：

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

结论：

```text
非执行版后的只读复查已通过
仍未允许测试网广播
仍未允许主网广播
未部署
未使用私钥
未使用真实资金
```

Foundry WARN 说明：

```text
命令输出中的 Foundry WARN 是源码 trace/cache/etherscan 信息提示。
最终判断以 Script ran successfully 和安全开关输出为准。
```

## 12. 下一步建议

下一步仍然不是广播。

建议下一步只做：

```text
owner 人工复核本非执行版广播指令草案和本次只读复查结果
然后再决定是否需要准备“Stage 1 最终广播指令”
```
