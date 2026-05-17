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
latest_full_test=317 passed, 0 failed
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
latest_full_test=317 passed, 0 failed
mainnet_broadcast=false
testnet_broadcast=false
private_key_requested=false
```

这一步只是本地 / fork 模拟准备，尚未把 rc3 真正部署到 Base Sepolia。

### 6. 停止条件

出现任一情况立即停止：

```text
命令准备广播 Base 主网
命令出现 --broadcast 但 owner 没有明确批准测试网广播
有人要求在聊天里提供私钥、助记词或恢复词
测试网地址和主网预测地址混用
旧版 MOON/USDC 演练结果被当成 rc3 全范围通过
```
