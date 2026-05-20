# 脚本目录

这里后续放部署脚本和辅助脚本。

## rc4 / mainnet 安全入口

当前 rc4 / Base mainnet 上线路径只允许使用新版统一 Hook：

```text
BaseSunMoonUsdcFeeV4Hook
```

主网上线前只读 / dry-run 应使用：

```text
script/PrepareBaseMainnetCoreDeployDryRun.s.sol
script/ComputeBaseMainnetSunMoonUsdcHookSalt.s.sol
script/ComputeBaseSunMoonUsdcPoolIds.s.sol
script/PrepareBaseMainnetSunMoonUsdcForkDryRun.s.sol
script/PrepareBaseMainnetSunMoonUsdcBroadcastDraft.s.sol
```

旧 `BaseMoonAmmFeeV4Hook`、`FindBaseMoonAmmFeeV4HookSalt.s.sol`、`PrepareBaseSepoliaHookDeploy.s.sol`、旧 `TinyMoonUsdc` 演练脚本均为 deprecated / legacy：旧方案，不用于 rc4/mainnet。

## 小白快速入口

当前状态：仍然只做文档、只读检查和 Base Sepolia 前端预览；不部署 Base 主网、不广播、不接触真实资金、不收集私钥。

- 外部 AI 审计提问包：`docs/Base-主网外部AI审计提问包-2026-05-20.md`
- AI 审计问题跟踪表：`docs/Base-主网AI审计问题跟踪表-2026-05-20.md`
- 最终红线清单：`docs/Base-主网部署前最终红线清单-2026-05-20.md`
- 最终只读复核记录：`docs/Base-主网最终只读复核记录-2026-05-20.md`
- 逐笔广播草案安全计划：`docs/Base-主网逐笔广播草案-2026-05-20.md`
- 中文白皮书：`docs/sunmoon-whitepaper.zh-CN.md`
- English whitepaper：`docs/sunmoon-whitepaper.en.md`
- Base Sepolia 前端只读预览：`frontend/README_OPEN.txt`
- 已推送安全标签：`mainnet-final-redline-checklist-2026-05-20`、`mainnet-readonly-review-2026-05-20`、`docs-audit-whitepaper-2026-05-20`

## 当前脚本

### `DeployLocal.s.sol`

用途：

- 部署 `MockUSDT`。
- 部署 `SunToken`。
- 部署 `SunCurve`。
- 部署 `MoonToken`。
- 部署 `MoonCurve`。
- 自动完成权限绑定。

绑定内容：

- `SunToken.setMinter(SunCurve)`
- `SunCurve.setMoonCurve(MoonCurve)`
- `SunCurve.setMoonAMM(MOON_AMM_ADDRESS)`
- `MoonToken.setMinter(MoonCurve)`

本地模拟运行：

```powershell
forge script script/DeployLocal.s.sol:DeployLocal -vvv
```

连接本地 Anvil 并广播时再使用：

```powershell
forge script script/DeployLocal.s.sol:DeployLocal --rpc-url http://127.0.0.1:8545 --broadcast
```

可选环境变量：

```text
PRIVATE_KEY=
PROTOCOL_BUDGET_ADDRESS=
MOON_AMM_ADDRESS=
MOON_LAUNCH_DELAY=0
```

### `FindBaseMoonAmmFeeV4HookSalt.s.sol`

Deprecated / legacy：旧 `BaseMoonAmmFeeV4Hook` salt 脚本，只保留历史 Base Sepolia / 本地测试参考；旧方案，不用于 rc4/mainnet。rc4/mainnet 使用 `ComputeBaseMainnetSunMoonUsdcHookSalt.s.sol`。

用途：

- 本地计算 `BaseMoonAmmFeeV4Hook` 的 CREATE2 init code hash。
- 搜索满足 Uniswap v4 Hook 低位权限 bit 的 salt。
- 只做预测和预检查，不广播、不部署。

本地运行：

```powershell
forge script script/FindBaseMoonAmmFeeV4HookSalt.s.sol
```

可选环境变量：

```text
CREATE2_DEPLOYER=0xE5Df76A1DF2e959C70c8b7591754a3a2a542Fb6D
HOOK_SALT_START=0
HOOK_MAX_SALT_SEARCH=200000
POOL_MANAGER=
MOON_TOKEN=
USDC_TOKEN=
SUN_CURVE=
PROTOCOL_BUDGET_ADDRESS=
SWAP_ADAPTER=
HOOK_OWNER=
```

说明：

- 如果不传环境变量，脚本会使用本地示例地址，只用于验证 salt 搜索逻辑。
- 真实测试网或主网部署前，必须填入真实构造参数重新计算 salt 和预测地址。
- 找到 salt 不等于已经部署合约，广播部署必须单独执行和复核。
- Base Sepolia 已部署 `CREATE2_DEPLOYER=0xE5Df76A1DF2e959C70c8b7591754a3a2a542Fb6D`，后续测试网 Hook salt 搜索必须使用该地址。
- `CREATE2_DEPLOYER` 必须等于未来实际部署 Hook 的 CREATE2 deployer；选择说明见 `docs/Base-Sepolia-CREATE2-Deployer选择说明.md`。

2026-05-15 使用真实 Base Sepolia 测试网参数重新运行：

```text
CREATE2_DEPLOYER=0xE5Df76A1DF2e959C70c8b7591754a3a2a542Fb6D
MOON_TOKEN=0x6E7FF34C7a7a518981BF6324e5FCC6599FcBC59D
SUN_CURVE=0x00F49621977e5219093A988879F07936F2155c07
SWAP_ADAPTER=0x50f232d1B40D9EF523cc53f958f8C80766aF35a7
HOOK_SALT=0x00000000000000000000000000000000000000000000000000000000000022b9
PREDICTED_HOOK=0xF612828Ba9dE01CF16Fae2D8EE187B0cA59100Cc
initCodeHash=0x306f254e5c441292e737d706681684bdcf210fecb5f71e35074fbd649a975bd4
actualLow14Bits=204
```

注意：

- 不要把真实私钥写进代码或文档。
- 当前脚本只用于本地和测试用途。
- 主网部署前需要单独准备正式部署脚本和部署参数记录。

### `Create2HookDeployer.sol`

位置：

```text
contracts/hooks/base/Create2HookDeployer.sol
```

用途：

- 作为项目自控的最小 CREATE2 Hook deployer 草图。
- 只允许 owner 调用部署函数。
- 支持按 `salt + initCodeHash` 预测地址。
- 支持 `deployHook()` 在部署前检查 Uniswap v4 Hook 低 14 位权限 bit。
- 当前只做本地测试，不广播、不部署测试网或主网。

对应回归测试：

```powershell
forge test --match-contract Create2HookDeployerTest
forge test --match-contract Create2HookDeployerRehearsalTest
forge test --match-contract BaseV4HookAddressMinerTest
```

说明：

- `CREATE2_DEPLOYER` 如果未来采用这个方案，应该填写已经部署到 Base Sepolia 的 `Create2HookDeployer` 合约地址。
- 不能把测试部署钱包 `DEPLOYER_ADDRESS` 自动当成 `CREATE2_DEPLOYER`。
- 在用户明确批准 Base Sepolia 广播前，本合约只停留在本地草图和测试阶段。

### `RehearseCreate2HookDeployer.s.sol`

Deprecated / legacy：旧 `BaseMoonAmmFeeV4Hook` 本地预演脚本，只保留历史参考；旧方案，不用于 rc4/mainnet。rc4/mainnet 使用 `RehearseBaseSunMoonUsdcFeeV4Hook.s.sol` 和主网 dry-run 脚本。

用途：

- 本地预演项目自控 `Create2HookDeployer` 方案。
- 部署本地 `Create2HookDeployer`。
- 用 `BaseMoonAmmFeeV4Hook` 构造参数计算 init code hash。
- 搜索满足 Uniswap v4 Hook 权限 bit 的 salt。
- 通过 `deployHook()` 部署 Hook，并验证实际地址等于预测地址。
- 只做本地模拟，不广播、不部署测试网或主网。

本地运行：

```powershell
forge script script/RehearseCreate2HookDeployer.s.sol
```

对应回归测试：

```powershell
forge test --match-contract Create2HookDeployerRehearsalTest
```

可选环境变量：

```text
CREATE2_DEPLOYER_OWNER=
HOOK_OWNER=
HOOK_SALT_START=0
HOOK_MAX_SALT_SEARCH=200000
POOL_MANAGER=
MOON_TOKEN=
USDC_TOKEN=
SUN_CURVE=
PROTOCOL_BUDGET_ADDRESS=
SWAP_ADAPTER=
```

说明：

- `CREATE2_DEPLOYER_OWNER` 是本地 deployer 草图的 owner；默认使用 `HOOK_OWNER`。
- 脚本输出的本地 `create2Deployer`、`hookSalt`、`predictedHook` 是模拟结果，不是 Base Sepolia 真实地址。
- 成功时会输出 `Create2HookDeployer local rehearsal passed`。
- 不要给这个脚本加 `--broadcast`。

### `PrepareBaseSepoliaCreate2Deployer.s.sol`

用途：

- 准备 Base Sepolia `Create2HookDeployer` 部署脚本。
- 已用于第一次 Base Sepolia 小额广播，输出并固定 `CREATE2_DEPLOYER`。
- 只部署 `Create2HookDeployer`，不部署 Hook、不部署曲线核心、不绑定 adapter。
- 连接到 Base Sepolia 链 ID 时，必须设置额外确认变量，否则脚本会拒绝运行。
- Base 主网链 ID 会直接拒绝。

本地模拟运行：

```powershell
$env:HOOK_OWNER="0x6E22b2e6fFAA30Fe75B71d53d1eC469b4e97A986"
forge script script/PrepareBaseSepoliaCreate2Deployer.s.sol
```

对应回归测试：

```powershell
forge test --match-contract BaseSepoliaCreate2DeployerPreparationTest
```

可选环境变量：

```text
PRIVATE_KEY=
HOOK_OWNER=
DEPLOYER_ADDRESS=
CREATE2_DEPLOYER_OWNER=
CONFIRM_BASE_SEPOLIA_CREATE2_DEPLOYER_RUN=0
```

说明：

- `CREATE2_DEPLOYER_OWNER` 默认使用 `HOOK_OWNER`。
- 如果设置了 `DEPLOYER_ADDRESS`，脚本会检查实际模拟/签名地址必须等于它，避免用错测试部署钱包。
- `CONFIRM_BASE_SEPOLIA_CREATE2_DEPLOYER_RUN=1` 只是允许脚本在 Base Sepolia 链 ID 上运行；不等于允许广播。
- 真正广播仍必须额外加 `--broadcast`，并且只能在用户明确批准后执行。
- 不要把私钥、助记词或完整 RPC key 写进脚本、文档或聊天记录。

2026-05-14 第一次 Base Sepolia 小额广播记录：

```text
CREATE2_DEPLOYER=0xE5Df76A1DF2e959C70c8b7591754a3a2a542Fb6D
CREATE2_DEPLOYER_OWNER=0x6E22b2e6fFAA30Fe75B71d53d1eC469b4e97A986
CREATE2_DEPLOYER_TX=0x87c9033101907c8e24aa13714154a212431a677837027191b023c00e70909596
```

后续不要重复部署新的 `Create2HookDeployer`，除非重新开启一轮完整的地址规划。下一步应准备曲线核心和 `TestnetUsdcAdapter` 的第二次小额广播脚本。

### `CheckBaseSepoliaDeploymentParams.s.sol`

用途：

- 本地检查 Base Sepolia 测试网前的关键部署参数。
- 校验官方 Base Sepolia v4 地址是否正确。
- 校验项目关键地址是否非零。
- 校验预测 Hook 地址低位权限 bit 是否等于 `BaseMoonAmmFeeV4Hook` v2 需要的 `204`。
- 只做参数检查，不广播、不部署。

本地运行：

```powershell
forge script script/CheckBaseSepoliaDeploymentParams.s.sol
```

环境变量：

```text
BASE_CHAIN_ID=84532
POOL_MANAGER=0x05E73354cFDd6745C338b50BcFDfA3Aa6fA03408
POSITION_MANAGER=0x4B2C77d209D3405F41a037Ec6c77F7F5b8e2ca80
UNIVERSAL_ROUTER=0x492E6456D9528771018DeB9E87ef7750EF184104
USDC_TOKEN=0x036CbD53842c5426634e7929541eC2318f3dCF7e
MOON_TOKEN=
SUN_CURVE=
PROTOCOL_BUDGET_ADDRESS=
SWAP_ADAPTER=
HOOK_OWNER=
PREDICTED_HOOK=
```

说明：

- 官方 Base Sepolia 地址有默认值；项目地址没有默认值，必须显式填写。
- Deprecated / legacy only：旧测试网 `PREDICTED_HOOK` 才来自 `FindBaseMoonAmmFeeV4HookSalt.s.sol`；rc4/mainnet 必须使用 `ComputeBaseMainnetSunMoonUsdcHookSalt.s.sol`。
- 预检脚本通过不等于已经部署成功，只代表参数形态可以进入下一轮人工复核。
- `StateView` 和 `Quoter` 已记录在 `BaseV4Addresses` 中，当前用于后续查询/报价准备，不是 Hook 构造参数。
- 公开地址来源：Uniswap v4 deployments 和 Circle USDC contract addresses；广播前必须再次打开官方来源复核。

2026-05-15 使用真实 Base Sepolia 测试网参数通过：

```text
PREDICTED_HOOK=0xF612828Ba9dE01CF16Fae2D8EE187B0cA59100Cc
expectedHookMask=204
actualHookMask=204
```

### `RehearseBaseSepoliaAdapter.s.sol`

用途：

- 本地预演测试版 USDC adapter 流程。
- 部署 Mock USDC、Mock fee asset、Mock USDC router 和 `TestnetUsdcAdapter`。
- 配置 token/router allowlist。
- 模拟授权 Hook 把非 USDC 手续费资产换成 Mock USDC。
- 模拟 `tokenIn == USDC` 的直通路径。
- 只做本地模拟，不广播、不部署测试网或主网。

本地运行：

```powershell
forge script script/RehearseBaseSepoliaAdapter.s.sol
```

对应回归测试：

```powershell
forge test --match-contract BaseSepoliaAdapterRehearsalTest
```

可选环境变量：

```text
HOOK_OWNER=
HOOK_ADDRESS=
REHEARSAL_AMOUNT_IN=30000000000000000000
REHEARSAL_MIN_USDC_OUT=40000000
REHEARSAL_MOCK_USDC_OUT=45000000
REHEARSAL_DIRECT_USDC_AMOUNT=30000000
REHEARSAL_DIRECT_MIN_USDC_OUT=25000000
```

说明：

- 这个脚本使用 `MockUSDT` 表示 6 位 USDC。
- `HOOK_ADDRESS` 只是本地模拟的授权调用者，不代表真实部署地址。
- 不要给这个脚本加 `--broadcast`。
- 成功时会输出 `Base Sepolia adapter local rehearsal passed`。

### `PrepareBaseSepoliaTestDeploy.s.sol`

用途：

- 准备 Base Sepolia 最小测试部署草图。
- 默认使用 Mock USDC 本地模拟，部署 `SunToken`、`SunCurve`、`MoonToken`、`MoonCurve` 和 `TestnetUsdcAdapter`。
- 自动绑定 `SunToken.setMinter(SunCurve)`、`SunCurve.setMoonCurve(MoonCurve)`、`MoonToken.setMinter(MoonCurve)`。
- 部署钱包会先作为临时 owner 完成绑定，脚本末尾再把所有权转给 `HOOK_OWNER`。
- 不部署 `BaseMoonAmmFeeV4Hook`，不设置 `SunCurve.moonAMM`；这两步必须等 CREATE2 预测 Hook 地址通过后再做。
- Base Sepolia 上必须显式设置确认变量，且禁止使用 Mock USDC。
- 只做本地模拟或 dry-run，不要加 `--broadcast`，除非用户明确批准 Base Sepolia 测试网广播。

本地模拟运行：

```powershell
forge script script/PrepareBaseSepoliaTestDeploy.s.sol
```

可选环境变量：

```text
PRIVATE_KEY=
HOOK_OWNER=
PROTOCOL_BUDGET_ADDRESS=
TEMP_AUTHORIZED_HOOK=
DEPLOYER_ADDRESS=
MOON_LAUNCH_DELAY=0
USE_MOCK_USDC=true
USDC_TOKEN=0x036CbD53842c5426634e7929541eC2318f3dCF7e
CONFIRM_BASE_SEPOLIA_TEST_DEPLOY_RUN=0
```

说明：

- `USE_MOCK_USDC=true` 是默认值，适合本地模拟，不需要 RPC。
- Base Sepolia dry-run / 广播必须设置 `USE_MOCK_USDC=false`，并使用官方 USDC：`0x036CbD53842c5426634e7929541eC2318f3dCF7e`。
- `CONFIRM_BASE_SEPOLIA_TEST_DEPLOY_RUN=1` 只是允许脚本在 Base Sepolia 链 ID 上运行，不等于允许广播。
- 如果设置了 `DEPLOYER_ADDRESS`，脚本会检查实际模拟/签名地址必须等于它，避免用错测试部署钱包。
- `TEMP_AUTHORIZED_HOOK` 只是 adapter 部署时的临时非零授权地址；Hook CREATE2 部署完成并复核后，必须调用 `setAuthorizedHook(Hook)` 切换到真实 Hook。
- 成功时会输出 `MOON_TOKEN`、`SUN_CURVE`、`SWAP_ADAPTER`、`HOOK_OWNER` 和 `PROTOCOL_BUDGET_ADDRESS`，用于下一步 CREATE2 预检。

2026-05-14 Base Sepolia dry-run 记录，不广播：

```text
deployer=0x2F6E887c6058deE520f9468a1022E3480A6334D3
chainId=84532
useMockUsdc=false
USDC=0x036CbD53842c5426634e7929541eC2318f3dCF7e
SUN_TOKEN_DRY_RUN=0xDa5a62F1c2c54AB79c974eE41
SUN_CURVE_DRY_RUN=0x00F49621977e5219093A988879F07936F2155c07
MOON_TOKEN_DRY_RUN=0x6E7FF34C7a7a518981BF6324e5FCC6599FcBC59D
MOON_CURVE_DRY_RUN=0x7f4296686917Be97E826DC790c367d93585A32c3
SWAP_ADAPTER_DRY_RUN=0x50f232d1B40D9EF523cc53f958f8C80766aF35a7
estimatedRequiredEth=0.000081493533
```

这些 dry-run 地址依赖 `DEPLOYER_ADDRESS` 当前 nonce 为 `1`；如果部署钱包先发了其他交易，必须重新 dry-run。

2026-05-15 Base Sepolia 第二次小额广播记录：

```text
chainId=84532
deployer=0x2F6E887c6058deE520f9468a1022E3480A6334D3
owner=0x6E22b2e6fFAA30Fe75B71d53d1eC469b4e97A986
protocolBudget=0x277ba3Cf597CdAaF958C301db3cF6a631F793039
USDC=0x036CbD53842c5426634e7929541eC2318f3dCF7e
SUN_TOKEN=0xDa5a62F1c2c54AB79c974eE41b9a5B83Dd307e41
SUN_CURVE=0x00F49621977e5219093A988879F07936F2155c07
MOON_TOKEN=0x6E7FF34C7a7a518981BF6324e5FCC6599FcBC59D
MOON_CURVE=0x7f4296686917Be97E826DC790c367d93585A32c3
SWAP_ADAPTER=0x50f232d1B40D9EF523cc53f958f8C80766aF35a7
DEPLOYER_ADDRESS nonce_after=14
DEPLOYER_ADDRESS balance_after=0.010063856527981176
```

链上复核已通过：

- 5 个合约地址均有非空 bytecode。
- 13 笔广播 receipt 均为 `status=0x1`。
- `SunToken.minter == SunCurve`，`MoonToken.minter == MoonCurve`。
- `SunCurve.moonCurve == MoonCurve`，`SunCurve.moonAMM == address(0)`。
- 所有 owner 已转给 `HOOK_OWNER`。
- `TestnetUsdcAdapter.usdc == 0x036CbD53842c5426634e7929541eC2318f3dCF7e`。
- `TestnetUsdcAdapter.authorizedHook` 最初是临时 `HOOK_OWNER`；Hook CREATE2 部署并复核后，已单独广播切换到实际 Hook。

