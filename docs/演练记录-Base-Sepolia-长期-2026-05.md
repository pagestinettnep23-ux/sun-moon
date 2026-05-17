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
latest_full_test=326 passed, 0 failed
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
latest_full_test=326 passed, 0 failed
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

### 6. 停止条件

出现任一情况立即停止：

```text
命令准备广播 Base 主网
命令出现 --broadcast 但 owner 没有明确批准测试网广播
有人要求在聊天里提供私钥、助记词或恢复词
测试网地址和主网预测地址混用
旧版 MOON/USDC 演练结果被当成 rc3 全范围通过
```
