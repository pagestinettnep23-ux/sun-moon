# 演练记录 - Base Sepolia - 2026-05-14

本文档是 Base Sepolia 受控演练的第一份参数复核草稿。当前已完成第一次 Base Sepolia 小额广播部署 `Create2HookDeployer`，并在 2026-05-15 完成第二次小额广播部署曲线核心和 `TestnetUsdcAdapter`；仍不部署主网、不接真实资金，并继续记录已知参数、待补参数和下一步预检命令。

## 1. 本轮状态

| 项目 | 记录 |
| --- | --- |
| 日期 | 2026-05-14 / 2026-05-15 |
| 网络 | Base Sepolia |
| 是否广播 | 是，第一次和第二次 Base Sepolia 小额广播已完成 |
| 是否部署主网 | 否 |
| 是否接真实资金 | 否 |
| 当前阶段 | `CREATE2_DEPLOYER`、曲线核心、adapter、Hook、绑定、受控 `MOON/USDC` 测试池白名单和初始化广播均已完成；极小额演练准备、资产/Permit2 授权和报价预检均已通过，下一步准备真实小额流动性 + swap 广播草案和最终 dry-run |
| 最近全量测试 | `forge test`：222 passed，0 failed |
| adapter 本地预演 | 已完成，`Base Sepolia adapter local rehearsal passed` |
| Create2 deployer RPC dry-run | 已完成 |
| Create2HookDeployer 广播 | 已完成，只部署 deployer，不部署 Hook、不部署曲线核心、不绑定 adapter |
| 曲线核心 + adapter dry-run | 已完成，随后已在用户明确批准后广播 |
| 曲线核心 + adapter 广播 | 已完成，部署 5 个测试网合约，不部署 Hook |
| `CREATE2_DEPLOYER` | `0xE5Df76A1DF2e959C70c8b7591754a3a2a542Fb6D` |
| `CREATE2_DEPLOYER_TX` | `0x87c9033101907c8e24aa13714154a212431a677837027191b023c00e70909596` |
| `MOON_TOKEN` | `0x6E7FF34C7a7a518981BF6324e5FCC6599FcBC59D` |
| `SUN_CURVE` | `0x00F49621977e5219093A988879F07936F2155c07` |
| `SWAP_ADAPTER` | `0x50f232d1B40D9EF523cc53f958f8C80766aF35a7` |
| `HOOK_SALT` | `0x00000000000000000000000000000000000000000000000000000000000022b9` |
| `PREDICTED_HOOK` | `0xF612828Ba9dE01CF16Fae2D8EE187B0cA59100Cc` |


## 2. 本轮复跑记录

2026-05-14 已复跑不需要真实测试网地址的 adapter 验证：

```text
forge test --match-contract TestnetUsdcAdapterTest
15 passed, 0 failed

forge test --match-contract BaseSepoliaAdapterRehearsalTest
1 passed, 0 failed

forge script script/RehearseBaseSepoliaAdapter.s.sol
Base Sepolia adapter local rehearsal passed
```

说明：上述命令均为本地 / Mock 预演，不广播、不部署测试网或主网。
2026-05-14 已复跑完整 Gate 0：

```text
forge test
222 passed, 0 failed
```

2026-05-14 已新增并复跑最小测试部署脚本草图：

```text
forge script script/PrepareBaseSepoliaTestDeploy.s.sol
Script ran successfully
```

本次为本地模拟，默认使用 Mock USDC，不广播交易。脚本输出了后续 CREATE2 预检所需的 `MOON_TOKEN`、`SUN_CURVE`、`SWAP_ADAPTER`、`HOOK_OWNER` 和 `PROTOCOL_BUDGET_ADDRESS` 示例值；这些是本地模拟地址，不是 Base Sepolia 测试网真实部署地址。

2026-05-14 已收到 3 个 Base Sepolia 测试用途公开钱包地址，并完成 checksum 格式校验：

```text
HOOK_OWNER=0x6E22b2e6fFAA30Fe75B71d53d1eC469b4e97A986
PROTOCOL_BUDGET_ADDRESS=0x277ba3Cf597CdAaF958C301db3cF6a631F793039
DEPLOYER_ADDRESS=0x2F6E887c6058deE520f9468a1022E3480A6334D3
```

说明：以上只记录公开地址，不包含私钥、助记词或完整 RPC key。

2026-05-14 已新增 `docs/Base-Sepolia-CREATE2-Deployer选择说明.md`。当前建议先写本地 `Create2HookDeployer` 草图和测试，不直接采用公共 deployer，也不把 `DEPLOYER_ADDRESS` 自动当成 `CREATE2_DEPLOYER`。

2026-05-14 已新增本地 `Create2HookDeployer` 草图和专项测试。该合约只允许 owner 调用，支持 CREATE2 地址预测，并在部署 Hook 前检查低 14 位权限 bit。此节点当时仍未广播交易，未部署测试网或主网。

2026-05-14 已新增 `script/RehearseCreate2HookDeployer.s.sol` 和 `test/hooks/base/Create2HookDeployerRehearsal.t.sol`，本地预演项目自控 deployer、salt 搜索、Hook 预测地址和实际部署地址复核。此节点当时仍未广播交易。

2026-05-14 已新增 `docs/Base-Sepolia-小额广播草案清单.md`，只记录未来 Base Sepolia 小额广播前的分步批准、停止条件和记录项。此节点当时仍未广播交易。

2026-05-14 已新增 `script/PrepareBaseSepoliaCreate2Deployer.s.sol` 和 `test/hooks/base/BaseSepoliaCreate2DeployerPreparation.t.sol`，用于本地模拟准备 Base Sepolia `Create2HookDeployer` 部署。该脚本只部署 deployer 草图，不部署 Hook、不部署曲线核心、不绑定 adapter；Base Sepolia 链 ID 需要额外确认变量，Base 主网链 ID 会直接拒绝。

本次新增测试结果：

```text
forge test --match-contract Create2HookDeployerTest
7 passed, 0 failed

forge test --match-contract BaseV4HookAddressMinerTest
3 passed, 0 failed

forge test --match-contract Create2HookDeployerRehearsalTest
1 passed, 0 failed

forge script script/RehearseCreate2HookDeployer.s.sol
Create2HookDeployer local rehearsal passed

forge test --match-contract BaseSepoliaCreate2DeployerPreparationTest
3 passed, 0 failed

$env:HOOK_OWNER="0x6E22b2e6fFAA30Fe75B71d53d1eC469b4e97A986"
forge script script/PrepareBaseSepoliaCreate2Deployer.s.sol
CREATE2_DEPLOYER_OWNER=0x6E22b2e6fFAA30Fe75B71d53d1eC469b4e97A986
```

2026-05-14 已完成 Base Sepolia RPC dry-run，不加 `--broadcast`，不使用私钥：

```powershell
$env:HOOK_OWNER="0x6E22b2e6fFAA30Fe75B71d53d1eC469b4e97A986"
$env:CONFIRM_BASE_SEPOLIA_CREATE2_DEPLOYER_RUN="1"
forge script script/PrepareBaseSepoliaCreate2Deployer.s.sol --rpc-url https://sepolia.base.org --sender 0x2F6E887c6058deE520f9468a1022E3480A6334D3
```

dry-run 输出：

```text
chainId=84532
baseSepoliaConfirmed=true
deployer=0x2F6E887c6058deE520f9468a1022E3480A6334D3
CREATE2_DEPLOYER_DRY_RUN=0xE5Df76A1DF2e959C70c8b7591754a3a2a542Fb6D
CREATE2_DEPLOYER_OWNER=0x6E22b2e6fFAA30Fe75B71d53d1eC469b4e97A986
estimatedGasUsed=454291
estimatedRequiredEth=0.000004997201
```

广播前公开链上复核：

```text
DEPLOYER_ADDRESS nonce=0
DEPLOYER_ADDRESS Base Sepolia ETH balance=0.010100000000000000
```

2026-05-14 在用户明确批准“允许广播部署 Create2HookDeployer 到 Base Sepolia”后，已完成第一次 Base Sepolia 小额广播。广播由用户在本机交互式确认，未向 Codex 提供私钥、助记词或完整 RPC key。

广播结果：

```text
CREATE2_DEPLOYER=0xE5Df76A1DF2e959C70c8b7591754a3a2a542Fb6D
CREATE2_DEPLOYER_OWNER=0x6E22b2e6fFAA30Fe75B71d53d1eC469b4e97A986
CREATE2_DEPLOYER_TX=0x87c9033101907c8e24aa13714154a212431a677837027191b023c00e70909596
DEPLOYER_ADDRESS nonce_after=1
DEPLOYER_ADDRESS Base Sepolia ETH balance_after=0.010097903269998070
receipt status=0x1
gasUsed=0x5550f
effectiveGasPrice=0x5b8d80
```

链上复核：

```text
cast code 0xE5Df76A1DF2e959C70c8b7591754a3a2a542Fb6D -> non-empty bytecode
cast call 0xE5Df76A1DF2e959C70c8b7591754a3a2a542Fb6D "owner()(address)" -> 0x6E22b2e6fFAA30Fe75B71d53d1eC469b4e97A986
```

说明：`CREATE2_DEPLOYER_DRY_RUN` 已与真实部署地址一致。后续 Hook 地址预测必须使用这个已部署的 `CREATE2_DEPLOYER`，不能再把 `DEPLOYER_ADDRESS` 当成 deployer。

2026-05-14 已为第二次小额广播补充脚本保护和测试：

```text
forge test --match-contract BaseSepoliaTestDeployPreparationTest
1 passed, 0 failed
```

本次脚本保护：

- Base 主网链 ID 直接拒绝。
- Base Sepolia 必须设置 `CONFIRM_BASE_SEPOLIA_TEST_DEPLOY_RUN=1`。
- Base Sepolia 禁止 `USE_MOCK_USDC=true`。
- Base Sepolia 的 `USDC_TOKEN` 必须是官方测试 USDC。
- 如果设置 `DEPLOYER_ADDRESS`，脚本会检查实际 deployer 是否一致。
- 部署钱包先作为临时 owner 完成绑定，脚本末尾再把所有权转给 `HOOK_OWNER`。

2026-05-14 已完成第二次小额广播 Base Sepolia dry-run，不加 `--broadcast`：

```text
chainId=84532
deployer=0x2F6E887c6058deE520f9468a1022E3480A6334D3
useMockUsdc=false
USDC=0x036CbD53842c5426634e7929541eC2318f3dCF7e
SUN_TOKEN_DRY_RUN=0xDa5a62F1c2c54AB79c974eE41
SUN_CURVE_DRY_RUN=0x00F49621977e5219093A988879F07936F2155c07
MOON_TOKEN_DRY_RUN=0x6E7FF34C7a7a518981BF6324e5FCC6599FcBC59D
MOON_CURVE_DRY_RUN=0x7f4296686917Be97E826DC790c367d93585A32c3
SWAP_ADAPTER_DRY_RUN=0x50f232d1B40D9EF523cc53f958f8C80766aF35a7
estimatedGasUsed=7408503
estimatedRequiredEth=0.000081493533
DEPLOYER_ADDRESS nonce=1
DEPLOYER_ADDRESS Base Sepolia ETH balance=0.010097903269998070
```

说明：以上是 dry-run 预测地址，不是已经部署的真实地址。如果 `DEPLOYER_ADDRESS` 在第二次广播前发生任何交易，nonce 会变化，以上地址必须重新 dry-run。

2026-05-15 在用户明确批准“允许广播部署曲线核心和 adapter 到 Base Sepolia”后，已完成第二次 Base Sepolia 小额广播。广播由用户在本机交互式确认，未向 Codex 提供私钥、助记词或完整 RPC key。

广播结果：

```text
SUN_TOKEN=0xDa5a62F1c2c54AB79c974eE41b9a5B83Dd307e41
SUN_CURVE=0x00F49621977e5219093A988879F07936F2155c07
MOON_TOKEN=0x6E7FF34C7a7a518981BF6324e5FCC6599FcBC59D
MOON_CURVE=0x7f4296686917Be97E826DC790c367d93585A32c3
SWAP_ADAPTER=0x50f232d1B40D9EF523cc53f958f8C80766aF35a7
DEPLOYER_ADDRESS nonce_after=14
DEPLOYER_ADDRESS Base Sepolia ETH balance_after=0.010063856527981176
receipt count=13
all receipt status=0x1
```

代表性交易哈希：

```text
SunToken deploy=0xd9a4e6645d9dcab6f0d5310d72a9ce638715791b41494ed79cf20e233f2928ac
SunCurve deploy=0x8d103ac83a28f1e05db2c71f3a61daf51adcf664ce67cbd1b16cb3c9185b4f8d
MoonToken deploy=0x6a9fdfd17914a5f8e78f7acd4e574b12a65de231ad5a34141a3788edbdcd306a
MoonCurve deploy=0x0a15be63b1135758681998da69158199cee43c5591b975bea01600661b769898
TestnetUsdcAdapter deploy=0x470d6ec345977c64a5f5f95151a1ef3a2e9a2e8920980db82978a0c8b2693db0
Final ownership tx=0x47d262a0ec7ccb1e2470112ad2e363929e2ed0f79b1ad074dc1a71d4971f6e46
```

链上复核：

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

说明：`SunCurve.moonAMM` 仍为零，`Adapter.authorizedHook` 仍为临时 `HOOK_OWNER`。真实 Hook 通过 CREATE2 部署并复核后，才进入切换 adapter 授权和设置 `SunCurve.moonAMM` 的下一步。

2026-05-15 已使用真实 Base Sepolia 测试网参数运行 CREATE2 salt 搜索：

```text
CREATE2_DEPLOYER=0xE5Df76A1DF2e959C70c8b7591754a3a2a542Fb6D
initCodeHash=0x306f254e5c441292e737d706681684bdcf210fecb5f71e35074fbd649a975bd4
HOOK_SALT=0x00000000000000000000000000000000000000000000000000000000000022b9
PREDICTED_HOOK=0xF612828Ba9dE01CF16Fae2D8EE187B0cA59100Cc
expectedMask=204
actualLow14Bits=204
```

随后运行 Base Sepolia 参数预检：

```text
Base Sepolia deployment preflight passed
expectedHookMask=204
actualHookMask=204
```

Base Sepolia 只读链上复核：

```text
PredictedHook.code = 0x
Create2Deployer.code = non-empty
Create2Deployer.owner = 0x6E22b2e6fFAA30Fe75B71d53d1eC469b4e97A986
PoolManager.code = non-empty
PositionManager.code = non-empty
UniversalRouter.code = non-empty
USDC.code = non-empty
```

## 3. 已知官方参数

2026-05-14 已按公开来源复核一次：

- Uniswap v4 deployments：`https://docs.uniswap.org/contracts/v4/deployments`
- Circle USDC contract addresses：`https://developers.circle.com/stablecoins/usdc-contract-addresses`

| 参数 | 值 | 状态 |
| --- | --- | --- |
| `BASE_CHAIN_ID` | `84532` | 已按公开来源复核，广播前仍需二次复核 |
| `POOL_MANAGER` | `0x05E73354cFDd6745C338b50BcFDfA3Aa6fA03408` | 已按公开来源复核，Hook 构造参数必用 |
| `POSITION_MANAGER` | `0x4B2C77d209D3405F41a037Ec6c77F7F5b8e2ca80` | 已按公开来源复核，后续池子操作准备 |
| `STATE_VIEW` | `0x571291b572ed32ce6751a2Cb2486EbEe8DEfB9B4` | 已按公开来源复核，后续查询准备 |
| `QUOTER` | `0x4A6513c898fe1B2d0E78d3b0e0A4a151589B1cBa` | 已按公开来源复核，后续报价准备 |
| `UNIVERSAL_ROUTER` | `0x492E6456D9528771018DeB9E87ef7750EF184104` | 已按公开来源复核，后续路由准备 |
| `USDC_TOKEN` | `0x036CbD53842c5426634e7929541eC2318f3dCF7e` | 已按 Circle 来源复核，Base Sepolia 测试 USDC |
| `PERMIT2` | `0x000000000022D473030F116dDEE9F6B43aC78BA3` | 已按公开来源复核 |

## 4. 待补项目参数

地址用途和新手准备流程见 `docs/Base-Sepolia-地址准备说明.md`。这里只记录公开地址，不记录私钥、助记词或完整 RPC key。

| 参数 | 当前状态 | 备注 |
| --- | --- | --- |
| `MOON_TOKEN` | `0x6E7FF34C7a7a518981BF6324e5FCC6599FcBC59D` | Base Sepolia 上的测试版 MOON token 地址 |
| `SUN_CURVE` | `0x00F49621977e5219093A988879F07936F2155c07` | Base Sepolia 上的测试版 SunCurve 地址 |
| `PROTOCOL_BUDGET_ADDRESS` | `0x277ba3Cf597CdAaF958C301db3cF6a631F793039` | 测试预算钱包公开地址，checksum 已校验，不能等于 adapter |
| `SWAP_ADAPTER` | `0x50f232d1B40D9EF523cc53f958f8C80766aF35a7` | 测试版 USDC adapter 地址 |
| `HOOK_OWNER` | `0x6E22b2e6fFAA30Fe75B71d53d1eC469b4e97A986` | 测试管理员公开地址，checksum 已校验，需要人工复核 |
| `DEPLOYER_ADDRESS` | `0x2F6E887c6058deE520f9468a1022E3480A6334D3` | 测试网部署钱包公开地址，checksum 已校验，只放少量测试 ETH |
| `CREATE2_DEPLOYER` | `0xE5Df76A1DF2e959C70c8b7591754a3a2a542Fb6D` | Base Sepolia 已部署，owner 已复核 |
| `HOOK_SALT` | `0x00000000000000000000000000000000000000000000000000000000000022b9` | 来自 `FindBaseMoonAmmFeeV4HookSalt.s.sol` |
| `PREDICTED_HOOK` | `0xF612828Ba9dE01CF16Fae2D8EE187B0cA59100Cc` | 低 14 位权限 bit 等于 `204` |

## 5. 待确认策略

| 项目 | 建议初始策略 | 状态 |
| --- | --- | --- |
| SUN 首次加池钱包 | 2026-05-15 主网新决策已取消该角色；官方永久不做 SUN AMM 流动性 | 已取消 |
| SUN 池白名单 | 初期只允许受控测试池 | 待确认 |
| MOON 池白名单 | 初期只允许 `MOON/USDC` 测试池 | 待确认 |
| adapter token allowlist | 初期只允许 USDC 直通和一个受控 Mock fee asset | 待确认 |
| adapter router allowlist | 初期只允许 `MockUsdcSwapRouter` 或受控测试 router | 待确认 |
| `minUSDTOut` 来源 | 初期由演练脚本显式传入，禁止为 0；前端/keeper 策略后置 | 待确认 |

## 6. 下一步本地命令

先复跑本地状态：

```powershell
forge test
forge test --match-contract TestnetUsdcAdapterTest
forge test --match-contract BaseSepoliaAdapterRehearsalTest
forge test --match-contract BaseSepoliaCreate2DeployerPreparationTest
forge script script/RehearseBaseSepoliaAdapter.s.sol
forge script script/PrepareBaseSepoliaCreate2Deployer.s.sol
```

使用已部署测试网地址，再跑：

```powershell
forge script script/FindBaseMoonAmmFeeV4HookSalt.s.sol
forge script script/CheckBaseSepoliaDeploymentParams.s.sol
forge test --match-contract BaseSepoliaHookDeployPreparationTest
forge script script/PrepareBaseSepoliaHookDeploy.s.sol --rpc-url https://sepolia.base.org --sender $env:HOOK_OWNER --rpc-timeout 120 --slow
```

## 7. 当前停止点

当前已固定真实测试网 `CREATE2_DEPLOYER`、`MOON_TOKEN`、`SUN_CURVE`、`SWAP_ADAPTER`、`HOOK_SALT` 和 `PREDICTED_HOOK`。Hook 部署已在用户明确批准后完成：

```text
PREDICTED_HOOK=0xF612828Ba9dE01CF16Fae2D8EE187B0cA59100Cc
DEPLOYED_HOOK_DRY_RUN=0xF612828Ba9dE01CF16Fae2D8EE187B0cA59100Cc
HOOK_DEPLOYED=0xF612828Ba9dE01CF16Fae2D8EE187B0cA59100Cc
HOOK_DEPLOY_TX=0x376baf6403018674a6b61bc4b84324e13fc7fafcb8c1970c8f15b06215e59e17
receiptStatus=0x1
expectedHookMask=204
actualLow14Bits=204
estimatedRequiredEth=0.000030782763
HOOK_OWNER_BALANCE_AFTER=0.001988519245970799
HOOK_OWNER_NONCE_AFTER=1
```

adapter / SunCurve 绑定 dry-run 已完成：

```text
adapterAuthorizedHookBefore=0x6E22b2e6fFAA30Fe75B71d53d1eC469b4e97A986
sunCurveMoonAMMBefore=0x0000000000000000000000000000000000000000
adapterAuthorizedHookAfter=0xF612828Ba9dE01CF16Fae2D8EE187B0cA59100Cc
sunCurveMoonAMMAfter=0xF612828Ba9dE01CF16Fae2D8EE187B0cA59100Cc
transactionsPlanned=2
estimatedRequiredEth=0.000001204511
```

用户明确批准后，adapter / SunCurve 绑定交易已广播并复核通过：

```text
BIND_ADAPTER_TX=0x1319e675384b1e014debdb806a27915797bbd0cf8da9e253f04b1cc643ef97c4
BIND_SUN_CURVE_TX=0x6a6154f5e075f4b6d0975c4b60e1d517885adccb4577eb678134f4cc3966ed7c
Adapter.authorizedHook=0xF612828Ba9dE01CF16Fae2D8EE187B0cA59100Cc
SunCurve.moonAMM=0xF612828Ba9dE01CF16Fae2D8EE187B0cA59100Cc
```

受控 `MOON/USDC` 测试池 dry-run 已完成：

```text
pool.currency0=0x036CbD53842c5426634e7929541eC2318f3dCF7e
pool.currency1=0x6E7FF34C7a7a518981BF6324e5FCC6599FcBC59D
pool.fee=3000
pool.tickSpacing=60
pool.hooks=0xF612828Ba9dE01CF16Fae2D8EE187B0cA59100Cc
poolId=0xfbb4ccec5e3fda3a97b9e2619e9e90588ad5e444bdb3d488e921a3192c42dd55
allowedMoonPoolBefore=false
allowedMoonPoolAfter=true
transactionsPlanned=1
estimatedRequiredEth=0.00000073733
```

白名单广播记录：

```text
ALLOW_MOON_USDC_POOL_TX=0x9f219d37f1a72dc6229df79217ed953f1e6ff01ed1f4d958854fe432616ed325
receiptStatus=1
blockNumber=41524110
allowedMoonPools(poolId)=true
```

受控测试池初始化 dry-run 记录：

```text
initialTick=276300
sqrtPriceX96=79133045881256921541446514419412387
humanPriceApprox=1 MOON ~= 1.0024 USDC
sqrtPriceBefore=0
alreadyInitialized=false
transactionsPlanned=1
estimatedRequiredEth=0.000000839773
```

初始化广播和复核记录：

```text
MOON_USDC_INITIALIZE_TX=0x72c93bb0a5bdb540b2e696eaff50614e4571cfe1dbe3bb64494ec9719cdc8310
receiptStatus=1
blockNumber=41525115
gasUsed=52201
slot0.sqrtPriceX96=79133045881256921541446514419412387
slot0.tick=276300
slot0.protocolFee=0
slot0.lpFee=3000
postBroadcastTransactionsPlanned=0
```

说明：`allowedMoonPoolAfter=true` 是 dry-run 模拟结果，真实链上已复核为 `true`。初始化广播已经完成。极小额流动性/交换演练准备、资产/Permit2 授权和报价预检均已通过，下一步不是重新部署 Hook，而是准备真实小额流动性 + swap 广播草案和最终 dry-run。

继续前必须先确认：

- `HOOK_SALT` 和 `PREDICTED_HOOK`
- `HOOK_DEPLOYED.code != 0x`
- `HOOK_DEPLOYED == PREDICTED_HOOK`
- 下一次演练范围只准备极小额测试资产和授权，不做主网、不接真实资金
- adapter 授权和 `SunCurve.moonAMM` 已链上绑定
- 受控测试池 `poolId` 白名单、初始化广播、极小额演练准备、资产/Permit2 授权和报价预检均已完成；下一轮准备真实小额流动性 + swap 广播草案和最终 dry-run

另外，`DEPLOYER_ADDRESS` 的 Base Sepolia nonce 当前为 `14`，余额约为 `0.010063856527981176` 测试 ETH；Hook 部署已由 `HOOK_OWNER` 签名完成，`HOOK_OWNER` nonce 当前为 `1`。

在这些结果人工复核通过前，不准备 Base 主网部署，也不接真实资金。



