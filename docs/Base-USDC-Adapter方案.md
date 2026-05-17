# Base USDC Adapter 方案

更新日期：2026-05-14

本文档记录 MOON 任意 AMM 交易对 5% 费用进入 Base 路线后的 USDC adapter 方案。当前只做设计和 Mock / fork 级测试，不部署主网，不接触真实资金。

## 1. 费用规则结论

MOON 任意交易对都收 5% AMM 费用，费用资产固定为交易对里的非 MOON 侧资产。

```text
MOON/USDC -> 收 USDC
MOON/WETH -> 收 WETH
MOON/SUN  -> 收 SUN
```

费用拆分：

| 比例 | 处理方式 |
| ---: | --- |
| 3% | 必须换成 USDC，并调用 `SunCurve.injectUSDT()` 注入 SUN 曲线 |
| 2% | 保留原手续费资产，进入协议预算钱包 |

所以用户之前问的“2% 是不是 USDC”，当前阶段答案是：

- 如果交易对是 `MOON/USDC`，2% 预算部分就是 USDC。
- 如果交易对是 `MOON/WETH`，2% 预算部分就是 WETH。
- 如果交易对是 `MOON/SUN`，2% 预算部分就是 SUN。

这样可以减少额外换币和滑点风险。

## 2. 当前代码状态

当前已完成：

- `BaseMoonAmmFeeV4Hook` v2 使用 Uniswap v4 return delta 收取 MOON 任意交易对 5% 费用。
- `hookData` 只承载 `minUSDTOut`，不再让前端指定 `feeToken` 或 `feeBaseAmount`。
- 3% 飞轮部分如果已经是 USDC，则直接注入 SUN 曲线。
- 3% 飞轮部分如果不是 USDC，则走 `IMoonAmmSwapAdapter.swapFeeAssetToUSDT()`。
- 2% 预算部分保留原手续费资产，直接转给协议预算钱包。
- 当前 adapter 仍是 Mock，不连接真实 DEX。
- 已新增 `contracts/hooks/TestnetUsdcAdapter.sol`，作为测试版 USDC adapter 草图。
- 已新增 `contracts/mocks/MockUsdcSwapRouter.sol`，作为可复用受控 Mock USDC 路由器。
- 已新增 `test/hooks/TestnetUsdcAdapter.t.sol`，使用 Mock 路由器验证 allowlist、USDC 输出、滑点、暂停和权限。
- `BaseMoonAmmFeeV4Hook.t.sol` 已新增一条集成测试，验证 MOON v4 Hook 可以通过 `TestnetUsdcAdapter` 和 Mock 路由器完成非 USDC 手续费资产到 USDC 注入。
- 已新增 `script/RehearseBaseSepoliaAdapter.s.sol`，用于本地预演 adapter 配置、非 USDC 路由和 USDC 直通路径。
- 已新增 `test/hooks/base/BaseSepoliaAdapterRehearsal.t.sol`，把上述预演流程固化为测试。
- 已新增 `script/PrepareBaseSepoliaControlledMoonPool.s.sol` 和 `test/hooks/base/BaseSepoliaControlledMoonPoolPreparation.t.sol`，用于计算受控 `MOON/USDC` 测试池 `poolId` 并 dry-run 白名单配置。

当前历史命名：

```text
USDT / MockUSDT / minUSDTOut / injectUSDT
```

在 Base 路线里实际含义是：

```text
USDC / MockUSDC / minUSDCOut / injectUSDC
```

后续是否重命名需要单独安排，不建议和真实 adapter 一起改。

## 3. 真实 adapter 的最小接口

保持现有 Hook 接口不变：

```solidity
function swapFeeAssetToUSDT(
    address tokenIn,
    uint256 amountIn,
    uint256 minUSDTOut
) external returns (uint256 usdtOut);
```

Base 路线中：

- `tokenIn` 是非 MOON 侧手续费资产。
- `amountIn` 是 3% 飞轮部分。
- `minUSDTOut` 是最少可接受 USDC 输出。
- 返回值 `usdtOut` 实际代表 USDC 输出。

## 4. 真实 adapter 必须具备的保护

真实 adapter 不应该做成“任意 calldata 转发器”。最低要求：

- 只允许授权 Hook 调用。
- 只允许 allowlist 中的 `tokenIn`。
- 只允许 allowlist 中的 router 或 route module。
- 输出 token 必须固定为 Base USDC。
- `amountIn` 和 `minUSDTOut` 必须大于 0。
- 实际 USDC 输出小于 `minUSDTOut` 时整笔交易回滚。
- 支持暂停。
- 支持 owner 更新 allowlist，并发出事件。
- 每次换币前后检查余额差，不信任外部返回值。
- 对 ERC20 授权使用安全 approve 流程，避免残留过大授权。
- 不支持 fee-on-transfer token，除非单独测试。
- 不支持管理员临时传任意 swap calldata，除非外部审计后再放开。

## 5. 推荐实现路线

### 5.1 第一版：只允许 USDC 直通

适合最早期测试网演练：

- `MOON/USDC` 交易对可以完整验证 5% 收费。
- 3% 直接注入 SUN 曲线。
- 2% USDC 进入预算钱包。
- 非 USDC 交易对先不开放真实池白名单。

优点是风险最低。

缺点是还没有验证 `MOON/WETH` 这类任意交易对真实换币。

### 5.2 第二版：白名单非 USDC 资产

逐步增加：

- `WETH -> USDC`
- `SUN -> USDC`

每新增一种 `tokenIn`，都要单独配置 route、滑点策略和测试。

### 5.3 第三版：真实路由器适配

再考虑接 Uniswap v4 periphery / Universal Router 等真实路由。

这一版之前必须先确认：

- 当前 Base 上 v4 periphery 的调用方式。
- Hook 合约直接调用 router 是否有额外限制。
- 是否需要中间 FeeRouter 合约隔离风险。
- 交易内立即换 USDC 是否会带来过高 MEV 和 gas 风险。

## 6. 测试计划

真实 adapter 进入测试网前，至少新增以下测试：

| 测试项 | 预期 |
| --- | --- |
| 非授权地址调用 adapter | 回滚 |
| 未 allowlist 的 tokenIn | 回滚 |
| `tokenIn == USDC` | 直接返回 `amountIn` 或由 Hook 直通，不走外部 swap |
| 非 USDC tokenIn 成功换出 USDC | 返回实际 USDC 输出 |
| 输出小于 `minUSDTOut` | 回滚 |
| router 调用失败 | 回滚 |
| adapter 暂停 | 回滚 |
| 恶意 token 重入 | 回滚或状态不被破坏 |
| fee-on-transfer token | 默认不支持并回滚 |
| 预算 2% | 始终保留原手续费资产，不被 adapter 换走 |

当前已覆盖：

```text
forge test --match-contract TestnetUsdcAdapterTest
15 passed, 0 failed

forge test --match-path test/hooks/base/BaseMoonAmmFeeV4Hook.t.sol
16 passed, 0 failed

forge test --match-contract BaseSepoliaAdapterRehearsalTest
1 passed, 0 failed

forge script script/RehearseBaseSepoliaAdapter.s.sol
Base Sepolia adapter local rehearsal passed

forge test
222 passed, 0 failed
```

已验证的重点：

- 只有授权 Hook 可以调用 adapter。
- 非 allowlist 的手续费资产会回滚。
- 已禁用的 router 会回滚。
- `tokenIn == USDC` 时走直通逻辑，不做外部 swap。
- 非 USDC 手续费资产通过 Mock router 换成 USDC。
- adapter 使用 Hook 的 USDC 余额差作为实际输出，不信任 router 返回值。
- 实际 USDC 输出小于 `minUSDTOut` 时回滚。
- router 失败或把 USDC 发错接收方时回滚。
- adapter 暂停后不能换币。
- 非 owner 不能改配置。

## 7. 当前不做

- 不把 2% 预算部分强制换成 USDC。
- 不允许任意 token 任意路由。
- 不接真实资金测试。
- 不把真实 adapter 和大规模命名重构放在同一轮。
- 不在没有 `minUSDTOut` 的情况下执行换币。

## 8. 下一步

测试版 USDC adapter 合约草图、Mock 路由器测试、本地预演脚本、`Create2HookDeployer` Base Sepolia 部署脚本、第一次小额广播、曲线核心 + `TestnetUsdcAdapter` 第二次小额广播、CREATE2 salt 搜索、参数预检、Hook dry-run、Hook 小额广播和 Hook 绑定 dry-run 均已完成。`CREATE2_DEPLOYER` 已固定为 `0xE5Df76A1DF2e959C70c8b7591754a3a2a542Fb6D`，`HOOK_DEPLOYED=0xF612828Ba9dE01CF16Fae2D8EE187B0cA59100Cc`。

当前状态：Hook 已部署并复核通过，绑定 dry-run、广播和链上复核也已通过。真实链上 `TestnetUsdcAdapter.authorizedHook` 和 `SunCurve.moonAMM` 都已经指向 Hook。受控 `MOON/USDC` 测试池 `poolId=0xfbb4ccec5e3fda3a97b9e2619e9e90588ad5e444bdb3d488e921a3192c42dd55` 已 dry-run 通过，并已在用户明确批准后完成链上白名单广播：`0x9f219d37f1a72dc6229df79217ed953f1e6ff01ed1f4d958854fe432616ed325`。初始化 dry-run 和广播也已通过：`0x72c93bb0a5bdb540b2e696eaff50614e4571cfe1dbe3bb64494ec9719cdc8310`，链上复核 `slot0.tick=276300`。极小额流动性/交换演练准备 dry-run 已通过，测试 USDC 已到账，资产/Permit2 授权和报价预检均已通过：

```text
真实 Base fork / Base Sepolia 演练前复核
  -> 先复核已部署 Create2HookDeployer owner 和 chainId
  -> 使用测试 token
  -> 使用 TestnetUsdcAdapter
  -> 使用已部署并复核的 HOOK_DEPLOYED
  -> 已 dry-run adapter 授权和 SunCurve moonAMM 绑定
  -> 绑定广播已完成并链上复核
  -> 极小额演练准备 dry-run 已完成，资产/授权准备 dry-run 也已完成
  -> 当前先给 REHEARSAL_ACTOR 准备至少 1.605 个 Base Sepolia 测试 USDC，建议 2 个
  -> 暂未广播真实流动性或 swap
  -> 不连接真实主网资金
```

等 fork 和 Base Sepolia 测试 token 演练稳定后，再评估是否接真实 Uniswap v4 路由器；这一步之前仍不接触真实资金。

