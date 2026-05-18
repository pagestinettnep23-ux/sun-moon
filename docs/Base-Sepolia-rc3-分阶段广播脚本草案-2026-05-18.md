# Base Sepolia rc3 分阶段广播脚本草案 - 2026-05-18

本文说明 rc3 Base Sepolia 真正广播脚本的分阶段草案。

这一步仍然不是广播批准。

固定边界：

```text
不加 --broadcast
不部署测试网合约
不部署主网合约
不使用真实资金
不索要私钥
不读取 PRIVATE_KEY
```

## 1. 新增脚本

```text
script/PrepareBaseSepoliaRc3SunMoonUsdcStagedBroadcastDraft.s.sol
```

它的作用：

```text
把未来真正 Base Sepolia 广播拆成 3 个阶段
输出每个阶段由哪个公开钱包执行
输出每个阶段预计交易数量
输出预测核心合约、预测 Hook、两个 poolId
检查 Stage 1 预测地址是否已有代码冲突
证明当前执行仍被锁住
```

它不会做：

```text
不会调用 vm.startBroadcast
不会发送交易
不会部署合约
不会读取 PRIVATE_KEY
```

## 2. 三个阶段

```text
Stage 1: 部署测试版核心合约和基础配置
Stage 2: 部署 Hook、绑定 SunCurve.moonAMM、白名单两个池、初始化两个池
Stage 3: renounce Hook owner
```

当前默认计划：

```text
stage1CoreDeploymentTxs=12
stage2HookAndPoolTxs=6
stage3RenounceTxs=1
totalTransactionsPlanned=19
```

小白理解：

```text
第 1 阶段：把测试版 SUN/MOON 核心合约放上测试网
第 2 阶段：把 Hook 和两个 v4 池准备好
第 3 阶段：确认没问题后放弃 Hook 管理权
```

## 3. 本地命令

本地只看总计划：

```powershell
forge script script/PrepareBaseSepoliaRc3SunMoonUsdcStagedBroadcastDraft.s.sol
```

本地只看某个阶段：

```powershell
$env:BASE_SEPOLIA_RC3_BROADCAST_STAGE="1"
forge script script/PrepareBaseSepoliaRc3SunMoonUsdcStagedBroadcastDraft.s.sol
```

阶段编号：

```text
0 = 全部阶段总览
1 = Stage 1 核心合约
2 = Stage 2 Hook 和两个池
3 = Stage 3 renounce
```

通过时应看到：

```text
Script ran successfully
broadcastAllowed=false
executionBlocked=true
simulationOnly=true
executeRequested=false
privateKeyPresent=false
```

## 4. Base Sepolia fork 只读命令

如果后续 owner 明确批准，可以跑 Base Sepolia fork 只读检查。

注意：仍然不加 `--broadcast`。

```powershell
$env:CONFIRM_BASE_SEPOLIA_RC3_STAGED_BROADCAST_DRAFT="1"
$env:BASE_SEPOLIA_RC3_BROADCAST_STAGE="0"
$env:EXECUTE_BASE_SEPOLIA_RC3_STAGE="0"
$env:PRIVATE_KEY=""
forge script script/PrepareBaseSepoliaRc3SunMoonUsdcStagedBroadcastDraft.s.sol --rpc-url https://sepolia.base.org --rpc-timeout 120 --slow
```

## 5. 防呆规则

脚本会拒绝：

```text
Base mainnet chainId=8453
BASE_SEPOLIA_RC3_BROADCAST_STAGE 大于 3
EXECUTE_BASE_SEPOLIA_RC3_STAGE=1
PRIVATE_KEY 非空
Base Sepolia 上没有设置 CONFIRM_BASE_SEPOLIA_RC3_STAGED_BROADCAST_DRAFT=1
```

人工也必须拒绝：

```text
命令里出现 --broadcast
命令里出现真实私钥
有人要求发送主网交易
有人要求使用真实资金
```

## 6. 当前验证

专项测试：

```text
forge test --match-path test/hooks/base/BaseSepoliaRc3SunMoonUsdcStagedBroadcastDraft.t.sol --threads 1 --isolate
8 passed, 0 failed
```

本地脚本：

```text
forge script script/PrepareBaseSepoliaRc3SunMoonUsdcStagedBroadcastDraft.s.sol
Script ran successfully
broadcastAllowed=false
executionBlocked=true
simulationOnly=true
totalTransactionsPlanned=19
stage1AddressCollision=false
stage2HookCollision=false
```

全量测试：
```text
forge test --threads 1 --isolate
334 passed, 0 failed
```

2026-05-18 Base Sepolia fork 只读检查：
```text
Script ran successfully
chainId=84532
stagedDraftConfirmed=true
selectedStage=0
broadcastAllowed=false
executionBlocked=true
simulationOnly=true
executeRequested=false
privateKeyPresent=false
stage1CoreDeploymentTxs=12
stage2HookAndPoolTxs=6
stage3RenounceTxs=1
totalTransactionsPlanned=19
PREDICTED_SUN_TOKEN=0xb5287fBbAD0e25B12f18497209fDac7e0ACf7293
PREDICTED_SUN_CURVE=0xe8D048aB83727419b00F4e30F4898C6B3bB91aD4
PREDICTED_MOON_TOKEN=0x92dC3B8056cA62A7dbc5c1C339891B45463bEe71
PREDICTED_MOON_CURVE=0x095c91aB279121300Ac16c57D1ecebB9ceEa1cd8
PREDICTED_CREATE2_HOOK_DEPLOYER=0x6E34D98e1925eaf6680941213E49741b8764DdfE
HOOK_SALT=0x0000000000000000000000000000000000000000000000000000000000002a9c
PREDICTED_HOOK=0x675D7a468d4d3b8d02d530539867F9e5feEFc0cc
SUN_USDC_POOL_ID=0xdbf2bf05916b4f79d43e3ee74fa48b36301e8e8c13805335e186648b792451dc
MOON_USDC_POOL_ID=0x5b2a79878be8e421c919a9acb8d853731d6d61b8053aa25bd32e0c994130bdfd
stage1AddressCollision=false
stage2HookCollision=false
mainnet_broadcast=false
testnet_broadcast=false
private_key_requested=false
```

说明：这些 predicted 地址和 poolId 是 fork 只读检查结果，不是已经部署地址。

人工复核表：

```text
docs/Base-Sepolia-rc3-分阶段广播人工复核表-2026-05-18.md
```

## 7. 当前结论

```text
分阶段广播脚本草案已准备
执行仍然被锁住
尚未允许测试网广播
尚未允许主网广播
```

人工复核表已创建；下一步只建议准备 Stage 1 测试网广播草案文档。仍不能直接广播。
