# Base 主网 mainnet fork dry-run 草案 - 2026-05-16

本文档是 Base 主网分叉模拟草案，不是主网部署批准。

当前 owner 已提供 `MAINNET_DEPLOYER`、`MAINNET_ADMIN_WALLET`、`PROTOCOL_BUDGET_WALLET`、`CREATE2_DEPLOYER_OWNER` 四个普通钱包公开地址。本文仍只准备 dry-run 方案，不执行主网部署，不广播交易，不接真实资金，不收集私钥。

正式合约地址和 CREATE2 参数的依赖顺序见：

```text
docs/Base-主网正式合约地址与CREATE2参数草案-2026-05-17.md
```

## 1. 这一步要做什么

mainnet fork dry-run 的意思是：

```text
读取 Base 主网真实状态
在本地临时分叉环境里模拟部署、配置、初始化和放弃 owner
所有变化只存在本地模拟里
不会写入 Base 主网
```

它不是：

```text
不是主网部署
不是真实加池
不是真实 swap
不是转真实 USDC
不是让你提供私钥
```

## 2. 当前公开地址状态

已提供四个普通钱包公开地址，仍需最终复核。本阶段不编造、不替代、不用测试网地址凑数。

```text
MAINNET_DEPLOYER=0xC0b399aE61d3Fb14EFE865A0304f0FC4b52b7B7b
MAINNET_ADMIN_WALLET=0xD37BDC458EdCe7006dDd3ce03eEBF29d629B2D6B
PROTOCOL_BUDGET_WALLET=0x215F1F09b765C0e893E8D7A40d51Bceb40B733F4
CREATE2_DEPLOYER_OWNER=0xf28020011C5e35329A78Cc4bCb34b2cA20958380
```

普通钱包路线已经确认，四个普通钱包公开地址已提供；初始价格已按两个代币的初始铸造价格确认；核心合约地址、Hook salt、poolId、initial tick 和 sqrtPriceX96 已有预测计算值。2026-05-17 已跑通 Base mainnet fork 只模拟总 dry-run。注意：这不是主网部署，正式合约地址和池仍未真实部署；`CREATE2_HOOK_DEPLOYER` 当前只是预测地址，脚本只在本地 fork 里临时模拟它的代码。

## 3. 已确认的池参数输入

这 4 项已经是 owner 确认的草案输入，用于后续计算 `PoolKey -> poolId`：

```text
SUN_USDC_POOL_FEE=3000
SUN_USDC_TICK_SPACING=60
MOON_USDC_POOL_FEE=3000
MOON_USDC_TICK_SPACING=60
```

对应人话：

```text
两个池的 Uniswap LP fee 都是 0.3%
两个池的 tickSpacing 都是 60
```

owner 已确认的初始化价格口径：

```text
SUN_USDC_INITIAL_PRICE=1 SUN = 1 USDC
MOON_USDC_INITIAL_PRICE=1 MOON = 0.24 USDC
```

这两个价格后续要由脚本根据正式 token 地址排序，换算成 `INITIAL_TICK` 和 `SQRT_PRICE_X96`。

## 4. 已执行只模拟 dry-run，但仍不能部署的原因

现在已经可以用预测地址执行只模拟 dry-run，但还不能把它当成主网部署批准。原因是：

```text
SUN_TOKEN / MOON_TOKEN / SUN_CURVE / MOON_CURVE 仍是预测地址，未部署
CREATE2_HOOK_DEPLOYER 仍是预测地址，主网上还没有代码
BASE_SUN_MOON_USDC_FEE_V4_HOOK 仍是预测 Hook 地址，未部署
SUN/USDC 和 MOON/USDC 池只在本地 fork 里初始化过，主网上还没有创建
正式广播前仍需要人工复核、审计和 owner 另行明确批准
```

四个角色钱包公开地址、两个池的人类可读初始价格、核心合约预测地址、Hook salt 预测值、poolId 和初始化价格参数已提供，并已通过本地 fork 只模拟复核。下一步仍不是主网广播，而是整理审计输入和正式上线前人工复核清单。

## 5. 草案 dry-run 分阶段

### Stage 0：核心合约地址预测和配置模拟

目标：

```text
读取 MAINNET_DEPLOYER 当前 nonce
预测 SUN_TOKEN / SUN_CURVE / MOON_TOKEN / MOON_CURVE / CREATE2_HOOK_DEPLOYER
模拟 SunToken.setMinter(SunCurve)
模拟 SunCurve.setMoonCurve(MoonCurve)
模拟 MoonToken.setMinter(MoonCurve)
模拟核心合约 owner 最终转给 MAINNET_ADMIN_WALLET
确认 SunCurve.moonAMM 仍然是 address(0)，等待 Hook 正式确定后再绑定
```

对应脚本：

```text
script/PrepareBaseMainnetCoreDeployDryRun.s.sol
```

这一阶段只输出预测值和本地模拟结果，不部署主网，不广播交易。预测地址只有在 `MAINNET_DEPLOYER` 没有先发其他交易、且正式部署顺序不变时才成立。

### Stage A：只读官方基础设施检查

目标：

```text
确认 chainId == 8453
确认 Base mainnet USDC 地址等于 Circle 官方地址
确认 USDC decimals == 6
确认 Uniswap v4 PoolManager 有代码
确认 Uniswap v4 PositionManager 有代码
确认 StateView / Quoter / UniversalRouter 有代码
确认 Permit2 地址有代码
```

这一阶段只读，不需要项目钱包地址。

### Stage B：正式参数完整性检查

目标：

```text
确认所有 MAINNET_*_WALLET 只是公开地址
确认 PROTOCOL_BUDGET_WALLET 不等于 owner / deployer / CREATE2 owner
确认没有使用 Base Sepolia 地址
确认没有把私钥、助记词、RPC key 写进文档或脚本
```

这一阶段仍然不广播。

### Stage C：CREATE2 Hook 地址模拟

目标：

```text
使用正式构造参数计算 initCodeHash
搜索 HOOK_SALT
得到 PREDICTED_HOOK
确认 uint160(PREDICTED_HOOK) & 0x3fff == 204
在 fork 模拟环境部署 Hook
确认 deployedHook == predictedHook
确认 deployedHook.code.length > 0
```

这一步只是 fork 模拟，不是真实部署。

### Stage D：PoolKey 和 poolId 计算

目标：

```text
用正式 SUN_TOKEN / USDC / Hook 计算 SUN_USDC_POOL_ID
用正式 MOON_TOKEN / USDC / Hook 计算 MOON_USDC_POOL_ID
确认 fee=3000
确认 tickSpacing=60
确认 currency0 / currency1 排序正确
确认 poolId 由 PoolKey.toId() 计算，不手填
```

2026-05-17 已完成 Stage D 本地计算，不广播：

```text
SUN_USDC_CURRENCY0=0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913
SUN_USDC_CURRENCY1=0xbA010450885AadcDA402358d04be881Bd53E482b
SUN_USDC_POOL_ID=0xf0006d5dde476ffd2b43648468d5c6a6a8cf1f40bcac5c0c7d070491587e075a
SUN_USDC_INITIAL_TICK=276324
SUN_USDC_SQRT_PRICE_X96=79228162514264337593543950336000000

MOON_USDC_CURRENCY0=0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913
MOON_USDC_CURRENCY1=0xf3Bff3b498369022313aD55138ea41B236B61EBf
MOON_USDC_POOL_ID=0xcf29a02432e947fe9240fe4378cb871b24691f7cd85e7e8c72464ff89c1c6735
MOON_USDC_INITIAL_TICK=290595
MOON_USDC_SQRT_PRICE_X96=161723809515207654377831473576838109
```

说明：这些值仍基于预测地址，不是已部署池；`initialTick` 是由 `sqrtPriceX96` 推导出的当前 tick，不要求是 `tickSpacing=60` 的倍数。

### Stage E：Hook 白名单和费用路径模拟

目标：

```text
模拟 setAllowedSunUsdcPool(SUN_USDC_POOL_ID, true)
模拟 setAllowedMoonUsdcPool(MOON_USDC_POOL_ID, true)
确认 SUN/USDC swap 收 2% USDC
确认 1.5% USDC 进入 SunCurve.injectUSDT()
确认 0.5% USDC 进入 PROTOCOL_BUDGET_WALLET
确认 MOON/USDC swap 收 5% USDC
确认 3% USDC 进入 SunCurve.injectUSDT()
确认 2% USDC 进入 PROTOCOL_BUDGET_WALLET
```

### Stage F：池初始化和小额路径模拟

目标：

```text
用 owner 确认的 SUN/USDC 初始价格计算 sqrtPriceX96
用 owner 确认的 MOON/USDC 初始价格计算 sqrtPriceX96
在 fork 模拟 PoolManager.initialize()
模拟极小额流动性参数
模拟极小额 swap 路径
检查 slippage / minOut / fee split
```

注意：2026-05-17 已用预测地址在 Base mainnet fork 里只模拟执行 Stage F。两个池都只在本地 fork 里完成 `PoolManager.initialize()`，并用 `StateView` 复核了 `slot0.sqrtPriceX96` 和 `slot0.tick`；这不是主网已建池，也不是主网广播批准。

### Stage G：renounce 后不可管理检查

目标：

```text
模拟配置完成后 renounceOwnership()
确认 ownerAfterRenounce == address(0)
确认 renounce 后不能新增 SUN/USDC 白名单
确认 renounce 后不能新增 MOON/USDC 白名单
确认 renounce 后不能改协议经费地址
```

## 6. 脚本安全要求

已新增 Foundry 脚本草稿：

```text
script/PrepareBaseMainnetCoreDeployDryRun.s.sol
script/ComputeBaseMainnetSunMoonUsdcHookSalt.s.sol
script/PrepareBaseMainnetSunMoonUsdcForkDryRun.s.sol
```

这些脚本必须满足：

```text
脚本内部不允许调用 vm.startBroadcast
脚本必须拒绝 EXECUTE_BASE_MAINNET_BROADCAST=1
核心部署 dry-run 脚本必须要求 CONFIRM_BASE_MAINNET_CORE_DRY_RUN=1
Hook salt dry-run 脚本必须要求 CONFIRM_BASE_MAINNET_HOOK_SALT_DRY_RUN=1
Hook/fork 总 dry-run 脚本必须要求 CONFIRM_BASE_MAINNET_SUN_MOON_FORK_DRY_RUN=1
脚本必须拒绝非本地模拟、非 Base mainnet fork 的链
脚本必须打印 simulationOnly=true
```

核心合约地址预测 dry-run 命令草案，不广播：

```powershell
$env:MAINNET_DEPLOYER="0xC0b399aE61d3Fb14EFE865A0304f0FC4b52b7B7b"
$env:MAINNET_ADMIN_WALLET="0xD37BDC458EdCe7006dDd3ce03eEBF29d629B2D6B"
$env:PROTOCOL_BUDGET_WALLET="0x215F1F09b765C0e893E8D7A40d51Bceb40B733F4"
$env:CREATE2_DEPLOYER_OWNER="0xf28020011C5e35329A78Cc4bCb34b2cA20958380"
$env:CONFIRM_BASE_MAINNET_CORE_DRY_RUN="1"
$env:EXECUTE_BASE_MAINNET_BROADCAST="0"
forge script script/PrepareBaseMainnetCoreDeployDryRun.s.sol --rpc-url $env:BASE_MAINNET_RPC --rpc-timeout 120 --slow
```

Hook salt dry-run 命令草案，不广播：

```powershell
$env:MAINNET_ADMIN_WALLET="0xD37BDC458EdCe7006dDd3ce03eEBF29d629B2D6B"
$env:PROTOCOL_BUDGET_WALLET="0x215F1F09b765C0e893E8D7A40d51Bceb40B733F4"
$env:CREATE2_HOOK_DEPLOYER="0xFdc4c4FC0200ee27345B179E52348bA4a4aC97c0"
$env:POOL_MANAGER="0x498581fF718922c3f8e6A244956aF099B2652b2b"
$env:SUN_TOKEN="0xbA010450885AadcDA402358d04be881Bd53E482b"
$env:MOON_TOKEN="0xf3Bff3b498369022313aD55138ea41B236B61EBf"
$env:USDC_TOKEN="0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913"
$env:SUN_CURVE="0x4104250C9C2E19CCe8625D0c2972c5EaE035D83a"
$env:HOOK_SALT_START="0"
$env:HOOK_MAX_SALT_SEARCH="200000"
$env:CONFIRM_BASE_MAINNET_HOOK_SALT_DRY_RUN="1"
$env:EXECUTE_BASE_MAINNET_BROADCAST="0"
forge script script/ComputeBaseMainnetSunMoonUsdcHookSalt.s.sol --rpc-url $env:BASE_MAINNET_RPC --rpc-timeout 120 --slow
```

Hook/fork 总 dry-run 命令草案只能是这种形式：

```powershell
$env:CONFIRM_BASE_MAINNET_SUN_MOON_FORK_DRY_RUN='1'
$env:EXECUTE_BASE_MAINNET_BROADCAST='0'
forge script script/PrepareBaseMainnetSunMoonUsdcForkDryRun.s.sol --rpc-url $env:BASE_MAINNET_RPC --rpc-timeout 120 --slow
```

注意：2026-05-17 已执行 Hook/fork 总 dry-run，只在本地 Base mainnet fork 里模拟。因为 `CREATE2_HOOK_DEPLOYER=0xFdc4c4FC0200ee27345B179E52348bA4a4aC97c0` 主网上还没有代码，脚本输出 `create2DeployerSimulated=true`，表示它只在本地 fork 里临时模拟 CREATE2 部署工具，不代表主网已部署。

禁止：

```text
不要加 --broadcast
不要传 PRIVATE_KEY
不要使用真实资金
不要在命令里写带密钥的完整 RPC URL
```

## 7. dry-run 输出应该长什么样

未来 dry-run 输出必须至少包含：

```text
simulationOnly=true
chainId=8453
USDC decimals=6
transactionsPlanned=6
create2DeployerSimulated=true
predictedSunToken=...
predictedSunCurve=...
predictedMoonToken=...
predictedMoonCurve=...
predictedCreate2HookDeployer=...
hookExpectedLow14Bits=204
predictedHook=...
deployedHookSimulation=...
sunUsdcPoolId=...
moonUsdcPoolId=...
sunUsdcFeeToSunCurve=1.5% USDC
sunUsdcFeeToProtocol=0.5% USDC
sunUsdcInitialTick=...
sunUsdcSqrtPriceX96=...
sunUsdcSqrtPriceAfter=...
moonUsdcFeeToSunCurve=3% USDC
moonUsdcFeeToProtocol=2% USDC
moonUsdcInitialTick=...
moonUsdcSqrtPriceX96=...
moonUsdcSqrtPriceAfter=...
ownerBeforeRenounce=MAINNET_ADMIN_WALLET
ownerAfterRenounce=address(0)
renounceBlocksSunAllowlist=true
renounceBlocksMoonAllowlist=true
renounceBlocksProtocolBudget=true
```

2026-05-17 已执行 Stage 0 Base mainnet fork dry-run，不广播：

```text
chainId=8453
simulationOnly=true
broadcastRequested=false
MAINNET_DEPLOYER_NONCE=0
PREDICTED_SUN_TOKEN=0xbA010450885AadcDA402358d04be881Bd53E482b
PREDICTED_SUN_CURVE=0x4104250C9C2E19CCe8625D0c2972c5EaE035D83a
PREDICTED_MOON_TOKEN=0xf3Bff3b498369022313aD55138ea41B236B61EBf
PREDICTED_MOON_CURVE=0x5de55E74728f42e0265cd712aA54d9b7D532D38d
PREDICTED_CREATE2_HOOK_DEPLOYER=0xFdc4c4FC0200ee27345B179E52348bA4a4aC97c0
```

这些仍然只是预测地址，不是已部署地址；只要 `MAINNET_DEPLOYER` nonce 或正式部署顺序变化，就必须重跑。

2026-05-17 已执行 Stage C Hook salt Base mainnet fork dry-run，不广播：

```text
chainId=8453
simulationOnly=true
broadcastRequested=false
CREATE2_HOOK_DEPLOYER=0xFdc4c4FC0200ee27345B179E52348bA4a4aC97c0
POOL_MANAGER=0x498581fF718922c3f8e6A244956aF099B2652b2b
SUN_TOKEN=0xbA010450885AadcDA402358d04be881Bd53E482b
MOON_TOKEN=0xf3Bff3b498369022313aD55138ea41B236B61EBf
USDC_TOKEN=0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913
USDC_DECIMALS=6
SUN_CURVE=0x4104250C9C2E19CCe8625D0c2972c5EaE035D83a
INIT_CODE_HASH=0x5429970db38722cd42a8728003452178fd22f9df318261160bcc97702b5823f1
HOOK_SALT=0x0000000000000000000000000000000000000000000000000000000000001f79
PREDICTED_HOOK=0x04f968dE5cd57B1EB8215a9a488dC32508Fb80cc
EXPECTED_HOOK_MASK=204
ACTUAL_LOW_14_BITS=204
```

这仍然只是预测 Hook 地址，不是已部署地址；只要 Hook 代码、构造参数、`CREATE2_HOOK_DEPLOYER` 或上游核心预测地址变化，就必须重跑。

2026-05-17 已执行 Hook/fork 总 dry-run，不广播：

```text
Script ran successfully
chainId=8453
simulationOnly=true
broadcastRequested=false
transactionsPlanned=6
create2DeployerSimulated=true
predictedHook=0x04f968dE5cd57B1EB8215a9a488dC32508Fb80cc
deployedHookSimulation=0x04f968dE5cd57B1EB8215a9a488dC32508Fb80cc
SUN_USDC_POOL_ID=0xf0006d5dde476ffd2b43648468d5c6a6a8cf1f40bcac5c0c7d070491587e075a
SUN_USDC_INITIAL_TICK=276324
SUN_USDC_SQRT_PRICE_X96=79228162514264337593543950336000000
SUN_USDC_SQRT_PRICE_BEFORE=0
SUN_USDC_SQRT_PRICE_AFTER=79228162514264337593543950336000000
MOON_USDC_POOL_ID=0xcf29a02432e947fe9240fe4378cb871b24691f7cd85e7e8c72464ff89c1c6735
MOON_USDC_INITIAL_TICK=290595
MOON_USDC_SQRT_PRICE_X96=161723809515207654377831473576838109
MOON_USDC_SQRT_PRICE_BEFORE=0
MOON_USDC_SQRT_PRICE_AFTER=161723809515207654377831473576838109
sunUsdcAllowedAfter=true
moonUsdcAllowedAfter=true
ownerAfterRenounce=0x0000000000000000000000000000000000000000
renounceBlocksSunAllowlist=true
renounceBlocksMoonAllowlist=true
renounceBlocksProtocolBudget=true
```

这一步只是把主网状态复制到本地 fork 后演练，不会写回 Base 主网。`create2DeployerSimulated=true` 是刻意保守的提示：预测的 CREATE2 部署工具还没有真的在主网上部署。

## 8. 停止条件

出现任何一条，立即停止：

- 任何必需公开地址仍然 `待填`，却有人要求跑最终 dry-run。
- 有人要求提供私钥、助记词或恢复词。
- 有人要求加 `--broadcast`。
- 有人要求用 Base Sepolia 地址顶替 Base mainnet 地址。
- 官方 Base / Circle / Uniswap 地址复核失败。
- Hook 地址低 14 位不是 `204`。
- poolId 不是由 `PoolKey.toId()` 计算。
- `PROTOCOL_BUDGET_WALLET` 被填成 owner 或管理员。
- renounce 后仍能新增白名单或改协议经费地址。

## 9. 当前结论

本阶段已经完成：

```text
mainnet fork dry-run 草案已准备
只模拟、不广播的核心部署 dry-run 脚本草稿已新增
核心部署 Stage 0 已用 Base mainnet fork 跑通，已输出预测核心地址
Hook salt Stage C 已用 Base mainnet fork 跑通，已输出 HOOK_SALT 和 PREDICTED_HOOK
Stage D 已用本地脚本算出两个池的 poolId、initialTick 和 sqrtPriceX96
Hook/fork 总 dry-run 已用 Base mainnet fork 只模拟跑通
两个池已在本地 fork 里模拟 initialize，并复核 slot0
renounce 后不能新增白名单或修改协议经费地址，已在本地 fork 里复核
只模拟、不广播的 Foundry 脚本已新增
脚本测试已通过：BaseMainnetCoreDeployDryRunPreparationTest，11 passed
脚本测试已通过：BaseMainnetSunMoonUsdcHookSaltPreparationTest，10 passed
脚本测试已通过：BaseSunMoonUsdcPoolIdsPreparationTest，7 passed
脚本测试已通过：BaseMainnetSunMoonUsdcForkDryRunPreparationTest，15 passed
全量 Foundry 测试已通过：296 passed，0 failed
四个角色钱包公开地址已填写，仍需最终复核
初始价格已确认：SUN/USDC = 1，MOON/USDC = 0.24
正式合约地址仍未部署，主网池仍未真实创建
CREATE2_HOOK_DEPLOYER 当前只是预测地址；总 dry-run 里是本地 fork 临时模拟代码
不部署主网
不广播交易
不接真实资金
不索要私钥
```

下一步不是主网部署。下一步应整理审计输入包和正式上线前人工复核清单；任何真实主网广播都必须在审计、复核和 owner 另行明确批准之后，且仍不能索要私钥。
