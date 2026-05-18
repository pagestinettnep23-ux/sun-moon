# Base Sepolia rc3 Stage 1 执行版命令草案（不广播）- 2026-05-18

本文根据 owner 当前指令创建：

```text
只准备 Stage 1 执行版命令草案，不广播。
```

本文是草案，不是执行。
本文不广播、不部署、不需要私钥、不使用真实资金。

固定边界：

```text
不广播 Base 主网
不使用真实资金
不索要私钥、助记词或恢复词
不在聊天、文档或代码里记录私钥
不执行 Stage 2
不执行 Stage 3
不部署 Hook
不建池、不加流动性、不 swap
不 renounce
```

## 1. 当前关键判断

当前脚本仍然是安全草案脚本，不是可广播脚本：

```text
script/PrepareBaseSepoliaRc3SunMoonUsdcStagedBroadcastDraft.s.sol
```

代码层安全边界：

```text
broadcastAllowed=false
executionBlocked=true
simulationOnly=true
如果 EXECUTE_BASE_SEPOLIA_RC3_STAGE=1，脚本会 revert
如果 PRIVATE_KEY 非空，脚本会 revert
当前脚本不调用 startBroadcast
```

所以，当前不能把这份脚本当成真正执行版。
本文件只能记录“未来执行版应该长什么样”和“现在允许复核什么”。

## 2. 本轮允许出现的命令

本轮只允许准备只读复核命令。
这条命令不广播，只用于确认 Stage 1 的 12 笔计划和安全开关。

```powershell
$env:CONFIRM_BASE_SEPOLIA_RC3_STAGED_BROADCAST_DRAFT='1'
$env:BASE_SEPOLIA_RC3_BROADCAST_STAGE='1'
$env:EXECUTE_BASE_SEPOLIA_RC3_STAGE='0'
$env:PRIVATE_KEY=''
forge script script/PrepareBaseSepoliaRc3SunMoonUsdcStagedBroadcastDraft.s.sol --rpc-url https://sepolia.base.org --rpc-timeout 120 --slow
```

这条命令的预期结果必须包含：

```text
Script ran successfully
chainId=84532
selectedStage=1
selectedStageTxs=12
stage1CoreDeploymentTxs=12
broadcastAllowed=false
executionBlocked=true
simulationOnly=true
executeRequested=false
privateKeyPresent=false
stage1AddressCollision=false
```

如果结果不同：

```text
停止。不准备真正执行版。
```

## 3. 未来真正执行版不能直接复用当前脚本

未来如果要真正执行 Base Sepolia rc3 Stage 1，不能直接把当前 staged draft 脚本改个环境变量就运行。

原因：

```text
当前脚本明确拒绝 EXECUTE_BASE_SEPOLIA_RC3_STAGE=1
当前脚本明确拒绝 PRIVATE_KEY 非空
当前脚本固定 broadcastAllowed=false
当前脚本固定 executionBlocked=true
当前脚本只用于 dry-run / review
```

未来真正执行版必须另行准备、另行审阅、另行批准。
在新的执行版脚本或命令出现前，不能广播。

## 4. 未来真正执行版必须满足的字段

未来真正执行版如果被单独准备，必须满足：

| 字段 | 必须值 |
| --- | --- |
| 网络 | Base Sepolia |
| chain id | `84532` |
| 阶段 | 只允许 Stage 1 |
| 计划交易数 | 只能是 12 |
| 执行钱包公开地址 | `0x2F6E887c6058deE520f9468a1022E3480A6334D3`，仅测试网 |
| 测试网管理员公开地址 | `0x6E22b2e6fFAA30Fe75B71d53d1eC469b4e97A986`，仅测试网 |
| 测试网协议经费公开地址 | `0x277ba3Cf597CdAaF958C301db3cF6a631F793039`，仅测试网 |
| Base 主网 | 不允许 |
| Stage 2 | 不允许 |
| Stage 3 | 不允许 |
| 真实资金 | 不允许 |
| 私钥、助记词、恢复词 | 不允许出现在聊天、文档或命令文本里 |

## 5. 未来真正执行版最多只能做的 12 笔交易

| 顺序 | 操作 | 是否允许进入 Stage 1 |
| ---: | --- | --- |
| 1 | Deploy `SunToken` | 允许 |
| 2 | Deploy `SunCurve` | 允许 |
| 3 | Deploy `MoonToken` | 允许 |
| 4 | Deploy `MoonCurve` | 允许 |
| 5 | Deploy `Create2HookDeployer` | 允许 |
| 6 | `SunToken.setMinter(SunCurve)` | 允许 |
| 7 | `SunCurve.setMoonCurve(MoonCurve)` | 允许 |
| 8 | `MoonToken.setMinter(MoonCurve)` | 允许 |
| 9 | `SunToken.transferOwnership(admin)` | 允许 |
| 10 | `SunCurve.transferOwnership(admin)` | 允许 |
| 11 | `MoonToken.transferOwnership(admin)` | 允许 |
| 12 | `MoonCurve.transferOwnership(admin)` | 允许 |

Stage 1 之外的任何动作都不允许混入。

## 6. 未来真正执行版必须禁止的内容

如果未来命令或脚本出现以下任意内容，立即停止：

```text
Base 主网
chainId=8453
Stage 2
Stage 3
部署 Hook
绑定 SunCurve.moonAMM
设置 SUN/USDC 白名单
设置 MOON/USDC 白名单
创建池
初始化池
添加流动性
swap
renounce
真实资金
私钥明文
助记词
恢复词
```

## 7. 签名边界

Codex 不会做以下事情：

```text
索要私钥
读取私钥
保存私钥
把私钥写进 .env
把私钥写进文档
把私钥写进聊天
让 owner 发送助记词或恢复词
```

未来如果真的广播测试网 Stage 1，签名只能发生在操作员自己的本地钱包环境中。
本文件不记录任何签名秘密。

## 8. 未来真正执行版出现前的最后人工确认

未来真正执行版出现前，owner 必须再次明确确认：

```text
我已阅读 Stage 1 执行版命令草案（不广播）。
我确认下一步只准备 Base Sepolia 测试网 rc3 Stage 1 真正执行版。
我不批准 Stage 2。
我不批准 Stage 3。
我不批准 Base 主网。
我不批准真实资金操作。
我不会在聊天或文档里提供私钥、助记词或恢复词。
```

没有这条新的确认：

```text
停止。不准备真正执行版。
```

## 9. Stage 1 如果未来成功后的第一件事

如果未来 Stage 1 真的广播成功，第一件事不是 Stage 2。

第一件事必须是：

```text
填写 12 笔交易 hash
检查 12 笔交易 receipt status
执行 Stage 1 广播后复核清单
```

必须使用：

```text
docs/Base-Sepolia-rc3-Stage1-广播后复核清单草案-2026-05-18.md
```

Stage 1 后复核没有全部通过：

```text
停止。不能准备 Stage 2。
```

## 10. 当前结论

```text
Stage 1 执行版命令草案（不广播）已准备
当前只提供不广播的只读复核命令
当前不提供真正广播命令
当前没有广播
当前没有部署
当前没有使用私钥
当前没有使用真实资金
```

## 11. 下一步建议

下一步仍然不是广播。

建议下一步只做：

```text
owner 人工阅读本草案
决定是否只准备真正 Stage 1 执行版脚本/命令
在新的明确确认前，不生成真正广播命令
```
