# Base Sepolia rc3 Stage 1 真正执行命令审阅版（不广播）- 2026-05-18

本文根据 owner 明确确认创建：

```text
我已阅读真正 Stage 1 广播前最终人工闸门。
请只准备 Base Sepolia 测试网 rc3 Stage 1 真正执行命令审阅版。
不广播。
不包含私钥。
不包含 --private-key。
不包含 Stage 2。
不包含 Stage 3。
不包含 Base 主网。
不使用真实资金。
```

重要：本文是审阅版，不是执行版。

本文不会被运行。
本文不广播、不部署、不需要私钥、不使用真实资金。

## 1. 当前状态

```text
真正执行命令审阅版=已准备
Base Sepolia Stage 1 广播执行=未批准
真正可运行执行命令=未生成
Base 主网广播=false
真实资金=false
私钥请求=false
当前文档类型=命令审阅版，不执行
```

小白理解：

```text
这一步只是把“未来如果真的执行，命令大概长什么样”写出来给你审阅。
它不是让你现在复制运行。
它里面不放私钥。
它不包含 --private-key。
```

## 2. 最近一次只读预检

进入本文前，已经完成 Base Sepolia rc3 Stage 1-only 只读预检。

关键结论：

```text
Script ran successfully
chainId=84532
stage1ExecutionConfirmed=true
executeRequested=false
privateKeyPresent=false
broadcastAllowed=false
executionBlocked=true
simulationOnly=true
stage1TransactionsPlanned=12
stage1CoreDeployerNonce=16
stage1AddressCollision=false
所有 DEPLOYED_* 均为零地址
```

人工结论：

```text
当前没有广播
当前没有部署
当前没有使用私钥
当前没有使用真实资金
当前预测地址没有代码冲突
```

## 3. 审阅版命令外形

下面不是执行命令。

它是未来真正执行命令的审阅版外形，保留了 `LOCAL_SIGNER_OPTION_PENDING_FINAL_REVIEW` 作为待填占位，所以不能直接复制运行。

```powershell
# REVIEW ONLY - DO NOT RUN
# Base Sepolia rc3 Stage 1 only
# No Base mainnet
# No real funds
# No private key in this file
# No private-key command-line flag
# Signer option is intentionally left pending final review

$env:CONFIRM_BASE_SEPOLIA_RC3_STAGE1_EXECUTION_DRAFT='1'
$env:EXECUTE_BASE_SEPOLIA_RC3_STAGE1='1'
$env:PRIVATE_KEY=''

forge script script/PrepareBaseSepoliaRc3Stage1ExecutionDraft.s.sol `
  --rpc-url https://sepolia.base.org `
  --rpc-timeout 120 `
  --slow `
  --sender 0x2F6E887c6058deE520f9468a1022E3480A6334D3 `
  --broadcast `
  LOCAL_SIGNER_OPTION_PENDING_FINAL_REVIEW
```

为什么它不能直接运行：

```text
它包含 REVIEW ONLY - DO NOT RUN。
它包含待填占位 LOCAL_SIGNER_OPTION_PENDING_FINAL_REVIEW。
它没有选择本地签名方式。
它没有经过最后一次只读复查。
它没有收到真正执行批准。
```

## 4. 签名方式边界

本文不选择签名方式。

未来如果真的进入测试网执行，签名只能发生在操作员自己的本地钱包环境中。

允许讨论的只是公开边界：

```text
执行钱包公开地址=0x2F6E887c6058deE520f9468a1022E3480A6334D3
网络=Base Sepolia
chainId=84532
阶段=Stage 1 only
```

禁止出现：

```text
私钥明文
助记词
恢复词
--private-key
把私钥写进聊天
把私钥写进文档
把私钥写进 .env
把私钥写进命令行
```

## 5. 命令字段人工检查

| 字段 | 审阅值 | 是否允许 |
| --- | --- | --- |
| 网络 | Base Sepolia | 允许 |
| chain id | `84532` | 允许 |
| RPC | `https://sepolia.base.org` | 允许 |
| 脚本 | `script/PrepareBaseSepoliaRc3Stage1ExecutionDraft.s.sol` | 允许 |
| 执行开关 | `EXECUTE_BASE_SEPOLIA_RC3_STAGE1='1'` | 只允许未来真正执行时使用 |
| 私钥环境变量 | `PRIVATE_KEY=''` | 允许，必须为空 |
| 执行钱包公开地址 | `0x2F6E887c6058deE520f9468a1022E3480A6334D3` | 允许，仅测试网 |
| 广播参数 | `--broadcast` | 只允许未来真正执行时使用 |
| 本地签名方式 | `LOCAL_SIGNER_OPTION_PENDING_FINAL_REVIEW` | 待填，不可执行 |
| `--private-key` | 不出现 | 必须不出现 |
| Base 主网 | 不出现 | 必须不出现 |
| Stage 2 | 不出现 | 必须不出现 |
| Stage 3 | 不出现 | 必须不出现 |
| 真实资金 | 不出现 | 必须不出现 |

人工确认：

- [ ] 我理解本文的命令外形不能直接复制运行。
- [ ] 我理解 `LOCAL_SIGNER_OPTION_PENDING_FINAL_REVIEW` 是故意保留的待填占位。
- [ ] 我理解 `PRIVATE_KEY=''` 必须保持为空。
- [ ] 我理解本文的命令外形没有使用 `--private-key`。
- [ ] 我理解本文仍不批准广播。

## 6. Stage 1 只允许 12 笔交易

未来如果真正执行，只允许下面 12 笔 Base Sepolia 测试网交易：

| 顺序 | 操作 |
| ---: | --- |
| 1 | Deploy `SunToken` |
| 2 | Deploy `SunCurve` |
| 3 | Deploy `MoonToken` |
| 4 | Deploy `MoonCurve` |
| 5 | Deploy `Create2HookDeployer` |
| 6 | `SunToken.setMinter(SunCurve)` |
| 7 | `SunCurve.setMoonCurve(MoonCurve)` |
| 8 | `MoonToken.setMinter(MoonCurve)` |
| 9 | `SunToken.transferOwnership(admin)` |
| 10 | `SunCurve.transferOwnership(admin)` |
| 11 | `MoonToken.transferOwnership(admin)` |
| 12 | `MoonCurve.transferOwnership(admin)` |

## 7. Stage 1 明确不包含

未来命令如果混入以下任意内容，立即停止：

```text
Stage 2
Stage 3
Base 主网
真实资金
部署 Hook
绑定 SunCurve.moonAMM
设置 SUN/USDC 白名单
设置 MOON/USDC 白名单
建池
初始化池
添加流动性
swap
renounce
私钥明文
助记词
恢复词
--private-key
```

## 8. 未来真正执行前必须再做什么

本文完成后，仍然不能广播。

如果 owner 后续想继续，只能先做：

```text
重新跑 Base Sepolia Stage 1-only 最终只读复查
确认 chainId=84532
确认 stage1CoreDeployerNonce 仍为预期值
确认 stage1AddressCollision=false
确认 privateKeyPresent=false
确认 DEPLOYED_* 全部仍为零地址
确认当前 commit 已记录
确认真正可运行命令仍不包含 --private-key
```

任一项不通过：

```text
停止。
不准备真正可运行执行命令。
不广播。
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
停止。
不能准备 Stage 2。
```

## 10. 下一步确认语句

如果 owner 想继续，下一步也仍然不是广播。

下一步只能明确要求：

```text
我已阅读 Base Sepolia rc3 Stage 1 真正执行命令审阅版。
请只跑最终执行前只读复查。
不广播。
不包含私钥。
不包含 --private-key。
不包含 Stage 2。
不包含 Stage 3。
不包含 Base 主网。
不使用真实资金。
```

没有这条明确确认：

```text
停止。
不跑最终执行前只读复查。
不准备真正可运行命令。
不广播。
```

## 11. 当前结论

```text
Base Sepolia rc3 Stage 1 真正执行命令审阅版=已准备
当前不是可运行执行命令
当前没有广播
当前没有部署
当前没有使用私钥
当前没有使用真实资金
当前没有进入 Stage 2
当前没有进入 Stage 3
当前没有进入 Base 主网
下一步只能由 owner 决定是否跑最终执行前只读复查
```
