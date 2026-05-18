# Base Sepolia rc3 Stage 1 操作员执行说明草案 - 2026-05-18

本文是给未来“操作员”看的 Stage 1 执行说明草案。

它不是广播批准，也不包含广播命令。

固定边界：

```text
不广播 Base 主网
不使用真实资金
不索要私钥
不把预测地址当成已部署地址
不从本文直接执行测试网广播
```

## 1. 操作员是谁

操作员是未来坐在本地电脑前、按 owner 明确批准执行测试网步骤的人。

操作员可以做：

```text
读取公开文档
运行本地测试
运行 Base Sepolia fork 只读检查
记录公开地址、交易哈希和命令输出
```

操作员不可以做：

```text
向任何人索要私钥
把私钥、助记词或恢复词写进聊天、文档、截图
广播 Base 主网交易
使用真实 ETH 或真实 USDC
跳过 Stage 1 后复核直接进入 Stage 2
```

## 2. 当前状态

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
这份文档只是操作手册草案。
它不能单独授权任何广播。
真正广播必须以后由 owner 单独明确批准。
```

## 3. 操作员必须先读的文档

操作员在任何 Stage 1 真实测试网广播前，必须先读：

| 顺序 | 文档 | 用途 |
| ---: | --- | --- |
| 1 | `docs/Base-Sepolia-rc3-Stage1-广播前最终确认单-2026-05-18.md` | owner 按钮前确认单 |
| 2 | `docs/Base-Sepolia-rc3-Stage1-测试网广播草案-2026-05-18.md` | Stage 1 12 笔交易说明 |
| 3 | `docs/Base-Sepolia-rc3-Stage1-广播后复核清单草案-2026-05-18.md` | Stage 1 成功后复核表 |
| 4 | `docs/Base-Sepolia-rc3-Stage1-2-3-总闸门清单-2026-05-18.md` | 三阶段总闸门 |

人工确认：

- [ ] 操作员已读完上面 4 份文档。
- [ ] 操作员理解本文不是广播批准。
- [ ] 操作员理解 Stage 1 批准不等于 Stage 2/3 批准。

## 4. Stage 1 会做什么

Stage 1 未来如果被单独批准，只做测试版核心合约部署和基础配置。

预计 12 笔测试网交易：

```text
1. Deploy SunToken
2. Deploy SunCurve
3. Deploy MoonToken
4. Deploy MoonCurve
5. Deploy Create2HookDeployer
6. SunToken.setMinter(SunCurve)
7. SunCurve.setMoonCurve(MoonCurve)
8. MoonToken.setMinter(MoonCurve)
9. SunToken.transferOwnership(admin)
10. SunCurve.transferOwnership(admin)
11. MoonToken.transferOwnership(admin)
12. MoonCurve.transferOwnership(admin)
```

Stage 1 不做：

```text
不部署 Hook
不设置池白名单
不初始化池
不添加流动性
不 swap
不 renounce Hook owner
不碰 Base 主网
```

## 5. 当前只允许执行的命令

当前只允许执行只读检查。

### 5.1 查看 git 状态

```powershell
git status --short
git log -1 --oneline
```

期望：

```text
没有未提交的合约或脚本改动
如果只有 frontend/ 未跟踪，可以记录为已知未跟踪目录
```

### 5.2 重新跑 Base Sepolia fork 只读检查

```powershell
$env:CONFIRM_BASE_SEPOLIA_RC3_STAGED_BROADCAST_DRAFT="1"
$env:BASE_SEPOLIA_RC3_BROADCAST_STAGE="0"
$env:EXECUTE_BASE_SEPOLIA_RC3_STAGE="0"
$env:PRIVATE_KEY=""
forge script script/PrepareBaseSepoliaRc3SunMoonUsdcStagedBroadcastDraft.s.sol --rpc-url https://sepolia.base.org --rpc-timeout 120 --slow
```

期望：

```text
Script ran successfully
chainId=84532
broadcastAllowed=false
executionBlocked=true
simulationOnly=true
executeRequested=false
privateKeyPresent=false
stage1CoreDeploymentTxs=12
stage1AddressCollision=false
```

### 5.3 只读检查部署钱包 nonce

```powershell
cast nonce 0x2F6E887c6058deE520f9468a1022E3480A6334D3 --rpc-url https://sepolia.base.org
```

期望：

```text
nonce=16
```

如果 nonce 不是 `16`：

```text
停止。
重新跑只读检查。
更新预测地址和所有相关文档。
```

## 6. 当前禁止执行的命令

当前禁止执行任何广播命令。

禁止：

```text
forge script ... --broadcast
cast send ...
任何带 Base 主网 RPC 的命令
任何 PRIVATE_KEY 非空的命令
任何会消耗真实 ETH 或真实 USDC 的命令
```

特别说明：

```text
本文不提供 Stage 1 广播命令。
如果 owner 未来明确批准测试网 Stage 1，必须另写一份“Stage 1 广播指令草案”，并再次人工复核。
```

## 7. 如果未来 owner 批准 Stage 1

未来 owner 的批准必须写清楚：

```text
只允许 Base Sepolia 测试网 Stage 1 广播。
不允许 Stage 2。
不允许 Stage 3。
不允许 Base 主网。
不允许真实资金。
不在聊天里提供私钥。
```

即使 owner 批准 Stage 1，操作员也必须先完成：

- [ ] 重新跑 Base Sepolia fork 只读检查。
- [ ] 确认 `chainId=84532`。
- [ ] 确认 `privateKeyPresent=false`。
- [ ] 确认 `stage1AddressCollision=false`。
- [ ] 确认部署钱包 nonce 与预测地址一致。
- [ ] 确认 owner 批准只覆盖 Stage 1。
- [ ] 确认已经准备好 Stage 1 广播后复核清单。

## 8. 操作员记录模板

当前先记录只读检查。

| 项目 | 记录 |
| --- | --- |
| 日期 | 待填 |
| 操作员 | 待填 |
| 当前 commit | 待填 |
| git status | 待填 |
| chainId | 待填 |
| deployer nonce | 待填 |
| privateKeyPresent | 待填 |
| broadcastAllowed | 待填 |
| executionBlocked | 待填 |
| stage1AddressCollision | 待填 |
| predicted SunToken | 待填 |
| predicted SunCurve | 待填 |
| predicted MoonToken | 待填 |
| predicted MoonCurve | 待填 |
| predicted Create2HookDeployer | 待填 |

说明：

```text
这些记录都是公开信息。
不要记录私钥、助记词、恢复词。
```

## 9. Stage 1 广播后第一件事

如果未来 Stage 1 真的广播成功，第一件事不是 Stage 2。

第一件事是填写并执行：

```text
docs/Base-Sepolia-rc3-Stage1-广播后复核清单草案-2026-05-18.md
```

必须确认：

```text
12 笔交易都有交易哈希
12 笔交易 receipt status 都是 1
5 个核心合约 code 都不是 0x
owner/minter/曲线配置正确
Stage 1 后仍未部署 Hook
Stage 1 后仍未建池、未加流动性、未 swap、未 renounce
```

## 10. 绝对停止条件

出现任一情况，立即停止：

```text
命令指向 Base 主网
命令出现 --broadcast 但没有单独的 Stage 1 广播批准
有人要求提供私钥、助记词或恢复词
有人要求使用真实资金
PRIVATE_KEY 非空
chainId 不是 84532
deployer nonce 与文档预测不一致
stage1AddressCollision=true
预测地址被说成已经部署地址
有人要求跳过 Stage 1 后复核
有人要求直接进入 Stage 2 或 Stage 3
```

## 11. 下一步建议

下一步仍然不是广播。

建议下一步只做：

```text
owner 人工阅读本操作员执行说明草案
如果仍想继续，再重新跑 Base Sepolia fork 只读检查
然后再单独讨论是否需要准备 Stage 1 广播指令草案
```
