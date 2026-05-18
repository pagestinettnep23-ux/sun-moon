# Base Sepolia rc3 Stage 1 执行版命令审阅清单 - 2026-05-18

本文是给 owner 和未来操作员看的“执行版命令出现前的最后审阅清单”。
本文不是执行版命令，不能复制到终端运行。

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

小白理解：

```text
这张清单的作用，是在真正出现“执行版命令”之前，先检查那条命令应该长什么样、不能包含什么。
它像上车前的安全检查表，不是油门。
```

## 1. 当前状态

```text
Base Sepolia Stage 1-only 人工批准=已形成
Stage 1 最终广播前只读检查=已通过
当前文档类型=审阅清单，不执行
当前没有广播
当前没有部署
当前没有使用私钥
当前没有使用真实资金
```

最近一次只读检查结果：

```text
Script ran successfully
chainId=84532
selectedStage=1
selectedStageTxs=12
stage1CoreDeploymentTxs=12
totalTransactionsPlanned=19
SEPOLIA_DEPLOYER nonce=16
broadcastAllowed=false
executionBlocked=true
simulationOnly=true
executeRequested=false
privateKeyPresent=false
stage1AddressCollision=false
stage2HookCollision=false
predictedSunTokenHasCode=false
predictedSunCurveHasCode=false
predictedMoonTokenHasCode=false
predictedMoonCurveHasCode=false
predictedCreate2HookDeployerHasCode=false
predictedHookHasCode=false
```

## 2. 本清单不提供什么

本文不提供可复制执行的终端命令。

本文不会提供：

```text
完整 forge broadcast 命令
cast send 命令
PRIVATE_KEY 非空写法
助记词写法
主网 RPC
真实资金操作步骤
```

如果有人把本文当成执行命令：

```text
停止。不能执行。必须回到人工复核。
```

## 3. 未来执行版命令只能覆盖什么

未来如果 owner 单独要求进入 Stage 1 执行版，最多只能覆盖下面 12 笔 Base Sepolia 测试网交易：

| 顺序 | 操作 | owner 复核 |
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

Stage 1 成功后，rc3 测试网演练仍未完成。Stage 2 和 Stage 3 必须另行批准。

## 4. 未来执行版命令必须满足的字段

未来如果真的准备执行版命令，owner 必须逐项检查：

| 检查项 | 必须是什么 |
| --- | --- |
| 网络 | Base Sepolia |
| chain id | `84532` |
| 目标阶段 | 只能是 `Stage 1` |
| 计划交易数 | 只能是 `12` |
| Stage 2 | 不允许 |
| Stage 3 | 不允许 |
| Base 主网 | 不允许 |
| 真实资金 | 不允许 |
| 私钥、助记词、恢复词 | 不允许出现在聊天、文档或命令文本里 |
| 签名动作 | 只能由操作员在自己的本地钱包环境里完成 |

## 5. 未来执行版命令必须禁止的内容

如果未来执行版命令里出现下面任意内容，立刻停止：

```text
Base 主网 RPC
chainId=8453
Stage 2
Stage 3
部署 Hook
绑定 SunCurve.moonAMM
设置 SUN/USDC 白名单
设置 MOON/USDC 白名单
建池
初始化池
加流动性
swap
renounce
真实资金
私钥明文
助记词
恢复词
```

## 6. 未来执行版命令出现前的最后确认

在真正写出执行版命令前，必须重新确认：

- [ ] 当前最新 commit 已记录。
- [ ] `frontend/` 等无关未跟踪目录不会被纳入本次操作。
- [ ] Stage 1 后复核清单已准备好。
- [ ] 最近一次只读检查仍显示 `selectedStage=1`。
- [ ] 最近一次只读检查仍显示 `selectedStageTxs=12`。
- [ ] 最近一次只读检查仍显示 `chainId=84532`。
- [ ] 最近一次只读检查仍显示 `SEPOLIA_DEPLOYER nonce=16`，或文档已按新 nonce 更新。
- [ ] 最近一次只读检查仍显示 `stage1AddressCollision=false`。
- [ ] 最近一次只读检查仍显示 `privateKeyPresent=false`。

任意一项不满足：

```text
停止。不能准备执行版命令。
```

## 7. 操作员必须理解的签名边界

Codex 不能做、也不会做：

```text
索要私钥
读取私钥
保存私钥
把私钥写进 .env
把私钥写进文档
把私钥写进聊天
让 owner 发送助记词或恢复词
```

如果未来真的执行测试网 Stage 1，签名只能发生在操作员自己的本地钱包环境里。
这个签名方式需要操作员自己确认安全，不能把私钥交给聊天、网站或文档。

## 8. Stage 1 成功后的第一件事

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

## 9. Owner 最后人工确认区

当前不填写执行确认，因为本文不是执行版。

未来如果 owner 要求继续，必须另行明确回复：

```text
我已读完 Stage 1 执行版命令审阅清单。
我确认下一步只准备 Base Sepolia 测试网 rc3 Stage 1 执行版命令。
我不批准 Stage 2。
我不批准 Stage 3。
我不批准 Base 主网。
我不批准真实资金操作。
我不会在聊天或文档里提供私钥、助记词或恢复词。
```

没有这条新的确认：

```text
停止。不准备执行版命令。
```

## 10. 当前结论

```text
Stage 1 执行版命令审阅清单已准备
当前仍不是执行版
当前没有广播
当前没有部署
当前没有使用私钥
当前没有使用真实资金
```

## 11. 下一步建议

下一步仍然不是广播。

建议下一步只做：

```text
owner 人工阅读本清单
确认是否只准备 Stage 1 执行版命令
在确认前，不生成可复制执行命令
```
