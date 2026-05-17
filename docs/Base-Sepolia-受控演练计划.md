# Base Sepolia 受控演练计划

更新日期：2026-05-14

本文档用于规划 SUN/MOON Base + Uniswap v4 路线的下一轮受控演练。当前目标不是部署主网，也不是接真实资金，而是在进入任何测试网广播前，把参数、权限、失败停止条件和演练顺序先固定下来。

## 1. 当前边界

当前继续保持：

- 只做本地 / Mock / fork / Base Sepolia 小额测试预演。
- 不部署 Base 主网。
- 不接真实资金。
- 不使用真实用户资产。
- 不把真实私钥、RPC key 或助记词写入代码、文档、截图或聊天记录。
- 不把真实 adapter 做成任意 calldata 转发器。

已经完成的前置基础：

- `BaseMoonAmmFeeV4Hook` v2 使用 Uniswap v4 return delta 收取 MOON 任意交易对 5% 费用。
- CREATE2 Hook 地址权限 bit 预检脚本和测试已完成。
- 本地 `Create2HookDeployer` 草图、CREATE2 Hook 部署保护测试和完整预演脚本已完成。
- Base Sepolia `Create2HookDeployer` 已完成第一次小额广播并链上复核。
- 曲线核心 + `TestnetUsdcAdapter` 的第二次小额广播已完成并链上复核，不部署 Hook。
- Base Sepolia 官方地址和部署参数预检脚本已完成。
- `TestnetUsdcAdapter`、`MockUsdcSwapRouter`、本地 adapter 预演脚本和回归测试已完成。
- 最新全量 Foundry 测试通过：`222 passed, 0 failed`。

## 2. 演练目标

本轮受控演练只验证三件事：

1. Base Sepolia 参数是否完整、可复核、没有零地址或明显冲突。
2. Hook 地址权限、构造参数和 CREATE2 salt 是否能在进入广播前被重复计算和记录。
3. 测试版 USDC adapter 在测试 token 和受控路由下的权限、allowlist、滑点和失败路径是否可复现。

本轮不验证：

- 主网流动性。
- 真实 Uniswap 路由收益或成交质量。
- 真实资金滑点。
- 生产级 keeper。
- 投资收益或市场表现。

## 3. 参数复核表

进入 Base Sepolia 广播前，以下参数必须先填表并人工复核。

| 参数 | 来源 | 当前要求 | 状态 |
| --- | --- | --- | --- |
| `BASE_CHAIN_ID` | Base Sepolia | 必须为 `84532` | 已记录，广播前二次复核 |
| `POOL_MANAGER` | Uniswap v4 官方地址 | `0x05E73354cFDd6745C338b50BcFDfA3Aa6fA03408` | 已记录，广播前二次复核 |
| `POSITION_MANAGER` | Uniswap v4 官方地址 | `0x4B2C77d209D3405F41a037Ec6c77F7F5b8e2ca80` | 已记录，广播前二次复核 |
| `UNIVERSAL_ROUTER` | Uniswap 官方地址 | `0x492E6456D9528771018DeB9E87ef7750EF184104` | 已记录，广播前二次复核 |
| `USDC_TOKEN` | Base Sepolia USDC | `0x036CbD53842c5426634e7929541eC2318f3dCF7e` | 已记录，广播前二次复核 |
| `MOON_TOKEN` | 项目测试网部署 | 非零地址 | 已部署：`0x6E7FF34C7a7a518981BF6324e5FCC6599FcBC59D` |
| `SUN_CURVE` | 项目测试网部署 | 非零地址 | 已部署：`0x00F49621977e5219093A988879F07936F2155c07` |
| `PROTOCOL_BUDGET_ADDRESS` | 项目钱包 | 非零地址，不能等于 adapter | 已填写：`0x277ba3Cf597CdAaF958C301db3cF6a631F793039` |
| `SWAP_ADAPTER` | 测试版 adapter | 非零地址，不能等于预算钱包 | 已部署：`0x50f232d1B40D9EF523cc53f958f8C80766aF35a7` |
| `HOOK_OWNER` | 管理员钱包 | 非零地址，建议多轮人工确认 | 已填写：`0x6E22b2e6fFAA30Fe75B71d53d1eC469b4e97A986` |
| `CREATE2_DEPLOYER` | 项目自控部署器 | 必须固定并记录 | 已部署：`0xE5Df76A1DF2e959C70c8b7591754a3a2a542Fb6D` |
| `CREATE2_DEPLOYER_DRY_RUN` | RPC dry-run 模拟输出 | 已与真实部署地址一致 | `0xE5Df76A1DF2e959C70c8b7591754a3a2a542Fb6D` |
| `HOOK_SALT` | salt 搜索脚本输出 | 必须和预测地址一起记录 | 已生成：`0x00000000000000000000000000000000000000000000000000000000000022b9` |
| `PREDICTED_HOOK` | salt 搜索脚本输出 | 低 14 位权限 bit 必须等于 `204` | 已生成：`0xF612828Ba9dE01CF16Fae2D8EE187B0cA59100Cc` |
| SUN 首次加池钱包 | 项目决策 | 主网新决策已取消该角色；不再用于主网 | 已取消 |
| SUN 池白名单 | 项目决策 | 初期建议只允许受控测试池 | 待确认 |
| MOON 池白名单 | 项目决策 | 初期建议只允许 `MOON/USDC` 测试池 | 待确认 |
| adapter token allowlist | 项目决策 | 初期建议只允许 USDC 直通和一个 Mock fee asset | 待确认 |
| adapter router allowlist | 项目决策 | 初期只允许受控 Mock router 或测试 router | 待确认 |
| `minUSDTOut` 生成方式 | 前端 / 脚本 / keeper | 必须禁止为 0，并记录来源 | 待确认 |

## 4. 执行闸门

必须按顺序通过以下闸门。任一项失败，就停止，不进入下一步。

### Gate 0：本地状态冻结

要求：

- `forge test` 通过。
- 当前文档和脚本 README 已同步。
- 没有未记录的参数口径变化。

当前记录：

```text
forge test
222 passed, 0 failed
```

### Gate 1：CREATE2 和参数预检

注意：本 Gate 需要真实 `MOON_TOKEN`、`SUN_CURVE` 和 `SWAP_ADAPTER`。当前这些地址已由第二次小额广播固定，下一步可以执行 Hook salt 搜索和参数预检；仍不得直接广播 Hook。

运行：

```powershell
forge script script/FindBaseMoonAmmFeeV4HookSalt.s.sol
forge script script/CheckBaseSepoliaDeploymentParams.s.sol
```

要求：

- `PREDICTED_HOOK` 非零。
- `PREDICTED_HOOK` 低 14 位权限 bit 等于 `204`。
- Base Sepolia 官方地址和项目地址通过预检。
- `HOOK_SALT`、`PREDICTED_HOOK`、构造参数写入部署记录草稿。

当前记录：已通过，`HOOK_SALT=0x00000000000000000000000000000000000000000000000000000000000022b9`，`PREDICTED_HOOK=0xF612828Ba9dE01CF16Fae2D8EE187B0cA59100Cc`，实际低 14 位权限 bit 为 `204`。

### Gate 2：本地 adapter 预演复跑

运行：

```powershell
forge test --match-contract BaseSepoliaAdapterRehearsalTest
forge script script/RehearseBaseSepoliaAdapter.s.sol
```

要求：

- 非 USDC fee asset 经 Mock router 换出 Mock USDC。
- `tokenIn == USDC` 直通路径通过。
- adapter 不保留 fee asset。
- 实际 USDC 输出以 Hook 余额差为准。
- 失败时不继续后续演练。

### Gate 3：Base fork 只读复核

要求：

- 只读检查 Base Sepolia / Base Mainnet 官方 v4 地址。
- 不广播交易。
- 不使用真实私钥。
- 记录 fork RPC 来源，但不把 RPC key 写入文档。

建议命令仍沿用现有 fork 测试；如果 RPC 不可用，只记录阻塞，不改成主网广播。

### Gate 4：Hook 小额广播 dry-run

只有 Gate 0 到 Gate 3 全部通过后，才允许准备 Hook 测试网广播脚本。当前已新增 `script/PrepareBaseSepoliaHookDeploy.s.sol` 并完成 Base Sepolia dry-run，不广播：

```text
DEPLOYED_HOOK_DRY_RUN=0xF612828Ba9dE01CF16Fae2D8EE187B0cA59100Cc
expectedHookMask=204
actualLow14Bits=204
estimatedRequiredEth=0.000030782763
```

此阶段仍然只允许：

- Base Sepolia。
- 测试 token。
- 小额测试环境。
- 受控 adapter / 受控 router。
- Hook dry-run，不带 `--broadcast`。

仍然禁止：

- Base 主网。
- 真实用户资金。
- 未审计真实 adapter。
- 任意 calldata 路由。

当前状态：Hook 已在用户明确批准后广播部署，receipt `status=0x1`，实际地址等于 `PREDICTED_HOOK`。

## 5. 演练步骤草案

### 5.1 本地复跑

```powershell
forge test
forge test --match-contract TestnetUsdcAdapterTest
forge test --match-contract BaseSepoliaAdapterRehearsalTest
forge script script/RehearseBaseSepoliaAdapter.s.sol
```

预期：

- 全量测试 `222 passed, 0 failed`。
- adapter 测试 `15 passed, 0 failed`。
- 本地 adapter 预演测试 `1 passed, 0 failed`。
- Base Sepolia `Create2HookDeployer` 准备测试 `3 passed, 0 failed`。
- Base Sepolia RPC dry-run 已通过。
- 第一次 Base Sepolia 小额广播已完成：`CREATE2_DEPLOYER=0xE5Df76A1DF2e959C70c8b7591754a3a2a542Fb6D`。
- 第二次 Base Sepolia 小额广播已完成，真实 `MOON_TOKEN=0x6E7FF34C7a7a518981BF6324e5FCC6599FcBC59D`、`SUN_CURVE=0x00F49621977e5219093A988879F07936F2155c07`、`SWAP_ADAPTER=0x50f232d1B40D9EF523cc53f958f8C80766aF35a7`。
- Hook 小额广播准备测试 `1 passed, 0 failed`。
- Hook Base Sepolia dry-run 已通过，模拟部署地址等于 `PREDICTED_HOOK`。
- 预演脚本输出 `Base Sepolia adapter local rehearsal passed`。

### 5.2 参数生成

当前可以运行，但只做本地参数生成和预检，不广播 Hook。

```powershell
forge script script/FindBaseMoonAmmFeeV4HookSalt.s.sol
```

记录：

- `CREATE2_DEPLOYER`
- `HOOK_SALT`
- `PREDICTED_HOOK`
- 构造参数
- 运行日期
- 运行人

### 5.3 参数预检

```powershell
forge script script/CheckBaseSepoliaDeploymentParams.s.sol
```

预期：

- 输出 `Base Sepolia deployment preflight passed`。
- 如果失败，停止并修正参数，不进入广播。

### 5.4 Hook dry-run

本步骤已执行，不广播：

```powershell
forge test --match-contract BaseSepoliaHookDeployPreparationTest
forge script script/PrepareBaseSepoliaHookDeploy.s.sol --rpc-url https://sepolia.base.org --sender $env:HOOK_OWNER --rpc-timeout 120 --slow
```

记录：

```text
PREDICTED_HOOK=0xF612828Ba9dE01CF16Fae2D8EE187B0cA59100Cc
DEPLOYED_HOOK_DRY_RUN=0xF612828Ba9dE01CF16Fae2D8EE187B0cA59100Cc
HOOK_DEPLOYED=0xF612828Ba9dE01CF16Fae2D8EE187B0cA59100Cc
HOOK_DEPLOY_TX=0x376baf6403018674a6b61bc4b84324e13fc7fafcb8c1970c8f15b06215e59e17
HOOK_OWNER_BALANCE_AFTER=0.001988519245970799
HOOK_OWNER_NONCE_AFTER=1
```

### 5.5 Base Sepolia Hook 绑定

本步骤已经完成脚本准备和 Base Sepolia dry-run，不广播。

计划顺序：

1. 准备 `TestnetUsdcAdapter.setAuthorizedHook(Hook)` 绑定交易。已完成。
2. 准备 `SunCurve.setMoonAMM(Hook)` 绑定交易。已完成。
3. dry-run 两笔绑定交易，不广播。已完成。
4. 用户明确批准后，才广播绑定交易。已完成。
5. 绑定后复核 adapter 和 SunCurve 状态。已完成。
6. 后续再只开放受控测试池。
7. 用极小测试数量验证 USDC 直通路径。
8. 再验证一个受控非 USDC fee asset 的 Mock router 路径。

任何一步失败，都停止并记录。

已执行命令：

```powershell
forge test --match-contract BaseSepoliaHookBindingPreparationTest
forge script script/PrepareBaseSepoliaHookBinding.s.sol --rpc-url https://sepolia.base.org --sender $env:HOOK_OWNER --rpc-timeout 120 --slow
```

dry-run 记录：

```text
chainId=84532
HOOK_ADDRESS=0xF612828Ba9dE01CF16Fae2D8EE187B0cA59100Cc
SWAP_ADAPTER=0x50f232d1B40D9EF523cc53f958f8C80766aF35a7
SUN_CURVE=0x00F49621977e5219093A988879F07936F2155c07
adapterAuthorizedHookBefore=0x6E22b2e6fFAA30Fe75B71d53d1eC469b4e97A986
sunCurveMoonAMMBefore=0x0000000000000000000000000000000000000000
adapterAuthorizedHookAfter=0xF612828Ba9dE01CF16Fae2D8EE187B0cA59100Cc
sunCurveMoonAMMAfter=0xF612828Ba9dE01CF16Fae2D8EE187B0cA59100Cc
transactionsPlanned=2
estimatedRequiredEth=0.000001204511
```

注意：`After` 原本是 dry-run 模拟结果；用户明确批准后，绑定交易已广播并复核通过。

绑定广播记录：

```text
BIND_ADAPTER_TX=0x1319e675384b1e014debdb806a27915797bbd0cf8da9e253f04b1cc643ef97c4
BIND_SUN_CURVE_TX=0x6a6154f5e075f4b6d0975c4b60e1d517885adccb4577eb678134f4cc3966ed7c
Adapter.authorizedHook=0xF612828Ba9dE01CF16Fae2D8EE187B0cA59100Cc
SunCurve.moonAMM=0xF612828Ba9dE01CF16Fae2D8EE187B0cA59100Cc
```

## 6. 停止条件

出现以下情况时必须停止：

- `forge test` 失败。
- CREATE2 预测地址权限 bit 不等于 `204`。
- Hook 实际地址不等于 `PREDICTED_HOOK`。
- adapter / SunCurve 绑定 dry-run 失败。
- Base Sepolia 官方地址和文档不一致。
- 任一项目关键地址为零地址。
- 预算钱包和 adapter 地址相同。
- adapter router 或 token allowlist 不清楚。
- `minUSDTOut` 生成方式没有定稿。
- 演练需要真实资金才能继续。
- 需要把私钥或 RPC key 写进代码、文档或聊天记录。
- 需要接入未经测试的真实 router。

## 7. 记录模板

每次演练都应新增一份记录，建议命名：

```text
docs/演练记录-Base-Sepolia-YYYY-MM-DD.md
```

记录内容：

```text
日期：
执行人：
网络：
是否广播：
RPC 来源：
forge test 结果：
CREATE2_DEPLOYER：
HOOK_SALT：
PREDICTED_HOOK：
MOON_TOKEN：
SUN_CURVE：
SWAP_ADAPTER：
PROTOCOL_BUDGET_ADDRESS：0x277ba3Cf597CdAaF958C301db3cF6a631F793039
HOOK_OWNER：0x6E22b2e6fFAA30Fe75B71d53d1eC469b4e97A986
DEPLOYER_ADDRESS：0x2F6E887c6058deE520f9468a1022E3480A6334D3
adapter token allowlist：
adapter router allowlist：
minUSDTOut 来源：
执行步骤：
失败或停止原因：
下一步：
```

不要记录真实私钥、助记词或完整敏感 RPC key。

## 8. 当前记录文件

- `docs/演练记录-Base-Sepolia-2026-05-14.md`：第一份参数复核草稿，已记录官方参数、第一次小额广播结果、待补项目参数、建议初始策略和当前停止点。
- `docs/Base-Sepolia-参数模板.md`：用于收集公开参数、项目待填地址、CREATE2 输出和初始策略，不记录私钥或完整 RPC key。
- `docs/Base-Sepolia-最小部署规划.md`：说明最小测试网部署对象、构造参数、部署顺序、批准节点和停止条件。
- `docs/Base-Sepolia-小额广播草案清单.md`：说明 Base Sepolia 小额广播前的分步草案、批准话术、停止条件和记录项。
- `docs/Base-Sepolia-地址准备说明.md`：给非技术成员说明需要准备哪些公开地址、各自用途、复核规则和安全边界。
- `docs/Base-Sepolia-CREATE2-Deployer选择说明.md`：说明 `CREATE2_DEPLOYER` 的作用、可选方案、当前推荐和停止条件。
- `contracts/hooks/base/Create2HookDeployer.sol`：本地项目自控 CREATE2 Hook deployer 草图。
- `script/RehearseCreate2HookDeployer.s.sol`：本地预演 deployer、salt 搜索、Hook 部署和地址复核。
- `script/PrepareBaseSepoliaCreate2Deployer.s.sol`：Base Sepolia `Create2HookDeployer` 部署脚本，已用于第一次小额广播；脚本包含 Base Sepolia 确认变量和 deployer 地址保护。
- `script/PrepareBaseSepoliaHookDeploy.s.sol`：Base Sepolia Hook dry-run / 广播准备脚本，已用于 Hook 小额广播。
- `script/PrepareBaseSepoliaHookBinding.s.sol`：Base Sepolia Hook 权限绑定准备脚本，已完成 dry-run，不广播。

## 9. 下一步任务

建议下一步按这个顺序推进：

1. 已收到并记录 `HOOK_OWNER`、`PROTOCOL_BUDGET_ADDRESS` 和 `DEPLOYER_ADDRESS` 的公开地址。
2. 已新增 `CREATE2_DEPLOYER` 选择说明、本地 `Create2HookDeployer` 草图/测试和完整预演脚本。
3. 已新增 Base Sepolia 小额广播草案清单。
4. 已新增并使用 `Create2HookDeployer` 的 Base Sepolia 部署脚本。
5. 已完成 Base Sepolia RPC dry-run，模拟发送者为 `DEPLOYER_ADDRESS`。
6. 已完成第一次小额广播部署 `Create2HookDeployer`，真实 `CREATE2_DEPLOYER` 已固定。
7. 第二次小额广播脚本保护、dry-run 和人工复核已完成。
8. 第二次小额广播已完成，真实 `MOON_TOKEN`、`SUN_CURVE` 和 `SWAP_ADAPTER` 已固定。
9. CREATE2 salt 搜索和参数预检已通过。
10. Hook 小额广播准备脚本、回归测试和 Base Sepolia dry-run 已通过。
11. Hook 小额广播已完成并复核通过。
12. adapter / SunCurve 绑定 dry-run 已通过。
13. adapter / SunCurve 绑定广播和链上复核已通过。
14. 受控 `MOON/USDC` 测试池 `PoolKey -> poolId` dry-run 已通过。
15. 用户明确批准后，`setAllowedMoonPool(poolId, true)` 已广播并链上复核通过。
16. 用户明确批准后，`PoolManager.initialize(poolKey, sqrtPriceX96)` 已广播并链上复核通过。

受控测试池 dry-run 记录：

```text
currency0=0x036CbD53842c5426634e7929541eC2318f3dCF7e
currency1=0x6E7FF34C7a7a518981BF6324e5FCC6599FcBC59D
fee=3000
tickSpacing=60
hooks=0xF612828Ba9dE01CF16Fae2D8EE187B0cA59100Cc
poolId=0xfbb4ccec5e3fda3a97b9e2619e9e90588ad5e444bdb3d488e921a3192c42dd55
allowedMoonPoolBefore=false
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

极小额流动性/交换演练准备 dry-run 也已完成：

```text
PrepareBaseSepoliaTinyMoonUsdcRehearsal=passed
readyForLiquidityDryRun=false
readyForSwapDryRun=false
readyForCombinedDryRun=false
actorUsdcBalance=0
actorMoonBalance=0
actorUsdcAllowanceToPermit2=0
actorMoonAllowanceToPermit2=0
transactionsPlanned=0
```

极小额资产/授权准备 dry-run 也已完成：

```text
PrepareBaseSepoliaTinyRehearsalAssets=passed
requiredUsdcBeforeAssetPrep=1605000
projectedSunOut=490000000000000000
projectedMoonOut=1187499858980000000
canExecuteAssetPrep=false
transactionsPlanned=9
transactionsExecuted=0
```

下一步不准备 Base 主网部署，也不接真实资金；准备真实小额流动性 + swap 广播草案和最终 dry-run。




