# Base Sepolia rc3 测试网广播草案 - 2026-05-18

本文是给非技术成员看的 rc3 Base Sepolia 测试网广播草案。

这不是测试网广播批准，也不是主网部署批准。

固定边界：

```text
不部署 Base 主网
不广播 Base 主网交易
不使用真实资金
不索要私钥
不读取 PRIVATE_KEY
不加 --broadcast
```

## 1. 本次新增内容

新增脚本：

```text
script/PrepareBaseSepoliaRc3SunMoonUsdcBroadcastDraft.s.sol
```

它做的事情：

```text
复用 rc3 dry-run 逻辑
生成 Base Sepolia 测试网广播前的分阶段计划
输出预测核心合约地址、Hook salt、预测 Hook 地址、两个 poolId 和初始价格参数
明确告诉 owner 一共大约需要几批交易
证明默认不能执行广播
```

它不会做的事情：

```text
不会调用 vm.startBroadcast
不会发送链上交易
不会部署测试网合约
不会部署主网合约
不会读取 PRIVATE_KEY
```

## 2. 为什么先写草案

rc3 最新方案比之前历史测试网 `MOON/USDC` 单池演练复杂。

当前 rc3 范围是：

```text
新测试版 SunToken
新测试版 SunCurve
新测试版 MoonToken
新测试版 MoonCurve
新 Create2HookDeployer
新 BaseSunMoonUsdcFeeV4Hook
SUN/USDC v4 Hook 池
MOON/USDC v4 Hook 池
初始化两个池
白名单两个池
最后 renounce Hook owner
```

所以不能直接广播，必须先把步骤拆清楚。

## 3. 分阶段计划

当前默认 Base Sepolia 角色是：

```text
SEPOLIA_DEPLOYER=0x2F6E887c6058deE520f9468a1022E3480A6334D3
SEPOLIA_ADMIN_WALLET=0x6E22b2e6fFAA30Fe75B71d53d1eC469b4e97A986
SEPOLIA_PROTOCOL_BUDGET_WALLET=0x277ba3Cf597CdAaF958C301db3cF6a631F793039
SEPOLIA_CREATE2_DEPLOYER_OWNER=0x6E22b2e6fFAA30Fe75B71d53d1eC469b4e97A986
```

按这个默认设置，草案计划是：

```text
Stage 1: 核心合约部署和基础配置，约 12 笔交易
Stage 2: Hook、两个池白名单、两个池初始化，约 6 笔交易
Stage 3: renounce Hook owner，约 1 笔交易
totalTransactionsPlanned=19
```

小白理解：

```text
第 1 阶段：先把测试版 SUN/MOON 曲线核心放到测试网
第 2 阶段：再把 Hook 和两个 v4 池准备好
第 3 阶段：确认都没问题后，再放弃 Hook 管理权
```

## 4. 本地草案命令

这一步不需要 RPC、不需要钱包、不需要私钥：

```powershell
forge script script/PrepareBaseSepoliaRc3SunMoonUsdcBroadcastDraft.s.sol
```

通过时应看到：

```text
Script ran successfully
broadcastAllowed=false
simulationOnly=true
executeRequested=false
privateKeyPresent=false
stage1CoreDeploymentTxs=12
stage2HookAndPoolTxs=6
stage3RenounceTxs=1
totalTransactionsPlanned=19
```

## 5. Base Sepolia fork 草案命令

如果后续 owner 明确批准，可以跑只读 fork 草案。

注意：仍然不加 `--broadcast`。

```powershell
$env:CONFIRM_BASE_SEPOLIA_RC3_BROADCAST_DRAFT="1"
$env:EXECUTE_BASE_SEPOLIA_RC3_BROADCAST="0"
forge script script/PrepareBaseSepoliaRc3SunMoonUsdcBroadcastDraft.s.sol --rpc-url https://sepolia.base.org --rpc-timeout 120 --slow
```

这仍然不是测试网广播。

## 6. 防呆规则

脚本会拒绝：

```text
Base mainnet chainId=8453
EXECUTE_BASE_SEPOLIA_RC3_BROADCAST=1
PRIVATE_KEY 环境变量非空
Base Sepolia 上没有设置 CONFIRM_BASE_SEPOLIA_RC3_BROADCAST_DRAFT=1
Base Sepolia USDC 不是官方测试 USDC
Hook 权限低 14 位不正确
两个池 fee/tickSpacing 不是 3000/60
```

人工也必须拒绝：

```text
命令里出现 --broadcast
命令里出现真实私钥
有人要求发送主网交易
有人要求使用真实资金
```

## 7. 当前测试结果

专项测试：

```text
forge test --match-path test/hooks/base/BaseSepoliaRc3SunMoonUsdcBroadcastDraft.t.sol --threads 1 --isolate
9 passed, 0 failed
```

本地草案脚本：

```text
forge script script/PrepareBaseSepoliaRc3SunMoonUsdcBroadcastDraft.s.sol
Script ran successfully
broadcastAllowed=false
simulationOnly=true
totalTransactionsPlanned=19
```

全量测试：

```text
forge test --threads 1 --isolate
326 passed, 0 failed
```

## 8. 当前结论

```text
rc3 Base Sepolia 测试网广播草案已准备
当前只允许 review 草案和跑 fork 只读草案
尚未允许测试网广播
尚未允许主网广播
```

下一步如果继续，也不是广播。

建议下一步只做：

```text
Base Sepolia fork 只读广播草案检查
仍不加 --broadcast
仍不使用 PRIVATE_KEY
```
