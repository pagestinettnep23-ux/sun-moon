# Base Sepolia 最小部署规划

更新日期：2026-05-14

本文档给非技术成员和后续开发者说明：如果 SUN/MOON 要进入 Base Sepolia 受控测试网演练，最少需要部署哪些合约、按什么顺序部署、每一步需要谁来决定，以及哪些地方必须停止。本文档只是规划，不广播交易，不部署主网，不接真实资金。

## 1. 你需要先做的决定

在写或执行任何测试网广播脚本前，需要你确认这些选择：

| 决策 | 推荐选择 | 你需要确认 |
| --- | --- | --- |
| 是否进入 Base Sepolia | 是，仅测试网 | 待确认 |
| 是否接 Base 主网 | 否 | 固定为否 |
| 是否接真实资金 | 否 | 固定为否 |
| 稳定币地址 | Base Sepolia USDC：`0x036CbD53842c5426634e7929541eC2318f3dCF7e` | 广播前二次复核 |
| Uniswap v4 公开地址 | PoolManager / PositionManager / StateView / Quoter / Universal Router 已记录 | 广播前二次复核 |
| `HOOK_OWNER` | 单独测试管理员钱包 | 已提供公开地址，broadcast 前再复核 |
| `PROTOCOL_BUDGET_ADDRESS` | 单独测试预算钱包 | 已提供公开地址，broadcast 前再复核 |
| 部署钱包 | 单独测试部署钱包 | 已提供公开地址，不给私钥 |
| `CREATE2_DEPLOYER` | 固定一个测试网可用 deployer | 已固定：`0xE5Df76A1DF2e959C70c8b7591754a3a2a542Fb6D` |

只需要公开地址，不要把私钥、助记词或完整 RPC key 发给我，也不要写进文档。

地址用途和新手准备步骤见 `docs/Base-Sepolia-地址准备说明.md`。

`CREATE2_DEPLOYER` 的选择说明见 `docs/Base-Sepolia-CREATE2-Deployer选择说明.md`。当前已新增本地 `Create2HookDeployer` 草图、预演脚本和 Base Sepolia 部署脚本，并已完成第一次小额广播；不直接采用公共 deployer，也不把 `DEPLOYER_ADDRESS` 自动当成 `CREATE2_DEPLOYER`。

`script/PrepareBaseSepoliaCreate2Deployer.s.sol` 已完成第一次 Base Sepolia 小额广播：它只部署 `Create2HookDeployer`，不部署 Hook、不部署曲线核心、不绑定 adapter。

Base Sepolia 小额广播前的分步草案见 `docs/Base-Sepolia-小额广播草案清单.md`。该草案只说明未来怎么分步批准和记录，不代表已经允许广播。

公开地址当前记录在 `docs/Base-Sepolia-参数模板.md`。来源为 Uniswap v4 deployments 和 Circle USDC contract addresses；任何广播前都要重新打开来源确认。

## 2. 最小部署对象

Base Sepolia 受控演练的最小对象分为三组。

### 2.1 曲线核心

| 合约 | 作用 | 是否必须 |
| --- | --- | --- |
| `SunToken` | SUN 测试 token | 必须 |
| `SunCurve` | SUN Mint/Burn 曲线，接收 USDC 注入 | 必须 |
| `MoonToken` | MOON 测试 token | 必须 |
| `MoonCurve` | MOON Mint/Burn 曲线 | 建议部署，保持完整路径 |

### 2.2 Base v4 / adapter

| 合约 | 作用 | 是否必须 |
| --- | --- | --- |
| `TestnetUsdcAdapter` | 测试版 USDC adapter，受控 allowlist | 必须 |
| `Create2HookDeployer` | 项目自控 CREATE2 Hook deployer，先本地测试 | 测试网 Hook 广播前必须固定 |
| `BaseMoonAmmFeeV4Hook` | MOON v4 5% 费用 Hook | 必须，但必须 CREATE2 地址预检 |

### 2.3 暂不进入的对象

| 对象 | 当前处理 |
| --- | --- |
| 真实生产 adapter | 暂不做 |
| 真实主网池 | 暂不做 |
| 任意 router calldata | 暂不做 |
| PancakeSwap / BNB 路线 | 暂不做 |

## 3. 构造参数清单

### 3.1 `SunToken`

```solidity
constructor(string name_, string symbol_, address initialOwner)
```

建议：

```text
name_ = "SUN"
symbol_ = "SUN"
initialOwner = HOOK_OWNER 或部署后准备管理曲线的钱包
```

### 3.2 `SunCurve`

```solidity
constructor(
    SunToken sunToken_,
    IERC20Metadata usdt_,
    address protocolBudget_,
    uint256 maxMintUsdt_,
    address initialOwner
)
```

建议：

```text
sunToken_ = SunToken 部署地址
usdt_ = Base Sepolia USDC
protocolBudget_ = PROTOCOL_BUDGET_ADDRESS
maxMintUsdt_ = 10_000 * 1e6
initialOwner = HOOK_OWNER
```

说明：代码里名字仍叫 `USDT`，Base Sepolia 路线里实际填 USDC 地址。

### 3.3 `MoonToken`

```solidity
constructor(string name_, string symbol_, address initialOwner)
```

建议：

```text
name_ = "MOON"
symbol_ = "MOON"
initialOwner = HOOK_OWNER
```

### 3.4 `MoonCurve`

```solidity
constructor(
    MoonToken moonToken_,
    SunToken sunToken_,
    SunCurve sunCurve_,
    address protocolBudget_,
    uint256 k_,
    uint256 s_,
    uint256 launchTime_,
    uint256 maxMintUsdtEquiv_,
    address initialOwner
)
```

建议沿用本地脚本参数：

```text
moonToken_ = MoonToken 部署地址
sunToken_ = SunToken 部署地址
sunCurve_ = SunCurve 部署地址
protocolBudget_ = PROTOCOL_BUDGET_ADDRESS
k_ = 5_000_000 * 1e18
s_ = 1_200_000 * 1e18
launchTime_ = 当前区块时间 + 测试延迟
maxMintUsdtEquiv_ = 10_000 * 1e6
initialOwner = HOOK_OWNER
```

### 3.5 `TestnetUsdcAdapter`

```solidity
constructor(IERC20 usdc_, address authorizedHook_, address initialOwner)
```

建议：

```text
usdc_ = Base Sepolia USDC
authorizedHook_ = 临时非零地址，例如 HOOK_OWNER
initialOwner = HOOK_OWNER
```

重要说明：

- `BaseMoonAmmFeeV4Hook` 的 CREATE2 预测需要先知道 `SWAP_ADAPTER` 地址。
- 因此测试网最小路径建议先部署 `TestnetUsdcAdapter`，临时把 `authorizedHook_` 设为 `HOOK_OWNER`。
- 等 Hook 预测地址和实际部署地址确定后，再由 owner 调用 `setAuthorizedHook(PREDICTED_HOOK)` 或 `setAuthorizedHook(实际 Hook 地址)`。
- 如果预测地址和实际部署地址不一致，必须停止。

### 3.6 `BaseMoonAmmFeeV4Hook`

```solidity
constructor(
    IPoolManager poolManager_,
    address moonToken_,
    IERC20 usdt_,
    SunCurve sunCurve_,
    address protocolBudget_,
    IMoonAmmSwapAdapter swapAdapter_,
    address owner_
)
```

建议：

```text
poolManager_ = Base Sepolia PoolManager
moonToken_ = MoonToken 部署地址
usdt_ = Base Sepolia USDC
sunCurve_ = SunCurve 部署地址
protocolBudget_ = PROTOCOL_BUDGET_ADDRESS
swapAdapter_ = TestnetUsdcAdapter 部署地址
owner_ = HOOK_OWNER
```

Hook 必须通过 CREATE2 预测地址，低 14 位权限 bit 必须等于 `204`。

## 4. 推荐部署顺序

### Step 0：不广播准备

准备公开地址：

```text
HOOK_OWNER=0x6E22b2e6fFAA30Fe75B71d53d1eC469b4e97A986
PROTOCOL_BUDGET_ADDRESS=0x277ba3Cf597CdAaF958C301db3cF6a631F793039
DEPLOYER_ADDRESS=0x2F6E887c6058deE520f9468a1022E3480A6334D3
CREATE2_DEPLOYER=0xE5Df76A1DF2e959C70c8b7591754a3a2a542Fb6D
```

只填公开地址，不填私钥。

### Step 1：准备或部署 `Create2HookDeployer`（已完成）

本地模拟命令：

```powershell
forge script script/PrepareBaseSepoliaCreate2Deployer.s.sol
```

记录输出：

```text
CREATE2_DEPLOYER=0xE5Df76A1DF2e959C70c8b7591754a3a2a542Fb6D
CREATE2_DEPLOYER_OWNER=0x6E22b2e6fFAA30Fe75B71d53d1eC469b4e97A986
CREATE2_DEPLOYER_TX=0x87c9033101907c8e24aa13714154a212431a677837027191b023c00e70909596
```

这一阶段已完成第一次小额测试网广播，并已链上复核代码非空、owner 正确。后续不得重新把 `DEPLOYER_ADDRESS` 当成 `CREATE2_DEPLOYER`。

### Step 2：部署曲线核心

当前状态：第二次小额广播已完成并链上复核。

顺序：

1. 部署 `SunToken`
2. 部署 `SunCurve`
3. 部署 `MoonToken`
4. 部署 `MoonCurve`

部署后绑定：

```text
SunToken.setMinter(SunCurve)
SunCurve.setMoonCurve(MoonCurve)
MoonToken.setMinter(MoonCurve)
```

暂时不要急着设置 `SunCurve.setMoonAMM()`，等 Hook 地址确定后再设置。

### Step 3：部署测试版 adapter

部署：

```text
TestnetUsdcAdapter(
  usdc = Base Sepolia USDC,
  authorizedHook = HOOK_OWNER 临时地址,
  initialOwner = HOOK_OWNER
)
```

记录输出：

```text
SWAP_ADAPTER=0x50f232d1B40D9EF523cc53f958f8C80766aF35a7
```

真实部署地址：

```text
SUN_TOKEN=0xDa5a62F1c2c54AB79c974eE41b9a5B83Dd307e41
SUN_CURVE=0x00F49621977e5219093A988879F07936F2155c07
MOON_TOKEN=0x6E7FF34C7a7a518981BF6324e5FCC6599FcBC59D
MOON_CURVE=0x7f4296686917Be97E826DC790c367d93585A32c3
SWAP_ADAPTER=0x50f232d1B40D9EF523cc53f958f8C80766aF35a7
```

这些地址已经由 Base Sepolia 广播固定，`DEPLOYER_ADDRESS` nonce 已变为 `14`。

### Step 4：计算 Hook salt 和预测地址

拿到以下地址后才能跑：

```text
MOON_TOKEN=0x6E7FF34C7a7a518981BF6324e5FCC6599FcBC59D
SUN_CURVE=0x00F49621977e5219093A988879F07936F2155c07
PROTOCOL_BUDGET_ADDRESS=0x277ba3Cf597CdAaF958C301db3cF6a631F793039
SWAP_ADAPTER=0x50f232d1B40D9EF523cc53f958f8C80766aF35a7
HOOK_OWNER=0x6E22b2e6fFAA30Fe75B71d53d1eC469b4e97A986
CREATE2_DEPLOYER=0xE5Df76A1DF2e959C70c8b7591754a3a2a542Fb6D
```

运行：

```powershell
forge script script/FindBaseMoonAmmFeeV4HookSalt.s.sol
```

记录：

```text
HOOK_SALT=0x00000000000000000000000000000000000000000000000000000000000022b9
PREDICTED_HOOK=0xF612828Ba9dE01CF16Fae2D8EE187B0cA59100Cc
```

`PREDICTED_HOOK` 权限 bit 已等于 `204`。

### Step 5：参数预检

把预测地址填入：

```text
PREDICTED_HOOK=0xF612828Ba9dE01CF16Fae2D8EE187B0cA59100Cc
```

运行：

```powershell
forge script script/CheckBaseSepoliaDeploymentParams.s.sol
```

如果失败，停止。

### Step 6：部署 Hook

当前已新增 `script/PrepareBaseSepoliaHookDeploy.s.sol`，并完成 Base Sepolia dry-run，不广播。dry-run 结果：

```text
PREDICTED_HOOK=0xF612828Ba9dE01CF16Fae2D8EE187B0cA59100Cc
DEPLOYED_HOOK_DRY_RUN=0xF612828Ba9dE01CF16Fae2D8EE187B0cA59100Cc
expectedHookMask=204
actualLow14Bits=204
estimatedRequiredEth=0.000030782763
```

真正部署 Hook 时，签名账户必须是 `HOOK_OWNER`，因为 `Create2HookDeployer.owner()` 已固定为：

```text
0x6E22b2e6fFAA30Fe75B71d53d1eC469b4e97A986
```

Hook 已在用户明确批准后广播部署，交易哈希：

```text
0x376baf6403018674a6b61bc4b84324e13fc7fafcb8c1970c8f15b06215e59e17
```

部署后复核通过：

```text
HOOK_DEPLOYED=0xF612828Ba9dE01CF16Fae2D8EE187B0cA59100Cc
HOOK_DEPLOYED == PREDICTED_HOOK
expectedHookMask=204
actualLow14Bits=204
receiptStatus=0x1
```

部署后必须检查：

```text
实际 Hook 地址 == PREDICTED_HOOK
实际 Hook 地址低 14 位权限 bit == 204
```

不一致就停止。

### Step 7：绑定 Hook 权限（dry-run 已完成，下一步需批准广播）

Hook 部署成功后，再配置：

```text
TestnetUsdcAdapter.setAuthorizedHook(Hook)
SunCurve.setMoonAMM(Hook)
```

后续等池子确定后，再配置：

```text
BaseMoonAmmFeeV4Hook.setAllowedMoonPool(poolId, true)
```

`poolId` 必须来自真实 `PoolKey.toId()`，不能手填猜测。

当前状态：

```text
TestnetUsdcAdapter.authorizedHook = 0x6E22b2e6fFAA30Fe75B71d53d1eC469b4e97A986
SunCurve.moonAMM = 0x0000000000000000000000000000000000000000
```

因此下一步不是重新部署 Hook。用户明确批准后，两笔绑定交易已经广播并复核通过。

当前已新增 `script/PrepareBaseSepoliaHookBinding.s.sol`，并完成 Base Sepolia dry-run，不广播。dry-run 结果：

```text
adapterAuthorizedHookBefore=0x6E22b2e6fFAA30Fe75B71d53d1eC469b4e97A986
sunCurveMoonAMMBefore=0x0000000000000000000000000000000000000000
adapterAuthorizedHookAfter=0xF612828Ba9dE01CF16Fae2D8EE187B0cA59100Cc
sunCurveMoonAMMAfter=0xF612828Ba9dE01CF16Fae2D8EE187B0cA59100Cc
transactionsPlanned=2
estimatedRequiredEth=0.000001204511
```

注意：这里的 `After` 原本是模拟结果；后续绑定广播已完成，真实链上状态现在已经绑定到 Hook。

## 5. 你需要批准的节点

| 节点 | 我会做什么 | 你是否需要确认 |
| --- | --- | --- |
| 写规划文档 | 只改文档 | 已确认 |
| 写最小部署脚本 | 新增脚本，但默认不广播 | 已确认，已完成 |
| 本地模拟部署脚本 | 跑 `forge script`，不带 `--broadcast` | 已确认，已完成 |
| 填公开地址 | 只记录公开地址 | 需要确认 |
| CREATE2 salt 搜索 | 不广播，只计算 | 需要确认 |
| Base Sepolia 广播 | 发测试网交易，花测试 ETH | 必须明确确认 |
| Base 主网 | 当前禁止 | 不执行 |

## 6. 停止条件

出现以下任一情况，必须停止：

- 缺少 `HOOK_OWNER` 或 `PROTOCOL_BUDGET_ADDRESS`。
- 缺少 `HOOK_SALT` 或 `PREDICTED_HOOK`。
- 预测 Hook 权限 bit 不等于 `204`。
- 实际部署 Hook 地址不等于预测地址。
- `SWAP_ADAPTER` 等于预算钱包。
- adapter 还没有把 `authorizedHook` 切到实际 Hook。
- `SunCurve.moonAMM` 还没有设为实际 Hook。
- 需要真实资金才能继续。
- 需要把私钥或完整 RPC key 写进文档。
- 准备连接 Base 主网。

## 7. 已新增脚本草图

已新增 `script/PrepareBaseSepoliaCreate2Deployer.s.sol`。该脚本已完成第一次 Base Sepolia 小额广播，只部署 `Create2HookDeployer`，不部署 Hook、不部署曲线核心、不绑定 adapter，并在 Base Sepolia 链 ID 上要求额外确认变量。

已新增 `script/PrepareBaseSepoliaTestDeploy.s.sol`。该脚本默认只做本地模拟，部署曲线核心和测试版 adapter，不部署 Hook，不设置 `SunCurve.moonAMM`，并输出下一步 CREATE2 预检需要的地址。当前已补充 Base Sepolia 确认变量、禁止 Mock USDC、官方 USDC 校验、部署钱包校验和最终 owner 转移保护。

已新增 `script/PrepareBaseSepoliaHookDeploy.s.sol`。该脚本用于 Hook 小额广播前的 dry-run 和保护检查，不默认广播；它会检查 CREATE2 owner、salt、预测 Hook 地址、低 14 位权限 bit、链上依赖代码和部署后构造参数。

已新增 `script/PrepareBaseSepoliaHookBinding.s.sol`。该脚本用于 Hook 权限绑定前的 dry-run 和保护检查，不默认广播；它会检查 Hook、adapter、SunCurve owner 和构造参数，并只计划两笔绑定交易。

已验证命令：

```powershell
forge script script/PrepareBaseSepoliaCreate2Deployer.s.sol
forge test --match-contract BaseSepoliaCreate2DeployerPreparationTest
forge script script/PrepareBaseSepoliaTestDeploy.s.sol
forge test --match-contract BaseSepoliaHookDeployPreparationTest
forge test --match-contract BaseSepoliaHookBindingPreparationTest
```

验证结果：脚本编译、本地模拟、专项测试、Base Sepolia dry-run 和全量测试均已通过。2026-05-15 在用户明确批准后，第二次 Base Sepolia 小额广播已完成，曲线核心和 `TestnetUsdcAdapter` 已部署并链上复核；Hook 小额广播也已完成并复核。adapter / SunCurve 绑定 dry-run、广播和链上复核均已通过。

## 8. 当前建议

当前不要重新广播 Hook，也不要连接 Base 主网。下一步建议是：

1. 已补齐测试用途公开地址：`HOOK_OWNER`、`PROTOCOL_BUDGET_ADDRESS`、`DEPLOYER_ADDRESS`。
2. 已新增 `docs/Base-Sepolia-CREATE2-Deployer选择说明.md`，并补充本地 `Create2HookDeployer` 草图、测试和完整预演脚本。
3. 已新增 `docs/Base-Sepolia-小额广播草案清单.md`。
4. 已新增并使用 `Create2HookDeployer` 的 Base Sepolia 部署脚本。
5. 已完成 Base Sepolia RPC dry-run，模拟发送者为 `DEPLOYER_ADDRESS`。
6. 已完成第一次小额广播，真实 `CREATE2_DEPLOYER` 已固定。
7. 第二次小额广播脚本保护、Base Sepolia dry-run 和人工复核已完成。
8. 第二次小额广播已完成，真实测试网地址已固定：`MOON_TOKEN=0x6E7FF34C7a7a518981BF6324e5FCC6599FcBC59D`、`SUN_CURVE=0x00F49621977e5219093A988879F07936F2155c07`、`SWAP_ADAPTER=0x50f232d1B40D9EF523cc53f958f8C80766aF35a7`。
9. CREATE2 salt 搜索和参数预检已通过。
10. Hook 小额广播准备脚本、测试和 Base Sepolia dry-run 已通过。
11. Hook 小额广播已完成，实际地址等于预测地址。
12. adapter / SunCurve 绑定脚本、测试和 Base Sepolia dry-run 已通过。
13. adapter / SunCurve 绑定广播和链上复核已通过。
14. 受控 `MOON/USDC` 测试池 `PoolKey -> poolId` dry-run 已通过。
15. 用户明确批准后，`setAllowedMoonPool(poolId, true)` 已广播并链上复核通过。

受控 `MOON/USDC` 测试池参数：

```text
currency0=0x036CbD53842c5426634e7929541eC2318f3dCF7e
currency1=0x6E7FF34C7a7a518981BF6324e5FCC6599FcBC59D
fee=3000
tickSpacing=60
hooks=0xF612828Ba9dE01CF16Fae2D8EE187B0cA59100Cc
poolId=0xfbb4ccec5e3fda3a97b9e2619e9e90588ad5e444bdb3d488e921a3192c42dd55
```

白名单广播记录：

```text
ALLOW_MOON_USDC_POOL_TX=0x9f219d37f1a72dc6229df79217ed953f1e6ff01ed1f4d958854fe432616ed325
receiptStatus=1
blockNumber=41524110
allowedMoonPools(poolId)=true
```

受控测试池初始化 dry-run 已完成：

```text
initialTick=276300
sqrtPriceX96=79133045881256921541446514419412387
humanPriceApprox=1 MOON ~= 1.0024 USDC
sqrtPriceBefore=0
transactionsPlanned=1
estimatedRequiredEth=0.000000839773
```

受控测试池初始化广播已完成：

```text
MOON_USDC_INITIALIZE_TX=0x72c93bb0a5bdb540b2e696eaff50614e4571cfe1dbe3bb64494ec9719cdc8310
receiptStatus=1
blockNumber=41525115
slot0.tick=276300
postBroadcastTransactionsPlanned=0
```

极小额流动性/交换演练准备 dry-run 和资产/Permit2 授权准备 dry-run 均已完成，链上配置健康；测试 USDC 已到账，资产/Permit2 授权和报价预检均已通过。下一步仍然不是 Base 主网，而是准备真实小额流动性 + swap 广播草案和最终 dry-run。

