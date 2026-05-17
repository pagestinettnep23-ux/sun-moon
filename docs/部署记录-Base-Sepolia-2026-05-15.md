# 部署记录 - Base Sepolia - 2026-05-15

本记录只涉及 Base Sepolia 测试网。没有部署 Base 主网，没有接触真实资金，也没有在聊天或文档中记录私钥、助记词或完整 RPC key。

## 概览

```text
chainId=84532
deployer=0x2F6E887c6058deE520f9468a1022E3480A6334D3
owner=0x6E22b2e6fFAA30Fe75B71d53d1eC469b4e97A986
protocolBudget=0x277ba3Cf597CdAaF958C301db3cF6a631F793039
USDC=0x036CbD53842c5426634e7929541eC2318f3dCF7e
CREATE2_DEPLOYER=0xE5Df76A1DF2e959C70c8b7591754a3a2a542Fb6D
```

## 第二次小额广播结果

```text
SUN_TOKEN=0xDa5a62F1c2c54AB79c974eE41b9a5B83Dd307e41
SUN_CURVE=0x00F49621977e5219093A988879F07936F2155c07
MOON_TOKEN=0x6E7FF34C7a7a518981BF6324e5FCC6599FcBC59D
MOON_CURVE=0x7f4296686917Be97E826DC790c367d93585A32c3
SWAP_ADAPTER=0x50f232d1B40D9EF523cc53f958f8C80766aF35a7
DEPLOYER_NONCE_AFTER=14
DEPLOYER_BALANCE_AFTER=0.010063856527981176
```

本次广播共 13 笔交易，receipt 均为 `status=0x1`。广播 artifact：

```text
broadcast/PrepareBaseSepoliaTestDeploy.s.sol/84532/run-latest.json
```

## 交易哈希

```text
SunToken deploy:           0xd9a4e6645d9dcab6f0d5310d72a9ce638715791b41494ed79cf20e233f2928ac
SunCurve deploy:           0x8d103ac83a28f1e05db2c71f3a61daf51adcf664ce67cbd1b16cb3c9185b4f8d
MoonToken deploy:          0x6a9fdfd17914a5f8e78f7acd4e574b12a65de231ad5a34141a3788edbdcd306a
MoonCurve deploy:          0x0a15be63b1135758681998da69158199cee43c5591b975bea01600661b769898
TestnetUsdcAdapter deploy: 0x470d6ec345977c64a5f5f95151a1ef3a2e9a2e8920980db82978a0c8b2693db0
Final ownership tx:        0x47d262a0ec7ccb1e2470112ad2e363929e2ed0f79b1ad074dc1a71d4971f6e46
```

完整 13 笔交易哈希保存在 Foundry broadcast artifact 中。

## 链上复核

```text
SunToken.owner           = 0x6E22b2e6fFAA30Fe75B71d53d1eC469b4e97A986
SunToken.minter          = 0x00F49621977e5219093A988879F07936F2155c07
SunCurve.owner           = 0x6E22b2e6fFAA30Fe75B71d53d1eC469b4e97A986
SunCurve.sunToken        = 0xDa5a62F1c2c54AB79c974eE41b9a5B83Dd307e41
SunCurve.usdt            = 0x036CbD53842c5426634e7929541eC2318f3dCF7e
SunCurve.protocolBudget  = 0x277ba3Cf597CdAaF958C301db3cF6a631F793039
SunCurve.moonCurve       = 0x7f4296686917Be97E826DC790c367d93585A32c3
SunCurve.moonAMM         = 0x0000000000000000000000000000000000000000
MoonToken.owner          = 0x6E22b2e6fFAA30Fe75B71d53d1eC469b4e97A986
MoonToken.minter         = 0x7f4296686917Be97E826DC790c367d93585A32c3
MoonCurve.owner          = 0x6E22b2e6fFAA30Fe75B71d53d1eC469b4e97A986
MoonCurve.moonToken      = 0x6E7FF34C7a7a518981BF6324e5FCC6599FcBC59D
MoonCurve.sunToken       = 0xDa5a62F1c2c54AB79c974eE41b9a5B83Dd307e41
MoonCurve.sunCurve       = 0x00F49621977e5219093A988879F07936F2155c07
MoonCurve.protocolBudget = 0x277ba3Cf597CdAaF958C301db3cF6a631F793039
Adapter.owner            = 0x6E22b2e6fFAA30Fe75B71d53d1eC469b4e97A986
Adapter.usdc             = 0x036CbD53842c5426634e7929541eC2318f3dCF7e
Adapter.authorizedHook   = 0x6E22b2e6fFAA30Fe75B71d53d1eC469b4e97A986
Adapter.paused           = false
```

说明：第二次广播后 `Adapter.authorizedHook` 仍是临时 `HOOK_OWNER`；后续 Hook 部署和绑定广播已把 adapter 授权切换到真实 Hook，并设置 `SunCurve.moonAMM`。

## 已完成的下一步

```powershell
forge script script/FindBaseMoonAmmFeeV4HookSalt.s.sol
forge script script/CheckBaseSepoliaDeploymentParams.s.sol
```

## CREATE2 Hook 预检 - 2026-05-15

已使用以上真实测试网地址运行 CREATE2 salt 搜索和 Base Sepolia 参数预检：

```text
CREATE2_DEPLOYER=0xE5Df76A1DF2e959C70c8b7591754a3a2a542Fb6D
initCodeHash=0x306f254e5c441292e737d706681684bdcf210fecb5f71e35074fbd649a975bd4
HOOK_SALT=0x00000000000000000000000000000000000000000000000000000000000022b9
PREDICTED_HOOK=0xF612828Ba9dE01CF16Fae2D8EE187B0cA59100Cc
expectedHookMask=204
actualHookMask=204
```

Base Sepolia 只读复核：

```text
PredictedHook.code = 0x
Create2Deployer.code = non-empty
Create2Deployer.owner = 0x6E22b2e6fFAA30Fe75B71d53d1eC469b4e97A986
PoolManager.code = non-empty
PositionManager.code = non-empty
UniversalRouter.code = non-empty
USDC.code = non-empty
```

## Hook 部署 dry-run - 2026-05-15

已新增并运行 `script/PrepareBaseSepoliaHookDeploy.s.sol`，不带 `--broadcast`，未发送交易：

```text
chainId=84532
baseSepoliaConfirmed=true
CREATE2_DEPLOYER=0xE5Df76A1DF2e959C70c8b7591754a3a2a542Fb6D
Create2Deployer.owner=0x6E22b2e6fFAA30Fe75B71d53d1eC469b4e97A986
HOOK_OWNER / tx sender=0x6E22b2e6fFAA30Fe75B71d53d1eC469b4e97A986
HOOK_SALT=0x00000000000000000000000000000000000000000000000000000000000022b9
initCodeHash=0x306f254e5c441292e737d706681684bdcf210fecb5f71e35074fbd649a975bd4
PREDICTED_HOOK=0xF612828Ba9dE01CF16Fae2D8EE187B0cA59100Cc
DEPLOYED_HOOK_DRY_RUN=0xF612828Ba9dE01CF16Fae2D8EE187B0cA59100Cc
expectedHookMask=204
actualLow14Bits=204
estimatedRequiredEth=0.000030782763
```

`HOOK_OWNER` 只读余额检查：

```text
HOOK_OWNER_BALANCE=0.002
HOOK_OWNER_NONCE=0
```

## Hook 小额广播 - 2026-05-15

用户已明确批准“允许广播部署 Hook 到 Base Sepolia”。本次只部署 `BaseMoonAmmFeeV4Hook`，不绑定 adapter，不设置 `SunCurve.moonAMM`，不连接 Base 主网。

```text
HOOK_DEPLOY_TX=0x376baf6403018674a6b61bc4b84324e13fc7fafcb8c1970c8f15b06215e59e17
receiptStatus=0x1
blockNumber=41507301
gasUsed=1913459
from=0x6E22b2e6fFAA30Fe75B71d53d1eC469b4e97A986
to=0xE5Df76A1DF2e959C70c8b7591754a3a2a542Fb6D
HOOK_DEPLOYED=0xF612828Ba9dE01CF16Fae2D8EE187B0cA59100Cc
HOOK_OWNER_BALANCE_AFTER=0.001988519245970799
HOOK_OWNER_NONCE_AFTER=1
```

链上复核：

```text
Hook.code               = non-empty
Hook.owner              = 0x6E22b2e6fFAA30Fe75B71d53d1eC469b4e97A986
Hook.poolManager        = 0x05E73354cFDd6745C338b50BcFDfA3Aa6fA03408
Hook.moonToken          = 0x6E7FF34C7a7a518981BF6324e5FCC6599FcBC59D
Hook.usdt               = 0x036CbD53842c5426634e7929541eC2318f3dCF7e
Hook.sunCurve           = 0x00F49621977e5219093A988879F07936F2155c07
Hook.protocolBudget     = 0x277ba3Cf597CdAaF958C301db3cF6a631F793039
Hook.swapAdapter        = 0x50f232d1B40D9EF523cc53f958f8C80766aF35a7
Hook.expectedHookMask   = 204
Hook.paused             = false
Adapter.authorizedHook  = 0x6E22b2e6fFAA30Fe75B71d53d1eC469b4e97A986
SunCurve.moonAMM        = 0x0000000000000000000000000000000000000000
```

说明：Hook 刚部署后 `Adapter.authorizedHook` 仍是临时 `HOOK_OWNER`，`SunCurve.moonAMM` 仍为空；后续绑定 dry-run 和绑定广播已在下面两节完成。

## Hook 权限绑定 dry-run - 2026-05-15

已新增并运行 `script/PrepareBaseSepoliaHookBinding.s.sol`，不带 `--broadcast`，未发送交易。

dry-run 前链上状态：

```text
Adapter.authorizedHook = 0x6E22b2e6fFAA30Fe75B71d53d1eC469b4e97A986
SunCurve.moonAMM       = 0x0000000000000000000000000000000000000000
```

dry-run 模拟结果：

```text
chainId=84532
baseSepoliaConfirmed=true
HOOK_OWNER / tx sender=0x6E22b2e6fFAA30Fe75B71d53d1eC469b4e97A986
HOOK_ADDRESS=0xF612828Ba9dE01CF16Fae2D8EE187B0cA59100Cc
SWAP_ADAPTER=0x50f232d1B40D9EF523cc53f958f8C80766aF35a7
SUN_CURVE=0x00F49621977e5219093A988879F07936F2155c07
adapterAuthorizedHookBefore=0x6E22b2e6fFAA30Fe75B71d53d1eC469b4e97A986
sunCurveMoonAMMBefore=0x0000000000000000000000000000000000000000
adapterAuthorizedHookAfter=0xF612828Ba9dE01CF16Fae2D8EE187B0cA59100Cc
sunCurveMoonAMMAfter=0xF612828Ba9dE01CF16Fae2D8EE187B0cA59100Cc
transactionsPlanned=2
estimatedGasUsed=109501
estimatedRequiredEth=0.000001204511
```

dry-run artifact：

```text
broadcast/PrepareBaseSepoliaHookBinding.s.sol/84532/dry-run/run-latest.json
```

说明：上面的 `adapterAuthorizedHookAfter` 与 `sunCurveMoonAMMAfter` 是 Foundry dry-run 的模拟结果；用户明确批准后，已在下一节广播两笔绑定交易并复核通过。

最新全量 Foundry 测试：

```text
222 tests passed, 0 failed
```

## Hook 权限绑定小额广播 - 2026-05-15

用户已明确批准“允许广播绑定 Hook 权限到 Base Sepolia”。本次只执行两笔配置交易，不部署新合约，不连接 Base 主网，不接触真实资金：

```text
TestnetUsdcAdapter.setAuthorizedHook(Hook)
SunCurve.setMoonAMM(Hook)
```

交易结果：

```text
BIND_ADAPTER_TX=0x1319e675384b1e014debdb806a27915797bbd0cf8da9e253f04b1cc643ef97c4
BIND_ADAPTER_RECEIPT_STATUS=0x1
BIND_ADAPTER_BLOCK=41522501
BIND_ADAPTER_GAS_USED=30147

BIND_SUN_CURVE_TX=0x6a6154f5e075f4b6d0975c4b60e1d517885adccb4577eb678134f4cc3966ed7c
BIND_SUN_CURVE_RECEIPT_STATUS=0x1
BIND_SUN_CURVE_BLOCK=41522502
BIND_SUN_CURVE_GAS_USED=47358
```

广播后链上复核：

```text
Adapter.authorizedHook = 0xF612828Ba9dE01CF16Fae2D8EE187B0cA59100Cc
SunCurve.moonAMM       = 0xF612828Ba9dE01CF16Fae2D8EE187B0cA59100Cc
transactionsPlanned    = 0
```

说明：Hook 权限绑定已经完成。下一步不是重新部署，也不是 Base 主网；受控测试池 `poolId` 计算和白名单 dry-run 已在下一节完成，仍然只使用 Base Sepolia / Mock / dry-run。

## 受控 MOON/USDC 测试池 dry-run - 2026-05-15

已新增并运行 `script/PrepareBaseSepoliaControlledMoonPool.s.sol`，不带 `--broadcast`，未发送交易。本步骤只计算完整 v4 `PoolKey` 对应的 `poolId`，并 dry-run 把该 `poolId` 加入 Hook 白名单。

PoolKey：

```text
currency0=0x036CbD53842c5426634e7929541eC2318f3dCF7e
currency1=0x6E7FF34C7a7a518981BF6324e5FCC6599FcBC59D
fee=3000
tickSpacing=60
hooks=0xF612828Ba9dE01CF16Fae2D8EE187B0cA59100Cc
```

dry-run 结果：

```text
poolId=0xfbb4ccec5e3fda3a97b9e2619e9e90588ad5e444bdb3d488e921a3192c42dd55
allowedMoonPoolBefore=false
allowedMoonPoolAfter=true
transactionsPlanned=1
estimatedGasUsed=67030
estimatedRequiredEth=0.00000073733
```

说明：`allowedMoonPoolAfter=true` 是 Foundry dry-run 的模拟结果，真实链上结果以广播 receipt 和 `cast call` 复核为准。

## 受控 MOON/USDC 测试池白名单广播 - 2026-05-15

用户已明确批准“允许广播白名单 MOON/USDC 测试池到 Base Sepolia”。本次只执行一笔配置交易，不部署新合约，不连接 Base 主网，不接触真实资金：

```text
BaseMoonAmmFeeV4Hook.setAllowedMoonPool(poolId, true)
```

交易结果：

```text
ALLOW_MOON_USDC_POOL_TX=0x9f219d37f1a72dc6229df79217ed953f1e6ff01ed1f4d958854fe432616ed325
ALLOW_MOON_USDC_POOL_RECEIPT_STATUS=1
ALLOW_MOON_USDC_POOL_BLOCK=41524110
ALLOW_MOON_USDC_POOL_GAS_USED=45833
from=0x6E22b2e6fFAA30Fe75B71d53d1eC469b4e97A986
to=0xF612828Ba9dE01CF16Fae2D8EE187B0cA59100Cc
```

广播后链上复核：

```text
allowedMoonPools(0xfbb4ccec5e3fda3a97b9e2619e9e90588ad5e444bdb3d488e921a3192c42dd55)=true
```

操作提示修正：以后需要用户输入私钥时，必须写明具体地址，例如“请输入 `HOOK_OWNER=0x6E22b2e6fFAA30Fe75B71d53d1eC469b4e97A986` 对应的钱包私钥”，不能只写角色名。

## 受控 MOON/USDC 测试池初始化 dry-run - 2026-05-15

已新增并运行 `script/PrepareBaseSepoliaControlledMoonPoolInitialize.s.sol`，不带 `--broadcast`，未发送交易。本步骤只准备官方 v4 `PoolManager.initialize(poolKey, sqrtPriceX96)`。

初始化参数：

```text
POOL_INITIALIZER=0x6E22b2e6fFAA30Fe75B71d53d1eC469b4e97A986
POOL_MANAGER=0x05E73354cFDd6745C338b50BcFDfA3Aa6fA03408
STATE_VIEW=0x571291b572ed32ce6751a2Cb2486EbEe8DEfB9B4
poolId=0xfbb4ccec5e3fda3a97b9e2619e9e90588ad5e444bdb3d488e921a3192c42dd55
initialTick=276300
sqrtPriceX96=79133045881256921541446514419412387
humanPriceApprox=1 MOON ~= 1.0024 USDC
```

dry-run 结果：

```text
allowedMoonPool=true
sqrtPriceBefore=0
alreadyInitialized=false
transactionsPlanned=1
sqrtPriceAfter=79133045881256921541446514419412387
tickAfter=276300
estimatedGasUsed=76343
estimatedRequiredEth=0.000000839773
```

说明：上方是广播前 dry-run 记录，用来证明初始化前 `sqrtPriceBefore=0`，且只计划 1 笔初始化交易。需要输入私钥时必须写明：请输入 `POOL_INITIALIZER=0x6E22b2e6fFAA30Fe75B71d53d1eC469b4e97A986` 对应的钱包私钥。

## 受控 MOON/USDC 测试池初始化广播 - 2026-05-15

用户已明确批准“允许广播初始化 MOON/USDC 测试池到 Base Sepolia”。本次只执行一笔官方 v4 `PoolManager.initialize(poolKey, sqrtPriceX96)` 交易，不部署新合约，不连接 Base 主网，不接触真实资金。

交易结果：

```text
MOON_USDC_INITIALIZE_TX=0x72c93bb0a5bdb540b2e696eaff50614e4571cfe1dbe3bb64494ec9719cdc8310
MOON_USDC_INITIALIZE_RECEIPT_STATUS=1
MOON_USDC_INITIALIZE_BLOCK=41525115
MOON_USDC_INITIALIZE_GAS_USED=52201
from=0x6E22b2e6fFAA30Fe75B71d53d1eC469b4e97A986
to=0x05E73354cFDd6745C338b50BcFDfA3Aa6fA03408
```

广播后链上复核：

```text
allowedMoonPools(0xfbb4ccec5e3fda3a97b9e2619e9e90588ad5e444bdb3d488e921a3192c42dd55)=true
StateView.getSlot0(poolId).sqrtPriceX96=79133045881256921541446514419412387
StateView.getSlot0(poolId).tick=276300
StateView.getSlot0(poolId).protocolFee=0
StateView.getSlot0(poolId).lpFee=3000
```

广播后重新运行初始化准备脚本，脚本识别池子已经按同一价格初始化：

```text
alreadyInitialized=true
transactionsPlanned=0
sqrtPriceAfter=79133045881256921541446514419412387
tickAfter=276300
```

说明：受控 `MOON/USDC` 测试池初始化已经完成。随后已进入极小额流动性/交换演练准备 dry-run；仍不是 Base 主网，也不是接真实资金。

## 极小额 MOON/USDC 流动性/交换演练准备 dry-run - 2026-05-15

已新增并运行 `script/PrepareBaseSepoliaTinyMoonUsdcRehearsal.s.sol`，不带 `--broadcast`，未发送交易。本步骤只读检查链上配置、演练账户余额和 Permit2 授权。

核心链上复核：

```text
REHEARSAL_ACTOR=0x6E22b2e6fFAA30Fe75B71d53d1eC469b4e97A986
POSITION_MANAGER=0x4B2C77d209D3405F41a037Ec6c77F7F5b8e2ca80
UNIVERSAL_ROUTER=0x492E6456D9528771018DeB9E87ef7750EF184104
PERMIT2=0x000000000022D473030F116dDEE9F6B43aC78BA3
poolInitialized=true
slot0.sqrtPriceX96=79133045881256921541446514419412387
slot0.tick=276300
slot0.protocolFee=0
slot0.lpFee=3000
allowedMoonPool=true
hookPaused=false
adapterAuthorized=true
sunCurveBound=true
protocolBudgetConfigured=true
```

极小额计划：

```text
tinyLiquidityUsdcAmount=1000000
tinyLiquidityMoonAmount=1000000000000000000
tinySwapUsdcIn=100000
swapFeeToSunCurve=3000
swapFeeToProtocol=2000
swapUsdcGrossInputWithHookFee=105000
swapMinUsdcToCurve=3000
swapHookData=0x0000000000000000000000000000000000000000000000000000000000000bb8
zeroForOneUsdcToMoon=true
```

演练账户当前状态：

```text
actorUsdcBalance=0
actorMoonBalance=0
actorUsdcAllowanceToPermit2=0
actorMoonAllowanceToPermit2=0
actorUsdcPermit2ToPositionManager=0
actorMoonPermit2ToPositionManager=0
actorUsdcPermit2ToUniversalRouter=0
readyForLiquidityDryRun=false
readyForSwapDryRun=false
readyForCombinedDryRun=false
transactionsPlanned=0
```

说明：链上配置已满足下一阶段前提，但测试账户还没有极小额测试 USDC/MOON，也没有 Permit2 授权。下一步仍不广播；需要先准备测试资产和授权。任何需要输入私钥的步骤都必须写明具体地址：请输入 `REHEARSAL_ACTOR=0x6E22b2e6fFAA30Fe75B71d53d1eC469b4e97A986` 对应的钱包私钥。

## 极小额资产与 Permit2 授权准备 dry-run - 2026-05-15

已新增并运行 `script/PrepareBaseSepoliaTinyRehearsalAssets.s.sol`，不带 `--broadcast`，未发送交易。本步骤只读检查测试资产准备和 Permit2 授权是否可执行。

默认准备计划：

```text
REHEARSAL_ACTOR=0x6E22b2e6fFAA30Fe75B71d53d1eC469b4e97A986
sunMintUsdcAmount=500000
moonMintSunAmount=300000000000000000
projectedSunOut=490000000000000000
projectedMoonOut=1187499858980000000
requiredUsdcForRehearsal=1105000
requiredUsdcBeforeAssetPrep=1605000
```

演练账户当前状态：

```text
actorUsdcBalance=0
actorSunBalance=0
actorMoonBalance=0
usdcAllowanceToSunCurve=0
sunAllowanceToMoonCurve=0
usdcAllowanceToPermit2=0
moonAllowanceToPermit2=0
usdcPermit2ToPositionManager=0
moonPermit2ToPositionManager=0
usdcPermit2ToUniversalRouter=0
canExecuteAssetPrep=false
transactionsPlanned=9
transactionsExecuted=0
```

## 极小额资产与 Permit2 授权广播复核 - 2026-05-15

用户已准备 Base Sepolia 测试 USDC，并明确批准“允许广播准备测试资产和 Permit2 授权到 Base Sepolia”。本次只为 `REHEARSAL_ACTOR=0x6E22b2e6fFAA30Fe75B71d53d1eC469b4e97A986` 准备后续小额演练资产和授权，不连接 Base 主网，不接触真实资金。

广播后链上复核：

```text
actorUsdcBalance=19500000
actorSunBalance=190000000000000000
actorMoonBalance=1187499858980000000
usdcAllowanceToPermit2=max
moonAllowanceToPermit2=max
usdcPermit2ToPositionManager=max uint160
moonPermit2ToPositionManager=max uint160
usdcPermit2ToUniversalRouter=max uint160
transactionsPlannedAfter=0
```

说明：资产/授权准备已完成。后续若需要输入私钥，必须写明具体地址：请输入 `REHEARSAL_ACTOR=0x6E22b2e6fFAA30Fe75B71d53d1eC469b4e97A986` 对应的钱包私钥。

## 极小额 MOON/USDC 报价预检 - 2026-05-15

已新增并运行 `script/PrecheckBaseSepoliaTinyMoonUsdcQuote.s.sol`，不带 `--broadcast`，未发送交易。本步骤在 Base Sepolia fork 本地模拟：

1. 复用准备脚本检查链上配置、余额和 Permit2 授权。
2. 临时模拟 mint 一个 `MOON/USDC` 流动性头寸。
3. 调用 Base Sepolia v4 Quoter 对 `0.1 USDC -> MOON` 做报价。

预检结果：

```text
REHEARSAL_ACTOR=0x6E22b2e6fFAA30Fe75B71d53d1eC469b4e97A986
QUOTER=0x4A6513c898fe1B2d0E78d3b0e0A4a151589B1cBa
poolId=0xfbb4ccec5e3fda3a97b9e2619e9e90588ad5e444bdb3d488e921a3192c42dd55
currentTick=276300
tickLower=275700
tickUpper=276900
liquidity=33796876514319
usdcSpentForLiquidity=1000000
moonSpentForLiquidity=997600359915023894
swapUsdcIn=100000
swapFeeToSunCurve=3000
swapFeeToProtocol=2000
swapUsdcGrossInputWithHookFee=105000
quoteMoonOut=94223974497341879
quoteGasEstimate=198242
suggestedMinMoonOut=84801577047607691
readinessPassed=true
liquiditySimulationPassed=true
quoteSimulationPassed=true
readyForTinyBroadcast=true
```

说明：小额流动性和报价路径已在 fork 里跑通。后续已继续准备真实小额加流动性 + swap 广播命令草案和最终 dry-run；仍不是 Base 主网。

说明：上方资产准备 dry-run 是广播前历史记录；后续测试 USDC 已到账，资产/Permit2 授权广播已完成并复核通过。

## 极小额 MOON/USDC 流动性 + swap 广播草案 dry-run - 2026-05-15

已新增并运行 `script/PrepareBaseSepoliaTinyMoonUsdcBroadcast.s.sol`，未带 `--broadcast`，未发送真实交易。本步骤在 Base Sepolia fork 本地模拟两笔后续可能广播的测试网交易：

```text
1. PositionManager.modifyLiquidities(...) 添加极小额 MOON/USDC 流动性
2. UniversalRouter.execute(...) 执行 0.1 USDC -> MOON swap
```

草案修正记录：

```text
Base Sepolia UniversalRouter 当前 v4 swap 路径需要旧版 5 字段 struct 参数编码。
已将草案中的 legacy swap params 从裸字段编码修正为单个 struct 编码。
对应测试：BaseSepoliaTinyMoonUsdcBroadcastPreparationTest
```

组合 dry-run 结果：

```text
REHEARSAL_ACTOR=0x6E22b2e6fFAA30Fe75B71d53d1eC469b4e97A986
readyForTinyBroadcast=true
transactionsPlanned=2
transactionsExecuted=2
liquidity=33796876514319
positionTokenId=22353
positionLiquidityAfterMint=33796876514319
swapUsdcIn=100000
swapFeeToSunCurve=3000
swapFeeToProtocol=2000
swapUsdcGrossInputWithHookFee=105000
quoteMoonOut=94223974497341879
minMoonOut=84801577047607691
actorUsdcBalanceAfter=18400000
actorMoonBalanceAfter=284123473562317985
estimatedTotalGasUsed=968383
estimatedRequiredEth=0.000010652213
```

回归测试：

```text
forge test --match-path test/hooks/base/BaseSepoliaTinyMoonUsdcBroadcastPreparation.t.sol -vvv
3 passed, 0 failed
```

## 极小额 MOON/USDC 流动性 + swap 广播 - 2026-05-15

用户已明确批准“允许广播小额 MOON/USDC 流动性和 swap 到 Base Sepolia”。本次只执行两笔 Base Sepolia 测试网交易，不连接 Base 主网，不接触真实资金：

```text
1. PositionManager.modifyLiquidities(...) 添加极小额 MOON/USDC 流动性
2. UniversalRouter.execute(...) 执行 0.1 USDC -> MOON swap
```

广播结果：

```text
REHEARSAL_ACTOR=0x6E22b2e6fFAA30Fe75B71d53d1eC469b4e97A986
LIQUIDITY_TX=0x99c69749bbd9199ac7476f8d0175d2f3a651b81d97a97a607e13ca2b5168517b
LIQUIDITY_RECEIPT_STATUS=1
LIQUIDITY_BLOCK=41534780
LIQUIDITY_GAS_USED=442218
LIQUIDITY_TO=0x4B2C77d209D3405F41a037Ec6c77F7F5b8e2ca80
POSITION_TOKEN_ID=22355
POSITION_OWNER=0x6E22b2e6fFAA30Fe75B71d53d1eC469b4e97A986
POSITION_MANAGER_BALANCE_OF_ACTOR=1

SWAP_TX=0x61744130044a25395399db900c542872fe8c887057025a8d6b86bc0c71aeebaa
SWAP_RECEIPT_STATUS=1
SWAP_BLOCK=41534781
SWAP_GAS_USED=232863
SWAP_TO=0x492E6456D9528771018DeB9E87ef7750EF184104
ACTOR_USDC_BALANCE_AFTER=18400000
ACTOR_MOON_BALANCE_AFTER=284123473562317985
```

链上复核：

```text
PositionManager.ownerOf(22355)=0x6E22b2e6fFAA30Fe75B71d53d1eC469b4e97A986
PositionManager.balanceOf(REHEARSAL_ACTOR)=1
USDC.balanceOf(REHEARSAL_ACTOR)=18400000
MOON.balanceOf(REHEARSAL_ACTOR)=284123473562317985
```

说明：真实小额流动性和 swap 演练已经完成。后续不应重复广播同一小额演练，除非先重新制定新的测试目的和金额。

最新全量 Foundry 测试：

```text
222 tests passed, 0 failed
```
