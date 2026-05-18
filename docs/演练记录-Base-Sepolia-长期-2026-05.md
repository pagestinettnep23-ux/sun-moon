# Base Sepolia 长期演练记录 - 2026-05

本文用于记录 Base Sepolia 长期演练。它不是主网部署批准。

固定安全边界：

```text
不部署 Base 主网
不广播 Base 主网交易
不接真实资金
不索要私钥
不把测试网成功当成主网安全
```

## Day 0 - 2026-05-17

### 1. 本次目标

本次只做长期演练启动记录和执行边界整理，不做任何主网动作。

本次不执行：

```text
不执行 Base 主网广播
不使用真实资金
不要求私钥
不把任何测试网结果写成主网结论
```

### 2. 当前代码版本

```text
candidate=rc3
commit=4ffcdbe6dd13103aaf1cba2e085d4c1c3ec87623
tag=audit-sun-moon-base-contracts-2026-05-17-rc3
latest_full_test=334 passed, 0 failed
```

### 3. 当前 Base Sepolia 状态说明

Base Sepolia 上已经完成过一轮历史小额演练：

```text
CREATE2_DEPLOYER=0xE5Df76A1DF2e959C70c8b7591754a3a2a542Fb6D
OLD_MOON_HOOK=0xF612828Ba9dE01CF16Fae2D8EE187B0cA59100Cc
MOON_USDC_POOL_ID=0xfbb4ccec5e3fda3a97b9e2619e9e90588ad5e444bdb3d488e921a3192c42dd55
TINY_MOON_USDC_LIQUIDITY_TX=0x99c69749bbd9199ac7476f8d0175d2f3a651b81d97a97a607e13ca2b5168517b
TINY_MOON_USDC_SWAP_TX=0x61744130044a25395399db900c542872fe8c887057025a8d6b86bc0c71aeebaa
```

重要区别：

```text
这轮历史 Base Sepolia 演练主要验证旧版 MOON/USDC Hook 路径
rc3 最新主网候选方案是 BaseSunMoonUsdcFeeV4Hook
rc3 最新方案同时支持 SUN/USDC 2% USDC 费用和 MOON/USDC 5% USDC 费用
所以历史 MOON/USDC 小额演练不能直接等同于 rc3 全范围测试通过
```

### 4. Day 0 结论

```text
Day0_status=started
mainnet_broadcast=false
real_funds=false
private_key_requested=false
rc3_full_scope_on_base_sepolia=false
```

当前可以继续观察旧版 Base Sepolia `MOON/USDC` 测试池，但如果目标是验证 rc3 最新方案，还需要另起一轮 Base Sepolia rc3 演练。

### 5. 后续建议顺序

第一步，先做本地确认：

```powershell
forge test --threads 1 --isolate
```

第二步，只读检查历史 Base Sepolia `MOON/USDC` 测试池：

```powershell
$env:REHEARSAL_ACTOR="0x6E22b2e6fFAA30Fe75B71d53d1eC469b4e97A986"
$env:HOOK_ADDRESS="0xF612828Ba9dE01CF16Fae2D8EE187B0cA59100Cc"
$env:CONFIRM_BASE_SEPOLIA_TINY_REHEARSAL_RUN="1"
forge script script/PrepareBaseSepoliaTinyMoonUsdcRehearsal.s.sol --rpc-url https://sepolia.base.org --sender $env:REHEARSAL_ACTOR --rpc-timeout 120 --slow
```

这一步只读，不加 `--broadcast`。

第三步，如果 owner 要验证 rc3 最新方案，应先准备新的 Base Sepolia rc3 dry-run 草案：

```text
部署新的测试版 SUN/MOON 曲线核心
部署新的 BaseSunMoonUsdcFeeV4Hook
计算并白名单 SUN/USDC 和 MOON/USDC 两个测试池
按 1 SUN = 1 USDC、1 MOON = 0.24 USDC 初始化测试池
只在用户明确批准后才允许 Base Sepolia 测试网广播
```

当前已经新增 rc3 dry-run 草案：

```text
script=script/PrepareBaseSepoliaRc3SunMoonUsdcDryRun.s.sol
doc=docs/Base-Sepolia-rc3-dry-run草案-2026-05-17.md
test=test/hooks/base/BaseSepoliaRc3SunMoonUsdcDryRunPreparation.t.sol
local_script_result=Script ran successfully
test_result=10 passed, 0 failed
latest_full_test=334 passed, 0 failed
mainnet_broadcast=false
testnet_broadcast=false
private_key_requested=false
```

这一步只是本地 / fork 模拟准备，尚未把 rc3 真正部署到 Base Sepolia。

## Day 1 - 2026-05-18

### 1. 本次目标

本次只跑 Base Sepolia fork 只读 dry-run，验证 rc3 最新统一 Hook 方案在 Base Sepolia 官方 v4 / USDC 地址环境下可以模拟通过。

本次不执行：

```text
不加 --broadcast
不部署测试网合约
不部署主网合约
不使用真实资金
不索要私钥
```

### 2. 执行命令

```powershell
$env:CONFIRM_BASE_SEPOLIA_RC3_DRY_RUN="1"
$env:EXECUTE_BASE_SEPOLIA_RC3_BROADCAST="0"
forge script script/PrepareBaseSepoliaRc3SunMoonUsdcDryRun.s.sol --rpc-url https://sepolia.base.org --rpc-timeout 120 --slow
```

### 3. 结果记录

```text
script_result=Script ran successfully
chainId=84532
baseSepoliaConfirmed=true
broadcastRequested=false
simulationOnly=true
simulatedActionsPlanned=19
POOL_MANAGER=0x05E73354cFDd6745C338b50BcFDfA3Aa6fA03408
STATE_VIEW=0x571291b572ed32ce6751a2Cb2486EbEe8DEfB9B4
USDC_TOKEN=0x036CbD53842c5426634e7929541eC2318f3dCF7e
USDC_DECIMALS=6
actualLow14Bits=204
hookSalt=0x00000000000000000000000000000000000000000000000000000000000095c0
predictedHook=0xcceD1a6C6f7E8210B9cEF6Ab8B3B59d62e2480Cc
deployedHookSimulation=0xcceD1a6C6f7E8210B9cEF6Ab8B3B59d62e2480Cc
SUN_USDC_POOL_ID=0xfce32214da284681d65059fa87ab5cf5dbf3af53e1d7afdcd78e9d7a6aad4a43
SUN_USDC_INITIAL_TICK=276324
SUN_USDC_SQRT_PRICE_X96=79228162514264337593543950336000000
MOON_USDC_POOL_ID=0x1377ffa0adbb4dcd0be26eb97d703b4f590adee9a7ad72411ec7e75b6bfddf4a
MOON_USDC_INITIAL_TICK=290595
MOON_USDC_SQRT_PRICE_X96=161723809515207654377831473576838109
sunUsdcAllowedAfter=true
moonUsdcAllowedAfter=true
ownerAfterRenounce=0x0000000000000000000000000000000000000000
renounceBlocksSunAllowlist=true
renounceBlocksMoonAllowlist=true
renounceBlocksProtocolBudget=true
mainnet_broadcast=false
testnet_broadcast=false
private_key_requested=false
```

### 4. 重要说明

```text
上面的 predictedHook 和 poolId 是 fork dry-run 模拟结果，不是已经部署的测试网地址。
这一步证明脚本能在 Base Sepolia 官方环境里模拟通过。
下一步如果要把 rc3 真正部署到 Base Sepolia，必须另写广播脚本，并由 owner 单独明确批准。
```

## Day 1 补充 - rc3 测试网广播草案

### 1. 本次目标

只创建 Base Sepolia rc3 测试网广播草案，仍不执行广播。

新增：

```text
script/PrepareBaseSepoliaRc3SunMoonUsdcBroadcastDraft.s.sol
test/hooks/base/BaseSepoliaRc3SunMoonUsdcBroadcastDraft.t.sol
docs/Base-Sepolia-rc3-测试网广播草案-2026-05-18.md
```

### 2. 草案边界

```text
broadcastAllowed=false
simulationOnly=true
EXECUTE_BASE_SEPOLIA_RC3_BROADCAST=1 会被拒绝
PRIVATE_KEY 非空会被拒绝
Base mainnet chainId=8453 会被拒绝
```

### 3. 本地验证

```text
forge test --match-path test/hooks/base/BaseSepoliaRc3SunMoonUsdcBroadcastDraft.t.sol --threads 1 --isolate
9 passed, 0 failed

forge script script/PrepareBaseSepoliaRc3SunMoonUsdcBroadcastDraft.s.sol
Script ran successfully
totalTransactionsPlanned=19

forge test --threads 1 --isolate
326 passed, 0 failed
```

### 4. 当前结论

```text
rc3 测试网广播草案已准备
尚未允许测试网广播
尚未允许主网广播
下一步只能做 Base Sepolia fork 只读广播草案检查
```

## Day 1 补充 - rc3 广播草案 fork 只读检查

### 1. 本次目标

只在 Base Sepolia fork 环境跑广播草案检查，确认草案在官方测试网 v4 / USDC 地址下仍然能生成计划。

本次不执行：

```text
不加 --broadcast
不部署测试网合约
不部署主网合约
不使用真实资金
不索要私钥
```

### 2. 执行命令

```powershell
$env:CONFIRM_BASE_SEPOLIA_RC3_BROADCAST_DRAFT="1"
$env:EXECUTE_BASE_SEPOLIA_RC3_BROADCAST="0"
$env:PRIVATE_KEY=""
forge script script/PrepareBaseSepoliaRc3SunMoonUsdcBroadcastDraft.s.sol --rpc-url https://sepolia.base.org --rpc-timeout 120 --slow
```

### 3. 结果记录

```text
script_result=Script ran successfully
chainId=84532
baseSepoliaDraftConfirmed=true
executeRequested=false
privateKeyPresent=false
broadcastAllowed=false
simulationOnly=true
stage1CoreDeploymentTxs=12
stage2HookAndPoolTxs=6
stage3RenounceTxs=1
totalTransactionsPlanned=19
PREDICTED_SUN_TOKEN=0xb5287fBbAD0e25B12f18497209fDac7e0ACf7293
PREDICTED_SUN_CURVE=0xe8D048aB83727419b00F4e30F4898C6B3bB91aD4
PREDICTED_MOON_TOKEN=0x92dC3B8056cA62A7dbc5c1C339891B45463bEe71
PREDICTED_MOON_CURVE=0x095c91aB279121300Ac16c57D1ecebB9ceEa1cd8
PREDICTED_CREATE2_HOOK_DEPLOYER=0x6E34D98e1925eaf6680941213E49741b8764DdfE
HOOK_SALT=0x00000000000000000000000000000000000000000000000000000000000063fb
PREDICTED_HOOK=0xa7b9302FABcf263D95Ed1cC526Dc9d73831bC0cC
SUN_USDC_POOL_ID=0xada206761935bad228030e12dbde37a46d58391fd755889c6ce5d3bf9d24c0ac
MOON_USDC_POOL_ID=0xa0a6f00c435fe448d3de1a3e095dfef63c8fc689c98841a95b445b37b0d72d8f
mainnet_broadcast=false
testnet_broadcast=false
private_key_requested=false
```

### 4. 重要说明

```text
这些 predicted 地址和 poolId 是 fork 草案检查结果，不是已经部署地址。
这一步只证明广播草案在 Base Sepolia 官方环境里能模拟生成计划。
下一步如果继续，应先人工复核草案结果；仍不能直接广播。
```

## Day 1 补充 - rc3 分阶段广播脚本草案

### 1. 本次目标

创建更接近真正测试网广播顺序的分阶段脚本草案，但仍不执行广播。

新增：

```text
script/PrepareBaseSepoliaRc3SunMoonUsdcStagedBroadcastDraft.s.sol
test/hooks/base/BaseSepoliaRc3SunMoonUsdcStagedBroadcastDraft.t.sol
docs/Base-Sepolia-rc3-分阶段广播脚本草案-2026-05-18.md
```

### 2. 阶段拆分

```text
Stage 1: 核心合约部署和基础配置，12 笔
Stage 2: Hook、两个池白名单、两个池初始化，6 笔
Stage 3: renounce Hook owner，1 笔
totalTransactionsPlanned=19
```

### 3. 防呆状态

```text
broadcastAllowed=false
executionBlocked=true
simulationOnly=true
EXECUTE_BASE_SEPOLIA_RC3_STAGE=1 会被拒绝
PRIVATE_KEY 非空会被拒绝
Base mainnet chainId=8453 会被拒绝
```

### 4. 本地验证

```text
forge test --match-path test/hooks/base/BaseSepoliaRc3SunMoonUsdcStagedBroadcastDraft.t.sol --threads 1 --isolate
8 passed, 0 failed

forge script script/PrepareBaseSepoliaRc3SunMoonUsdcStagedBroadcastDraft.s.sol
Script ran successfully
stage1AddressCollision=false
stage2HookCollision=false

forge test --threads 1 --isolate
334 passed, 0 failed
```

### 5. 当前结论

```text
分阶段广播脚本草案已准备
尚未允许测试网广播
尚未允许主网广播
下一步只能做 Base Sepolia fork 只读分阶段草案检查
```

## Day 1 补充 - rc3 分阶段广播草案 fork 只读检查

### 1. 本次目标

只在 Base Sepolia fork 环境跑分阶段广播草案检查，确认脚本在官方测试网 v4 / USDC 地址下仍能生成计划。

本次不执行：

```text
不加 --broadcast
不部署测试网合约
不部署主网合约
不使用真实资金
不索要私钥
```

### 2. 执行命令

```powershell
$env:CONFIRM_BASE_SEPOLIA_RC3_STAGED_BROADCAST_DRAFT="1"
$env:BASE_SEPOLIA_RC3_BROADCAST_STAGE="0"
$env:EXECUTE_BASE_SEPOLIA_RC3_STAGE="0"
$env:PRIVATE_KEY=""
forge script script/PrepareBaseSepoliaRc3SunMoonUsdcStagedBroadcastDraft.s.sol --rpc-url https://sepolia.base.org --rpc-timeout 120 --slow
```

### 3. 结果记录

```text
script_result=Script ran successfully
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

### 4. 当前结论

```text
分阶段广播草案 fork 只读检查已通过
执行仍然被锁住
尚未允许测试网广播
尚未允许主网广播
下一步只能人工复核检查结果
```

这些 predicted 地址和 poolId 是 fork 只读检查结果，不是已经部署地址。

## Day 1 补充 - rc3 分阶段广播人工复核表

### 1. 本次目标

把 rc3 分阶段广播草案 fork 只读检查结果整理成人工复核表，方便 owner 逐项确认。

新增：

```text
docs/Base-Sepolia-rc3-分阶段广播人工复核表-2026-05-18.md
```

### 2. 复核表覆盖内容

```text
安全边界：不广播、不部署、不用真实资金、不读取 PRIVATE_KEY
三阶段拆分：Stage 1/2/3 和预计交易数
公开钱包：每个阶段的执行钱包公开地址
预测地址：SUN、SunCurve、MOON、MoonCurve、CREATE2 deployer、Hook
两个 poolId：SUN/USDC 与 MOON/USDC
费用和价格：LP fee、Hook fee、初始价格
停止条件：出现 --broadcast、私钥、真实资金、主网广播等立即停止
```

### 3. 当前结论

```text
人工复核表已创建
仍未允许测试网广播
仍未允许主网广播
下一步只建议准备 Stage 1 测试网广播草案文档
```

## Day 1 补充 - rc3 Stage 1 测试网广播草案

### 1. 本次目标

把 Stage 1 的 12 笔核心部署交易拆成小白可读清单，但仍不广播。

新增：

```text
docs/Base-Sepolia-rc3-Stage1-测试网广播草案-2026-05-18.md
```

### 2. Stage 1 覆盖内容

```text
5 笔部署：SunToken、SunCurve、MoonToken、MoonCurve、Create2HookDeployer
3 笔基础配置：SUN minter、SunCurve moonCurve、MOON minter
4 笔 owner 转移：SUN、SunCurve、MOON、MoonCurve 交给测试网管理员
```

### 3. Stage 1 不覆盖内容

```text
不部署 Hook
不创建 SUN/USDC 或 MOON/USDC 池
不添加流动性
不 swap
不 renounce Hook owner
不触碰 Base 主网
```

### 4. 当前结论

```text
Stage 1 测试网广播草案已创建
仍未允许测试网广播
仍未允许主网广播
下一步只建议准备 Stage 1 后复核清单草案
```

## Day 1 补充 - rc3 Stage 1 广播后复核清单草案

### 1. 本次目标

准备 Stage 1 未来如果真的广播成功后的只读复核清单，但当前仍不广播。

新增：

```text
docs/Base-Sepolia-rc3-Stage1-广播后复核清单草案-2026-05-18.md
```

### 2. 复核清单覆盖内容

```text
12 笔 Stage 1 交易哈希记录区
5 个合约 code 是否存在
SUN/MOON name、symbol、owner、minter、minterLocked
SunCurve owner、USDC、protocolBudget、moonCurve、moonAMM
MoonCurve owner、token 地址、k/s、launchTime、timeUntilLaunch
Create2HookDeployer owner
Stage 1 后仍未部署 Hook、未建池、未加流动性、未 renounce
```

### 3. 当前结论

```text
Stage 1 广播后复核清单草案已创建
仍未允许测试网广播
仍未允许主网广播
下一步只建议准备 Stage 2 测试网广播草案文档
```

## Day 1 补充 - rc3 Stage 2 测试网广播草案

### 1. 本次目标

把 Stage 2 的 6 笔 Hook 和池准备交易拆成小白可读清单，但仍不广播。

新增：

```text
docs/Base-Sepolia-rc3-Stage2-测试网广播草案-2026-05-18.md
```

### 2. Stage 2 覆盖内容

```text
1 笔 Hook 部署：Create2HookDeployer.deployHook
1 笔绑定：SunCurve.setMoonAMM(Hook)
2 笔白名单：SUN/USDC 和 MOON/USDC poolId
2 笔初始化：SUN/USDC 和 MOON/USDC v4 池初始价格
```

### 3. Stage 2 不覆盖内容

```text
不添加流动性
不 swap
不 renounce Hook owner
不触碰 Base 主网
不使用真实资金
```

### 4. 当前结论

```text
Stage 2 测试网广播草案已创建
仍未允许测试网广播
仍未允许主网广播
下一步只建议准备 Stage 2 后复核清单草案
```

## Day 1 补充 - rc3 Stage 2 广播后复核清单草案

### 1. 本次目标

准备 Stage 2 未来如果真的广播成功后的只读复核清单，但当前仍不广播。

新增：

```text
docs/Base-Sepolia-rc3-Stage2-广播后复核清单草案-2026-05-18.md
```

### 2. 复核清单覆盖内容

```text
6 笔 Stage 2 交易哈希记录区
Hook code、owner、poolManager、token、USDC、SunCurve、protocolBudget、paused、expectedHookMask
SunCurve.moonAMM 是否等于 Hook
SUN/USDC 和 MOON/USDC 白名单是否为 true
SUN/USDC 和 MOON/USDC slot0 的 sqrtPriceX96、tick、protocolFee、lpFee
两个池 liquidity 是否仍为 0
Stage 2 后仍未添加流动性、未 swap、未 renounce
```

### 3. 当前结论

```text
Stage 2 广播后复核清单草案已创建
仍未允许测试网广播
仍未允许主网广播
下一步只建议准备 Stage 3 测试网广播草案文档
```

## Day 1 补充 - rc3 Stage 3 测试网广播草案

### 1. 本次目标

把 Stage 3 的 1 笔 renounce Hook owner 交易拆成小白可读清单，但仍不广播。

新增：

```text
docs/Base-Sepolia-rc3-Stage3-测试网广播草案-2026-05-18.md
```

### 2. Stage 3 覆盖内容

```text
1 笔交易：Hook.renounceOwnership()
目标：Hook.owner 变为 0x0000000000000000000000000000000000000000
风险：之后不能再改白名单、protocolBudget、paused 或 owner
```

### 3. Stage 3 不覆盖内容

```text
不部署合约
不创建池
不初始化池
不添加流动性
不 swap
不触碰 Base 主网
```

### 4. 当前结论

```text
Stage 3 测试网广播草案已创建
仍未允许测试网广播
仍未允许主网广播
下一步只建议准备 Stage 3 后复核清单草案
```

## Day 1 补充 - rc3 Stage 3 广播后复核清单草案

### 1. 本次目标

准备 Stage 3 未来如果真的广播成功后的只读复核清单，但当前仍不广播。

新增：

```text
docs/Base-Sepolia-rc3-Stage3-广播后复核清单草案-2026-05-18.md
```

### 2. 复核清单覆盖内容

```text
1 笔 Stage 3 交易哈希记录区
确认 receipt status=1 且 chain-id=84532
确认 Hook code 不是 0x
确认 Hook.owner 已变成零地址
确认 Hook poolManager、token、USDC、SunCurve、protocolBudget、paused、expectedHookMask 不变
确认 SunCurve.moonAMM 仍等于 Hook
确认 SUN/USDC 和 MOON/USDC 白名单仍为 true
确认两个池 slot0 和 liquidity 仍符合预期
用 cast call 只读模拟确认 owner-only 函数已经不能再改参数
```

### 3. 当前结论

```text
Stage 3 广播后复核清单草案已创建
仍未允许测试网广播
仍未允许主网广播
下一步只建议准备 rc3 Stage 1/2/3 总闸门清单
```

## Day 1 补充 - rc3 Stage 1/2/3 总闸门清单

### 1. 本次目标

把 Stage 1/2/3 的广播前确认、广播后复核、owner 单独批准区和绝对停止条件合并成一张最终人工审批表，但当前仍不广播。

新增：

```text
docs/Base-Sepolia-rc3-Stage1-2-3-总闸门清单-2026-05-18.md
```

### 2. 总闸门覆盖内容

```text
当前状态：三阶段均为草案，未广播
固定测试网参数：Base Sepolia chain-id=84532
三阶段总览：Stage 1 12 笔、Stage 2 6 笔、Stage 3 1 笔
当前 fork 只读检查输出和预测地址记录
SUN/USDC 与 MOON/USDC 两个项目支持 v4 Hook 池参数
Stage 1 前闸门和 Stage 1 后闸门
Stage 2 前闸门和 Stage 2 后闸门
Stage 3 前闸门和 Stage 3 后闸门
绝对停止条件
owner 最终确认区
```

### 3. 当前结论

```text
Stage 1/2/3 总闸门清单已创建
仍未允许测试网广播
仍未允许主网广播
下一步只建议 owner 人工阅读总闸门清单
如需继续，也应先重新跑 Base Sepolia fork 只读检查
```

## Day 1 补充 - rc3 总闸门后分阶段 fork 只读复查

### 1. 本次目标

根据总闸门清单要求，重新跑一次 Base Sepolia fork 只读检查，确认分阶段草案仍然能生成计划，并且执行仍然被锁住。

本次不执行：

```text
不加 --broadcast
不部署测试网合约
不部署主网合约
不使用真实资金
不索要私钥
```

### 2. 执行命令

```powershell
$env:CONFIRM_BASE_SEPOLIA_RC3_STAGED_BROADCAST_DRAFT="1"
$env:BASE_SEPOLIA_RC3_BROADCAST_STAGE="0"
$env:EXECUTE_BASE_SEPOLIA_RC3_STAGE="0"
$env:PRIVATE_KEY=""
forge script script/PrepareBaseSepoliaRc3SunMoonUsdcStagedBroadcastDraft.s.sol --rpc-url https://sepolia.base.org --rpc-timeout 120 --slow
```

### 3. 结果记录

```text
script_result=Script ran successfully
chainId=84532
stagedDraftConfirmed=true
selectedStage=0
executeRequested=false
privateKeyPresent=false
broadcastAllowed=false
executionBlocked=true
simulationOnly=true
stage1CoreDeploymentTxs=12
stage2HookAndPoolTxs=6
stage3RenounceTxs=1
selectedStageTxs=19
totalTransactionsPlanned=19
stage1AddressCollision=false
stage2HookCollision=false
```

预测地址和池：

```text
PREDICTED_SUN_TOKEN=0xb5287fBbAD0e25B12f18497209fDac7e0ACf7293
PREDICTED_SUN_CURVE=0xe8D048aB83727419b00F4e30F4898C6B3bB91aD4
PREDICTED_MOON_TOKEN=0x92dC3B8056cA62A7dbc5c1C339891B45463bEe71
PREDICTED_MOON_CURVE=0x095c91aB279121300Ac16c57D1ecebB9ceEa1cd8
PREDICTED_CREATE2_HOOK_DEPLOYER=0x6E34D98e1925eaf6680941213E49741b8764DdfE
HOOK_SALT=0x0000000000000000000000000000000000000000000000000000000000002a9c
PREDICTED_HOOK=0x675D7a468d4d3b8d02d530539867F9e5feEFc0cc
SUN_USDC_POOL_ID=0xdbf2bf05916b4f79d43e3ee74fa48b36301e8e8c13805335e186648b792451dc
MOON_USDC_POOL_ID=0x5b2a79878be8e421c919a9acb8d853731d6d61b8053aa25bd32e0c994130bdfd
```

池初始化参数：

```text
SUN_USDC_INITIAL_TICK=276324
SUN_USDC_SQRT_PRICE_X96=79228162514264337593543950336000000
MOON_USDC_INITIAL_TICK=290595
MOON_USDC_SQRT_PRICE_X96=161723809515207654377831473576838109
```

锁定检查：

```text
sunUsdcAllowedAfterDryRun=true
moonUsdcAllowedAfterDryRun=true
ownerAfterRenounce=0x0000000000000000000000000000000000000000
renounceBlocksSunAllowlist=true
renounceBlocksMoonAllowlist=true
renounceBlocksProtocolBudget=true
```

### 4. 当前结论

```text
总闸门后分阶段 fork 只读复查已通过
执行仍然被锁住
尚未允许测试网广播
尚未允许主网广播
private_key_requested=false
real_funds_used=false
```

说明：

```text
命令输出中的 Foundry WARN 是源码 trace/cache/etherscan 信息提示，不影响本次脚本成功结论。
最终判断以 Script ran successfully 和返回的安全开关为准。
```

## Day 1 补充 - rc3 Stage 1 广播前最终确认单

### 1. 本次目标

准备给 owner 在未来决定是否进入 Base Sepolia 测试网 Stage 1 前看的最终确认单，但当前仍不广播。

新增：

```text
docs/Base-Sepolia-rc3-Stage1-广播前最终确认单-2026-05-18.md
```

### 2. 确认单覆盖内容

```text
当前状态：Stage 1/2/3 均未广播
Stage 1 预计 12 笔测试网交易
Stage 1 只部署核心合约和基础配置
Stage 1 不部署 Hook、不建池、不加流动性、不 swap、不 renounce
测试网公开地址确认
最近一次 fork 只读检查结果
当前预测地址和 nonce 风险
Stage 1 前最后必须再跑的只读检查
Stage 1 批准边界
Stage 1 后必须先做广播后复核
绝对停止条件
owner 最终签字区
```

### 3. 当前结论

```text
Stage 1 广播前最终确认单已创建
仍未允许测试网广播
仍未允许主网广播
下一步只建议 owner 人工阅读确认单
如需继续，也应先重新跑 Base Sepolia fork 只读检查
```

## Day 1 补充 - rc3 Stage 1 操作员执行说明草案

### 1. 本次目标

准备给未来操作员看的 Stage 1 执行说明草案。当前仍不广播，且本文不提供广播命令。

新增：

```text
docs/Base-Sepolia-rc3-Stage1-操作员执行说明草案-2026-05-18.md
```

### 2. 操作员说明覆盖内容

```text
操作员是谁、可以做什么、不可以做什么
当前 Stage 1/2/3 均未广播
操作员必须先读的 Stage 1 文档
Stage 1 的 12 笔测试网交易范围
当前只允许执行的只读命令
当前禁止执行的广播命令和主网命令
如果未来 owner 批准 Stage 1，操作员仍需先完成哪些只读复核
操作员记录模板
Stage 1 广播后第一件事必须是 Stage 1 后复核
绝对停止条件
```

### 3. 当前结论

```text
Stage 1 操作员执行说明草案已创建
仍未允许测试网广播
仍未允许主网广播
本文不包含广播命令
下一步只建议 owner 人工阅读确认单和操作员说明
如需继续，也应先重新跑 Base Sepolia fork 只读检查
```

## Day 1 补充 - rc3 Stage 1 前 fork 只读检查

### 1. 本次目标

按照 Stage 1 广播前最终确认单和操作员执行说明草案的要求，重新跑一次 Base Sepolia fork 只读检查，确认 Stage 1 前关键条件仍然成立。

本次不执行：

```text
不加 --broadcast
不部署测试网合约
不部署主网合约
不使用真实资金
不索要私钥
```

### 2. 执行命令

```powershell
$env:CONFIRM_BASE_SEPOLIA_RC3_STAGED_BROADCAST_DRAFT="1"
$env:BASE_SEPOLIA_RC3_BROADCAST_STAGE="0"
$env:EXECUTE_BASE_SEPOLIA_RC3_STAGE="0"
$env:PRIVATE_KEY=""
forge script script/PrepareBaseSepoliaRc3SunMoonUsdcStagedBroadcastDraft.s.sol --rpc-url https://sepolia.base.org --rpc-timeout 120 --slow
```

### 3. 结果记录

```text
script_result=Script ran successfully
chainId=84532
stagedDraftConfirmed=true
selectedStage=0
executeRequested=false
privateKeyPresent=false
broadcastAllowed=false
executionBlocked=true
simulationOnly=true
stage1CoreDeploymentTxs=12
stage2HookAndPoolTxs=6
stage3RenounceTxs=1
selectedStageTxs=19
totalTransactionsPlanned=19
stage1AddressCollision=false
stage2HookCollision=false
SEPOLIA_DEPLOYER_NONCE=16
```

Stage 1 预测地址：

```text
PREDICTED_SUN_TOKEN=0xb5287fBbAD0e25B12f18497209fDac7e0ACf7293
PREDICTED_SUN_CURVE=0xe8D048aB83727419b00F4e30F4898C6B3bB91aD4
PREDICTED_MOON_TOKEN=0x92dC3B8056cA62A7dbc5c1C339891B45463bEe71
PREDICTED_MOON_CURVE=0x095c91aB279121300Ac16c57D1ecebB9ceEa1cd8
PREDICTED_CREATE2_HOOK_DEPLOYER=0x6E34D98e1925eaf6680941213E49741b8764DdfE
```

后续 Stage 2/3 相关预测仍保持：

```text
HOOK_SALT=0x0000000000000000000000000000000000000000000000000000000000002a9c
PREDICTED_HOOK=0x675D7a468d4d3b8d02d530539867F9e5feEFc0cc
SUN_USDC_POOL_ID=0xdbf2bf05916b4f79d43e3ee74fa48b36301e8e8c13805335e186648b792451dc
MOON_USDC_POOL_ID=0x5b2a79878be8e421c919a9acb8d853731d6d61b8053aa25bd32e0c994130bdfd
```

### 4. 当前结论

```text
Stage 1 前 fork 只读检查已通过
部署钱包 nonce 仍为 16
Stage 1 预测地址仍可用
执行仍然被锁住
尚未允许测试网广播
尚未允许主网广播
private_key_requested=false
real_funds_used=false
```

说明：

```text
命令输出中的 Foundry WARN 是源码 trace/cache/etherscan 信息提示，不影响本次脚本成功结论。
最终判断以 Script ran successfully 和返回的安全开关为准。
```

## Day 1 补充 - rc3 Stage 1 广播指令草案（非执行版）

### 1. 本次目标

准备一份给 owner 人工阅读的 Stage 1 广播指令边界说明，但当前仍不广播、不部署、不需要私钥。

### 2. 新增文档

```text
docs/Base-Sepolia-rc3-Stage1-广播指令草案-非执行版-2026-05-18.md
```

### 3. 覆盖内容

```text
当前脚本仍然 broadcastAllowed=false、executionBlocked=true
本文不提供可复制广播命令
本文不包含 --broadcast、cast send 或私钥非空写法
Stage 1 未来如果被批准，只能覆盖 12 笔核心部署和基础配置交易
Stage 1 不能包含 Hook、建池、流动性、swap、renounce、Stage 2/3 或 Base 主网
```

### 4. 当前结论

```text
Stage 1 广播指令草案（非执行版）已创建
仍未允许测试网广播
仍未允许主网广播
private_key_requested=false
real_funds_used=false
下一步只建议 owner 人工阅读非执行版指令草案
如需继续，也应先重新跑 Base Sepolia fork 只读检查
```

## Day 1 补充 - rc3 Stage 1 非执行版后 fork 只读复查

### 1. 本次目标

按 Stage 1 广播指令草案（非执行版）的要求，重新跑一次 Base Sepolia fork 只读检查，确认预测地址、阶段交易数和安全开关仍然成立。

### 2. 执行边界

```text
不加 --broadcast
不部署
不进入 Base 主网
不使用真实资金
不使用私钥
PRIVATE_KEY=""
```

### 3. 关键输出

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
PREDICTED_SUN_TOKEN=0xb5287fBbAD0e25B12f18497209fDac7e0ACf7293
PREDICTED_SUN_CURVE=0xe8D048aB83727419b00F4e30F4898C6B3bB91aD4
PREDICTED_MOON_TOKEN=0x92dC3B8056cA62A7dbc5c1C339891B45463bEe71
PREDICTED_MOON_CURVE=0x095c91aB279121300Ac16c57D1ecebB9ceEa1cd8
PREDICTED_CREATE2_HOOK_DEPLOYER=0x6E34D98e1925eaf6680941213E49741b8764DdfE
PREDICTED_HOOK=0x675D7a468d4d3b8d02d530539867F9e5feEFc0cc
SUN_USDC_POOL_ID=0xdbf2bf05916b4f79d43e3ee74fa48b36301e8e8c13805335e186648b792451dc
MOON_USDC_POOL_ID=0x5b2a79878be8e421c919a9acb8d853731d6d61b8053aa25bd32e0c994130bdfd
```

### 4. 当前结论

```text
Stage 1 非执行版后 fork 只读复查已通过
部署钱包 nonce 仍为 16
Stage 1 预测地址仍可用
Stage 2 Hook 预测地址仍可用
执行仍然被锁住
尚未允许测试网广播
尚未允许主网广播
private_key_requested=false
real_funds_used=false
```

说明：

```text
命令输出中的 Foundry WARN 是源码 trace/cache/etherscan 信息提示，不影响本次脚本成功结论。
最终判断以 Script ran successfully 和返回的安全开关为准。
```

## Day 1 补充 - rc3 Stage 1 最终广播指令草案（审阅版，不执行）

### 1. 本次目标

准备 Stage 1 最终广播指令草案的审阅版，让 owner 在任何执行版出现前先确认边界。当前仍不广播、不部署、不需要私钥。

### 2. 新增文档

```text
docs/Base-Sepolia-rc3-Stage1-最终广播指令草案-审阅版-2026-05-18.md
```

### 3. 覆盖内容

```text
当前状态和最近一次只读复查结果
审阅版不提供可直接执行的命令
Stage 1 未来如果执行，只能做 12 笔核心部署和基础配置交易
Stage 1 明确不能包含 Hook、建池、流动性、swap、renounce、Stage 2/3 或 Base 主网
公开参数和预测地址
真正执行版出现前必须重新确认的只读条件
owner 批准语句模板
操作员本地签名边界
未来执行版交易哈希记录区
Stage 1 成功后第一件事必须是 Stage 1 后复核
绝对停止条件
```

### 4. 当前结论

```text
Stage 1 最终广播指令草案（审阅版，不执行）已创建
当前不是执行版
仍未允许测试网广播
仍未允许主网广播
private_key_requested=false
real_funds_used=false
```

下一步只建议 owner 人工阅读最终指令审阅版。

## 停止条件

出现任一情况立即停止：

```text
命令准备广播 Base 主网
命令出现 --broadcast 但 owner 没有明确批准测试网广播
有人要求在聊天里提供私钥、助记词或恢复词
测试网地址和主网预测地址混用
旧版 MOON/USDC 演练结果被当成 rc3 全范围通过
```
