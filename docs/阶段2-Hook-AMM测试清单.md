# 阶段 2 - Hook/AMM 测试清单

更新日期：2026-05-15

本文档用于阶段 2 合约侧测试规划和执行记录。当前已经完成 Mock Hook / Mock Adapter 层测试，并完成 `BaseMoonAmmFeeV4Hook` v2 的本地真实 `PoolManager` 适配测试；这仍不代表已经接入真实 DEX 或真实资金。

2026-05-15 主网决策更新：SUN 永久不做官方 AMM 流动性。本文里的 SUN AMM 加池守卫测试只作为历史原型记录，不进入主网部署计划。

## 1. 测试范围

阶段 2 测试分四层：

1. Mock Hook 单元测试。
2. SUN AMM 加池守卫测试。历史原型，主网不使用。
3. MOON AMM 税费路由测试。
4. Uniswap v4 / PancakeSwap Infinity 适配测试。

当前暂不测试：

- 主网真实资金。
- 真实 USDT。
- 未确认的 BNB 主网部署。
- 未经验证的生产级外部换币。
- Uniswap v4 / PancakeSwap Infinity 的真实 PoolManager 和真实路由。

## 2. SUN AMM 加池守卫测试

当前状态：历史原型测试已完成；主网不设置 SUN 首次加池钱包，不部署官方 SUN AMM guard。

| 编号 | 测试项 | 预期结果 |
| --- | --- | --- |
| H-SUN-001 | 不包含 SUN 的池子执行 Hook | 不受 SUN 加池限制影响 |
| H-SUN-002 | SUN AMM 未解锁时普通用户加池 | 交易失败 |
| H-SUN-003 | SUN AMM 未解锁时指定钱包首次加池 | 交易成功 |
| H-SUN-004 | 首次加池成功后状态变化 | `sunAmmUnlocked = true` |
| H-SUN-005 | 解锁后普通用户对允许的 SUN 池加池 | 交易成功 |
| H-SUN-006 | 未允许的 SUN 池加池 | 交易失败 |
| H-SUN-007 | 错误的首次加池钱包 | 交易失败 |
| H-SUN-008 | 管理员修改首次加池钱包 | 成功并发出事件 |
| H-SUN-009 | 非管理员修改首次加池钱包 | 交易失败 |
| H-SUN-010 | 暂停状态下 SUN 高风险操作 | 交易失败 |

建议测试文件名：

```text
test/hooks/SunAmmGuardHook.t.sol
```

## 3. MOON AMM 税费测试

| 编号 | 测试项 | 预期结果 |
| --- | --- | --- |
| H-MOON-001 | 不涉及 MOON 的交易 | 不收 MOON AMM 税费 |
| H-MOON-002 | 涉及 MOON 的买入方向交易 | 收取 5% 费用 |
| H-MOON-003 | 涉及 MOON 的卖出方向交易 | 收取 5% 费用 |
| H-MOON-004 | 3% 费用进入 SUN 飞轮路径 | 最终调用 `SunCurve.injectUSDT()` |
| H-MOON-005 | 2% 费用进入协议预算钱包 | 预算钱包收到原手续费资产 |
| H-MOON-006 | `minUSDTOut = 0` | 交易失败 |
| H-MOON-007 | 实际换出 USDT 小于 `minUSDTOut` | 交易失败 |
| H-MOON-008 | Mock 适配器返回 USDT | 注入 SUN 曲线成功 |
| H-MOON-009 | Mock 适配器失败 | 整笔交易回滚 |
| H-MOON-010 | 费用计算舍入 | 不能出现多收、少收或下溢 |

建议测试文件名：

```text
test/hooks/MoonAmmFeeHook.t.sol
```

## 4. 适配器测试

| 编号 | 测试项 | 预期结果 |
| --- | --- | --- |
| H-ADP-001 | 只有授权 Hook 可以调用适配器 | 非授权地址调用失败 |
| H-ADP-002 | 适配器目标 USDT 地址为零 | 部署或配置失败 |
| H-ADP-003 | 换币路径为空或无效 | 交易失败 |
| H-ADP-004 | `amountIn = 0` | 交易失败 |
| H-ADP-005 | `minUSDTOut` 未满足 | 交易失败 |
| H-ADP-006 | 成功换出 USDT | 返回实际 USDT 数量 |
| H-ADP-007 | 适配器被暂停 | 交易失败 |
| H-ADP-008 | 外部调用重入尝试 | 交易失败或被保护 |

建议测试文件名：

```text
test/hooks/AmmSwapAdapter.t.sol
```

## 5. DEX 专项测试

### 5.1 Uniswap v4

第一条真实 DEX 技术路线选择 Base + Uniswap v4。先做 Base Sepolia / Base fork，不部署 Base 主网。

| 编号 | 测试项 | 预期结果 |
| --- | --- | --- |
| H-UNI-001 | Hook 地址权限和声明权限一致 | 测试通过 |
| H-UNI-002 | Hook 地址权限不匹配 | 部署或初始化失败 |
| H-UNI-003 | PoolManager 地址配置错误 | 交易失败 |
| H-UNI-004 | 池子身份不在白名单 | Hook 拒绝 |
| H-UNI-005 | 允许池子执行最小加池流程 | 交易成功 |
| H-UNI-006 | Base Sepolia 官方 v4 地址配置 | PoolManager / PositionManager / Router 地址与官方文档一致 |
| H-UNI-007 | Base fork 只读官方 v4 合约状态 | 本地 fork 可读取 PoolManager 和 StateView |
| H-UNI-008 | SUN 加池守卫映射到 v4 callback | `beforeAddLiquidity` 路径按预期拦截 |
| H-UNI-009 | MOON AMM 费用映射到 v4 callback 或 custom accounting | 5% 费用路径按预期执行 |
| H-UNI-010 | MOON return delta 收费后的 3%/2% 路由闭环 | 3% 转 USDC 注入 SUN 曲线，2% 原手续费资产进预算钱包 |
| H-UNI-011 | Base Sepolia 测试网前参数预检 | 官方地址、项目地址和 Hook 权限 bit 检查通过 |
| H-UNI-012 | 测试版 USDC adapter 与 Mock 路由器 | allowlist、余额差、`minUSDTOut`、暂停和权限检查通过 |
| H-UNI-013 | 本地 Base Sepolia adapter 预演 | 测试 token、Mock 路由器、非 USDC 路由和 USDC 直通路径检查通过 |
| H-UNI-014 | Base Sepolia `Create2HookDeployer` 脚本准备 | 本地模拟通过，Base Sepolia 需确认变量，Base 主网拒绝 |

### 5.2 PancakeSwap Infinity / BNB

| 编号 | 测试项 | 预期结果 |
| --- | --- | --- |
| H-PCS-001 | `PoolKey.parameters` 权限正确编码 | Hook 权限按预期生效 |
| H-PCS-002 | Hook 地址不要求 Uniswap 式权限 bit | 部署方式单独验证 |
| H-PCS-003 | BNB 测试网 PoolManager 地址正确 | 可以初始化测试池 |
| H-PCS-004 | PancakeSwap Hook 回调和 Uniswap 路线差异 | 文档记录并测试覆盖 |
| H-PCS-005 | 小额测试交易 | 行为与 Mock 预期一致 |

## 6. 与现有曲线的集成测试

| 编号 | 测试项 | 预期结果 |
| --- | --- | --- |
| H-INT-001 | MOON AMM 费用注入 SUN 曲线 | SUN 曲线价格上升或不下降 |
| H-INT-002 | SUN 价格上升后 MOON USDT 计价 | MOON Mint 价格同步变化 |
| H-INT-003 | Hook/AMM 测试不影响站内 SUN Mint/Burn | 现有测试继续通过 |
| H-INT-004 | Hook/AMM 测试不影响站内 MOON Mint/Burn | 现有测试继续通过 |
| H-INT-005 | 同一区块 Mint/Burn 保护仍有效 | 交易失败或被合约拒绝 |

建议测试文件名：

```text
test/hooks/HookIntegration.t.sol
```

## 7. 安全专项测试

| 编号 | 测试项 | 预期结果 |
| --- | --- | --- |
| H-SEC-001 | 所有关键地址不能为零地址 | 部署或配置失败 |
| H-SEC-002 | 非管理员不能修改池子配置 | 交易失败 |
| H-SEC-003 | 非管理员不能修改预算钱包 | 交易失败 |
| H-SEC-004 | 非管理员不能修改适配器 | 交易失败 |
| H-SEC-005 | 暂停后高风险路径不可用 | 交易失败 |
| H-SEC-006 | 恢复后正常路径可用 | 交易成功 |
| H-SEC-007 | 未知池子不能绕过限制 | 交易失败 |
| H-SEC-008 | 恶意 Token 回调或重入 | 交易失败或状态不被破坏 |
| H-SEC-009 | 极小数量交易 | 不出现除零、下溢或异常舍入 |
| H-SEC-010 | 极大数量交易 | 不出现溢出或账本错误 |

## 8. 阶段 2 最低通过标准

开始真实 DEX 适配前，至少需要满足：

- [x] 当前阶段 1 + 阶段 2 Mock Foundry 测试继续通过。
- [x] SUN AMM 加池守卫 Mock 测试通过。
- [x] MOON AMM 税费 Mock 测试通过。
- [x] AmmSwapAdapter Mock 测试通过。
- [x] Hook 与曲线集成测试通过。
- [x] `minUSDTOut` 失败路径测试通过。
- [x] 未授权、零地址、暂停、错误池子测试通过。
- [x] Uniswap v4 和 PancakeSwap Infinity 的 Hook 权限模型在文档中分开记录。
- [x] 真实 DEX 适配前，已确认第一条路线选择 Base + Uniswap v4。
- [x] Base Sepolia / Base fork 的 v4 Hook 最小回调测试通过。
- [x] SUN 加池守卫规则映射到 v4 `beforeAddLiquidity` 的适配测试通过。
- [x] MOON 5% AMM 费用规则映射到 v4 return delta 的 `BaseMoonAmmFeeV4Hook` v2 测试通过。
- [x] Base Sepolia 测试网前部署参数预检测试通过。
- [x] 测试版 USDC adapter 和 Mock 路由器测试通过。
- [x] 本地 Base Sepolia adapter 预演脚本和测试通过。
- [x] Base Sepolia `Create2HookDeployer` 脚本准备测试通过。

## 9. 当前执行记录

2026-05-13 已完成第一批 SUN AMM 加池守卫 Mock 测试：

- [x] 新增 `contracts/hooks/SunAmmGuardHook.sol`。
- [x] 新增 `test/hooks/SunAmmGuardHook.t.sol`。
- [x] 覆盖非 SUN 池子不受未解锁限制影响。
- [x] 覆盖 SUN AMM 未解锁时普通用户不能加池。
- [x] 覆盖指定钱包可以完成第一次 SUN 加池并解锁。
- [x] 覆盖解锁后普通用户可以对允许的 SUN 池加池。
- [x] 覆盖未允许的 SUN 池不能绕过限制。
- [x] 覆盖暂停、非管理员修改配置、零地址和无效池子。

2026-05-13 已完成第二批 MOON AMM 税费 Mock 测试：

- [x] 新增 `contracts/hooks/MoonAmmFeeHook.sol`。
- [x] 新增 `test/hooks/MoonAmmFeeHook.t.sol`。
- [x] 覆盖非 MOON 池子不收 MOON AMM 费用。
- [x] 覆盖 MOON 买入方向和卖出方向都收取 5% 费用。
- [x] 覆盖 3% 费用换成 USDT/USDC 后注入 `SunCurve.injectUSDT()`。
- [x] 覆盖 2% 费用保留原手续费资产并进入协议预算钱包。
- [x] 覆盖非 USDT/USDC 手续费资产时，协议预算钱包收到原手续费资产而不是换出的稳定币。
- [x] 覆盖 `minUSDTOut = 0` 和实际 USDT 输出不足时回滚。
- [x] 覆盖 Mock Adapter 成功返回 USDT 并注入 SUN 曲线。
- [x] 覆盖 Mock Adapter 失败时整条 MOON fee route 回滚。
- [x] 覆盖费用舍入不会多收、不会下溢。

2026-05-13 已完成第三批 Hook 集成测试：

- [x] 新增 `test/hooks/HookIntegration.t.sol`。
- [x] 覆盖 MOON AMM Mock swap 触发费用路由后，SUN 曲线价格上升。
- [x] 覆盖 SUN 价格上升后，`MoonCurve.getMintPriceInUSDT()` 同步上升。
- [x] 覆盖 Hook/AMM 测试不影响站内 `MockUSDT -> SUN -> MOON -> SUN -> USDT` 主流程。
- [x] 覆盖 `SunAmmGuardHook` 和 `MoonAmmFeeHook` 状态机相互独立。
- [x] 覆盖非 SUN 池、非 MOON 池仍按预期不受影响。

2026-05-13 已完成第四批 AmmSwapAdapter 独立 Mock 测试：

- [x] 新增 `contracts/hooks/AmmSwapAdapter.sol`。
- [x] 新增 `test/hooks/AmmSwapAdapter.t.sol`。
- [x] 覆盖只有授权 Hook 可以调用适配器。
- [x] 覆盖 `tokenIn`、`amountIn`、`minUSDTOut` 输入校验。
- [x] 覆盖 Mock 输出 USDT 小于 `minUSDTOut` 时回滚。
- [x] 覆盖暂停状态下不能换币。
- [x] 覆盖 Mock 换币失败时不移动手续费资产、不铸出 MockUSDT。
- [x] 覆盖非管理员不能修改配置，零地址配置会失败。
- [x] `MoonAmmFeeHook.t.sol` 已改为使用正式 `AmmSwapAdapter`，不再使用测试文件内临时适配器。
- [x] `HookIntegration.t.sol` 已覆盖非 USDT 手续费资产通过 `AmmSwapAdapter` 转换为 MockUSDT 后注入 SUN 曲线。

当前 Foundry 验证结果：

```text
forge test --match-path test/hooks/AmmSwapAdapter.t.sol
12 passed, 0 failed

forge test --match-path test/hooks/MoonAmmFeeHook.t.sol
16 passed, 0 failed

forge test --match-path test/hooks/HookIntegration.t.sol
5 passed, 0 failed

forge test --match-path test/hooks/base/BaseSunAmmGuardV4Hook.t.sol
8 passed, 0 failed

forge test --match-path test/hooks/base/BaseMoonAmmFeeV4Hook.t.sol
15 passed, 0 failed

forge test --match-path test/hooks/base/BaseMoonAmmFeePolicy.t.sol
10 passed, 0 failed

forge test --match-path test/hooks/base/BaseMoonAmmFeeReturnDeltaSettlement.t.sol
4 passed, 0 failed

forge test --match-path test/hooks/base/BaseMoonAmmFeeReturnDeltaRoute.t.sol
4 passed, 0 failed

forge test --match-path test/hooks/base/BaseV4HookAddressMiner.t.sol
2 passed, 0 failed

forge test --match-path test/hooks/base/BaseMoonAmmFeeV4HookSecurity.t.sol
1 passed, 0 failed

forge test --match-contract BaseDeploymentPreflightTest
6 passed, 0 failed

forge test --match-contract TestnetUsdcAdapterTest
15 passed, 0 failed

forge test --match-path test/hooks/base/BaseMoonAmmFeeV4Hook.t.sol
16 passed, 0 failed

forge test --match-contract BaseSepoliaAdapterRehearsalTest
1 passed, 0 failed

forge script script/RehearseBaseSepoliaAdapter.s.sol
Base Sepolia adapter local rehearsal passed

forge test --match-contract BaseSepoliaCreate2DeployerPreparationTest
3 passed, 0 failed

forge script script/PrepareBaseSepoliaCreate2Deployer.s.sol
Base Sepolia Create2HookDeployer preparation

forge test
历史记录：241 passed, 0 failed
```

2026-05-13 已确认第一条真实 DEX 技术路线：

- [x] 路线选择：Base + Uniswap v4。
- [x] 新增 `docs/Base-Uniswap-v4-技术路线.md`。
- [x] 记录 Base Mainnet Chain ID：`8453`。
- [x] 记录 Base Sepolia Chain ID：`84532`。
- [x] 记录 Uniswap v4 在 Base Mainnet / Base Sepolia 的官方部署地址。
- [x] 明确下一步只做 Base Sepolia / Base fork 技术预研，不部署 Base 主网。
- [x] 检查本地 v4 依赖状态。
- [x] 安装 `v4-core` 和 `v4-periphery`。
- [x] 安装 `solmate` 和 `permit2`，满足 v4 依赖导入。
- [x] 编译最小 Uniswap v4 Hook 适配草图。
- [x] 新增 `contracts/hooks/base/BaseV4HookProbe.sol`。
- [x] 新增 `test/hooks/base/BaseV4HookProbe.t.sol`。
- [x] 最小 v4 Hook 探针测试通过：5 passed，0 failed。
- [x] 新增 `contracts/hooks/base/BaseV4Addresses.sol`，记录 Base 官方 v4 地址。
- [x] 新增 `test/hooks/base/BaseV4Addresses.t.sol`。
- [x] Base Sepolia fork 官方地址只读检查通过。
- [x] Base Mainnet fork 官方地址只读检查通过。
- [x] 新增 `test/hooks/base/BaseV4PoolManagerProbe.t.sol`。
- [x] 本地真实 `PoolManager` 最小 Hook 权限地址测试通过：2 passed，0 failed。
- [x] 新增 `test/hooks/base/BaseV4ForkPoolManagerProbe.t.sol`。
- [x] Base Sepolia fork 官方 `PoolManager.initialize()` 最小 Hook callback 测试通过。
- [x] Base Mainnet fork 官方 `PoolManager.initialize()` 最小 Hook callback 测试通过。
- [x] 新增 `contracts/hooks/base/BaseSunAmmGuardV4Hook.sol`。
- [x] 新增 `test/hooks/base/BaseSunAmmGuardV4Hook.t.sol`。
- [x] 覆盖 SUN v4 `beforeAddLiquidity` 适配层只能由 PoolManager 调用。
- [x] 覆盖 v4 `PoolKey.toId()` 计算出的 PoolId 必须在 `SunAmmGuardHook` 白名单中。
- [x] 覆盖非 SUN 池不影响 `sunAmmUnlocked`。
- [x] 覆盖普通用户不能抢先完成 SUN 首次加池。
- [x] 覆盖指定首次加池钱包可以通过 v4 适配层解锁 SUN AMM。
- [x] 覆盖解锁后允许池仍可加池，未知 SUN 池仍会回滚。
- [x] `forge test --match-path test/hooks/base/BaseSunAmmGuardV4Hook.t.sol` 通过：8 passed，0 failed。
- [x] 新增 `contracts/hooks/base/BaseMoonAmmFeeV4Hook.sol`。
- [x] 新增 `test/hooks/base/BaseMoonAmmFeeV4Hook.t.sol`。
- [x] 覆盖 MOON v4 return delta 适配层只能由 PoolManager 调用。
- [x] 覆盖非 MOON 池不解析 `hookData` 且不收费用。
- [x] 覆盖 MOON/USDT 池通过 v4 `beforeSwap` / `afterSwap` return delta 路由 5% 费用：3% 注入 SUN 曲线，2% USDT 进入协议预算钱包。
- [x] 覆盖非 USDT 手续费资产的 3% 飞轮部分通过 Mock `AmmSwapAdapter` 转换为 MockUSDT 后注入 SUN 曲线。
- [x] 覆盖非 USDT 手续费资产的 2% 预算部分保留原资产进入协议预算钱包。
- [x] 覆盖未允许 MOON 池回滚、空 `hookData` 回滚、`minUSDTOut = 0` 回滚、暂停回滚和非管理员配置失败。
- [x] 覆盖正式合约不再从 `hookData` 读取 `feeToken` 或 `feeBaseAmount`。
- [x] `forge test --match-path test/hooks/base/BaseMoonAmmFeeV4Hook.t.sol` 通过：15 passed，0 failed。
- [x] 新增 `contracts/hooks/base/BaseMoonAmmFeePolicy.sol`。
- [x] 新增 `test/hooks/base/BaseMoonAmmFeePolicy.t.sol`。
- [x] 确认 MOON 任意交易对生产级费用来源固定为非 MOON 侧。
- [x] 覆盖非 MOON 费用资产为 specified currency 的场景：可在 `beforeSwap` 使用 `amountSpecified` 确定费用基数，并用 specified return delta 收取。
- [x] 覆盖非 MOON 费用资产为 unspecified currency 的场景：必须在 `afterSwap` 使用实际非 MOON 资产 delta，并用 unspecified return delta 收取。
- [x] 覆盖卖 MOON 换固定数量非 MOON 资产：非 MOON 输出是 specified currency，可走 `beforeSwap`，不需要等前端传入金额。
- [x] 覆盖 `MOON/WETH` 交易对使用 WETH 作为 fee token。
- [x] `forge test --match-path test/hooks/base/BaseMoonAmmFeePolicy.t.sol` 通过：10 passed，0 failed。
- [x] 新增 `test/hooks/base/BaseMoonAmmFeeReturnDeltaSettlement.t.sol`。
- [x] 覆盖本地真实 `PoolManager` 中 `beforeSwap` specified return delta 能把费用实际结算到 Hook。
- [x] 覆盖本地真实 `PoolManager` 中 `afterSwap` unspecified return delta 能把费用实际结算到 Hook。
- [x] 覆盖非 MOON 侧作为 input 和 output 时都能完成 5% 费用结算。
- [x] `forge test --match-path test/hooks/base/BaseMoonAmmFeeReturnDeltaSettlement.t.sol` 通过：4 passed，0 failed。
- [x] 新增 `test/hooks/base/BaseMoonAmmFeeReturnDeltaRoute.t.sol`。
- [x] 覆盖本地真实 `PoolManager` return delta 收到 5% 费用后，3% 通过 Mock `AmmSwapAdapter` 转成 MockUSDT/USDC 并调用 `SunCurve.injectUSDT()`。
- [x] 覆盖 2% 预算部分保留原手续费资产：MOON/USDC 收 USDC，MOON/非 USDC 交易对收原资产。
- [x] 覆盖 specified / unspecified 两类 v4 return delta 路径都能完成 3% 注入和 2% 预算分配。
- [x] `forge test --match-path test/hooks/base/BaseMoonAmmFeeReturnDeltaRoute.t.sol` 通过：4 passed，0 failed。
- [x] `BaseMoonAmmFeeV4Hook` 已从第一版 `afterSwap` Mock 适配升级为 v2 return delta 正式适配层。
- [x] 新增 `contracts/hooks/base/BaseV4HookAddressMiner.sol`。
- [x] 新增 `script/FindBaseMoonAmmFeeV4HookSalt.s.sol`。
- [x] 新增 `test/hooks/base/BaseV4HookAddressMiner.t.sol`，覆盖 CREATE2 salt 搜索、预测地址权限 bit 精确匹配、额外权限 bit 被拒绝。
- [x] 新增 `test/hooks/base/BaseMoonAmmFeeV4HookSecurity.t.sol`，覆盖恶意 fee token 在 Hook 外部调用路径中尝试嵌套 swap 重入，重入失败且外层状态正确。
- [x] `forge test --match-contract Create2HookDeployerTest` 通过：7 passed，0 failed。
- [x] `forge test --match-contract Create2HookDeployerRehearsalTest` 通过：1 passed，0 failed。
- [x] `forge test --match-contract BaseV4HookAddressMinerTest` 通过：3 passed，0 failed。
- [x] `forge test --match-path test/hooks/base/BaseMoonAmmFeeV4HookSecurity.t.sol` 通过：1 passed，0 failed。
- [x] 新增 `contracts/hooks/base/BaseDeploymentPreflight.sol`。
- [x] 新增 `script/CheckBaseSepoliaDeploymentParams.s.sol`。
- [x] 新增 `test/hooks/base/BaseDeploymentPreflight.t.sol`，覆盖 Base Sepolia 参数预检。
- [x] 新增 `docs/Base-Sepolia-测试网前部署参数清单.md`。
- [x] 新增 `docs/Base-USDC-Adapter方案.md`。
- [x] `forge test --match-contract BaseDeploymentPreflightTest` 通过：6 passed，0 failed。
- [x] `forge script script/CheckBaseSepoliaDeploymentParams.s.sol` 使用本地示例参数通过。
- [x] 新增 `contracts/hooks/TestnetUsdcAdapter.sol`。
- [x] 新增 `test/hooks/TestnetUsdcAdapter.t.sol`。
- [x] 覆盖授权 Hook、token/router allowlist、USDC 直通、实际 USDC 余额差、Mock router 返回值不可信、`minUSDTOut`、暂停、权限和失败回滚。
- [x] 新增 `contracts/hooks/DirectUsdcOnlyAdapter.sol`，作为主网第一阶段 `Direct-USDC-only` 的防呆占位 adapter。
- [x] 新增 `test/hooks/DirectUsdcOnlyAdapter.t.sol`，覆盖授权 Hook、暂停、零地址、零金额、`minUSDTOut`、非 USDC token 拒绝、owner 配置权限和非 owner 拒绝。
- [x] 新增 `script/PrepareBaseMainnetDirectUsdcOnlyAdapter.s.sol`，用于不广播地检查 Base mainnet 官方 USDC 和 adapter 参数。
- [x] 新增 `test/hooks/base/BaseMainnetDirectUsdcOnlyAdapterPreparation.t.sol`，覆盖 mainnet 确认变量、禁止广播 flag、官方 USDC、依赖代码、错误小数位和错误链。
- [x] 新增 `BaseMoonAmmFeeV4Hook` 调用 `TestnetUsdcAdapter` 的集成测试。
- [x] `forge test --match-contract DirectUsdcOnlyAdapterTest` 通过：10 passed，0 failed。
- [x] `forge test --match-contract BaseMainnetDirectUsdcOnlyAdapterPreparationTest` 通过：9 passed，0 failed。
- [x] `forge test --match-contract TestnetUsdcAdapterTest` 通过：15 passed，0 failed。
- [x] `forge test --match-path test/hooks/base/BaseMoonAmmFeeV4Hook.t.sol` 通过：16 passed，0 failed。
- [x] 新增 `contracts/mocks/MockUsdcSwapRouter.sol`，作为可复用受控 Mock USDC 路由器。
- [x] 新增 `script/RehearseBaseSepoliaAdapter.s.sol`，本地预演 adapter 配置、非 USDC 路由和 USDC 直通路径。
- [x] 新增 `test/hooks/base/BaseSepoliaAdapterRehearsal.t.sol`，把本地预演流程固化为回归测试。
- [x] `forge test --match-contract BaseSepoliaAdapterRehearsalTest` 通过：1 passed，0 failed。
- [x] `forge script script/RehearseBaseSepoliaAdapter.s.sol` 本地预演通过。
- [x] `forge script script/RehearseCreate2HookDeployer.s.sol` 本地预演通过。
- [x] 新增 `script/PrepareBaseSepoliaCreate2Deployer.s.sol`，本地模拟准备 Base Sepolia `Create2HookDeployer` 部署。
- [x] 新增 `test/hooks/base/BaseSepoliaCreate2DeployerPreparation.t.sol`，覆盖本地模拟、Base Sepolia 确认变量和 Base 主网拒绝。
- [x] `forge test --match-contract BaseSepoliaCreate2DeployerPreparationTest` 通过：3 passed，0 failed。
- [x] `forge script script/PrepareBaseSepoliaCreate2Deployer.s.sol` 本地模拟通过。
- [x] 第一次 Base Sepolia 小额广播完成，只部署 `Create2HookDeployer`。
- [x] `CREATE2_DEPLOYER=0xE5Df76A1DF2e959C70c8b7591754a3a2a542Fb6D`，owner 链上复核通过。
- [x] Hook 小额广播已完成并链上复核，实际地址等于 CREATE2 预测地址。
- [x] 新增 `script/PrepareBaseSepoliaHookBinding.s.sol` 和 `test/hooks/base/BaseSepoliaHookBindingPreparation.t.sol`。
- [x] `forge test --match-contract BaseSepoliaHookBindingPreparationTest` 通过：1 passed，0 failed。
- [x] Base Sepolia Hook 绑定 dry-run 通过，不加 `--broadcast`。
- [x] Base Sepolia Hook 绑定广播和链上复核通过：adapter 与 `SunCurve.moonAMM` 均指向实际 Hook。
- [x] 新增 `script/PrepareBaseSepoliaControlledMoonPool.s.sol` 和 `test/hooks/base/BaseSepoliaControlledMoonPoolPreparation.t.sol`。
- [x] Base Sepolia 受控 `MOON/USDC` 测试池 `poolId` dry-run 通过：`0xfbb4ccec5e3fda3a97b9e2619e9e90588ad5e444bdb3d488e921a3192c42dd55`。
- [x] Base Sepolia 受控 `MOON/USDC` 测试池白名单广播和链上复核通过：`allowedMoonPools(poolId)=true`。
- [x] 新增 `script/PrepareBaseSepoliaControlledMoonPoolInitialize.s.sol` 和 `test/hooks/base/BaseSepoliaControlledMoonPoolInitializePreparation.t.sol`。
- [x] Base Sepolia 受控 `MOON/USDC` 测试池初始化 dry-run 通过：`initialTick=276300`、`transactionsPlanned=1`。
- [x] Base Sepolia 受控 `MOON/USDC` 测试池初始化广播和链上复核通过：`0x72c93bb0a5bdb540b2e696eaff50614e4571cfe1dbe3bb64494ec9719cdc8310`，`slot0.tick=276300`。
- [x] Base Sepolia 极小额 `MOON/USDC` 流动性/交换演练准备测试通过：`BaseSepoliaTinyMoonUsdcRehearsalPreparationTest`，1 passed。
- [x] Base Sepolia 极小额演练只读 dry-run 通过：链上配置健康，演练账户余额和 Permit2 授权暂为 `0`。
- [x] Base Sepolia 极小额资产/授权准备测试通过：`BaseSepoliaTinyRehearsalAssetsPreparationTest`，1 passed。
- [x] Base Sepolia 极小额资产/授权准备只读 dry-run 通过；用户准备测试 USDC 后，资产与 Permit2 授权广播已完成并链上复核。
- [x] Base Sepolia fork 报价预检通过：`PrecheckBaseSepoliaTinyMoonUsdcQuote.s.sol` 模拟加 `1 USDC + 1 MOON` 流动性后，`0.1 USDC -> MOON` 报价 `quoteMoonOut=94223974497341879`，`readyForTinyBroadcast=true`。
- [x] 新增 `script/PrepareBaseSepoliaTinyMoonUsdcBroadcast.s.sol` 和 `test/hooks/base/BaseSepoliaTinyMoonUsdcBroadcastPreparation.t.sol`，准备真实小额 `MOON/USDC` 加流动性 + swap 广播草案。
- [x] Base Sepolia fork 组合 dry-run 通过：模拟两笔交易，`transactionsPlanned=2`、`transactionsExecuted=2`、`readyForTinyBroadcast=true`；未带 `--broadcast`，未发送真实交易。
- [x] 用户明确批准后，真实 Base Sepolia 小额流动性 + swap 广播完成并链上复核：流动性交易 `0x99c69749bbd9199ac7476f8d0175d2f3a651b81d97a97a607e13ca2b5168517b`，swap 交易 `0x61744130044a25395399db900c542872fe8c887057025a8d6b86bc0c71aeebaa`，两笔 receipt 均为 `status=1`。
- [x] `forge test --match-path test/hooks/base/BaseSepoliaTinyMoonUsdcBroadcastPreparation.t.sol -vvv` 通过：3 passed，0 failed。
- [x] Base mainnet RPC dry-run 通过：`PrepareBaseMainnetDirectUsdcOnlyAdapter`，`broadcastRequested=false`，未部署主网。
- [x] 历史全量 Foundry 测试通过：241 passed，0 failed。
- [x] 新增 `contracts/hooks/base/BaseSunMoonUsdcFeeV4Hook.sol`，统一覆盖 `SUN/USDC` 2% USDC 和 `MOON/USDC` 5% USDC v4 Hook 收费路径。
- [x] 新增 `test/hooks/base/BaseSunMoonUsdcFeeV4Hook.t.sol`，覆盖 SUN/MOON 自由转账、SunCurve/MoonCurve mint/burn 兼容、2%/5% 收费、未白名单支持池拒绝、第三方 SUN/MOON 池不触发项目收费、transfer/renounce 后配置锁定。
- [x] `forge test --match-path test/hooks/base/BaseSunMoonUsdcFeeV4Hook.t.sol -vvv` 通过：11 passed，0 failed。
- [x] 新增 `script/RehearseBaseSunMoonUsdcFeeV4Hook.s.sol`，本地预演新版统一 Hook 的 CREATE2 salt 搜索、预测地址、部署地址和 v4 Hook 权限 bit。
- [x] 新增 `test/hooks/base/BaseSunMoonUsdcFeeV4HookCreate2Rehearsal.t.sol`，把新版统一 Hook 的 CREATE2 预演固化为回归测试。
- [x] `forge test --match-path test/hooks/base/BaseSunMoonUsdcFeeV4HookCreate2Rehearsal.t.sol -vvv` 通过：1 passed，0 failed。
- [x] 新增 `script/ComputeBaseSunMoonUsdcPoolIds.s.sol`，本地计算新版 `SUN/USDC` 和 `MOON/USDC` v4 Hook 池 `PoolKey -> poolId`、`initialTick`、`sqrtPriceX96`，不广播。
- [x] 新增 `test/hooks/base/BaseSunMoonUsdcPoolIdsPreparation.t.sol`，覆盖 poolId 计算、初始化价格计算、Hook 权限 bit、重复 token、零地址和无效 pool 参数。
- [x] `forge test --match-contract BaseSunMoonUsdcPoolIdsPreparationTest --threads 1 --isolate` 通过：7 passed，0 failed。
- [x] 使用 Base mainnet 预测地址完成两个池参数计算：`SUN_USDC_POOL_ID=0xf0006d5dde476ffd2b43648468d5c6a6a8cf1f40bcac5c0c7d070491587e075a`，`MOON_USDC_POOL_ID=0xcf29a02432e947fe9240fe4378cb871b24691f7cd85e7e8c72464ff89c1c6735`；未广播、未部署、未用私钥。
- [x] 新统一 Hook 和 poolId dry-run 脚本合入后，全量 `forge test --threads 1 --isolate` 通过：259 passed，0 failed。
- [x] 新增 `script/ComputeBaseMainnetSunMoonUsdcHookSalt.s.sol` 和 `test/hooks/base/BaseMainnetSunMoonUsdcHookSaltPreparation.t.sol`，覆盖 Base mainnet Hook salt 只读 dry-run、防广播、官方 USDC 和 Hook 权限 bit 检查。
- [x] Base mainnet fork Hook salt dry-run 已通过，输出 `PREDICTED_HOOK=0x04f968dE5cd57B1EB8215a9a488dC32508Fb80cc`；未广播、未部署、未用私钥。
- [x] 初始化价格计算合入后，全量 `forge test --threads 1 --isolate` 通过：293 passed，0 failed。
