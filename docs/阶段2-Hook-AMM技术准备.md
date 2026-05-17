# 阶段 2 - Hook/AMM 技术准备

更新日期：2026-05-15

本文档用于统一阶段 2 Hook/AMM 技术方向。当前已经完成 Mock 合约、Mock 测试、Base v4 技术预研、`BaseMoonAmmFeeV4Hook` v2 的本地真实 `PoolManager` 适配测试、Base Sepolia 测试网前参数预检方案、测试版 USDC adapter 草图、本地 adapter 预演脚本和 `Create2HookDeployer` Base Sepolia 第一次小额广播；仍不部署主网，不接触真实资金。

2026-05-16 主网前方向更新：SUN/MOON 都保持自由转账，不再从 token 合约层禁止市场自行创建 AMM 池；`SunAmmGuardHook` 和 `BaseSunAmmGuardV4Hook` 作为历史技术原型保留。下一阶段改为设计统一 v4 Hook：`SUN/USDC` swap 收 `2% USDC`，`MOON/USDC` swap 收 `5% USDC`。

## 1. 当前结论

SUN/MOON 的核心不是 AMM，而是站内曲线铸造和燃烧：

```text
USDT -> SUN -> MOON
MOON -> SUN -> USDT
```

因此阶段 2 的 Hook/AMM 只作为辅助层，重点解决：

- SUN AMM 首次加池和解锁控制已作为历史原型完成；2026-05-16 新决策是不再采用“禁止加池 / 首池守卫”模型，SUN/MOON 保持自由转账，项目只对指定 v4 Hook 池收费。
- MOON AMM 交易税费拦截。
- 将 MOON AMM 费用中的一部分转换为 USDT 并注入 SUN 曲线。
- 保护池子、价格、滑点和管理员配置。

不要把 AMM 做成用户主入口。官网正式版仍应把 Mint/Burn 和曲线数据作为核心。

## 2. 官方文档确认点

### 2.1 Uniswap v4 路线

Uniswap v4 Hook 可以在池子生命周期的关键位置执行自定义逻辑，例如初始化、加流动性、移除流动性和交换前后。

关键限制：

- Hook 权限编码在 Hook 合约地址的低位 bit 中。
- 部署 Hook 时通常需要使用 `CREATE2` 和地址挖矿，让合约地址匹配启用的回调权限。
- 如果地址权限和合约声明的权限不匹配，Hook 可能无法按预期工作。

官方参考：

- https://developers.uniswap.org/docs/protocols/v4/concepts/hooks
- https://developers.uniswap.org/docs/protocols/v4/guides/hooks/hook-deployment
- https://developers.uniswap.org/docs/protocols/v4/deployments

当前路线选择：

- 第一条真实 DEX 技术路线确定为 Base + Uniswap v4。
- Base Mainnet Chain ID 为 `8453`，Base Sepolia Chain ID 为 `84532`。
- Uniswap v4 官方部署页已经列出 Base Mainnet 和 Base Sepolia 的 v4 地址。
- Base 真实路线稳定币确定使用 USDC，第一阶段官方核心池收敛为 `MOON/USDC`；`SUN/USDC` 不进入主网官方池计划。
- 当前合约里的 `USDT` 命名暂时作为 6 位稳定币历史命名保留；进入 Base 真实路线时，对应地址应配置为 USDC。
- 下一步只做 Base Sepolia / Base fork 技术预研，不部署 Base 主网，不接触真实资金。
- 详细路线见 `docs/Base-Uniswap-v4-技术路线.md`。

### 2.2 PancakeSwap Infinity / BNB Chain 路线

PancakeSwap Infinity 的 Hook 设计与 Uniswap v4 类似，但官方文档说明其 Hook 可以部署在任意地址，权限和参数编码在 `PoolKey.parameters` 中。

这意味着：

- 不能直接假设 Uniswap v4 的 Hook 部署脚本能用于 PancakeSwap。
- 如果后续部署到 BNB Chain，需要单独做 PancakeSwap Infinity 的本地或测试网适配。
- BNB 路线应独立验证 PoolManager、PoolKey、Hook 权限和路由器交互。

官方参考：

- https://developer.pancakeswap.finance/contracts/infinity/overview
- https://developer.pancakeswap.finance/contracts/infinity/overview/custom-layer-hook
- https://developer.pancakeswap.finance/contracts/infinity/guides/develop-a-hook

## 3. 阶段 2 推荐路线

阶段 2 不建议一上来就做真实 DEX 集成。建议分成五小步：

1. `2A`：先写 Hook/AMM 接口草图和 Mock 测试框架。已完成。
2. `2B`：实现 SUN AMM 加池守卫的最小版测试。已完成，现作为历史原型保留，不进入主网。
3. `2C`：实现 MOON AMM 费用路由的 Mock 版测试。已完成。
4. `2D`：实现 AmmSwapAdapter 独立 Mock 测试。已完成。
5. `2E`：确定第一条真实 DEX 路线为 Base + Uniswap v4。已完成。
6. `2F`：进入 Base Sepolia / Base fork 的 Uniswap v4 技术预研。进行中，已完成官方地址/fork 检查、最小 callback、SUN v4 `beforeAddLiquidity` 适配测试、MOON v4 return delta 收费、Mock 路由闭环测试、测试网前参数预检、测试版 USDC adapter 草图、本地 adapter 预演和 `Create2HookDeployer` 第一次小额广播。
7. `2G`：最后单独验证 PancakeSwap Infinity / BNB Chain 可行性。未开始。

优先级建议：

```text
SUN AMM 加池守卫
MOON AMM 税费 Mock
  -> DEX 适配层
  -> 测试网
```

说明：早期曾优先做 SUN 加池守卫，因为它的业务边界清晰。2026-05-16 新方向不再在 `SunToken` 层禁止 SUN AMM；后续优先级转为统一 v4 Hook：`SUN/USDC` 收 `2% USDC`，`MOON/USDC` 收 `5% USDC`，并完成放弃管理权方案。

## 4. 拟拆分合约模块

### 4.1 SunAmmGuardHook

当前状态：历史原型，不进入主网部署计划。主网不再需要 SUN 首次加池钱包、SUN 池白名单或 SUN AMM 解锁状态。

用途：

- 管理包含 SUN 的 AMM 池加池权限。
- 在 SUN AMM 未解锁前，只允许指定钱包完成第一次加池。
- 第一次有效加池成功后，设置 `sunAmmUnlocked = true`。
- 解锁后，包含 SUN 的池子可以按规则开放。
- 不包含 SUN 的池子应不受影响。

建议状态：

```text
sunToken
authorizedFirstLiquidityWallet
sunAmmUnlocked
allowedSunPools
paused
owner
```

建议事件：

```text
SunAmmUnlocked
FirstLiquidityWalletSet
SunPoolAllowedSet
PausedSet
```

当前 Mock 状态：

- 已新增 `contracts/hooks/SunAmmGuardHook.sol`。
- 已新增 `test/hooks/SunAmmGuardHook.t.sol`。
- 已覆盖首次加池钱包、白名单池、暂停、权限和零地址配置。

### 4.2 MoonAmmFeeHook

用途：

- 对涉及 MOON 的 AMM 交易收取 5% 费用。
- 其中 3% 用于 SUN 曲线飞轮。
- 其中 2% 保留为原手续费资产，进入协议预算钱包。

阶段 2 先不要直接做真实外部换币。先做 Mock 版，把“费用资产 -> USDT -> `SunCurve.injectUSDT()`”的路径用测试替身跑通。

长期目标：

```text
MOON AMM 交易费用
  -> 3% 通过适配器换成 USDT/USDC
  -> 调用 SunCurve.injectUSDT()
  -> 2% 保留原手续费资产，进入协议预算钱包
```

当前 Mock 状态：

- 已新增 `contracts/hooks/MoonAmmFeeHook.sol`。
- 已新增 `test/hooks/MoonAmmFeeHook.t.sol`。
- 已覆盖 MOON 买入/卖出方向 5% 费用。
- 已覆盖 3% 换成 USDT/USDC 后注入 SUN 曲线、2% 原手续费资产进入协议预算钱包。
- 已覆盖 `minUSDTOut`、未授权调用、暂停、错误池子和舍入边界。

### 4.3 AmmSwapAdapter

用途：

- 隔离不同 DEX 的换币逻辑。
- Uniswap v4 和 PancakeSwap Infinity 不要写进同一个核心 Hook 里。
- 所有换币必须带 `minUSDTOut`。

建议先有接口，不急着生产实现：

```text
swapFeeAssetToUSDT(tokenIn, amountIn, minUSDTOut) returns (usdtOut)
```

当前 Mock 状态：

- 已新增 `contracts/hooks/AmmSwapAdapter.sol`。
- 已新增 `test/hooks/AmmSwapAdapter.t.sol`。
- 当前实现只用于 Mock 测试：不连接真实 DEX，只用 MockUSDT 模拟换出 USDT。
- 已覆盖授权 Hook、暂停、输入校验、`minUSDTOut` 不满足、模拟失败和配置权限。
- `MoonAmmFeeHook` 测试和 `HookIntegration` 测试已改为使用独立 `AmmSwapAdapter`。

### 4.4 HookConfigRegistry

用途：

- 记录允许的池子、预算钱包、适配器地址和暂停状态。
- 降低 Hook 合约本身的配置复杂度。

如果初版过于复杂，可以先不单独拆合约，把配置放在 Hook 里，但测试要覆盖所有管理员路径。

## 5. 当前合约需要保持的边界

阶段 2 不应破坏当前已验证的核心规则：

- SUN 价格来自 `SunCurve` 储备账本，不依赖 AMM 市价。
- MOON Mint 必须先有 SUN，不提供 `USDT -> MOON` 一键路径。
- MOON Burn 只返回 SUN，不提供 `MOON -> USDT` 一键路径。
- `SunCurve.injectUSDT()` 只能由授权的 MOON AMM/Hook 路径调用。
- `SunCurve.burnAndRetain()` 只能由授权的 `MoonCurve` 调用。
- 当前站内 Mint/Burn 逻辑必须继续通过全部测试。

## 6. 高风险点

阶段 2 的风险明显高于阶段 1，主要集中在：

- Hook 权限和部署地址不匹配。
- 不同 DEX 的 Hook API 和权限模型不同。
- Hook 中做外部换币可能引入重入、滑点和 MEV 风险。
- 池子身份识别错误，导致未知池子绕过限制。
- `minUSDTOut` 设置不合理，导致费用换币损失。
- 税费资产可能不是 USDT，需要可靠的换币路径。
- 管理员误配置池子、适配器或预算钱包。
- 暂停机制不足，出现异常时无法快速止损。

## 7. 阶段 2 前必须确认的问题

进入真实 Hook 代码前，必须确认：

- 第一条 DEX 路线优先做 Uniswap v4 还是 PancakeSwap Infinity？
- 第一批 Base 真实池子已收敛为 `MOON/USDC`；`SUN/USDC` 不进入主网官方池计划。
- SUN 首次加池钱包已取消；主网前不再通过 `SunToken` 转账限制禁止 AMM，而是设计 `SUN/USDC` 与 `MOON/USDC` 的统一 USDC 费用 Hook。
- SUN AMM 解锁状态已取消；`SunAmmGuardHook` 仅作为历史原型保留。
- MOON AMM 交易税费适用于任意 MOON 交易对，优先从交易对里的非 MOON 侧资产扣；其中 3% 如果不是 USDC，再通过适配器换成 USDC；2% 保留原手续费资产给协议预算钱包。
- 3% 费用是交易内立刻注入 USDC，还是先进入 FeeRouter 后由 keeper 执行？
- `minUSDTOut` 由用户传、管理员配置，还是前端根据报价生成？
- Hook 是否必须支持紧急暂停？

## 8. 阶段 2 验收标准

阶段 2 准备完成的标准：

- 技术路线文档完成。
- Hook/AMM 测试清单完成。
- 安全清单补充 Hook/AMM 专项检查。
- 明确 Uniswap v4 和 PancakeSwap Infinity 的差异。
- Mock Hook 测试完成，但仍不接触真实资金。
- Mock Adapter 测试完成，但仍不接真实 DEX。
- Hook 与站内曲线集成测试完成。
- Base + Uniswap v4 最小 Hook 探针编译测试完成。
- Base Sepolia / Base Mainnet fork 官方地址只读检查完成。
- Base Sepolia / Base Mainnet fork 官方 `PoolManager.initialize()` 最小 Hook callback 测试完成。
- SUN 加池守卫到 Uniswap v4 `beforeAddLiquidity` 的适配合约和测试完成。
- MOON 5% AMM 费用到 Uniswap v4 的 `BaseMoonAmmFeeV4Hook` v2 return delta 适配合约和测试完成。
- MOON 任意交易对生产级费用来源策略确认：固定从非 MOON 侧收，四种 swap 方向和 `MOON/WETH` 已用纯逻辑测试覆盖。
- MOON 任意交易对生产级费用收取方式确认：优先使用 v4 return delta；非 MOON 费用资产为 specified currency 时走 `beforeSwap`，为 unspecified currency 时走 `afterSwap`。
- MOON 任意交易对费用在本地真实 `PoolManager` return delta 结算原型中已通过。
- MOON return delta 收到 5% 费用后的 Mock 路由闭环已通过：3% 转 MockUSDT/USDC 并注入 SUN 曲线，2% 保留原手续费资产进入预算钱包。
- CREATE2 Hook 地址权限位预检查脚本和测试已完成。
- MOON v2 Hook 外部调用路径的恶意 fee token 重入测试已完成。
- Base Sepolia 测试网前部署参数清单、真实 USDC adapter 方案和本地参数预检脚本已完成。
- 测试版 `TestnetUsdcAdapter` 和 Mock 路由器测试已完成。
- 本地 Base Sepolia adapter 预演脚本和测试已完成。
- 本地 `Create2HookDeployer` 草图、测试和完整预演脚本已完成。
- Base Sepolia `Create2HookDeployer` 部署脚本、安全测试和第一次小额广播已完成。
- `CREATE2_DEPLOYER` 已固定为 `0xE5Df76A1DF2e959C70c8b7591754a3a2a542Fb6D`，owner 已链上复核。
- Base Sepolia 曲线核心和 `TestnetUsdcAdapter` 第二次小额广播已完成并链上复核。
- `PrepareBaseSepoliaHookDeploy` / `BaseSepoliaHookDeployPreparation`：Hook 小额广播前的 owner、salt、预测地址、权限 bit 和依赖代码保护已完成，Base Sepolia dry-run 已通过。
- Base Sepolia Hook 小额广播已完成并链上复核，实际地址等于 CREATE2 预测地址。
- `PrepareBaseSepoliaHookBinding` / `BaseSepoliaHookBindingPreparation`：Hook 权限绑定前的 owner、参数、权限 bit 和链上依赖保护已完成，Base Sepolia dry-run 已通过。
- `PrepareBaseSepoliaControlledMoonPool` / `BaseSepoliaControlledMoonPoolPreparation`：受控 `MOON/USDC` 测试池 `PoolKey -> poolId` 计算和白名单 dry-run 已完成。
- 当前全量 Foundry 测试通过：`222 passed, 0 failed`。

## 9. 当前结论和下一步

截至 2026-05-14，阶段 2 的 Mock 层和 Base v4 技术预研原型已经完成：

- `SunAmmGuardHook`：SUN AMM 首次加池和白名单守卫。
- `MoonAmmFeeHook`：MOON AMM 5% 费用路由。
- `AmmSwapAdapter`：手续费资产到 MockUSDT 的 Mock 适配层。
- `HookIntegration`：MOON AMM 费用注入 SUN 曲线，并推动 SUN / MOON 曲线计价同步变化。
- `BaseV4HookProbe`：最小 Uniswap v4 Hook 编译探针，用于验证 v4-core 依赖、接口签名和 selector。
- `BaseV4Addresses`：Base Mainnet / Base Sepolia 的 Uniswap v4 官方地址常量。
- `BaseV4PoolManagerProbe`：使用本地真实 `PoolManager` 验证 Hook 权限 bit。
- `BaseV4ForkPoolManagerProbe`：使用 Base Sepolia / Base Mainnet fork 验证官方 `PoolManager` 最小 callback。
- `BaseSunAmmGuardV4Hook`：把现有 `SunAmmGuardHook` 规则映射到 v4 `beforeAddLiquidity`，验证 PoolManager 调用限制、v4 PoolId 白名单、首次加池解锁和未知 SUN 池回滚。
- `BaseMoonAmmFeeV4Hook`：已升级为 v2，正式合约直接使用 v4 `beforeSwap` / `afterSwap` return delta 收取 MOON 任意交易对 5% 费用，并在同一笔交易内完成 3% MockUSDT/USDC 注入和 2% 原手续费资产预算分配。
- `BaseMoonAmmFeePolicy`：确定 MOON 任意交易对生产级费用来源固定为非 MOON 侧，覆盖 exact-in/exact-out、买入/卖出四种方向，确认优先走 v4 return delta，并覆盖 `MOON/WETH`。
- `BaseMoonAmmFeeReturnDeltaSettlement`：使用本地真实 `PoolManager`、`PoolSwapTest` 和 `PoolModifyLiquidityTest`，验证 `beforeSwap` specified return delta 与 `afterSwap` unspecified return delta 都能把 5% 费用实际结算到 Hook 地址。
- `BaseMoonAmmFeeReturnDeltaRoute`：在真实本地 `PoolManager` return delta 结算之后，继续验证 3% fee token 通过 Mock adapter 转 MockUSDT/USDC 并调用 `SunCurve.injectUSDT()`，2% 保留原手续费资产进入协议预算钱包。
- `BaseV4HookAddressMiner` / `FindBaseMoonAmmFeeV4HookSalt`：本地搜索 CREATE2 salt，并检查预测 Hook 地址低位权限 bit 精确匹配 v2 需要的 `204`。
- `BaseMoonAmmFeeV4HookSecurity`：恶意 fee token 在 Hook 外部调用过程中尝试嵌套 swap 重入，测试确认重入失败且外层状态正确。
- `BaseDeploymentPreflight` / `CheckBaseSepoliaDeploymentParams`：本地检查 Base Sepolia 官方地址、项目关键地址和预测 Hook 权限 bit。
- `docs/Base-Sepolia-测试网前部署参数清单.md`：记录测试网前需要填写和复核的参数。
- `docs/Base-USDC-Adapter方案.md`：记录 3% 换 USDC 注入、2% 保留原手续费资产进入预算钱包的真实 adapter 路线。
- `TestnetUsdcAdapter`：测试版 USDC adapter 草图，包含授权 Hook、token/router allowlist、余额差校验、`minUSDTOut`、暂停和 owner 配置。
- `MockUsdcSwapRouter`：可复用受控 Mock USDC 路由器，用于验证 adapter 不信任 router 返回值，只认实际 USDC 余额差。
- `RehearseBaseSepoliaAdapter` / `BaseSepoliaAdapterRehearsal`：本地预演测试 token、Mock 路由器、非 USDC 路由和 USDC 直通路径。
- `PrepareBaseSepoliaCreate2Deployer` / `BaseSepoliaCreate2DeployerPreparation`：准备 Base Sepolia `Create2HookDeployer` 部署，确认 owner、chainId、部署钱包保护和 Base 主网拒绝逻辑；第一次小额广播已完成。
- `PrepareBaseSepoliaHookDeploy` / `BaseSepoliaHookDeployPreparation`：准备 Base Sepolia Hook 部署，dry-run 确认 `DEPLOYED_HOOK == PREDICTED_HOOK` 且权限 bit 为 `204`；Hook 小额广播已完成并复核。
- `PrepareBaseSepoliaHookBinding` / `BaseSepoliaHookBindingPreparation`：准备 adapter 授权和 `SunCurve.moonAMM` 绑定，dry-run、广播和链上复核均已完成。
- `PrepareBaseSepoliaControlledMoonPool` / `BaseSepoliaControlledMoonPoolPreparation`：受控 `MOON/USDC` 测试池 dry-run 已完成，`poolId=0xfbb4ccec5e3fda3a97b9e2619e9e90588ad5e444bdb3d488e921a3192c42dd55`。
- `PrepareBaseSepoliaControlledMoonPoolInitialize` / `BaseSepoliaControlledMoonPoolInitializePreparation`：受控 `MOON/USDC` 测试池初始化 dry-run、广播和链上复核已完成，`slot0.tick=276300`。

下一步不应直接上主网，也不应接触真实资金。更稳妥的下一步是：

1. 保持 Base Sepolia / Base fork 技术预研路线，不部署 Base 主网。
2. 继续保持 Mock / fork / Base Sepolia 小额测试路线；当前 Hook 绑定广播、受控测试池 `poolId` dry-run、测试池白名单广播、初始化广播、极小额演练准备、资产/Permit2 授权和报价预检均已完成；下一步准备真实小额流动性 + swap 广播草案和最终 dry-run。
3. 当前 MOON v4 适配只通过 `hookData` 传入 `minUSDTOut`；生产级方案已经不依赖前端传入费用金额。
4. 在确认 `minUSDTOut` 生成方式、真实路由器、滑点策略、USDC adapter 路径和测试网演练参数之前，不接真实资金。
5. 若后续做测试网演练，只使用测试 token 和小额测试环境。
