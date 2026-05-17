# 脚本目录

这里后续放部署脚本和辅助脚本。

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

用途：

- 本地预演项目自控 `Create2HookDeployer` 方案。
- 部署本地 `Create2HookDeployer`。
- 用 `BaseMoonAmmFeeV4Hook` 构造参数计算 init code hash。
- 搜索满足 Uniswap v4 Hook 权限 bit 的 salt。
- 通过 `deployHook()` 部署 Hook，并验证实际地址等于预测地址。

### `RehearseBaseSunMoonUsdcFeeV4Hook.s.sol`

用途：

- 本地预演新版统一 `BaseSunMoonUsdcFeeV4Hook` 的 CREATE2 部署。
- 用 `SUN/USDC` + `MOON/USDC` 统一 Hook 构造参数计算 init code hash。
- 搜索满足 Uniswap v4 Hook 权限 bit 的 salt。
- 通过本地 `Create2HookDeployer.deployHook()` 部署 Hook。
- 验证预测地址、实际部署地址、低 14 位权限 mask 和构造参数一致。

本地运行：

```powershell
forge script script/RehearseBaseSunMoonUsdcFeeV4Hook.s.sol
```

对应回归测试：

```powershell
forge test --match-path test/hooks/base/BaseSunMoonUsdcFeeV4HookCreate2Rehearsal.t.sol -vvv
```

可选环境变量：

```text
CREATE2_DEPLOYER_OWNER=
HOOK_OWNER=
HOOK_SALT_START=0
HOOK_MAX_SALT_SEARCH=200000
POOL_MANAGER=
SUN_TOKEN=
MOON_TOKEN=
USDC_TOKEN=
SUN_CURVE=
PROTOCOL_BUDGET_ADDRESS=
```

说明：

- 该脚本不调用 `startBroadcast`，只做本地预演。
- 不需要私钥，不接触真实资金，不部署主网。
- 如果不传环境变量，脚本会使用本地示例地址；这些输出不能当作测试网或主网部署参数。
- 真正进入测试网或主网前，必须用正式构造参数、固定的 `CREATE2_DEPLOYER`、正式 `SUN/USDC` 和 `MOON/USDC` pool 参数重新计算。
- 只做本地模拟，不广播、不部署测试网或主网。

### `ComputeBaseSunMoonUsdcPoolIds.s.sol`

用途：

- 本地计算新版统一 Hook 的 `SUN/USDC` 和 `MOON/USDC` 两个 v4 池 `PoolKey -> poolId`。
- 根据 owner 已确认的初始价格，计算 `initialTick` 和 `sqrtPriceX96`。
- 检查 Hook 地址低 14 位权限 bit 必须匹配 `BaseSunMoonUsdcFeeV4Hook`。
- 检查 SUN、MOON、USDC 地址不能为零、不能重复。
- 检查 fee 和 tickSpacing 有效。
- 只输出计算结果，不调用 `startBroadcast`，不授权、不部署、不需要私钥。

本地运行：

```powershell
forge script script/ComputeBaseSunMoonUsdcPoolIds.s.sol
```

对应回归测试：

```powershell
forge test --match-path test/hooks/base/BaseSunMoonUsdcPoolIdsPreparation.t.sol -vvv
```

可选环境变量：

```text
HOOK_ADDRESS=
SUN_TOKEN=
MOON_TOKEN=
USDC_TOKEN=
SUN_USDC_POOL_FEE=3000
SUN_USDC_POOL_TICK_SPACING=60
SUN_USDC_INITIAL_TOKEN_AMOUNT=1000000000000000000
SUN_USDC_INITIAL_USDC_AMOUNT=1000000
MOON_USDC_POOL_FEE=3000
MOON_USDC_POOL_TICK_SPACING=60
MOON_USDC_INITIAL_TOKEN_AMOUNT=1000000000000000000
MOON_USDC_INITIAL_USDC_AMOUNT=240000
```

说明：

- `SUN_USDC_INITIAL_TOKEN_AMOUNT=1e18` 与 `SUN_USDC_INITIAL_USDC_AMOUNT=1e6` 表示 `1 SUN = 1 USDC`。
- `MOON_USDC_INITIAL_TOKEN_AMOUNT=1e18` 与 `MOON_USDC_INITIAL_USDC_AMOUNT=240000` 表示 `1 MOON = 0.24 USDC`。
- `PoolManager.initialize(poolKey, sqrtPriceX96)` 可以使用精确价格对应的 `sqrtPriceX96`；输出的 `initialTick` 是 v4 根据该价格推导出的 tick，不要求是 `tickSpacing=60` 的倍数。后续 LP 仓位的 `tickLower/tickUpper` 才必须遵守 tick spacing。

### `PrepareBaseSepoliaRc3SunMoonUsdcDryRun.s.sol`

用途：

- 为 rc3 最新统一 Hook 方案准备 Base Sepolia dry-run。
- 本地或 Base Sepolia fork 中模拟部署新的测试版 `SunToken`、`SunCurve`、`MoonToken`、`MoonCurve`、`Create2HookDeployer`。
- 通过 CREATE2 模拟部署 `BaseSunMoonUsdcFeeV4Hook`，并检查 Hook 低 14 位权限 bit。
- 计算并初始化 `SUN/USDC` 与 `MOON/USDC` 两个测试池。
- 模拟白名单、`SunCurve.moonAMM` 绑定和 `renounceOwnership()` 后配置锁定。
- 拒绝 Base 主网 chainId，拒绝 `EXECUTE_BASE_SEPOLIA_RC3_BROADCAST=1`。

本地模拟命令，不需要 RPC、不需要私钥、不广播：

```powershell
forge script script/PrepareBaseSepoliaRc3SunMoonUsdcDryRun.s.sol
```

Base Sepolia fork 只模拟命令，不广播：

```powershell
$env:CONFIRM_BASE_SEPOLIA_RC3_DRY_RUN="1"
$env:EXECUTE_BASE_SEPOLIA_RC3_BROADCAST="0"
forge script script/PrepareBaseSepoliaRc3SunMoonUsdcDryRun.s.sol --rpc-url https://sepolia.base.org --rpc-timeout 120 --slow
```

可选环境变量：

```text
SEPOLIA_DEPLOYER=
SEPOLIA_ADMIN_WALLET=
SEPOLIA_PROTOCOL_BUDGET_WALLET=
SEPOLIA_CREATE2_DEPLOYER_OWNER=
POOL_MANAGER=
STATE_VIEW=
USDC_TOKEN=
MOON_LAUNCH_DELAY=0
SUN_USDC_POOL_FEE=3000
SUN_USDC_POOL_TICK_SPACING=60
SUN_USDC_INITIAL_TOKEN_AMOUNT=1000000000000000000
SUN_USDC_INITIAL_USDC_AMOUNT=1000000
MOON_USDC_POOL_FEE=3000
MOON_USDC_POOL_TICK_SPACING=60
MOON_USDC_INITIAL_TOKEN_AMOUNT=1000000000000000000
MOON_USDC_INITIAL_USDC_AMOUNT=240000
HOOK_SALT_START=0
HOOK_MAX_SALT_SEARCH=300000
CONFIRM_BASE_SEPOLIA_RC3_DRY_RUN=0
EXECUTE_BASE_SEPOLIA_RC3_BROADCAST=0
```

对应回归测试：

```powershell
forge test --match-path test/hooks/base/BaseSepoliaRc3SunMoonUsdcDryRunPreparation.t.sol -vvv
```

2026-05-17 本地专项测试结果：

```text
10 passed, 0 failed
```

2026-05-18 Base Sepolia fork 只读 dry-run 结果：

```text
Script ran successfully
chainId=84532
broadcastRequested=false
simulationOnly=true
predictedHook=0xcceD1a6C6f7E8210B9cEF6Ab8B3B59d62e2480Cc
SUN_USDC_POOL_ID=0xfce32214da284681d65059fa87ab5cf5dbf3af53e1d7afdcd78e9d7a6aad4a43
MOON_USDC_POOL_ID=0x1377ffa0adbb4dcd0be26eb97d703b4f590adee9a7ad72411ec7e75b6bfddf4a
renounceBlocksSunAllowlist=true
renounceBlocksMoonAllowlist=true
renounceBlocksProtocolBudget=true
```

说明：

- 这是 rc3 Base Sepolia 测试网演练草案，不是测试网广播批准。
- 真正广播前仍需要 owner 单独明确批准。
- 不要把私钥、助记词或完整 RPC key 写进命令、文档或聊天。

### `PrepareBaseSepoliaRc3SunMoonUsdcBroadcastDraft.s.sol`

用途：

- 为 rc3 最新统一 Hook 方案准备 Base Sepolia 测试网广播草案。
- 只生成分阶段计划，不执行广播。
- 复用 rc3 dry-run，输出预测核心地址、Hook salt、预测 Hook、两个 poolId 和初始化参数。
- 默认 `broadcastAllowed=false`。
- 拒绝 Base 主网、拒绝 `EXECUTE_BASE_SEPOLIA_RC3_BROADCAST=1`、拒绝非空 `PRIVATE_KEY`。

本地草案命令，不需要 RPC、不需要私钥、不广播：

```powershell
forge script script/PrepareBaseSepoliaRc3SunMoonUsdcBroadcastDraft.s.sol
```

Base Sepolia fork 只读草案命令，不广播：

```powershell
$env:CONFIRM_BASE_SEPOLIA_RC3_BROADCAST_DRAFT="1"
$env:EXECUTE_BASE_SEPOLIA_RC3_BROADCAST="0"
forge script script/PrepareBaseSepoliaRc3SunMoonUsdcBroadcastDraft.s.sol --rpc-url https://sepolia.base.org --rpc-timeout 120 --slow
```

对应回归测试：

```powershell
forge test --match-path test/hooks/base/BaseSepoliaRc3SunMoonUsdcBroadcastDraft.t.sol --threads 1 --isolate
```

2026-05-18 本地专项测试结果：

```text
9 passed, 0 failed
```

2026-05-18 本地草案脚本结果：

```text
Script ran successfully
broadcastAllowed=false
simulationOnly=true
totalTransactionsPlanned=19
```

说明：

- 这是广播草案，不是测试网广播批准。
- 不要添加 `--broadcast`。
- 不要设置 `PRIVATE_KEY`。
- 真正测试网广播前仍需要 owner 单独明确批准。

2026-05-17 使用 Base mainnet 预测地址运行本地计算，不广播：

```text
HOOK_ADDRESS=0x04f968dE5cd57B1EB8215a9a488dC32508Fb80cc
SUN_TOKEN=0xbA010450885AadcDA402358d04be881Bd53E482b
MOON_TOKEN=0xf3Bff3b498369022313aD55138ea41B236B61EBf
USDC_TOKEN=0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913

SUN_USDC_CURRENCY0=0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913
SUN_USDC_CURRENCY1=0xbA010450885AadcDA402358d04be881Bd53E482b
SUN_USDC_POOL_FEE=3000
SUN_USDC_TICK_SPACING=60
SUN_USDC_INITIAL_TICK=276324
SUN_USDC_SQRT_PRICE_X96=79228162514264337593543950336000000
SUN_USDC_POOL_ID=0xf0006d5dde476ffd2b43648468d5c6a6a8cf1f40bcac5c0c7d070491587e075a

MOON_USDC_CURRENCY0=0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913
MOON_USDC_CURRENCY1=0xf3Bff3b498369022313aD55138ea41B236B61EBf
MOON_USDC_POOL_FEE=3000
MOON_USDC_TICK_SPACING=60
MOON_USDC_INITIAL_TICK=290595
MOON_USDC_SQRT_PRICE_X96=161723809515207654377831473576838109
MOON_USDC_POOL_ID=0xcf29a02432e947fe9240fe4378cb871b24691f7cd85e7e8c72464ff89c1c6735
```

这些仍是基于预测地址的计算结果，不是已部署池，也不是主网广播批准。

说明：

- 如果不传环境变量，脚本只使用本地示例地址，输出不能当作测试网或主网参数。
- 正式参数必须在部署当天再次复核，尤其是 Hook 地址、正式 SUN、正式 MOON、Base 官方 USDC、fee 和 tickSpacing。
- 这个脚本只计算 poolId，不会把 poolId 写入 Hook 白名单。
- 后续任何白名单或初始化广播都必须单独提出，并由用户明确批准。

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
- `PREDICTED_HOOK` 应来自 `FindBaseMoonAmmFeeV4HookSalt.s.sol` 的输出。
- 预检脚本通过不等于已经部署成功，只代表参数形态可以进入下一轮人工复核。
- `StateView` 和 `Quoter` 已记录在 `BaseV4Addresses` 中，当前用于后续查询/报价准备，不是 Hook 构造参数。
- 公开地址来源：Uniswap v4 deployments 和 Circle USDC contract addresses；广播前必须再次打开官方来源复核。

2026-05-15 使用真实 Base Sepolia 测试网参数通过：

```text
PREDICTED_HOOK=0xF612828Ba9dE01CF16Fae2D8EE187B0cA59100Cc
expectedHookMask=204
actualHookMask=204
```

### `PrepareBaseSepoliaHookDeploy.s.sol`

用途：

- 准备 Base Sepolia `BaseMoonAmmFeeV4Hook` CREATE2 部署脚本。
- 复核 `CREATE2_DEPLOYER.owner == HOOK_OWNER`，避免用错签名钱包。
- 复核 `HOOK_SALT + initCodeHash` 计算出的地址等于 `PREDICTED_HOOK`。
- 复核预测 Hook 地址低 14 位权限 bit 等于 `204`。
- 复核 PoolManager、USDC、MOON、SunCurve、adapter 等链上依赖均有代码。
- Base Sepolia 上必须显式设置确认变量；Base 主网链 ID 直接拒绝。

本地/测试网 dry-run 命令示例，不广播：

```powershell
$env:CREATE2_DEPLOYER="0xE5Df76A1DF2e959C70c8b7591754a3a2a542Fb6D"
$env:HOOK_OWNER="0x6E22b2e6fFAA30Fe75B71d53d1eC469b4e97A986"
$env:PROTOCOL_BUDGET_ADDRESS="0x277ba3Cf597CdAaF958C301db3cF6a631F793039"
$env:MOON_TOKEN="0x6E7FF34C7a7a518981BF6324e5FCC6599FcBC59D"
$env:SUN_CURVE="0x00F49621977e5219093A988879F07936F2155c07"
$env:SWAP_ADAPTER="0x50f232d1B40D9EF523cc53f958f8C80766aF35a7"
$env:USDC_TOKEN="0x036CbD53842c5426634e7929541eC2318f3dCF7e"
$env:HOOK_SALT="0x00000000000000000000000000000000000000000000000000000000000022b9"
$env:PREDICTED_HOOK="0xF612828Ba9dE01CF16Fae2D8EE187B0cA59100Cc"
$env:CONFIRM_BASE_SEPOLIA_HOOK_DEPLOY_RUN="1"
forge script script/PrepareBaseSepoliaHookDeploy.s.sol --rpc-url https://sepolia.base.org --sender $env:HOOK_OWNER --rpc-timeout 120 --slow
```

对应回归测试：

```powershell
forge test --match-contract BaseSepoliaHookDeployPreparationTest
```

2026-05-15 Base Sepolia Hook dry-run 记录，不广播：

```text
chainId=84532
CREATE2_DEPLOYER=0xE5Df76A1DF2e959C70c8b7591754a3a2a542Fb6D
HOOK_OWNER / tx sender=0x6E22b2e6fFAA30Fe75B71d53d1eC469b4e97A986
HOOK_SALT=0x00000000000000000000000000000000000000000000000000000000000022b9
initCodeHash=0x306f254e5c441292e737d706681684bdcf210fecb5f71e35074fbd649a975bd4
PREDICTED_HOOK=0xF612828Ba9dE01CF16Fae2D8EE187B0cA59100Cc
DEPLOYED_HOOK_DRY_RUN=0xF612828Ba9dE01CF16Fae2D8EE187B0cA59100Cc
expectedHookMask=204
actualLow14Bits=204
estimatedRequiredEth=0.000030782763
HOOK_OWNER_BALANCE=0.002
HOOK_OWNER_NONCE=0
```

说明：

- 真正 Hook 广播必须由 `HOOK_OWNER` 签名，因为 `Create2HookDeployer` 的 owner 是 `HOOK_OWNER`。
- `DEPLOYER_ADDRESS` 已经不是这一步的签名账户；它只负责了前两次测试网部署。
- 当前 `HOOK_OWNER` 已有 Base Sepolia 测试 ETH，最终 dry-run 已通过；真实广播仍需要用户单独明确批准。
- 后续只有在用户明确批准“允许广播部署 Hook 到 Base Sepolia”后，才能加 `--broadcast`。
- 不要把私钥、助记词或完整 RPC key 写进脚本、文档或聊天记录。

2026-05-15 Base Sepolia Hook 小额广播记录：

```text
HOOK_DEPLOY_TX=0x376baf6403018674a6b61bc4b84324e13fc7fafcb8c1970c8f15b06215e59e17
receiptStatus=0x1
blockNumber=41507301
gasUsed=1913459
HOOK_DEPLOYED=0xF612828Ba9dE01CF16Fae2D8EE187B0cA59100Cc
HOOK_OWNER_BALANCE_AFTER=0.001988519245970799
HOOK_OWNER_NONCE_AFTER=1
```

链上复核已通过：

- `HOOK_DEPLOYED == PREDICTED_HOOK`。
- `HOOK_DEPLOYED.code` 非空。
- `owner == HOOK_OWNER`。
- `expectedHookMask == 204`。
- Hook 构造参数中的 PoolManager、USDC、MOON、SunCurve、protocolBudget、swapAdapter 均与预检一致。
- `paused == false`。

后续绑定当前状态：

- `TestnetUsdcAdapter.authorizedHook == HOOK_ADDRESS`。
- `SunCurve.moonAMM == HOOK_ADDRESS`。
- 绑定 dry-run、广播和链上复核均已通过。
- 本次绑定只做配置交易，没有重新部署 Hook。

### `PrepareBaseSepoliaHookBinding.s.sol`

用途：

- 准备 Base Sepolia Hook 权限绑定脚本。
- 复核 `HOOK_ADDRESS`、`SWAP_ADAPTER`、`SUN_CURVE` 三个地址都有链上代码。
- 复核 Hook、adapter、SunCurve 的 owner 都是 `HOOK_OWNER`。
- 复核 Hook 构造参数里的 `swapAdapter` 和 `sunCurve` 与准备绑定的地址一致。
- 复核 Hook 低 14 位权限 bit 和 `expectedHookMask` 都是 `204`。
- 如果尚未绑定，预演两笔交易：`TestnetUsdcAdapter.setAuthorizedHook(Hook)` 与 `SunCurve.setMoonAMM(Hook)`。
- Base Sepolia 上必须显式设置确认变量；Base 主网链 ID 直接拒绝。

Base Sepolia dry-run 命令示例，不广播：

```powershell
$env:HOOK_OWNER="0x6E22b2e6fFAA30Fe75B71d53d1eC469b4e97A986"
$env:HOOK_ADDRESS="0xF612828Ba9dE01CF16Fae2D8EE187B0cA59100Cc"
$env:SWAP_ADAPTER="0x50f232d1B40D9EF523cc53f958f8C80766aF35a7"
$env:SUN_CURVE="0x00F49621977e5219093A988879F07936F2155c07"
$env:CONFIRM_BASE_SEPOLIA_HOOK_BINDING_RUN="1"
forge script script/PrepareBaseSepoliaHookBinding.s.sol --rpc-url https://sepolia.base.org --sender $env:HOOK_OWNER --rpc-timeout 120 --slow
```

对应回归测试：

```powershell
forge test --match-contract BaseSepoliaHookBindingPreparationTest
```

2026-05-15 Base Sepolia Hook 绑定 dry-run 记录，不广播：

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
estimatedRequiredEth=0.000001204511
```

说明：

- 上面的 `After` 是 dry-run 模拟结果，不代表已经上链。
- 用户明确批准后，已广播绑定交易，链上状态已复核。
- `TestnetUsdcAdapter.authorizedHook == HOOK_ADDRESS`。
- `SunCurve.moonAMM == HOOK_ADDRESS`。
- 不要把私钥、助记词或完整 RPC key 写进脚本、文档或聊天记录。

2026-05-15 Base Sepolia Hook 绑定广播记录：

```text
BIND_ADAPTER_TX=0x1319e675384b1e014debdb806a27915797bbd0cf8da9e253f04b1cc643ef97c4
BIND_ADAPTER_RECEIPT_STATUS=0x1
BIND_SUN_CURVE_TX=0x6a6154f5e075f4b6d0975c4b60e1d517885adccb4577eb678134f4cc3966ed7c
BIND_SUN_CURVE_RECEIPT_STATUS=0x1
adapterAuthorizedHookAfter=0xF612828Ba9dE01CF16Fae2D8EE187B0cA59100Cc
sunCurveMoonAMMAfter=0xF612828Ba9dE01CF16Fae2D8EE187B0cA59100Cc
```

### `PrepareBaseSepoliaControlledMoonPool.s.sol`

用途：

- 准备 Base Sepolia 受控 `MOON/USDC` 测试池。
- 使用完整 Uniswap v4 `PoolKey` 计算 `poolId`，不手填、不猜测。
- 复核 Hook owner、MOON token、USDC token 和 Hook 权限 bit。
- dry-run `BaseMoonAmmFeeV4Hook.setAllowedMoonPool(poolId, true)`，不默认广播。
- Base Sepolia 上必须显式设置确认变量；Base 主网链 ID 直接拒绝。

Base Sepolia dry-run 命令示例，不广播：

```powershell
$env:HOOK_OWNER="0x6E22b2e6fFAA30Fe75B71d53d1eC469b4e97A986"
$env:HOOK_ADDRESS="0xF612828Ba9dE01CF16Fae2D8EE187B0cA59100Cc"
$env:CONTROLLED_POOL_MOON_TOKEN="0x6E7FF34C7a7a518981BF6324e5FCC6599FcBC59D"
$env:CONTROLLED_POOL_USDC_TOKEN="0x036CbD53842c5426634e7929541eC2318f3dCF7e"
$env:MOON_USDC_POOL_FEE="3000"
$env:MOON_USDC_POOL_TICK_SPACING="60"
$env:CONFIRM_BASE_SEPOLIA_CONTROLLED_POOL_RUN="1"
forge script script/PrepareBaseSepoliaControlledMoonPool.s.sol --rpc-url https://sepolia.base.org --sender $env:HOOK_OWNER --rpc-timeout 120 --slow
```

对应回归测试：

```powershell
forge test --match-contract BaseSepoliaControlledMoonPoolPreparationTest
```

2026-05-15 Base Sepolia 受控 `MOON/USDC` poolId dry-run 记录，不广播：

```text
chainId=84532
HOOK_ADDRESS=0xF612828Ba9dE01CF16Fae2D8EE187B0cA59100Cc
MOON_TOKEN=0x6E7FF34C7a7a518981BF6324e5FCC6599FcBC59D
USDC_TOKEN=0x036CbD53842c5426634e7929541eC2318f3dCF7e
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

说明：

- `allowedMoonPoolAfter=true` 是 dry-run 模拟结果；真实链上结果以广播 receipt 和 `cast call` 复核为准。
- 2026-05-15 用户明确批准“允许广播白名单 MOON/USDC 测试池到 Base Sepolia”后，已广播 `setAllowedMoonPool(poolId, true)`。
- 交互式广播需要用户在本机输入私钥时，提示必须带上具体地址：请输入 `HOOK_OWNER=0x6E22b2e6fFAA30Fe75B71d53d1eC469b4e97A986` 对应的钱包私钥。

广播记录：

```text
ALLOW_MOON_USDC_POOL_TX=0x9f219d37f1a72dc6229df79217ed953f1e6ff01ed1f4d958854fe432616ed325
receiptStatus=1
blockNumber=41524110
gasUsed=45833
allowedMoonPools(poolId)=true
```

### `PrepareBaseSepoliaControlledMoonPoolInitialize.s.sol`

用途：

- 准备 Base Sepolia 受控 `MOON/USDC` 测试池初始化。
- 复用完整 `PoolKey` 和已白名单的 `poolId`。
- 复核 `PoolManager`、`StateView`、Hook、MOON、USDC、白名单状态和初始 tick。
- dry-run `PoolManager.initialize(poolKey, sqrtPriceX96)`，不默认广播。
- 如果池已经按同一价格初始化，则计划 0 笔交易；如果已用不同价格初始化，则直接拒绝。

Base Sepolia dry-run 命令示例，不广播：

```powershell
$env:HOOK_OWNER="0x6E22b2e6fFAA30Fe75B71d53d1eC469b4e97A986"
$env:POOL_INITIALIZER="0x6E22b2e6fFAA30Fe75B71d53d1eC469b4e97A986"
$env:HOOK_ADDRESS="0xF612828Ba9dE01CF16Fae2D8EE187B0cA59100Cc"
$env:CONTROLLED_POOL_MOON_TOKEN="0x6E7FF34C7a7a518981BF6324e5FCC6599FcBC59D"
$env:CONTROLLED_POOL_USDC_TOKEN="0x036CbD53842c5426634e7929541eC2318f3dCF7e"
$env:MOON_USDC_POOL_FEE="3000"
$env:MOON_USDC_POOL_TICK_SPACING="60"
$env:MOON_USDC_INITIAL_TICK="276300"
$env:CONFIRM_BASE_SEPOLIA_POOL_INITIALIZE_RUN="1"
forge script script/PrepareBaseSepoliaControlledMoonPoolInitialize.s.sol --rpc-url https://sepolia.base.org --sender $env:POOL_INITIALIZER --rpc-timeout 120 --slow
```

对应回归测试：

```powershell
forge test --match-contract BaseSepoliaControlledMoonPoolInitializePreparationTest
```

2026-05-15 Base Sepolia 受控 `MOON/USDC` 初始化 dry-run 记录，不广播：

```text
chainId=84532
POOL_INITIALIZER=0x6E22b2e6fFAA30Fe75B71d53d1eC469b4e97A986
POOL_MANAGER=0x05E73354cFDd6745C338b50BcFDfA3Aa6fA03408
STATE_VIEW=0x571291b572ed32ce6751a2Cb2486EbEe8DEfB9B4
HOOK_ADDRESS=0xF612828Ba9dE01CF16Fae2D8EE187B0cA59100Cc
poolId=0xfbb4ccec5e3fda3a97b9e2619e9e90588ad5e444bdb3d488e921a3192c42dd55
allowedMoonPool=true
initialTick=276300
sqrtPriceX96=79133045881256921541446514419412387
humanPriceApprox=1 MOON ~= 1.0024 USDC
sqrtPriceBefore=0
alreadyInitialized=false
transactionsPlanned=1
sqrtPriceAfter=79133045881256921541446514419412387
tickAfter=276300
estimatedRequiredEth=0.000000839773
```

说明：

- 上方是广播前 dry-run 记录，用来证明初始化前 `sqrtPriceBefore=0`，且只计划 1 笔初始化交易。
- 2026-05-15 用户明确批准“允许广播初始化 MOON/USDC 测试池到 Base Sepolia”后，已广播 `PoolManager.initialize(poolKey, sqrtPriceX96)`。
- 交互式广播需要用户在本机输入私钥时，提示必须带上具体地址：请输入 `POOL_INITIALIZER=0x6E22b2e6fFAA30Fe75B71d53d1eC469b4e97A986` 对应的钱包私钥。

广播记录：

```text
MOON_USDC_INITIALIZE_TX=0x72c93bb0a5bdb540b2e696eaff50614e4571cfe1dbe3bb64494ec9719cdc8310
receiptStatus=1
blockNumber=41525115
gasUsed=52201
from=0x6E22b2e6fFAA30Fe75B71d53d1eC469b4e97A986
to=0x05E73354cFDd6745C338b50BcFDfA3Aa6fA03408
```

广播后链上复核：

```text
StateView.getSlot0(poolId).sqrtPriceX96=79133045881256921541446514419412387
StateView.getSlot0(poolId).tick=276300
StateView.getSlot0(poolId).protocolFee=0
StateView.getSlot0(poolId).lpFee=3000
allowedMoonPools(poolId)=true
alreadyInitialized=true
transactionsPlanned=0
```

### `PrepareBaseSepoliaTinyMoonUsdcRehearsal.s.sol`

用途：

- 准备 Base Sepolia 受控 `MOON/USDC` 测试池的极小额流动性/交换演练。
- 只读检查 PoolManager、StateView、PositionManager、UniversalRouter、Permit2、Hook、adapter、SunCurve、MOON、USDC 是否都有代码且参数匹配。
- 复核池子已经初始化、`allowedMoonPools(poolId)=true`、Hook 未暂停、adapter 已授权、`SunCurve.moonAMM` 已绑定、protocol budget 非零。
- 读取演练账户的 USDC/MOON 余额、ERC20 -> Permit2 授权、Permit2 -> PositionManager/UniversalRouter 授权。
- 计算极小额默认计划：加流动性 `1 USDC + 1 MOON`，交换 `0.1 USDC`，Hook 费用为 `0.003 USDC` 注入 SUN 曲线、`0.002 USDC` 进入预算钱包。
- 本脚本永远不广播交易，`transactionsPlanned=0`；即使加 `--broadcast` 也只是读取和打印状态。

Base Sepolia 只读 dry-run 命令示例：

```powershell
$env:REHEARSAL_ACTOR="0x6E22b2e6fFAA30Fe75B71d53d1eC469b4e97A986"
$env:HOOK_ADDRESS="0xF612828Ba9dE01CF16Fae2D8EE187B0cA59100Cc"
$env:CONFIRM_BASE_SEPOLIA_TINY_REHEARSAL_RUN="1"
forge script script/PrepareBaseSepoliaTinyMoonUsdcRehearsal.s.sol --rpc-url https://sepolia.base.org --sender $env:REHEARSAL_ACTOR --rpc-timeout 120 --slow
```

对应回归测试：

```powershell
forge test --match-contract BaseSepoliaTinyMoonUsdcRehearsalPreparationTest
```

2026-05-15 Base Sepolia 只读 dry-run 结果：

```text
poolInitialized=true
slot0.tick=276300
slot0.lpFee=3000
allowedMoonPool=true
hookPaused=false
adapterAuthorized=true
sunCurveBound=true
protocolBudgetConfigured=true
tinyLiquidityUsdcAmount=1000000
tinyLiquidityMoonAmount=1000000000000000000
tinySwapUsdcIn=100000
swapFeeToSunCurve=3000
swapFeeToProtocol=2000
swapUsdcGrossInputWithHookFee=105000
swapMinUsdcToCurve=3000
swapHookData=0x0000000000000000000000000000000000000000000000000000000000000bb8
actorUsdcBalance=0
actorMoonBalance=0
actorUsdcAllowanceToPermit2=0
actorMoonAllowanceToPermit2=0
readyForLiquidityDryRun=false
readyForSwapDryRun=false
readyForCombinedDryRun=false
transactionsPlanned=0
```

说明：这是资产准备前的历史 dry-run 记录。后续已完成测试 USDC 充值、资产/Permit2 授权广播和链上复核；再次运行准备脚本时 `readyForCombinedDryRun=true`。需要用户输入私钥时必须写明具体地址，例如：请输入 `REHEARSAL_ACTOR=0x6E22b2e6fFAA30Fe75B71d53d1eC469b4e97A986` 对应的钱包私钥。

### `PrepareBaseSepoliaTinyRehearsalAssets.s.sol`

用途：

- 为后续极小额 `MOON/USDC` 流动性/交换演练准备测试资产和 Permit2 授权。
- 默认只读，不广播，不要求私钥。
- 检查 USDC、SUN、MOON、SunCurve、MoonCurve、Permit2、PositionManager、UniversalRouter 的链上代码和参数绑定。
- 估算默认资产准备路径：用 `0.5 USDC` 铸造约 `0.49 SUN`，再用 `0.3 SUN` 铸造约 `1.18749985898 MOON`。
- 计算演练所需测试 USDC：流动性和 swap 预留 `1.105 USDC`，再加铸造 SUN 的 `0.5 USDC`，当前最少需要 `1.605 USDC`。
- 只有在 `EXECUTE_BASE_SEPOLIA_TINY_ASSET_APPROVALS=1` 且用户明确批准后，才允许进入资产/授权准备广播。

Base Sepolia 只读 dry-run 命令示例：

```powershell
$env:REHEARSAL_ACTOR="0x6E22b2e6fFAA30Fe75B71d53d1eC469b4e97A986"
$env:CONFIRM_BASE_SEPOLIA_TINY_ASSET_APPROVALS_RUN="1"
$env:EXECUTE_BASE_SEPOLIA_TINY_ASSET_APPROVALS="0"
forge script script/PrepareBaseSepoliaTinyRehearsalAssets.s.sol --rpc-url https://sepolia.base.org --sender $env:REHEARSAL_ACTOR --rpc-timeout 120 --slow
```

对应回归测试：

```powershell
forge test --match-contract BaseSepoliaTinyRehearsalAssetsPreparationTest
```

2026-05-15 Base Sepolia 只读 dry-run 结果：

```text
moonLaunchSecondsRemaining=0
sunPrice=0
moonPriceInSun=240000000000000000
moonPriceInUsdc=0
liquidityUsdcAmount=1000000
liquidityMoonAmount=1000000000000000000
swapUsdcIn=100000
swapUsdcGrossInputWithHookFee=105000
requiredUsdcForRehearsal=1105000
sunMintUsdcAmount=500000
moonMintSunAmount=300000000000000000
projectedSunOut=490000000000000000
projectedMoonOut=1187499858980000000
actorUsdcBalance=0
actorSunBalance=0
actorMoonBalance=0
requiredUsdcBeforeAssetPrep=1605000
canExecuteAssetPrep=false
transactionsPlanned=9
transactionsExecuted=0
```

后续状态：

- 用户已给 `REHEARSAL_ACTOR=0x6E22b2e6fFAA30Fe75B71d53d1eC469b4e97A986` 准备 Base Sepolia 测试 USDC。
- 用户明确批准后，资产与 Permit2 授权准备广播已完成；链上复核余额为 `19.5 USDC`、`0.19 SUN`、约 `1.18749985898 MOON`。
- 复跑本脚本只读 dry-run 后 `transactionsPlanned=0`，表示资产/授权准备没有剩余待执行交易。
- 若后续还需要交互式广播，提示必须写明具体地址：请输入 `REHEARSAL_ACTOR=0x6E22b2e6fFAA30Fe75B71d53d1eC469b4e97A986` 对应的钱包私钥。不要把私钥发到聊天或文档。

### `PrecheckBaseSepoliaTinyMoonUsdcQuote.s.sol`

用途：

- 在 Base Sepolia fork 本地模拟极小额 `MOON/USDC` 加流动性和 swap 报价。
- 先复用 `PrepareBaseSepoliaTinyMoonUsdcRehearsal.s.sol` 检查链上配置、余额和 Permit2 授权。
- 本地模拟 mint 一个窄区间流动性头寸：默认 tick 区间 `[275700, 276900]`。
- 再调用 Base Sepolia v4 Quoter 对 `0.1 USDC -> MOON` 进行报价。
- 不广播、不要求私钥；即使加 `--broadcast`，脚本也不使用 `vm.startBroadcast`。

Base Sepolia 只读预检命令：

```powershell
$env:REHEARSAL_ACTOR="0x6E22b2e6fFAA30Fe75B71d53d1eC469b4e97A986"
$env:HOOK_ADDRESS="0xF612828Ba9dE01CF16Fae2D8EE187B0cA59100Cc"
$env:CONFIRM_BASE_SEPOLIA_TINY_REHEARSAL_RUN="1"
forge script script/PrecheckBaseSepoliaTinyMoonUsdcQuote.s.sol --rpc-url https://sepolia.base.org --sender $env:REHEARSAL_ACTOR --rpc-timeout 120 --slow
```

2026-05-15 Base Sepolia fork 预检结果：

```text
readyForLiquidityDryRun=true
readyForSwapDryRun=true
readyForCombinedDryRun=true
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
suggestedMinMoonOut=84801577047607691
readyForTinyBroadcast=true
```

说明：这一步证明小额流动性和报价路径可以在 fork 中跑通。后续已继续准备真实广播命令草案和 dry-run，不直接进入 Base 主网，也不接真实资金。

### `PrepareBaseSepoliaTinyMoonUsdcBroadcast.s.sol`

用途：

- 准备 Base Sepolia 极小额 `MOON/USDC` 加流动性 + swap 广播草案。
- 复用 `PrepareBaseSepoliaTinyMoonUsdcRehearsal.s.sol` 检查链上配置、余额和 Permit2 授权。
- 先在 fork 中模拟 `1 USDC + 约 0.997600359915023894 MOON` 的窄区间流动性，再模拟 `0.1 USDC -> MOON` swap。
- 默认只读草案，不广播、不要求私钥；只有显式设置执行变量并由用户明确批准后，才允许进入真实 Base Sepolia 广播。
- 使用 Base Sepolia 当前 Universal Router 兼容的旧版 v4 swap struct 编码；不要改回裸字段编码。

Base Sepolia 草案 dry-run 命令，不广播：

```powershell
$env:REHEARSAL_ACTOR="0x6E22b2e6fFAA30Fe75B71d53d1eC469b4e97A986"
$env:HOOK_ADDRESS="0xF612828Ba9dE01CF16Fae2D8EE187B0cA59100Cc"
$env:CONFIRM_BASE_SEPOLIA_TINY_REHEARSAL_RUN="1"
$env:CONFIRM_BASE_SEPOLIA_TINY_BROADCAST_RUN="1"
$env:EXECUTE_BASE_SEPOLIA_TINY_LIQUIDITY="1"
$env:EXECUTE_BASE_SEPOLIA_TINY_SWAP="1"
$env:QUOTE_AFTER_TINY_LIQUIDITY_SIMULATION="1"
forge script script/PrepareBaseSepoliaTinyMoonUsdcBroadcast.s.sol --rpc-url https://sepolia.base.org --sender $env:REHEARSAL_ACTOR --rpc-timeout 120 --slow
```

2026-05-15 Base Sepolia fork 组合 dry-run 结果：

```text
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

2026-05-15 用户明确批准后，真实 Base Sepolia 小额广播已完成：

```text
LIQUIDITY_TX=0x99c69749bbd9199ac7476f8d0175d2f3a651b81d97a97a607e13ca2b5168517b
LIQUIDITY_RECEIPT_STATUS=1
LIQUIDITY_BLOCK=41534780
LIQUIDITY_GAS_USED=442218
POSITION_TOKEN_ID=22355
POSITION_OWNER=0x6E22b2e6fFAA30Fe75B71d53d1eC469b4e97A986
SWAP_TX=0x61744130044a25395399db900c542872fe8c887057025a8d6b86bc0c71aeebaa
SWAP_RECEIPT_STATUS=1
SWAP_BLOCK=41534781
SWAP_GAS_USED=232863
ACTOR_USDC_BALANCE_AFTER=18400000
ACTOR_MOON_BALANCE_AFTER=284123473562317985
```

说明：这次真实广播只发生在 Base Sepolia 测试网。后续不要重复广播同一演练交易，除非先重新规划新的测试目的和金额。

对应回归测试：

```powershell
forge test --match-path test/hooks/base/BaseSepoliaTinyMoonUsdcBroadcastPreparation.t.sol -vvv
```

2026-05-15 该测试结果：`3 passed, 0 failed`。

说明：真实广播前仍必须由用户明确批准。需要输入私钥时，提示必须写明：请输入 `REHEARSAL_ACTOR=0x6E22b2e6fFAA30Fe75B71d53d1eC469b4e97A986` 对应的钱包私钥。不要把私钥发到聊天或文档。

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
- `TestnetUsdcAdapter.authorizedHook` 最初是临时 `HOOK_OWNER`；Hook 部署后已单独广播切换到实际 Hook。

### `PrepareBaseMainnetDirectUsdcOnlyAdapter.s.sol`

用途：

- 为主网第一阶段 `Direct-USDC-only` 方案做 adapter 参数 dry-run。
- 只检查 Base mainnet 官方 USDC、USDC decimals、主网 v4 依赖地址是否有代码，以及 `DirectUsdcOnlyAdapter` 构造参数是否一致。
- 脚本内部不调用 `startBroadcast`，并且如果设置 `EXECUTE_BASE_MAINNET_DIRECT_ADAPTER_BROADCAST=1` 会直接拒绝。
- 这不是主网部署脚本，不要加 `--broadcast`。

Base mainnet dry-run 命令示例，不广播：

```powershell
$env:DEPLOYER_ADDRESS="0x2F6E887c6058deE520f9468a1022E3480A6334D3"
$env:MAINNET_ADMIN_WALLET="0x6E22b2e6fFAA30Fe75B71d53d1eC469b4e97A986"
$env:TEMP_AUTHORIZED_HOOK="0x6E22b2e6fFAA30Fe75B71d53d1eC469b4e97A986"
$env:CONFIRM_BASE_MAINNET_DIRECT_ADAPTER_DRY_RUN="1"
$env:EXECUTE_BASE_MAINNET_DIRECT_ADAPTER_BROADCAST="0"
forge script script/PrepareBaseMainnetDirectUsdcOnlyAdapter.s.sol --rpc-url https://mainnet.base.org --rpc-timeout 120 --slow
```

对应回归测试：

```powershell
forge test --match-contract BaseMainnetDirectUsdcOnlyAdapterPreparationTest
```

2026-05-15 Base mainnet RPC dry-run 记录，不广播：

```text
chainId=8453
baseMainnetConfirmed=true
broadcastRequested=false
deployer=0x2F6E887c6058deE520f9468a1022E3480A6334D3
MAINNET_ADMIN_WALLET=0x6E22b2e6fFAA30Fe75B71d53d1eC469b4e97A986
TEMP_AUTHORIZED_HOOK=0x6E22b2e6fFAA30Fe75B71d53d1eC469b4e97A986
USDC=0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913
USDC_DECIMALS=6
DIRECT_USDC_ONLY_ADAPTER_SIMULATION=0x842e4cE04400479a062fEFa4548256BE3180667D
```

说明：
- 本次 mainnet dry-run 使用现有测试地址作为占位参数，不是最终主网普通钱包地址。
- `DIRECT_USDC_ONLY_ADAPTER_SIMULATION` 是 fork dry-run 临时模拟地址，不是链上部署地址。
- 后续真实主网部署前，必须先最终复核四个角色普通钱包公开地址、正式部署地址、CREATE2 预测参数和预测 Hook 地址。

### `PrepareBaseMainnetCoreDeployDryRun.s.sol`

用途：

- 为 Base 主网核心合约部署做只模拟 dry-run 草案。
- 读取 `MAINNET_DEPLOYER` 当前 nonce，并按正式部署顺序预测 5 个 CREATE 地址。
- 预测顺序：`SUN_TOKEN`、`SUN_CURVE`、`MOON_TOKEN`、`MOON_CURVE`、`CREATE2_HOOK_DEPLOYER`。
- 在本地/fork 临时环境里模拟核心合约部署、minter 锁定、`SunCurve.setMoonCurve(MoonCurve)`、owner 转给 `MAINNET_ADMIN_WALLET`。
- 确认 `SunCurve.moonAMM == address(0)`，等待 Hook 正式确定后再绑定。
- 脚本内部不调用 `startBroadcast`，并且如果设置 `EXECUTE_BASE_MAINNET_BROADCAST=1` 会直接拒绝。
- 这不是主网部署脚本，不要加 `--broadcast`。

Base mainnet fork dry-run 命令草案，不广播：

```powershell
$env:MAINNET_DEPLOYER="0xC0b399aE61d3Fb14EFE865A0304f0FC4b52b7B7b"
$env:MAINNET_ADMIN_WALLET="0xD37BDC458EdCe7006dDd3ce03eEBF29d629B2D6B"
$env:PROTOCOL_BUDGET_WALLET="0x215F1F09b765C0e893E8D7A40d51Bceb40B733F4"
$env:CREATE2_DEPLOYER_OWNER="0xf28020011C5e35329A78Cc4bCb34b2cA20958380"
$env:CONFIRM_BASE_MAINNET_CORE_DRY_RUN="1"
$env:EXECUTE_BASE_MAINNET_BROADCAST="0"
forge script script/PrepareBaseMainnetCoreDeployDryRun.s.sol --rpc-url $env:BASE_MAINNET_RPC --rpc-timeout 120 --slow
```

本地模拟命令草案，不需要 RPC：

```powershell
$env:MAINNET_DEPLOYER="0xC0b399aE61d3Fb14EFE865A0304f0FC4b52b7B7b"
$env:MAINNET_ADMIN_WALLET="0xD37BDC458EdCe7006dDd3ce03eEBF29d629B2D6B"
$env:PROTOCOL_BUDGET_WALLET="0x215F1F09b765C0e893E8D7A40d51Bceb40B733F4"
$env:CREATE2_DEPLOYER_OWNER="0xf28020011C5e35329A78Cc4bCb34b2cA20958380"
$env:EXECUTE_BASE_MAINNET_BROADCAST="0"
forge script script/PrepareBaseMainnetCoreDeployDryRun.s.sol
```

说明：

- `prediction` 地址只有在 `MAINNET_DEPLOYER` 没有先发其他交易、且正式部署顺序不变时才成立。
- 脚本输出的 `simulation` 地址只是本地临时地址，不是主网正式地址。
- 不要传 `PRIVATE_KEY`，不要使用真实资金，不要在命令里写带密钥的完整 RPC URL。

对应回归测试：

```powershell
forge test --match-contract BaseMainnetCoreDeployDryRunPreparationTest
```

2026-05-17 本地测试记录：

```text
11 passed, 0 failed
```

2026-05-17 Base mainnet fork dry-run 记录，不广播：

```text
chainId=8453
simulationOnly=true
broadcastRequested=false
MAINNET_DEPLOYER_NONCE=0
USDC_TOKEN=0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913
USDC_DECIMALS=6
PREDICTED_SUN_TOKEN=0xbA010450885AadcDA402358d04be881Bd53E482b
PREDICTED_SUN_CURVE=0x4104250C9C2E19CCe8625D0c2972c5EaE035D83a
PREDICTED_MOON_TOKEN=0xf3Bff3b498369022313aD55138ea41B236B61EBf
PREDICTED_MOON_CURVE=0x5de55E74728f42e0265cd712aA54d9b7D532D38d
PREDICTED_CREATE2_HOOK_DEPLOYER=0xFdc4c4FC0200ee27345B179E52348bA4a4aC97c0
```

这些地址仍是预测地址，不是已部署地址。`MAINNET_DEPLOYER` 如果先发出任何交易，或正式部署顺序变化，必须重新运行 dry-run。

### `ComputeBaseMainnetSunMoonUsdcHookSalt.s.sol`

用途：

- 用 Base mainnet 正式公开参数草案计算 `BaseSunMoonUsdcFeeV4Hook` 的 `initCodeHash`、`HOOK_SALT` 和 `PREDICTED_HOOK`。
- 在 Base mainnet fork 上复核 chainId、官方 `PoolManager`、官方 USDC 地址和 USDC decimals。
- 确认 `uint160(PREDICTED_HOOK) & 0x3fff == 204`，也就是 v4 Hook 地址权限 bit 正确。
- 脚本内部不调用 `startBroadcast`，并且如果设置 `EXECUTE_BASE_MAINNET_BROADCAST=1` 会直接拒绝。
- 这不是主网部署脚本，不要加 `--broadcast`。

Base mainnet fork dry-run 命令草案，不广播：

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

对应回归测试：

```powershell
forge test --match-contract BaseMainnetSunMoonUsdcHookSaltPreparationTest
```

2026-05-17 本地测试记录：

```text
10 passed, 0 failed
```

2026-05-17 Base mainnet fork dry-run 记录，不广播：

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

这些值仍是预测值，不是已部署地址。只要 Hook 代码、构造参数、`CREATE2_HOOK_DEPLOYER` 或上游核心预测地址变化，必须重新运行 dry-run。

### `PrepareBaseMainnetSunMoonUsdcForkDryRun.s.sol`

用途：

- 为新版 `SUN/USDC` 和 `MOON/USDC` v4 Hook 池做 Base mainnet fork 只模拟 dry-run。
- 只模拟 CREATE2 Hook 部署、Hook 权限 bit、两个 `PoolKey -> poolId`、两个池白名单、两个池 `PoolManager.initialize()`、slot0 复核和 `renounceOwnership()` 后不可管理检查。
- 脚本内部不调用 `startBroadcast`，并且如果设置 `EXECUTE_BASE_MAINNET_BROADCAST=1` 会直接拒绝。
- 已填写：`MAINNET_DEPLOYER`、`MAINNET_ADMIN_WALLET`、`PROTOCOL_BUDGET_WALLET`、`CREATE2_DEPLOYER_OWNER` 公开地址，仍需最终复核。
- 已确认：`SUN/USDC` 初始价 `1 SUN = 1 USDC`，`MOON/USDC` 初始价 `1 MOON = 0.24 USDC`。
- 已用预测地址算出：poolId、initial tick 和 sqrtPriceX96；2026-05-17 已在 Base mainnet fork 里跑通只模拟总 dry-run。注意：`CREATE2_HOOK_DEPLOYER` 当前仍是预测地址，脚本只在本地 fork 内临时模拟它的代码，不代表主网已部署。
- 正式合约地址与 CREATE2 参数依赖顺序见 `docs/Base-主网正式合约地址与CREATE2参数草案-2026-05-17.md`。

Base mainnet fork dry-run 命令草案，不广播：

```powershell
$env:CONFIRM_BASE_MAINNET_SUN_MOON_FORK_DRY_RUN="1"
$env:EXECUTE_BASE_MAINNET_BROADCAST="0"
forge script script/PrepareBaseMainnetSunMoonUsdcForkDryRun.s.sol --rpc-url $env:BASE_MAINNET_RPC --rpc-timeout 120 --slow
```

运行前还必须设置这些公开地址环境变量；四个角色钱包公开地址已有 owner 提供的公开地址。池参数、官方 Uniswap 地址和 USDC 地址默认使用脚本内的 Base mainnet 草案值，也可以用公开环境变量覆盖复核。

```text
MAINNET_DEPLOYER
MAINNET_ADMIN_WALLET
PROTOCOL_BUDGET_WALLET
CREATE2_DEPLOYER_OWNER
CREATE2_HOOK_DEPLOYER
SUN_TOKEN
MOON_TOKEN
SUN_CURVE
```

可选复核值：

```text
SUN_USDC_POOL_ID
MOON_USDC_POOL_ID
SUN_USDC_INITIAL_TOKEN_AMOUNT
SUN_USDC_INITIAL_USDC_AMOUNT
MOON_USDC_INITIAL_TOKEN_AMOUNT
MOON_USDC_INITIAL_USDC_AMOUNT
```

禁止：

```text
不要加 --broadcast
不要传 PRIVATE_KEY
不要使用真实资金
不要在命令里写带密钥的完整 RPC URL
```

对应回归测试：

```powershell
forge test --match-contract BaseMainnetSunMoonUsdcForkDryRunPreparationTest
```

2026-05-17 本地测试记录：

```text
15 passed, 0 failed
```

2026-05-17 Base mainnet fork 只模拟记录：

```text
Script ran successfully
chainId=8453
simulationOnly=true
broadcastRequested=false
transactionsPlanned=6
create2DeployerSimulated=true
predictedHook=0x04f968dE5cd57B1EB8215a9a488dC32508Fb80cc
SUN_USDC_POOL_ID=0xf0006d5dde476ffd2b43648468d5c6a6a8cf1f40bcac5c0c7d070491587e075a
MOON_USDC_POOL_ID=0xcf29a02432e947fe9240fe4378cb871b24691f7cd85e7e8c72464ff89c1c6735
SUN/USDC initialized on fork only
MOON/USDC initialized on fork only
ownerAfterRenounce=0x0000000000000000000000000000000000000000
renounceBlocksSunAllowlist=true
renounceBlocksMoonAllowlist=true
renounceBlocksProtocolBudget=true
no --broadcast
no PRIVATE_KEY
no real funds
```

