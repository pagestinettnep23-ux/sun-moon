# Base 正式 USDC Adapter 方案选择 - 2026-05-15

本文档是主网前的 adapter 方案草案，不是主网部署批准。当前项目仍停留在本地 / Mock / Base Sepolia 测试网阶段，不接真实资金，不部署 Base 主网。

## 2026-05-16 更新

用户已确认新方向：

```text
SUN/MOON 都保持自由转账
不再试图禁止市场自行创建 AMM 池
项目支持的 v4 Hook 池使用 USDC 计费
SUN/USDC v4 Hook 池 swap 收 2% USDC
MOON/USDC v4 Hook 池 swap 收 5% USDC
```

因此本文原先的 `Direct-USDC-only` 判断仍有一部分成立：第一阶段仍应只处理 USDC 费用，不启用非 USDC 自动路由。但“只开放 MOON/USDC 核心池”的说法已经被扩展为：

```text
项目第一阶段支持两个 USDC 计费 v4 Hook 池：
  SUN/USDC
  MOON/USDC
```

后续代码更适合从 `BaseMoonAmmFeeV4Hook` 演进为统一 Hook，例如 `BaseSunMoonUsdcFeeV4Hook`。

## 官方参考

- Base Mainnet chainId 是 `8453`，公共 RPC 是 `https://mainnet.base.org`；Base 官方提醒公共 endpoint 有限流，不适合作为生产系统的唯一依赖。参考：[Base Connecting to Base](https://docs.base.org/chain/using-base)、[Base RPC Overview](https://docs.base.org/base-chain/api-reference/rpc-overview)。
- Circle 官方 USDC 地址表记录 Base Mainnet USDC 为 `0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913`，且提醒 mainnet token 有真实金融价值，必须充分测试、复核地址并保护私钥。参考：[Circle USDC Contract Addresses](https://developers.circle.com/stablecoins/usdc-contract-addresses?hsLang=en)。
- Uniswap v4 官方 deployments 文档记录各网络 v4 core / periphery / Universal Router / Permit2 地址，并明确集成方不应假设各链地址相同，必须按网络复核。参考：[Uniswap v4 Deployments](https://developers.uniswap.org/docs/protocols/v4/deployments)。
- Uniswap Universal Router 官方文档说明 Universal Router 是 unowned、non-upgradeable，聚合 v2/v3/v4 swap，并集成 Permit2。参考：[Universal Router Overview](https://developers.uniswap.org/docs/protocols/universal-router/overview)。
- Uniswap v4 swap routing 文档说明，v4 swap 可通过 Universal Router 执行，直接操作 PoolManager 更复杂；routing 需要 `commands`、`inputs`、Permit2、deadline、`minAmountOut` 等约束。参考：[Uniswap v4 Swap Routing](https://developers.uniswap.org/docs/protocols/v4/guides/swapping/routing)。

## 一句话结论

主网第一阶段推荐 `USDC-fee-only`：

```text
项目支持 SUN/USDC v4 Hook 池
项目支持 MOON/USDC v4 Hook 池
不开放项目支持的 SUN/WETH、MOON/WETH 或 native ETH Hook 池
不启用非 USDC 手续费资产自动换 USDC 的正式 adapter
```

用户未来仍可以在前端获得“用 ETH 买 MOON”的体验，但实现方式应是路由组合：

```text
ETH -> USDC -> MOON
```

也就是说，用户体验可以支持 ETH 入口；项目核心 Hook 第一阶段只承担 `SUN/USDC` 和 `MOON/USDC` 这两条 USDC 计费路径。

## 当前 Hook 的实际需求

`BaseMoonAmmFeeV4Hook` 的收费逻辑分两种：

```text
feeToken == USDC:
  Hook 直接把 feeToSunCurve 注入 SunCurve
  不调用 adapter

feeToken != USDC:
  Hook 把 feeToSunCurve 交给 swapAdapter
  adapter 负责把 feeToken 换成 USDC
  Hook 再把 USDC 注入 SunCurve
```

因此，如果主网第一阶段只支持 `SUN/USDC` 和 `MOON/USDC` 两类 USDC 计费池，并且白名单只允许这两个 pool，adapter 不需要真的做非 USDC swap。这个判断是当前最重要的安全简化。

## ETH 入口和 MOON/ETH 池的区别

这两个概念必须分开：

```text
用户体验上的 ETH 买 SUN/MOON:
  前端或路由器把 ETH 先换成 USDC
  再用 USDC 买 SUN 或 MOON
  项目支持池只开放 SUN/USDC 和 MOON/USDC

链上真实 MOON/ETH 或 MOON/WETH AMM 池:
  项目自己开放第二个 MOON/WETH 池
  Hook 会收到非 USDC 手续费资产
  必须启用 WETH -> USDC adapter
  攻击面、滑点、router 和审计复杂度都会上升
```

当前决策采用第一种：前端未来可以做 ETH 入口，但主网第一阶段不创建项目自己的 `MOON/ETH` 或 `MOON/WETH` 池。

## 方案对比

| 方案 | 做法 | 优点 | 风险 | 当前建议 |
| --- | --- | --- | --- | --- |
| A. USDC-fee-only | 支持 `SUN/USDC` 和 `MOON/USDC` v4 Hook 池，adapter 禁用所有非 USDC route | 最简单、攻击面小、符合新方向 | 需要新增 SUN/USDC 2% Hook 逻辑，ETH 入口需要前端/路由器先换 USDC | 推荐第一阶段 |
| B. MOON/USDC + MOON/WETH | 开放两个池，adapter 固定 WETH -> USDC | 用户可以直接交易 MOON/WETH 池 | router、报价、滑点、approval、MEV 和审计复杂度上升 | 后续阶段评估 |
| C. 通用 Universal Router adapter | adapter 支持多个非 USDC token route | 后续扩展性强 | 编码复杂，approval、deadline、slippage、MEV 风险更高 | 第二阶段之后评估 |
| D. 外部聚合器 adapter | adapter 调用第三方聚合器 | 路由灵活 | 外部依赖、任意 calldata、授权和返回值风险大 | 暂不采用 |
| E. 不部署 Hook/AMM 主网 | 继续只做测试网和只读前端 | 风险最低 | 无法进入真实交易 | 审计未完成时保持 |

## 推荐方案 A：USDC-fee-only

### 核心规则

```text
只允许两个项目支持池：
  SUN / USDC
  MOON / USDC

Hook.allowedMoonPools:
  白名单正式 MOON/USDC poolId

Hook.allowedSunPools:
  白名单正式 SUN/USDC poolId

adapter:
  必须是非零地址
  不允许任何非 USDC token route
  被调用时如果 tokenIn != USDC，直接 revert
```

### 为什么这样更稳

- 当前测试网已经完整验证了 `MOON/USDC` 小额路径。
- 新增 `SUN/USDC` 后仍然只收 USDC，Hook 对 USDC 手续费有直接路径，不需要 router。
- 少一个外部 swap，就少一层价格、滑点、deadline、Permit2、approval 和 MEV 风险。
- 主网第一阶段更容易解释、测试、审计和回滚。
- 用户仍可通过前端组合路由实现 `ETH -> USDC -> MOON` 的购买入口，不要求项目自己维护 `MOON/ETH` 池。

### 需要新增或确认的合约

当前 `TestnetUsdcAdapter` 是测试网 adapter，不建议直接主网复用。主网第一阶段可以保留一个更保守的防呆 adapter 草案：

```text
DirectUsdcOnlyAdapter
  - immutable USDC
  - authorizedHook
  - owner = MAINNET_ADMIN_WALLET
  - paused
  - swapFeeAssetToUSDT(tokenIn, amountIn, minUSDTOut)
      if paused revert
      if msg.sender != authorizedHook revert
      if tokenIn != USDC revert TokenNotAllowed
      if amountIn < minUSDTOut revert
      return amountIn
```

注意：在当前 Hook 实现里，`feeToken == USDC` 时不会调用 adapter，所以这个 adapter 主要是构造参数占位和防呆兜底。它的设计目标不是路由，而是防止误开非 USDC 路径。2026-05-16 新方向下，更关键的主合约是统一 USDC 费用 Hook，而不是扩展 adapter。

### 第一阶段主网参数原则

```text
USDC=0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913
SUN_USDC_POOL_SUPPORTED=true
MOON_USDC_POOL_SUPPORTED=true
SWAP_ADAPTER=DirectUsdcOnlyAdapter
ALLOW_NON_USDC_FEE_ROUTES=false
ALLOW_EXTERNAL_AGGREGATOR=false
FRONTEND_ETH_ENTRY_ALLOWED=true
CORE_HOOK_ETH_POOL=false
```

## 方案 B：MOON/USDC + MOON/WETH

这是后续阶段候选，不建议直接作为第一阶段主网方案。

如果未来一定要开放项目自己的 `SUN/ETH` 或 `MOON/ETH` 交易对，合约层应优先使用 WETH，前端再显示为 ETH。原因是 WETH 是 ERC20，更适合当前 Hook、Permit2 和 adapter 流程；native ETH 需要单独改 Hook、改测试并重新审计。

方案 B 必须解决：

- WETH -> USDC adapter 实现。
- 固定 router 和固定 route。
- `minUSDTOut` 来源。
- deadline 设置。
- approval 上限和重置。
- router 返回值不能直接信任，必须用 USDC 余额差校验。
- WETH 手续费预算部分如何进入并管理 `PROTOCOL_BUDGET_WALLET`。
- mainnet fork 下低流动性、大滑点、router revert 和 MEV 风险。

## 方案 C：通用 Universal Router adapter

这是第二阶段之后候选，不建议第一阶段采用。

如果 adapter 调用 Universal Router，需要明确：

- 使用 Base Mainnet 哪个 Universal Router 地址，且必须以 Uniswap 官方 deployments 复核。
- 使用哪个 Permit2 地址，且必须以 Uniswap 官方 deployments 复核。
- adapter 持有什么 token 授权，授权给谁，额度多少，到期时间如何控制。
- route 是否只允许固定 token path，还是允许多跳。
- `minUSDTOut` 从哪里来，谁负责设置，是否能被用户 / 前端恶意填太低。
- deadline 如何设置。
- partial fill 是否允许；当前建议不允许。
- router 返回值是否可信，还是必须用 USDC 余额差复核。
- 失败时是否整笔 swap 回滚；当前建议必须整笔回滚。

### 必须保留的安全约束

```text
allowedRouters[router] == true
tokenRouter[tokenIn] != address(0)
route hash allowlist
minUSDTOut > 0
deadline <= block.timestamp + shortWindow
actualUSDCOut = USDC.balanceOf(hook) - before
actualUSDCOut >= minUSDTOut
approval reset to 0 after swap
paused 可用
onlyAuthorizedHook
nonReentrant
```

### 不允许的做法

- 不允许 adapter 成为任意 calldata 转发器。
- 不允许任何人传入任意 router。
- 不允许只相信 router 返回值。
- 不允许 `minUSDTOut=0`。
- 不允许无限期 Permit2 授权给不固定的 spender。
- 不允许没有 route allowlist 就上主网。

## 方案 D：外部聚合器 adapter

当前不建议。

原因：

- 聚合器 calldata 通常复杂，容易变成任意外部调用。
- 真实返回 token、spender、target、allowance 和滑点更难审计。
- 聚合器服务可变，离线签名或 API 结果可能和链上执行不一致。
- 对非技术 owner 更难复核。

除非后续有独立审计和严格 route / target allowlist，否则不进入主网计划。

## Gate C 状态

来自主网前风险清单：

```text
Gate C = 正式 adapter 方案确定
```

当前状态：

```text
Gate C = 2026-05-16 已更新为 USDC-fee-only 方向；旧 adapter 草图、专项测试和 Base mainnet RPC dry-run 仍可作为防呆基础；统一 Hook 本地版已实现并通过专项测试、CREATE2 本地预演和 poolId 本地计算测试，但人工 review、正式参数 poolId、正式 CREATE2 salt 和 mainnet fork dry-run 未完成
```

已完成项：

- `DirectUsdcOnlyAdapter` 草图已实现，可作为非 USDC route 防呆基础。
- `DirectUsdcOnlyAdapterTest` 已覆盖授权 Hook、暂停、零地址、零金额、`minUSDTOut`、非 USDC token 拒绝、owner 配置权限和非 owner 拒绝。
- `PrepareBaseMainnetDirectUsdcOnlyAdapter` 已新增，脚本内部不调用 `startBroadcast`，并拒绝 `EXECUTE_BASE_MAINNET_DIRECT_ADAPTER_BROADCAST=1`。
- Base mainnet RPC dry-run 已通过：`chainId=8453`、`USDC=0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913`、`usdcDecimals=6`、`broadcastRequested=false`。
- `BaseSunMoonUsdcFeeV4Hook` 本地版已新增，覆盖 `SUN/USDC` 2% USDC、`MOON/USDC` 5% USDC、自由转账、SunCurve/MoonCurve mint/burn 兼容、白名单和 renounce 后配置锁定。
- `RehearseBaseSunMoonUsdcFeeV4Hook` 本地预演已新增，覆盖新版统一 Hook 的 CREATE2 salt 搜索、预测地址、实际部署地址和 v4 Hook 权限 mask 复核。
- `ComputeBaseSunMoonUsdcPoolIds` 本地 dry-run 已新增，只计算新版 `SUN/USDC` 和 `MOON/USDC` v4 Hook 池 `PoolKey -> poolId`、`initialTick`、`sqrtPriceX96`，不广播、不授权、不需要私钥。
- `Base-主网正式参数确认清单模板-2026-05-16.md` 已新增，用于后续逐项确认公开地址、官方地址、CREATE2、poolId、初始化价格和 Gate。
- 当前专项 Foundry 测试通过：`BaseSunMoonUsdcFeeV4HookTest`，`11 passed, 0 failed`。
- 当前 poolId dry-run 测试通过：`BaseSunMoonUsdcPoolIdsPreparationTest`，`7 passed, 0 failed`。
- 当前全量 Foundry 测试通过：`forge test --threads 1 --isolate`，`293 passed, 0 failed`。

未完成原因：

- 主网 `SUN/USDC` 和 `MOON/USDC` 正式参数 poolKey、poolId 和初始化价格参数已有预测地址计算值；仍需正式部署地址复核。
- 正式部署参数下的 CREATE2 salt 和预测 Hook 地址已有 dry-run 预测值；仍需正式部署后复核。
- Base Mainnet Uniswap v4 地址还没有在部署当天二次复核。
- 还没有外部 review / 审计。
- 主网正式普通钱包公开地址还没有最终确认；本次 mainnet dry-run 使用的是测试地址占位。

## 测试覆盖状态

方案 A 已覆盖 / 仍需补充：

- 已完成：SUN/MOON 都保持自由转账。
- 已完成：统一 Hook 对 `SUN/USDC` 收 `2% USDC`。
- 已完成：统一 Hook 对 `MOON/USDC` 收 `5% USDC`。
- `DirectUsdcOnlyAdapter` 只允许授权 Hook 调用。
- `tokenIn != USDC` 必须 revert。
- `paused=true` 必须 revert。
- `amountIn < minUSDTOut` 必须 revert。
- Hook 在 `SUN/USDC` 和 `MOON/USDC` 池中不调用 adapter 也能完成 USDC 注入。
- 非白名单项目支持池必须 revert 或不触发项目费用逻辑。
- 前端 ETH 入口必须只作为组合路由，不新增 Hook 白名单池。

如果后续进入方案 B 或 C：

- WETH -> USDC route 编码固定且可复核。
- Permit2 approval 上限和过期时间测试。
- `minUSDTOut` 边界测试。
- deadline 过期测试。
- router 返回值虚假时，余额差校验仍然保护。
- router revert 时整笔 Hook swap revert。
- route 未 allowlist 时 revert。
- 多 token、多 hop、低流动性和大滑点 fork 测试。

## 前端配套要求

方案 A 的前端：

- 项目支持池只显示 `SUN/USDC` 和 `MOON/USDC`。
- 可以做“ETH 买 MOON”的入口，但底层必须走 `ETH -> USDC -> MOON`。
- 不应把项目支持池描述成 `SUN/ETH`、`SUN/WETH`、`MOON/ETH` 或 `MOON/WETH`。
- 不应提交任何新增 WETH/ETH 池白名单、mint、burn 或 swap 交易。
- 明确标注主网前仍未开放真实交易，直到 Gate 全部通过。

如果后续启用方案 B 或 C：

- 每笔交易必须显示 route、min received、deadline、滑点、Hook fee。
- 禁止默认 `minUSDTOut=0`。
- 如果 quote 失败，不能自动提交交易。
- 如果 route 不是 allowlist route，不能提交交易。

## 决策建议

当前推荐：

```text
主网第一阶段：方案 A USDC-fee-only，支持 SUN/USDC 与 MOON/USDC v4 Hook 池
用户 ETH 买入体验：前端后续做 ETH -> USDC -> SUN/MOON 组合路由
后续可评估：方案 B MOON/USDC + MOON/WETH
第二阶段之后：评估方案 C 通用 Universal Router adapter
暂不采用：方案 D 外部聚合器 adapter
```

这意味着下一步不是主网部署，也不是广播交易。`DirectUsdcOnlyAdapter` 草图、测试和 Base mainnet RPC dry-run 已完成，统一 Hook 本地版、专项测试、CREATE2 本地预演和 poolId 本地计算工具也已完成；但新方向还需要人工 review、主网普通钱包公开地址确认、正式参数 poolId、CREATE2 salt、主网部署参数清单和 mainnet fork dry-run。只有这些完成后，Gate C 才能从“本地实现完成”变成“主网前确认完成”。
