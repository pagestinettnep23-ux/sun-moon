# Base Sepolia 小额广播草案清单

更新日期：2026-05-14

本文档给非技术成员和后续开发者说明：如果后续要开始 Base Sepolia 小额测试网广播，应该按什么顺序准备、每一步需要你确认什么、哪些情况必须停止。本文档只是广播前草案，不执行广播，不部署主网，不接真实资金，不记录私钥、助记词或完整 RPC key。

## 1. 一句话解释

“小额广播”指的是只在 Base Sepolia 测试网发送少量测试交易，消耗少量测试 ETH，用来验证部署流程和地址预测。

它不是主网上线，也不是接真实用户资金。

## 2. 当前状态

当前已经完成：

- 全量 Foundry 测试通过：`222 passed, 0 failed`。
- 已有 3 个测试用途公开钱包地址：
  - `HOOK_OWNER=0x6E22b2e6fFAA30Fe75B71d53d1eC469b4e97A986`
  - `PROTOCOL_BUDGET_ADDRESS=0x277ba3Cf597CdAaF958C301db3cF6a631F793039`
  - `DEPLOYER_ADDRESS=0x2F6E887c6058deE520f9468a1022E3480A6334D3`
- 已新增本地 `Create2HookDeployer` 草图。
- 已新增本地 `RehearseCreate2HookDeployer.s.sol`，可以本地验证 deployer、salt、预测 Hook 和实际 Hook 地址一致。
- 已新增 `PrepareBaseSepoliaCreate2Deployer.s.sol`，用于本地模拟准备 Base Sepolia `Create2HookDeployer` 部署。
- 已完成一次 Base Sepolia RPC dry-run，不加 `--broadcast`，模拟发送者为 `DEPLOYER_ADDRESS`。
- 已完成第一次 Base Sepolia 小额广播，只部署 `Create2HookDeployer`。
- 已链上复核 `CREATE2_DEPLOYER` 代码非空、owner 正确。
- 已新增 `PrepareBaseSepoliaTestDeploy.s.sol`，但当前默认只用于本地模拟。

当前仍缺：

- Base Sepolia 上真实部署后的 `MOON_TOKEN`
- Base Sepolia 上真实部署后的 `SUN_CURVE`
- Base Sepolia 上真实部署后的 `SWAP_ADAPTER`
- 用真实构造参数生成的 `HOOK_SALT`
- 用真实构造参数生成的 `PREDICTED_HOOK`

## 3. 广播前必须确认

以下事项全部确认前，不进入任何 `--broadcast`：

| 项目 | 当前建议 | 状态 |
| --- | --- | --- |
| 网络 | Base Sepolia，只测试网 | 待你明确确认 |
| 主网 | 不接 Base 主网 | 固定为否 |
| 真实资金 | 不接真实资金 | 固定为否 |
| 部署钱包 | `DEPLOYER_ADDRESS`，只放少量测试 ETH | 已有公开地址 |
| CREATE2 deployer owner | 使用 `HOOK_OWNER` | 已链上复核 |
| `DEPLOYER_ADDRESS` 测试 ETH | 广播后余额约 `0.010097903269998070` | 后续广播前仍需复核余额 |
| USDC | Base Sepolia USDC：`0x036CbD53842c5426634e7929541eC2318f3dCF7e` | 广播前二次复核 |
| 部署方式 | 先小步广播，不一次性全部部署 | 推荐 |
| 私钥处理 | 只在你本机本地终端使用，不发给我，不写文档 | 必须遵守 |

## 4. 推荐小额广播顺序

### Step A：只写广播脚本，不运行（已完成）

目标：

- 已写一个专门部署 `Create2HookDeployer` 的 Base Sepolia 脚本：`PrepareBaseSepoliaCreate2Deployer.s.sol`。
- 默认只允许本地模拟。
- 脚本输出未来的 `CREATE2_DEPLOYER` 地址。

这一步不需要私钥，不广播。

验收：

```powershell
forge script script/PrepareBaseSepoliaCreate2Deployer.s.sol
forge test --match-contract BaseSepoliaCreate2DeployerPreparationTest
forge test
```

必须通过后，才考虑下一步。

### Step B：本地 dry-run / 模拟

目标：

- 用 Base Sepolia 参数跑脚本模拟。
- 确认构造参数里 owner 是你指定的测试管理员地址。
- 确认脚本没有部署 Hook、没有绑定池子、没有设置真实资金路径。

这一步仍不加 `--broadcast`。

### Step C：第一次小额广播，只部署 `Create2HookDeployer`（已完成）

目标：

- 只在 Base Sepolia 部署一个 `Create2HookDeployer`。
- 不部署 SUN/MOON。
- 不部署 Hook。
- 不建池。
- 不接 adapter 路由。

广播后记录：

```text
CREATE2_DEPLOYER=0xE5Df76A1DF2e959C70c8b7591754a3a2a542Fb6D
CREATE2_DEPLOYER_OWNER=0x6E22b2e6fFAA30Fe75B71d53d1eC469b4e97A986
CREATE2_DEPLOYER_TX=0x87c9033101907c8e24aa13714154a212431a677837027191b023c00e70909596
```

停止条件：

- 部署出来的 owner 不是预期地址。
- 部署网络不是 Base Sepolia。
- 输出地址为空或无法在 Base Sepolia 浏览器上查看。
- 花费明显异常。

### Step D：第二次小额广播，部署曲线核心和测试版 adapter

当前状态：脚本保护和 Base Sepolia dry-run 已完成，但还没有广播。

目标：

- 部署 `SunToken`
- 部署 `SunCurve`
- 部署 `MoonToken`
- 部署 `MoonCurve`
- 部署 `TestnetUsdcAdapter`
- 绑定 token minter 和 `SunCurve.moonCurve`
- 暂时不设置 `SunCurve.moonAMM`

广播后记录：

```text
MOON_TOKEN=
SUN_CURVE=
SWAP_ADAPTER=
```

当前 dry-run 预测记录：

```text
SUN_TOKEN_DRY_RUN=0xDa5a62F1c2c54AB79c974eE41
SUN_CURVE_DRY_RUN=0x00F49621977e5219093A988879F07936F2155c07
MOON_TOKEN_DRY_RUN=0x6E7FF34C7a7a518981BF6324e5FCC6599FcBC59D
MOON_CURVE_DRY_RUN=0x7f4296686917Be97E826DC790c367d93585A32c3
SWAP_ADAPTER_DRY_RUN=0x50f232d1B40D9EF523cc53f958f8C80766aF35a7
estimatedRequiredEth=0.000081493533
DEPLOYER_ADDRESS nonce=1
DEPLOYER_ADDRESS Base Sepolia ETH balance=0.010097903269998070
```

说明：这些是预测地址，不是已部署地址。如果 `DEPLOYER_ADDRESS` 的 nonce 变化，必须重新 dry-run。

停止条件：

- 使用了 Base 主网。
- `USE_MOCK_USDC=true` 被误用于真实 Base Sepolia 广播。
- USDC 地址不是 Base Sepolia USDC。
- owner 或 protocol budget 和预期不一致。
- `SunCurve.moonAMM` 被提前设置。

### Step E：本地生成 Hook salt 和预测地址

拿到以下真实 Base Sepolia 地址后，再本地运行：

```text
CREATE2_DEPLOYER=0xE5Df76A1DF2e959C70c8b7591754a3a2a542Fb6D
MOON_TOKEN=
SUN_CURVE=
SWAP_ADAPTER=
HOOK_OWNER=
PROTOCOL_BUDGET_ADDRESS=
```

运行：

```powershell
forge script script/FindBaseMoonAmmFeeV4HookSalt.s.sol
forge script script/CheckBaseSepoliaDeploymentParams.s.sol
```

记录：

```text
HOOK_SALT=
PREDICTED_HOOK=
```

要求：

- `PREDICTED_HOOK` 低 14 位权限 bit 必须等于 `204`。
- `CheckBaseSepoliaDeploymentParams.s.sol` 必须通过。
- 构造参数、salt、预测地址必须一起写入演练记录。

### Step F：第三次小额广播，部署 Hook

只有 Step A 到 Step E 全部通过后，才考虑部署 `BaseMoonAmmFeeV4Hook`。

广播后必须马上检查：

```text
实际 Hook 地址 == PREDICTED_HOOK
实际 Hook 地址低 14 位权限 bit == 204
```

不一致就停止，不继续绑定权限。

### Step G：绑定权限

Hook 地址确认后，才允许配置：

```text
TestnetUsdcAdapter.setAuthorizedHook(Hook)
SunCurve.setMoonAMM(Hook)
```

池子白名单必须后置：

```text
BaseMoonAmmFeeV4Hook.setAllowedMoonPool(poolId, true)
```

`poolId` 必须来自真实 `PoolKey.toId()`，不能手填猜测。

## 5. 你需要明确批准的节点

| 节点 | 需要你怎么批准 |
| --- | --- |
| 写广播脚本草图 | 说“可以写脚本，但不要广播” |
| 本地 dry-run | 说“可以本地 dry-run，不广播” |
| 第一次 Base Sepolia 广播 | 必须明确说“允许广播部署 Create2HookDeployer 到 Base Sepolia” |
| 第二次 Base Sepolia 广播 | 必须明确说“允许广播部署曲线核心和 adapter 到 Base Sepolia” |
| 第三次 Base Sepolia 广播 | 必须明确说“允许广播部署 Hook 到 Base Sepolia” |
| Base 主网 | 当前不批准，也不执行 |

## 6. 绝对不能做

- 不能把私钥、助记词、完整 RPC key 发给我。
- 不能把私钥、助记词、完整 RPC key 写进 `.md`、`.sol`、`.env.example` 或截图。
- 不能连接 Base 主网。
- 不能使用真实用户资金。
- 不能把 `DEPLOYER_ADDRESS` 自动当成 `CREATE2_DEPLOYER`。
- 不能跳过 `PREDICTED_HOOK` 权限 bit 检查。
- 不能在 Hook 地址不一致时继续配置 adapter 或 `SunCurve.moonAMM`。

## 7. 当前下一步

当前建议的下一步不是重新部署 Hook，也不是 Base 主网。adapter 授权和 `SunCurve.moonAMM` 绑定广播已完成，受控 `MOON/USDC` 测试池 `poolId` dry-run、白名单广播、初始化广播和链上复核也都已完成。极小额流动性/交换演练准备 dry-run、资产/Permit2 授权准备、报价预检、真实小额流动性 + swap 广播草案 dry-run、以及真实 Base Sepolia 小额流动性 + swap 广播均已完成并链上复核。

第一次小额广播已完成，记录如下：

```text
chainId=84532
deployer=0x2F6E887c6058deE520f9468a1022E3480A6334D3
CREATE2_DEPLOYER_DRY_RUN=0xE5Df76A1DF2e959C70c8b7591754a3a2a542Fb6D
CREATE2_DEPLOYER=0xE5Df76A1DF2e959C70c8b7591754a3a2a542Fb6D
CREATE2_DEPLOYER_OWNER=0x6E22b2e6fFAA30Fe75B71d53d1eC469b4e97A986
CREATE2_DEPLOYER_TX=0x87c9033101907c8e24aa13714154a212431a677837027191b023c00e70909596
DEPLOYER_ADDRESS nonce_after=1
DEPLOYER_ADDRESS Base Sepolia ETH balance_after=0.010097903269998070
```

链上复核结果：

```text
Create2HookDeployer code=non-empty
Create2HookDeployer.owner()=0x6E22b2e6fFAA30Fe75B71d53d1eC469b4e97A986
receipt status=0x1
```

第二次小额广播脚本保护、dry-run、人工复核和用户明确批准均已完成。2026-05-15 已广播部署曲线核心和 `TestnetUsdcAdapter` 到 Base Sepolia，链上复核通过。

真实 `MOON_TOKEN`、`SUN_CURVE`、`SWAP_ADAPTER` 已用于 CREATE2 salt 搜索、Base Sepolia 参数预检和 Hook dry-run，结果如下：

```text
HOOK_SALT=0x00000000000000000000000000000000000000000000000000000000000022b9
PREDICTED_HOOK=0xF612828Ba9dE01CF16Fae2D8EE187B0cA59100Cc
DEPLOYED_HOOK_DRY_RUN=0xF612828Ba9dE01CF16Fae2D8EE187B0cA59100Cc
expectedHookMask=204
actualLow14Bits=204
estimatedRequiredEth=0.000030782763
HOOK_OWNER_BALANCE_BEFORE_BROADCAST=0.002
HOOK_OWNER_NONCE_BEFORE_BROADCAST=0
```

充值后已复跑最终 dry-run，并在用户明确说“允许广播部署 Hook 到 Base Sepolia”后进入第三次小额广播。

2026-05-15 第三次小额广播已完成：

```text
HOOK_DEPLOY_TX=0x376baf6403018674a6b61bc4b84324e13fc7fafcb8c1970c8f15b06215e59e17
HOOK_DEPLOYED=0xF612828Ba9dE01CF16Fae2D8EE187B0cA59100Cc
receiptStatus=0x1
HOOK_DEPLOYED == PREDICTED_HOOK
expectedHookMask=204
```

第四次小额配置 dry-run 已完成，不广播：

```text
adapterAuthorizedHookBefore=0x6E22b2e6fFAA30Fe75B71d53d1eC469b4e97A986
sunCurveMoonAMMBefore=0x0000000000000000000000000000000000000000
adapterAuthorizedHookAfter=0xF612828Ba9dE01CF16Fae2D8EE187B0cA59100Cc
sunCurveMoonAMMAfter=0xF612828Ba9dE01CF16Fae2D8EE187B0cA59100Cc
transactionsPlanned=2
estimatedRequiredEth=0.000001204511
```

第四次小额配置广播已完成：

```text
BIND_ADAPTER_TX=0x1319e675384b1e014debdb806a27915797bbd0cf8da9e253f04b1cc643ef97c4
BIND_SUN_CURVE_TX=0x6a6154f5e075f4b6d0975c4b60e1d517885adccb4577eb678134f4cc3966ed7c
Adapter.authorizedHook=0xF612828Ba9dE01CF16Fae2D8EE187B0cA59100Cc
SunCurve.moonAMM=0xF612828Ba9dE01CF16Fae2D8EE187B0cA59100Cc
```

受控 `MOON/USDC` 测试池 dry-run 记录：

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
gasUsed=45833
allowedMoonPools(poolId)=true
```

说明：`allowedMoonPoolAfter=true` 是 dry-run 模拟结果；真实链上已通过 `cast call` 复核为 `true`。

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

初始化广播记录：

```text
MOON_USDC_INITIALIZE_TX=0x72c93bb0a5bdb540b2e696eaff50614e4571cfe1dbe3bb64494ec9719cdc8310
receiptStatus=1
blockNumber=41525115
gasUsed=52201
slot0.sqrtPriceX96=79133045881256921541446514419412387
slot0.tick=276300
postBroadcastTransactionsPlanned=0
```

真实小额流动性 + swap 广播草案 dry-run 记录：

```text
script=PrepareBaseSepoliaTinyMoonUsdcBroadcast.s.sol
REHEARSAL_ACTOR=0x6E22b2e6fFAA30Fe75B71d53d1eC469b4e97A986
readyForTinyBroadcast=true
transactionsPlanned=2
transactionsExecuted=2
liquidity=33796876514319
positionLiquidityAfterMint=33796876514319
swapUsdcIn=100000
swapUsdcGrossInputWithHookFee=105000
quoteMoonOut=94223974497341879
minMoonOut=84801577047607691
actorUsdcBalanceAfter=18400000
actorMoonBalanceAfter=284123473562317985
estimatedRequiredEth=0.000010652213
```

真实小额流动性 + swap 广播记录：

```text
script=PrepareBaseSepoliaTinyMoonUsdcBroadcast.s.sol
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

说明：真实广播已经完成，且两笔 receipt 都是 `status=1`。这是 Base Sepolia 测试网小额演练，不是 Base 主网，不接真实资金，也没有在聊天或文档中记录私钥。

当前停止点不是重新部署 Hook，也不是 Base 主网。小额流动性 + swap 已经完成；下一步应做广播后复盘、监控和前端读取测试网数据对齐。
