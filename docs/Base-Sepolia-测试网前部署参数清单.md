# Base Sepolia 测试网前部署参数清单

更新日期：2026-05-14

本文档只用于“测试网前预检查”。当前仍不部署主网，不接触真实资金，也不把真实私钥写入代码或文档。受控演练的完整流程见 `docs/Base-Sepolia-受控演练计划.md`，参数模板见 `docs/Base-Sepolia-参数模板.md`，地址准备说明见 `docs/Base-Sepolia-地址准备说明.md`，CREATE2 deployer 选择说明见 `docs/Base-Sepolia-CREATE2-Deployer选择说明.md`，最小部署规划见 `docs/Base-Sepolia-最小部署规划.md`，当前参数复核草稿见 `docs/演练记录-Base-Sepolia-2026-05-14.md`。

## 1. 当前结论

下一步如果进入测试网演练，建议只走 Base Sepolia，并且先跑参数预检：

```text
本地全量测试
  -> 计算 CREATE2 Hook salt
  -> 校验 Base Sepolia 官方地址
  -> 校验项目地址非零
  -> 校验预测 Hook 地址权限 bit
  -> 本地 adapter 预演
  -> Create2HookDeployer 已完成第一次小额广播并链上复核
  -> 准备曲线核心和 adapter 的第二次广播脚本
  -> 人工复核
  -> 才允许进入下一次测试网广播
```

当前新增的只读预检模块：

- `contracts/hooks/base/BaseDeploymentPreflight.sol`
- `contracts/hooks/base/Create2HookDeployer.sol`
- `script/CheckBaseSepoliaDeploymentParams.s.sol`
- `script/RehearseCreate2HookDeployer.s.sol`
- `script/PrepareBaseSepoliaCreate2Deployer.s.sol`
- `script/PrepareBaseSepoliaTestDeploy.s.sol`
- `script/PrepareBaseSepoliaHookDeploy.s.sol`
- `script/PrepareBaseSepoliaHookBinding.s.sol`
- `test/hooks/base/BaseDeploymentPreflight.t.sol`
- `test/hooks/base/Create2HookDeployer.t.sol`
- `test/hooks/base/Create2HookDeployerRehearsal.t.sol`
- `test/hooks/base/BaseSepoliaCreate2DeployerPreparation.t.sol`
- `test/hooks/base/BaseSepoliaTestDeployPreparation.t.sol`
- `test/hooks/base/BaseSepoliaHookDeployPreparation.t.sol`
- `test/hooks/base/BaseSepoliaHookBindingPreparation.t.sol`
- `script/RehearseBaseSepoliaAdapter.s.sol`
- `test/hooks/base/BaseSepoliaAdapterRehearsal.t.sol`

这些文件当前只用于本地预检、草图和测试；其中 `PrepareBaseSepoliaCreate2Deployer.s.sol` 已在用户明确批准后完成第一次 Base Sepolia 小额广播。`PrepareBaseSepoliaTestDeploy.s.sol` 已在用户明确批准后完成第二次 Base Sepolia 小额广播，部署曲线核心和 `TestnetUsdcAdapter`。`PrepareBaseSepoliaHookDeploy.s.sol` 已在用户明确批准后完成 Hook 小额广播。`PrepareBaseSepoliaHookBinding.s.sol` 已完成 dry-run、绑定广播和链上复核。

## 2. 官方 Base Sepolia 参数

2026-05-14 已按公开来源复核一次；广播或真实测试网交易前仍需再次打开来源复核：

- Uniswap v4 deployments：`https://docs.uniswap.org/contracts/v4/deployments`
- Circle USDC contract addresses：`https://developers.circle.com/stablecoins/usdc-contract-addresses`

预检脚本默认使用以下 Base Sepolia 官方地址：

| 参数 | 值 |
| --- | --- |
| `BASE_CHAIN_ID` | `84532` |
| `POOL_MANAGER` | `0x05E73354cFDd6745C338b50BcFDfA3Aa6fA03408` |
| `POSITION_MANAGER` | `0x4B2C77d209D3405F41a037Ec6c77F7F5b8e2ca80` |
| `STATE_VIEW` | `0x571291b572ed32ce6751a2Cb2486EbEe8DEfB9B4` |
| `QUOTER` | `0x4A6513c898fe1B2d0E78d3b0e0A4a151589B1cBa` |
| `UNIVERSAL_ROUTER` | `0x492E6456D9528771018DeB9E87ef7750EF184104` |
| `USDC_TOKEN` | `0x036CbD53842c5426634e7929541eC2318f3dCF7e` |
| `PERMIT2` | `0x000000000022D473030F116dDEE9F6B43aC78BA3` |

说明：

- 当前项目代码里仍有 `USDT`、`MockUSDT`、`injectUSDT()`、`minUSDTOut` 这些历史命名。
- 到 Base 路线时，这些位置实际对应 USDC。
- 暂时不做大规模重命名，避免打断已通过的测试。
- `STATE_VIEW` 和 `QUOTER` 先记录为后续池子查询/报价准备；当前 Hook 构造参数和预检脚本不依赖它们。

## 3. 项目必须补齐的参数

以下参数不能使用零地址，必须在测试网部署前人工确认：

| 参数 | 用途 | 当前要求 |
| --- | --- | --- |
| `MOON_TOKEN` | Base Sepolia 上的 MOON token 地址 | 已部署：`0x6E7FF34C7a7a518981BF6324e5FCC6599FcBC59D` |
| `SUN_CURVE` | Base Sepolia 上的 SunCurve 地址 | 已部署：`0x00F49621977e5219093A988879F07936F2155c07` |
| `PROTOCOL_BUDGET_ADDRESS` | 协议预算钱包 | 已填写：`0x277ba3Cf597CdAaF958C301db3cF6a631F793039`，不能等于 adapter |
| `SWAP_ADAPTER` | 真实或测试版 USDC adapter 地址 | 已部署：`0x50f232d1B40D9EF523cc53f958f8C80766aF35a7` |
| `HOOK_OWNER` | Hook 管理员 | 已填写：`0x6E22b2e6fFAA30Fe75B71d53d1eC469b4e97A986` |
| `DEPLOYER_ADDRESS` | 测试网部署钱包公开地址 | 已填写：`0x2F6E887c6058deE520f9468a1022E3480A6334D3`，用于广播前复核 |
| `CREATE2_DEPLOYER` | 项目自控 CREATE2 deployer 地址 | 已部署：`0xE5Df76A1DF2e959C70c8b7591754a3a2a542Fb6D` |
| `HOOK_SALT` | CREATE2 salt | 已生成：`0x00000000000000000000000000000000000000000000000000000000000022b9` |
| `PREDICTED_HOOK` | CREATE2 预测出的 Hook 地址 | 已生成：`0xF612828Ba9dE01CF16Fae2D8EE187B0cA59100Cc`，低 14 位权限 bit 等于 `204` |

还需要人工确认但当前预检脚本不自动判断：

- SUN 首次加池钱包：主网新决策已取消该角色；测试网历史项不再用于主网。
- SUN 池白名单。
- MOON 池白名单。
- `minUSDTOut` 由前端、脚本还是 keeper 生成。
- adapter 初始支持哪些非 USDC 手续费资产。

## 4. 本地预检步骤

第一步，先跑全量测试：

```powershell
forge test
```

第二步，用真实构造参数计算 Hook salt 和预测地址：

```powershell
forge script script/FindBaseMoonAmmFeeV4HookSalt.s.sol
```

运行时必须传入测试网准备使用的构造参数：

```text
CREATE2_DEPLOYER=0xE5Df76A1DF2e959C70c8b7591754a3a2a542Fb6D
POOL_MANAGER=0x05E73354cFDd6745C338b50BcFDfA3Aa6fA03408
MOON_TOKEN=0x6E7FF34C7a7a518981BF6324e5FCC6599FcBC59D
USDC_TOKEN=0x036CbD53842c5426634e7929541eC2318f3dCF7e
SUN_CURVE=0x00F49621977e5219093A988879F07936F2155c07
PROTOCOL_BUDGET_ADDRESS=0x277ba3Cf597CdAaF958C301db3cF6a631F793039
SWAP_ADAPTER=0x50f232d1B40D9EF523cc53f958f8C80766aF35a7
HOOK_OWNER=0x6E22b2e6fFAA30Fe75B71d53d1eC469b4e97A986
HOOK_SALT_START=0
HOOK_MAX_SALT_SEARCH=200000
```

`CREATE2_DEPLOYER` 必须等于未来实际部署 Hook 的 CREATE2 deployer。当前已固定为 `0xE5Df76A1DF2e959C70c8b7591754a3a2a542Fb6D`；不要把 `DEPLOYER_ADDRESS` 自动当成 `CREATE2_DEPLOYER`。

第三步，把 salt 搜索脚本输出的预测地址填入 `PREDICTED_HOOK`，再运行部署参数预检：

```powershell
forge script script/CheckBaseSepoliaDeploymentParams.s.sol
```

这个脚本会检查：

- Chain ID 必须是 Base Sepolia 的 `84532`。
- PoolManager / PositionManager / Universal Router / USDC 必须等于 Base Sepolia 官方地址。
- MOON、SunCurve、预算钱包、adapter、owner、预测 Hook 地址不能是零地址。
- 预算钱包不能和 adapter 是同一个地址。
- 预测 Hook 地址的低 14 位权限 bit 必须等于 `204`。

如果脚本失败，不应该继续部署。

第四步，复核已部署的 `Create2HookDeployer`：

```powershell
forge test --match-contract BaseSepoliaCreate2DeployerPreparationTest
forge script script/PrepareBaseSepoliaCreate2Deployer.s.sol
```

这个脚本只准备或部署 `Create2HookDeployer`，不部署 Hook、不部署曲线核心、不绑定 adapter。第一次小额广播已完成；后续如果重跑应只做 dry-run 或链上复核，不能重复把 `DEPLOYER_ADDRESS` 当成新的 `CREATE2_DEPLOYER`。

第五步，本地预演测试版 adapter，只使用测试 token 和受控 Mock 路由器：

```powershell
forge test --match-contract BaseSepoliaAdapterRehearsalTest
forge script script/RehearseBaseSepoliaAdapter.s.sol
```

这个预演不广播、不部署测试网，也不接真实 DEX。

## 5. 验收标准

测试网部署脚本开始前，至少满足：

- [x] `forge test` 全部通过：222 passed，0 failed。
- [x] `Create2HookDeployerTest` 本地测试已通过。
- [x] `Create2HookDeployerRehearsalTest` 本地预演测试已通过。
- [x] `BaseSepoliaCreate2DeployerPreparationTest` 本地脚本安全测试已通过。
- [x] 第一次 Base Sepolia 小额广播已完成，只部署 `Create2HookDeployer`。
- [x] `CREATE2_DEPLOYER` 已链上复核：代码非空，owner 正确。
- [x] 第二次小额广播脚本保护测试已通过：1 passed，0 failed。
- [x] 第二次小额广播 Base Sepolia dry-run 已通过，不加 `--broadcast`。
- [x] `FindBaseMoonAmmFeeV4HookSalt.s.sol` 使用真实构造参数重新跑过。
- [x] `CheckBaseSepoliaDeploymentParams.s.sol` 通过。
- [x] `BaseSepoliaAdapterRehearsal.t.sol` 本地 Mock 预演测试已通过。
- [x] `RehearseBaseSepoliaAdapter.s.sol` 本地 Mock 预演脚本已通过。
- [x] `PREDICTED_HOOK` 和 CREATE2 salt 已记录。
- [x] Hook 小额广播已完成并链上复核。
- [x] Hook 绑定 dry-run 已通过，不加 `--broadcast`。
- [x] Hook 绑定广播已完成并链上复核。
- [x] 受控 `MOON/USDC` 测试池 `poolId` dry-run 已通过：`0xfbb4ccec5e3fda3a97b9e2619e9e90588ad5e444bdb3d488e921a3192c42dd55`。
- [x] 受控 `MOON/USDC` 测试池白名单已在用户明确批准后广播并链上复核：`allowedMoonPools(poolId)=true`。
- [x] 受控 `MOON/USDC` 测试池初始化 dry-run 已通过：`initialTick=276300`，计划 1 笔初始化交易。
- [x] 用户明确批准后，受控 `MOON/USDC` 测试池初始化广播已完成并链上复核：`slot0.tick=276300`。
- [ ] 所有项目地址由两个人或两轮人工复核。
- [ ] `.env` 不提交到仓库。
- [ ] 不在文档、聊天记录、截图里保存真实私钥。
- [ ] 只准备 Base Sepolia，小额测试环境，不准备 Base 主网。

## 6. 当前不做

- 不部署 Base 主网。
- 不接真实资金。
- 不做未经测试的真实换币 adapter。
- 不让前端任意传入 fee token 或 fee amount。
- 不跳过 `BaseDeploymentPreflight` 参数预检。




