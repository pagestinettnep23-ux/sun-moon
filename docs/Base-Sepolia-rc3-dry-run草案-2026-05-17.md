# Base Sepolia rc3 dry-run 草案 - 2026-05-17

本文给非技术成员说明：如果要把 rc3 最新统一 Hook 方案拿到 Base Sepolia 做新一轮测试网演练，第一步应该先怎么模拟。

这不是主网部署批准，也不是测试网广播批准。

固定边界：

```text
不部署 Base 主网
不广播 Base 主网交易
不使用真实资金
不索要私钥
不把旧版 MOON/USDC 测试网结果当成 rc3 全范围通过
```

## 1. 为什么需要 rc3 dry-run

Base Sepolia 上之前跑通过一轮历史 `MOON/USDC` 小额演练，但那是旧版 `BaseMoonAmmFeeV4Hook` 路径。

当前 rc3 最新方案是：

```text
BaseSunMoonUsdcFeeV4Hook
SUN/USDC v4 Hook 池收 2% USDC
MOON/USDC v4 Hook 池收 5% USDC
SUN/MOON 自由转账
不限制市场自己创建第三方 AMM 池
项目只支持指定的 SUN/USDC 和 MOON/USDC v4 Hook 池
```

所以如果要观察 rc3，不能只看旧的 `MOON/USDC` 测试池，需要先为 rc3 准备一轮新的 Base Sepolia dry-run。

## 2. 本次新增脚本

新增脚本：

```text
script/PrepareBaseSepoliaRc3SunMoonUsdcDryRun.s.sol
```

它会在本地或 Base Sepolia fork 里模拟：

```text
部署新的测试版 SunToken
部署新的测试版 SunCurve
部署新的测试版 MoonToken
部署新的测试版 MoonCurve
部署新的测试版 Create2HookDeployer
通过 CREATE2 部署 BaseSunMoonUsdcFeeV4Hook
把 SunCurve.moonAMM 指向新 Hook
计算 SUN/USDC 和 MOON/USDC 两个 v4 PoolKey / poolId
把两个池加入 Hook 白名单
按 1 SUN = 1 USDC 初始化 SUN/USDC
按 1 MOON = 0.24 USDC 初始化 MOON/USDC
模拟 renounceOwnership
验证 renounce 后不能再改白名单和协议经费地址
```

它不会做：

```text
不会调用 Base 主网
不会允许 Base 主网 chainId
不会接受 EXECUTE_BASE_SEPOLIA_RC3_BROADCAST=1
不会要求私钥
不会接触真实资金
```

## 3. 本地模拟命令

这一步不需要 RPC、不需要钱包、不需要私钥：

```powershell
forge script script/PrepareBaseSepoliaRc3SunMoonUsdcDryRun.s.sol
```

输出里要重点看：

```text
simulationOnly=true
broadcastRequested=false
USDC decimals=6
actualLow14Bits=204
SUN/USDC sqrtPriceAfter == SUN/USDC sqrtPriceX96
MOON/USDC sqrtPriceAfter == MOON/USDC sqrtPriceX96
sunUsdcAllowedAfter=true
moonUsdcAllowedAfter=true
ownerAfterRenounce=0x0000000000000000000000000000000000000000
renounceBlocksSunAllowlist=true
renounceBlocksMoonAllowlist=true
renounceBlocksProtocolBudget=true
```

## 4. Base Sepolia fork 只模拟命令

如果后续要连接 Base Sepolia RPC 做只读 / fork dry-run，命令形态如下。

注意：不加 `--broadcast`。

```powershell
$env:CONFIRM_BASE_SEPOLIA_RC3_DRY_RUN="1"
$env:EXECUTE_BASE_SEPOLIA_RC3_BROADCAST="0"
forge script script/PrepareBaseSepoliaRc3SunMoonUsdcDryRun.s.sol --rpc-url https://sepolia.base.org --rpc-timeout 120 --slow
```

这仍然不是测试网广播。它只是让脚本在 Base Sepolia 链环境中检查官方地址和模拟流程。

如果出现下面任意情况，停止：

```text
命令里出现 --broadcast
EXECUTE_BASE_SEPOLIA_RC3_BROADCAST 被设为 1
链 ID 是 Base mainnet 8453
USDC 不是 Base Sepolia 官方 USDC
Hook 地址低 14 位权限不是 204
两个池任一没有初始化成功
renounce 后还能修改白名单或协议经费地址
```

## 5. 和真正测试网广播的关系

rc3 dry-run 通过以后，下一步仍然不是直接广播。

真正进入 Base Sepolia 测试网广播前，还需要单独写广播步骤，并让 owner 明确批准类似下面的话：

```text
允许广播部署 rc3 测试版核心合约到 Base Sepolia
```

没有这类明确批准时，只能停留在本地模拟和 Base Sepolia fork dry-run。

## 6. 当前测试结果

本地脚本已直接运行通过：

```text
forge script script/PrepareBaseSepoliaRc3SunMoonUsdcDryRun.s.sol
Script ran successfully
simulationOnly=true
broadcastRequested=false
actualLow14Bits=204
sunUsdcAllowedAfter=true
moonUsdcAllowedAfter=true
ownerAfterRenounce=0x0000000000000000000000000000000000000000
renounceBlocksSunAllowlist=true
renounceBlocksMoonAllowlist=true
renounceBlocksProtocolBudget=true
```

新增专项测试：

```text
test/hooks/base/BaseSepoliaRc3SunMoonUsdcDryRunPreparation.t.sol
```

已验证：

```text
本地 rc3 dry-run 可以模拟部署新核心、统一 Hook、两个池、白名单、初始化和 renounce
Base Sepolia chainId 必须显式确认
Base mainnet chainId 会直接拒绝
广播开关会直接拒绝
Base Sepolia USDC 必须是官方测试 USDC
USDC decimals 必须是 6
fee 必须是 3000，tickSpacing 必须是 60
```

测试记录：

```text
forge test --match-path test/hooks/base/BaseSepoliaRc3SunMoonUsdcDryRunPreparation.t.sol --threads 1 --isolate
10 passed, 0 failed
```

全量测试记录：

```text
forge test --threads 1 --isolate
317 passed, 0 failed
```

Base Sepolia fork 只读 dry-run 记录：

```text
date=2026-05-18
command=forge script script/PrepareBaseSepoliaRc3SunMoonUsdcDryRun.s.sol --rpc-url https://sepolia.base.org --rpc-timeout 120 --slow
script_result=Script ran successfully
chainId=84532
baseSepoliaConfirmed=true
broadcastRequested=false
simulationOnly=true
POOL_MANAGER=0x05E73354cFDd6745C338b50BcFDfA3Aa6fA03408
STATE_VIEW=0x571291b572ed32ce6751a2Cb2486EbEe8DEfB9B4
USDC_TOKEN=0x036CbD53842c5426634e7929541eC2318f3dCF7e
USDC_DECIMALS=6
actualLow14Bits=204
hookSalt=0x00000000000000000000000000000000000000000000000000000000000095c0
predictedHook=0xcceD1a6C6f7E8210B9cEF6Ab8B3B59d62e2480Cc
SUN_USDC_POOL_ID=0xfce32214da284681d65059fa87ab5cf5dbf3af53e1d7afdcd78e9d7a6aad4a43
MOON_USDC_POOL_ID=0x1377ffa0adbb4dcd0be26eb97d703b4f590adee9a7ad72411ec7e75b6bfddf4a
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

这些地址和 poolId 是 fork 模拟结果，不代表 rc3 已经部署到 Base Sepolia。

## 7. 小白理解版结论

这一步相当于：

```text
先在电脑里演一遍 rc3 上测试网会发生什么
确认脚本不会误跑主网
确认没有广播权限时不会真的发交易
确认新 Hook 能同时准备 SUN/USDC 和 MOON/USDC 两个测试池
确认管理员放弃后不能再偷偷加池或改收款地址
```

它还没有把 rc3 真正部署到 Base Sepolia。
