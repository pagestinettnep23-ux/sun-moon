# Base + Uniswap v4 技术路线

更新日期：2026-05-15

本文档记录 SUN/MOON 阶段 2 之后的第一条真实 DEX 技术路线。当前结论是：优先选择 Base 生态上的 Uniswap v4，但只进入本地 fork / Base Sepolia 技术预研，不部署 Base 主网，不接触真实资金。

2026-05-16 主网前方向更新：SUN/MOON 都保持自由转账，不再从 token 合约层禁止市场自行创建 AMM 池；项目支持路径改为两个 Uniswap v4 Hook 池：`SUN/USDC` swap 收 `2% USDC`，`MOON/USDC` swap 收 `5% USDC`。第三方池不代表协议价格，也不保证触发项目费用和 SUN 曲线回灌。

## 1. 路线结论

第一条真实 DEX 路线确定为：

```text
Base
  -> Uniswap v4
  -> 先 Base Sepolia 或 Base fork
  -> 再考虑测试网部署
  -> 最后才评估 Base 主网
```

选择原因：

- Uniswap v4 官方已部署到 Base 主网和 Base Sepolia。
- Base 交易成本较低，适合 Hook 测试和反复验证。
- Uniswap v4 Hook 文档、部署地址和工具链相对成熟。
- 相比 PancakeSwap Infinity，先走 Uniswap v4 可以减少一套 Hook 权限模型差异。

当前仍然禁止：

- 不部署 Base 主网。
- 不接真实 USDC。
- 不接触真实资金。
- 不把 AMM 做成用户主入口。
- 不跳过站内路径 `USDC -> SUN -> MOON` 和 `MOON -> SUN -> USDC`。

## 2. 官方资料核对

资料来源：

- Uniswap v4 Deployments: https://developers.uniswap.org/docs/protocols/v4/deployments
- Uniswap v4 Hook Deployment: https://developers.uniswap.org/docs/protocols/v4/guides/hooks/hook-deployment
- Base Connecting to Base: https://docs.base.org/base-chain/quickstart/connecting-to-base

Base 网络信息：

| 网络 | Chain ID | RPC | 说明 |
| --- | ---: | --- | --- |
| Base Mainnet | 8453 | `https://mainnet.base.org` | 官方公共 RPC 有限流，不适合作为生产唯一 RPC |
| Base Sepolia | 84532 | `https://sepolia.base.org` | 优先用于测试网预研 |

## 3. Uniswap v4 官方地址

### 3.1 Base Mainnet

| 合约 | 地址 |
| --- | --- |
| PoolManager | `0x498581ff718922c3f8e6a244956af099b2652b2b` |
| PositionManager | `0x7c5f5a4bbd8fd63184577525326123b519429bdc` |
| Quoter | `0x0d5e0f971ed27fbff6c2837bf31316121532048d` |
| StateView | `0xa3c0c9b65bad0b08107aa264b0f3db444b867a71` |
| Universal Router | `0x6ff5693b99212da76ad316178a184ab56d299b43` |
| Universal Router 2.1.1 | `0xfdf682f51fe81aa4898f0ae2163d8a55c127fbc7` |
| USDC | `0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913` |
| Permit2 | `0x000000000022D473030F116dDEE9F6B43aC78BA3` |

### 3.2 Base Sepolia

| 合约 | 地址 |
| --- | --- |
| PoolManager | `0x05E73354cFDd6745C338b50BcFDfA3Aa6fA03408` |
| Universal Router | `0x492e6456d9528771018deb9e87ef7750ef184104` |
| PositionManager | `0x4b2c77d209d3405f41a037ec6c77f7f5b8e2ca80` |
| StateView | `0x571291b572ed32ce6751a2cb2486ebee8defb9b4` |
| Quoter | `0x4a6513c898fe1b2d0e78d3b0e0a4a151589b1cba` |
| PoolSwapTest | `0x8b5bcc363dde2614281ad875bad385e0a785d3b9` |
| PoolModifyLiquidityTest | `0x37429cd17cb1454c34e7f50b09725202fd533039` |
| USDC | `0x036CbD53842c5426634e7929541eC2318f3dCF7e` |
| Permit2 | `0x000000000022D473030F116dDEE9F6B43aC78BA3` |

### 3.3 稳定币选择

Base 真实路线稳定币确定使用 USDC：

- 第一阶段官方核心池收敛为 `MOON/USDC`。历史文档和测试中出现的 `SUN/USDC` 仅作为早期原型背景，不进入主网官方池计划。
- MOON AMM 生产级 5% 费用适用于任何包含 MOON 的 AMM 交易对。
- 费用资产固定为交易对里的非 MOON 侧资产；如果非 MOON 侧是 USDC，则可直接注入 SUN 曲线；如果非 MOON 侧不是 USDC，则需要先通过适配器换成 USDC。
- 当前合约和测试里仍有 `USDT`、`MockUSDT`、`minUSDTOut`、`injectUSDT()` 等历史命名；阶段 2 暂不大规模重命名，避免影响已通过的测试。进入 Base 真实路线时，这些参数位置应配置为 USDC 地址和 USDC 数量。
- 后续如果要改名，应单独做一轮机械重命名和全量回归测试。

## 4. Hook 权限重点

Uniswap v4 Hook 权限由 Hook 合约地址的低位 bit 表示。也就是说，合约不是随便部署到任意地址就能被 PoolManager 正确调用。

当前 SUN/MOON Mock 逻辑需要映射到真实 v4 Hook 时，至少要确认：

| 当前 Mock 逻辑 | 可能对应的 v4 Hook 回调 | 说明 |
| --- | --- | --- |
| `SunAmmGuardHook.beforeAddLiquidity()` | `beforeAddLiquidity` | 历史原型；主网不部署 SUN AMM 守卫 |
| `MoonAmmFeeHook.afterSwap()` | `beforeSwap` / `afterSwap` return delta | 用于 MOON AMM 费用拦截和路由 |
| `AmmSwapAdapter.swapFeeAssetToUSDT()` | Hook 内部或后续 FeeRouter 调用 | 需要继续评估是否应在交易内立刻换币 |

下一步必须验证：

- Hook 地址权限 bit 是否与声明回调一致。
- 主网部署计划必须确认 `SunToken` 已经在转账层限制 SUN 流入 AMM / router / PoolManager / pair / 任意非协议地址。
- MOON 5% AMM 费用已确认优先使用 v4 原生 return delta：指定币种侧用 `beforeSwap`，非指定币种侧用 `afterSwap`。
- `SunCurve.injectUSDT()` 在 Base 真实路线中实际注入 USDC；是否应该在 swap 同交易内完成，还是先累计费用再由 keeper 处理。

## 5. 推荐执行步骤

### 第一步：只做依赖和接口预研

- 研究 `v4-core`、`v4-periphery` 当前版本。
- 新增最小 v4 Hook 适配草图，不替换现有 Mock 合约。
- 确认 Foundry 能编译 v4 Hook 基础依赖。

当前依赖状态：

- `remappings.txt` 已预留 `@uniswap/v4-core/` 和 `@uniswap/v4-periphery/`。
- `lib/v4-core` 已安装，`package.json` 显示版本为 `1.0.2`。
- `lib/v4-periphery` 已安装，`package.json` 显示版本为 `1.0.4`。
- `lib/solmate` 已安装，用于满足 `v4-core` 的 `solmate/` 导入。
- `lib/permit2` 已安装，用于满足 `v4-periphery` 的 `permit2/` 导入。
- 当前是 zip 下载方式安装，不是 git submodule。由于 `.gitignore` 忽略 `lib/`，依赖目录不会自动进入 git 状态。
- `forge install` 的 submodule 模式仍然因为本机 Git `git-sh-setup` 找不到而不可用。

已执行并通过：

```text
forge test --match-path test/hooks/base/BaseV4HookProbe.t.sol
5 passed, 0 failed

forge test --match-path test/hooks/base/BaseV4Addresses.t.sol
6 passed, 0 failed

forge test --match-path test/hooks/base/BaseV4PoolManagerProbe.t.sol
2 passed, 0 failed

forge test --match-path test/hooks/base/BaseV4ForkPoolManagerProbe.t.sol
1 passed, 0 failed

forge test --match-path test/hooks/base/BaseV4Addresses.t.sol --fork-url https://sepolia.base.org
6 passed, 0 failed

forge test --match-path test/hooks/base/BaseV4Addresses.t.sol --fork-url https://mainnet.base.org
6 passed, 0 failed

forge test --match-path test/hooks/base/BaseV4ForkPoolManagerProbe.t.sol --fork-url https://sepolia.base.org
1 passed, 0 failed

forge test --match-path test/hooks/base/BaseV4ForkPoolManagerProbe.t.sol --fork-url https://mainnet.base.org
1 passed, 0 failed

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
222 passed, 0 failed
```

如果后续希望把依赖作为 git submodule 管理，需要先修复本机 Git submodule 脚本问题。

### 第二步：Base Sepolia 最小 Hook 本地测试

- 使用 Base Sepolia 官方 v4 地址作为配置。
- 使用 Mock token，不使用真实 USDC。
- 先验证 Hook 地址权限和 PoolManager 回调能否跑通。当前已新增最小编译探针 `contracts/hooks/base/BaseV4HookProbe.sol`。
- 已新增 `contracts/hooks/base/BaseV4Addresses.sol`，记录 Base Mainnet / Base Sepolia 官方 v4 地址。
- 已新增 `test/hooks/base/BaseV4Addresses.t.sol`，支持本地常量检查和 fork 只读代码检查。
- 已新增 `test/hooks/base/BaseV4PoolManagerProbe.t.sol`，验证本地真实 `PoolManager` 会拒绝无权限 bit 的 Hook 地址，并接受带权限 bit 的 Hook 地址。
- 已新增 `test/hooks/base/BaseV4ForkPoolManagerProbe.t.sol`，验证 Base Sepolia / Base Mainnet fork 上官方 `PoolManager.initialize()` 可以触发最小 Hook callback。
- 已新增 `contracts/hooks/base/BaseSunAmmGuardV4Hook.sol` 和 `test/hooks/base/BaseSunAmmGuardV4Hook.t.sol`，验证 SUN 加池守卫可以映射到 v4 `beforeAddLiquidity`；该路径现在仅作为历史原型，不进入主网部署计划。
- 不接 SUN/MOON 真实资金逻辑。

### 第三步：Base fork 测试

- Fork Base Mainnet，只读官方 v4 合约状态。
- 部署本地测试 token 和测试 Hook。
- 验证池子初始化、加池、swap、Hook 回调触发。
- 所有测试仍用本地/fork 资产，不使用真实资金。

### 第四步：适配 SUN/MOON Mock 逻辑

- `SunAmmGuardHook` 到真实 v4 callback 的映射已作为历史原型完成；主网新决策是不部署 SUN AMM guard。
- 把 `MoonAmmFeeHook` 的费用规则映射到真实 v4 callback 或 custom accounting。当前已完成第一版 `BaseMoonAmmFeeV4Hook`：使用 v4 `afterSwap` + `hookData` 的 Mock 测试路径验证 5% 费用规则。
- 保留站内 Mint/Burn 主路径，不做一键 AMM 主入口。

## 6. `SunAmmGuardHook` 到 v4 `beforeAddLiquidity` 的适配

本节是历史技术原型记录。2026-05-15 之后，主网官方不做 SUN AMM 流动性，不再需要 SUN 首次加池地址，也不把 `SunAmmGuardHook` / `BaseSunAmmGuardV4Hook` 放入主网部署计划。

当前 Mock 版接口：

```solidity
beforeAddLiquidity(
    address liquidityProvider,
    bytes32 poolId,
    address token0,
    address token1
) returns (bytes4)
```

真实 Uniswap v4 接口：

```solidity
beforeAddLiquidity(
    address sender,
    PoolKey calldata key,
    ModifyLiquidityParams calldata params,
    bytes calldata hookData
) returns (bytes4)
```

字段映射：

| Mock 字段 | v4 来源 | 适配说明 |
| --- | --- | --- |
| `liquidityProvider` | 第一版适配层使用 `sender` | 如果通过 `PositionManager` 加池，`sender` 可能是 periphery 合约；生产方案需要 wrapper、签名或受控执行器进一步确认真实 LP |
| `poolId` | `PoolId.unwrap(key.toId())` | `PoolId` 由完整 `PoolKey` 计算，包含币种、费率、tickSpacing 和 hook 地址 |
| `token0` | `Currency.unwrap(key.currency0)` | v4 的 currency 已排序；原生 ETH 是 `address(0)`，不能当作 SUN |
| `token1` | `Currency.unwrap(key.currency1)` | 只要任一 currency 等于 `sunToken`，就进入 SUN 加池守卫 |
| `hookCaller` | `msg.sender == poolManager` | 真实 v4 里应固定为官方 `PoolManager`，不再用任意 Mock caller |
| `allowedSunPools` | `allowedSunPools[poolId]` | 仍按池子 ID 白名单，而不是只按 token pair 白名单 |
| `paused` | Hook 本地状态 | 保留紧急暂停；暂停时所有 SUN 池加池回滚 |
| `sunAmmUnlocked` | Hook 本地状态 | 第一次有效 SUN 加池触发后置为 `true` |

当前已落地的最小适配合约：

- `contracts/hooks/base/BaseSunAmmGuardV4Hook.sol`
- `test/hooks/base/BaseSunAmmGuardV4Hook.t.sol`

核心逻辑：

```solidity
using PoolIdLibrary for PoolKey;

function beforeAddLiquidity(
    address sender,
    PoolKey calldata key,
    ModifyLiquidityParams calldata,
    bytes calldata
) external onlyPoolManager returns (bytes4) {
    PoolKey memory poolKey = key;
    bytes32 poolId = PoolId.unwrap(poolKey.toId());
    address token0 = Currency.unwrap(key.currency0);
    address token1 = Currency.unwrap(key.currency1);

    return sunGuard.beforeAddLiquidity(sender, poolId, token0, token1);
}
```

真实适配注意事项：

- Hook 地址只需要 `BEFORE_ADD_LIQUIDITY_FLAG` 就能承载 SUN 加池守卫；如果 SUN 守卫和 MOON 费用放在同一个 Hook 合约，还需要同时满足 `AFTER_SWAP_FLAG` 或后续选定的 swap 权限。
- `vm.etch` 只适合测试权限 bit，不是部署方案。真实部署需要 `CREATE2` 地址挖矿，让 Hook 地址低位 bit 匹配启用的回调。
- 如果前端或脚本通过官方 `PositionManager` 加池，v4 传入的 `sender` 可能不是用户钱包。第一版真实测试建议只允许项目自有的首次加池执行器完成首池；如果要识别 EOA，需要在 `hookData` 中传入地址和签名，并在 Hook 内验证。
- `hookData` 来自调用方，不能单独作为权限来源。只有经过签名、白名单执行器或受控 wrapper 验证后，才能用于还原最终流动性提供者。
- `params.salt` 用于头寸标识，不应用作池子白名单 ID。
- 如果后续加池流程在 `beforeAddLiquidity` 之后失败，整个交易会回滚，`sunAmmUnlocked = true` 也会随之回滚；因此可以在 `beforeAddLiquidity` 中设置解锁状态。

第一批真实 v4 测试建议：

| 测试项 | 预期 |
| --- | --- |
| 非 SUN 池调用 `beforeAddLiquidity` | 直接返回 selector，不改变 `sunAmmUnlocked` |
| SUN 池未在白名单 | 回滚 `SunPoolNotAllowed(poolId)` |
| SUN 池未解锁且非首次执行器加池 | 回滚 `SunAmmLocked(liquidityProvider)` |
| SUN 池未解锁且首次执行器加池 | 返回 selector，设置 `sunAmmUnlocked = true` |
| SUN 池已解锁但池子不在白名单 | 仍然回滚，避免未知 SUN 池绕过 |
| 暂停状态下 SUN 池加池 | 回滚 `HookPaused()` |
| 非 `PoolManager` 调用 Hook | 回滚 `NotPoolManager()` |

## 7. `BaseMoonAmmFeeV4Hook` v2 return delta 适配

当前已落地的 Base v4 生产方向合约和测试：

- `contracts/hooks/base/BaseMoonAmmFeeV4Hook.sol`
- `test/hooks/base/BaseMoonAmmFeeV4Hook.t.sol`

当前 v2 映射：

| 字段 | v4 来源 | 适配说明 |
| --- | --- | --- |
| `poolId` | `PoolId.unwrap(key.toId())` | 使用完整 v4 `PoolKey` 计算池子身份 |
| `token0/token1` | `Currency.unwrap(key.currency0/1)` | 用于判断是否涉及 MOON |
| `feeToken` | 交易对里的非 MOON 侧资产 | 不再由前端或 `hookData` 指定 |
| `feeBaseAmount` | `amountSpecified` 或实际 `swapDelta` | specified currency 在 `beforeSwap` 收，unspecified currency 在 `afterSwap` 收 |
| `minUSDTOut` | `hookData` | 仍作为滑点保护参数，不允许为 0 |

已验证：

- 非 MOON 池不会解析 `hookData`，也不会收取费用。
- MOON 任意交易对 5% 费用可通过 v4 return delta 收取。
- specified fee token 路径使用 `beforeSwap` + specified return delta。
- unspecified fee token 路径使用 `afterSwap` + unspecified return delta。
- 3% 费用换成 USDC 后注入 `SunCurve.injectUSDT()`。
- 2% 费用保留为原手续费资产，直接进入协议预算钱包。
- 非 USDC 手续费资产只有 3% 飞轮部分会通过 Mock `AmmSwapAdapter` 转换为 MockUSDC 后注入 SUN 曲线。
- 未允许 MOON 池、空 `hookData`、`minUSDTOut = 0`、暂停、非 PoolManager 调用都会回滚。

重要限制：

- 当前仍使用 Mock `AmmSwapAdapter`，没有接真实外部 DEX 路由器。
- `hookData` 现在只承载 `minUSDTOut`，不再承载 `feeToken` 或 `feeBaseAmount`。
- 已新增 `contracts/hooks/base/BaseV4HookAddressMiner.sol` 和 `script/FindBaseMoonAmmFeeV4HookSalt.s.sol`，用于本地预检查 CREATE2 salt 和 Hook 权限 bit。
- 已新增 `test/hooks/base/BaseMoonAmmFeeV4HookSecurity.t.sol`，用恶意 fee token 尝试嵌套 swap 重入，确认外部调用路径不会破坏状态。
- 已新增 `contracts/hooks/base/BaseDeploymentPreflight.sol` 和 `script/CheckBaseSepoliaDeploymentParams.s.sol`，用于进入测试网前检查官方地址、项目地址和预测 Hook 权限 bit。
- 已新增 `docs/Base-Sepolia-测试网前部署参数清单.md` 和 `docs/Base-USDC-Adapter方案.md`。
- 已新增 `contracts/hooks/TestnetUsdcAdapter.sol` 和 `test/hooks/TestnetUsdcAdapter.t.sol`，用于本地验证测试版 USDC adapter 的 allowlist、余额差、滑点和权限模型。
- 已新增 `contracts/mocks/MockUsdcSwapRouter.sol`，作为可复用受控 Mock USDC 路由器。
- 已新增 `script/RehearseBaseSepoliaAdapter.s.sol` 和 `test/hooks/base/BaseSepoliaAdapterRehearsal.t.sol`，用于本地预演测试 token、Mock 路由器、非 USDC 路由和 USDC 直通路径。
- 已新增 `script/PrepareBaseSepoliaCreate2Deployer.s.sol` 和 `test/hooks/base/BaseSepoliaCreate2DeployerPreparation.t.sol`，用于准备 Base Sepolia `Create2HookDeployer` 部署，并拒绝 Base 主网。
- Base Sepolia 第一次小额广播已完成：`CREATE2_DEPLOYER=0xE5Df76A1DF2e959C70c8b7591754a3a2a542Fb6D`，owner 已链上复核。
- 已新增 `script/PrepareBaseSepoliaControlledMoonPool.s.sol` 和 `test/hooks/base/BaseSepoliaControlledMoonPoolPreparation.t.sol`，用于受控 `MOON/USDC` 测试池 `PoolKey -> poolId` dry-run。
- 受控 `MOON/USDC` 测试池 dry-run 已通过：`poolId=0xfbb4ccec5e3fda3a97b9e2619e9e90588ad5e444bdb3d488e921a3192c42dd55`；链上白名单已广播并复核 `allowedMoonPools(poolId)=true`。
- 受控 `MOON/USDC` 测试池初始化 dry-run 和广播均已完成：`MOON_USDC_INITIALIZE_TX=0x72c93bb0a5bdb540b2e696eaff50614e4571cfe1dbe3bb64494ec9719cdc8310`，链上复核 `slot0.tick=276300`、`lpFee=3000`。
- 进入下一轮真实 Base fork / Base Sepolia 演练前还需要确认 `minUSDTOut` 生成方式、部署参数记录、受控路由演练方式和极小额流动性/交换测试范围。

## 8. MOON 任意交易对生产级费用来源策略

当前决策：

- Base 真实路线中，只要 AMM 交易对包含 MOON，就收取 5% MOON AMM 费用。
- 费用资产固定为交易对里的非 MOON 侧资产，例如 `MOON/USDC` 收 USDC，`MOON/WETH` 收 WETH，`MOON/SUN` 收 SUN。
- 买入和卖出都不从 MOON 侧扣费，避免额外影响 MOON 曲线供应、用户余额和 AMM 价格路径。
- 费用基数使用实际非 MOON 资产输入或输出金额，而不是前端传入的任意金额。
- 已新增 `contracts/hooks/base/BaseMoonAmmFeePolicy.sol` 和 `test/hooks/base/BaseMoonAmmFeePolicy.t.sol`，用纯逻辑测试锁定四种 swap 场景、v4 return delta 收取方式，并额外覆盖 `MOON/WETH`。

四种 v4 swap 场景：

| 场景 | v4 参数形态 | 费用基数来源 | 建议处理阶段 | v4 收取方式 |
| --- | --- | --- | --- | --- |
| 用固定数量非 MOON 资产买 MOON | exact-in，非 MOON 资产是 input / specified | `abs(amountSpecified)` | `beforeSwap` | specified return delta |
| 买固定数量 MOON，实际支付非 MOON 资产 | exact-out，非 MOON 资产是 input / unspecified | `swapDelta` 中实际非 MOON input | `afterSwap` | unspecified return delta |
| 卖固定数量 MOON，收到非 MOON 资产 | exact-in，非 MOON 资产是 output / unspecified | `swapDelta` 中实际非 MOON output | `afterSwap` | unspecified return delta |
| 卖 MOON 换固定数量非 MOON 资产 | exact-out，非 MOON 资产是 output / specified | `abs(amountSpecified)` | `beforeSwap` | specified return delta |

当前策略结论：

- 只要非 MOON 费用资产是 v4 的 specified currency，就可以使用可信的 `amountSpecified`，在 `beforeSwap` 中通过 specified return delta 收取。
- 如果非 MOON 费用资产是 v4 的 unspecified currency，则必须等 `afterSwap` 的实际 `swapDelta`，再通过 unspecified return delta 收取。
- 因为四种方向都能落到 v4 原生 return delta，费用截留本身不建议以外部 `transferFrom` 作为主路径，也暂不需要为了单纯收取 5% 费用引入 custom accounting。
- 生产级 Hook 地址权限需要同时包含 `BEFORE_SWAP_FLAG`、`BEFORE_SWAP_RETURNS_DELTA_FLAG`、`AFTER_SWAP_FLAG` 和 `AFTER_SWAP_RETURNS_DELTA_FLAG`。
- 3% 飞轮部分最终仍应转换为 USDC 并注入 SUN 曲线；如果费用资产不是 USDC，则必须经过适配器换成 USDC。
- 2% 协议预算部分保留原手续费资产，不额外换成 USDC。例如 `MOON/WETH` 的预算钱包收到 WETH，`MOON/SUN` 的预算钱包收到 SUN。
- 已新增 `test/hooks/base/BaseMoonAmmFeeReturnDeltaSettlement.t.sol`，用本地真实 `PoolManager`、`PoolSwapTest` 和 `PoolModifyLiquidityTest` 跑通四种 swap 方向，确认 specified / unspecified return delta 都能把 5% 费用实际结算到 Hook 地址。
- 已新增 `test/hooks/base/BaseMoonAmmFeeReturnDeltaRoute.t.sol`，在本地真实 `PoolManager` return delta 收到 5% 费用后，继续验证 3% 走 Mock adapter / USDC 注入 `SunCurve.injectUSDT()`，2% 保留原手续费资产进入协议预算钱包。
- `BaseMoonAmmFeeV4Hook` 已升级为 v2：正式合约直接使用 `beforeSwap` / `afterSwap` return delta 收费，并在同一笔交易内完成 3% 注入和 2% 预算分配。

## 9. 当前未解决问题

- SUN 首次加池路径不再需要决策；主网官方永久不做 SUN AMM 流动性。
- MOON 任意交易对费用收取方式已确认优先用 v4 return delta；`BaseMoonAmmFeeV4Hook` v2、CREATE2 地址预检查、恶意 fee token 重入测试、测试版 USDC adapter 测试、本地 adapter 预演、`Create2HookDeployer` 第一次小额广播、曲线核心 + `TestnetUsdcAdapter` 第二次小额广播、CREATE2 salt 搜索、参数预检、Hook Base Sepolia dry-run 和 Hook 小额广播均已通过。当前停止点是 adapter 授权和 `SunCurve.moonAMM` 仍未切到真实 Hook；不接触主网资金。
- `minUSDTOut` 由前端传入、管理员配置，还是由链上报价/keeper 生成。
- 是否需要把 3% 费用先进入 FeeRouter，再由 keeper 批量换成 USDC。
- 是否保留代码层 `USDT` 历史命名，还是在进入测试网前统一重命名为 stable/USDC。

## 10. 验收标准

进入任何真实资金部署前，至少要满足：

- [x] `v4-core` 和 `v4-periphery` 依赖安装完成。
- [x] Foundry 可以编译最小 Uniswap v4 Hook 合约。
- [x] 最小 Uniswap v4 Hook 探针测试通过。
- [x] Base Sepolia 和 Base Mainnet 官方地址 fork 只读检查通过。
- [x] Base Sepolia 和 Base Mainnet fork 的官方 PoolManager 最小 Hook callback 测试通过。
- [x] Hook 地址权限 bit 验证通过。
- [x] `SunAmmGuardHook` 规则到 v4 `beforeAddLiquidity` 的适配草图完成；现作为历史原型保留，不进入主网。
- [x] `PoolManager`、`PositionManager`、`Universal Router` 地址配置从官方文档核对。
- [x] SUN AMM 首次加池守卫在 v4 callback 适配层测试通过；现作为历史原型保留，不进入主网。
- [x] MOON AMM 5% 费用路径在 `BaseMoonAmmFeeV4Hook` v2 return delta 适配层测试通过。
- [x] MOON 任意交易对生产级费用来源策略确认：固定从非 MOON 侧收取，四种 swap 方向和 `MOON/WETH` 已用纯逻辑测试覆盖。
- [x] MOON 任意交易对费用收取方式确认：优先使用 v4 return delta，不把外部 transfer 作为主路径。
- [x] MOON 任意交易对费用在本地真实 `PoolManager` return delta 结算原型中通过：4 passed，0 failed。
- [x] MOON return delta 收到 5% 费用后的 Mock 路由闭环通过：3% 转 USDC 并注入 SUN 曲线，2% 保留原手续费资产进入预算钱包。
- [x] `BaseMoonAmmFeeV4Hook.t.sol` v2 测试通过：15 passed，0 failed。
- [x] `BaseV4HookAddressMinerTest` CREATE2 权限位预检查通过：3 passed，0 failed。
- [x] `BaseMoonAmmFeeV4HookSecurity.t.sol` 恶意 fee token 重入测试通过：1 passed，0 failed。
- [x] `BaseDeploymentPreflight.t.sol` Base Sepolia 参数预检测试通过：6 passed，0 failed。
- [x] `TestnetUsdcAdapter.t.sol` 测试版 USDC adapter 测试通过：15 passed，0 failed。
- [x] `BaseMoonAmmFeeV4Hook.t.sol` 已覆盖调用测试版 USDC adapter 的集成路径：16 passed，0 failed。
- [x] `BaseSepoliaAdapterRehearsal.t.sol` 本地 adapter 预演测试通过：1 passed，0 failed。
- [x] `RehearseBaseSepoliaAdapter.s.sol` 本地 adapter 预演脚本通过。
- 所有失败路径测试通过：错误池子、未授权、暂停、`minUSDTOut` 不满足、零地址。
- [x] 本地 `Create2HookDeployer` 草图和测试已完成。
- [x] 本地 `RehearseCreate2HookDeployer.s.sol` 预演脚本已完成。
- [x] Base Sepolia `Create2HookDeployer` 部署脚本、安全测试和第一次小额广播已完成：准备测试 3 passed，0 failed。
- [x] Base Sepolia 曲线核心和 `TestnetUsdcAdapter` 第二次小额广播已完成并链上复核。
- [x] Hook 小额广播准备脚本、回归测试和 Base Sepolia dry-run 已通过：准备测试 1 passed，0 failed。
- [x] Hook 小额广播已完成并链上复核，实际地址等于 CREATE2 预测地址。
- [x] Hook 权限绑定准备脚本、回归测试和 Base Sepolia dry-run 已通过：准备测试 1 passed，0 failed。
- [x] 受控 `MOON/USDC` 测试池 `poolId` dry-run 已通过：`0xfbb4ccec5e3fda3a97b9e2619e9e90588ad5e444bdb3d488e921a3192c42dd55`。
- [x] 受控 `MOON/USDC` 测试池初始化 dry-run 已通过。
- [x] 全量 Foundry 测试继续通过：222 passed，0 failed。
- 文档和安全清单同步更新。

