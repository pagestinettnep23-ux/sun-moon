# Base Sepolia CREATE2 Deployer 选择说明

更新日期：2026-05-14

本文档给非技术成员和后续开发者说明：`CREATE2_DEPLOYER` 是什么，为什么它会影响 Uniswap v4 Hook 地址预测，以及 SUN/MOON 在 Base Sepolia 受控演练中应该如何选择它。当前已完成第一次 Base Sepolia 小额广播，只部署项目自控测试版 CREATE2 工厂；仍不部署主网，不接真实资金。

## 1. 一句话解释

`CREATE2_DEPLOYER` 是实际执行 `CREATE2` 部署 Hook 的合约或部署器地址。

它不是 `HOOK_OWNER`，也不是预算钱包。它像一台固定的施工机器：同一份 Hook 代码、同一组构造参数、同一个 salt，只有通过同一个 `CREATE2_DEPLOYER` 部署，才会得到同一个预测 Hook 地址。

## 2. 为什么它重要

Uniswap v4 Hook 地址本身带权限信息。项目当前的 `BaseMoonAmmFeeV4Hook` v2 需要的低 14 位权限 bit 是：

```text
204
```

因此 Hook 部署前必须先预测地址：

```text
PREDICTED_HOOK = hash(CREATE2_DEPLOYER, HOOK_SALT, BaseMoonAmmFeeV4Hook init code)
```

如果 `CREATE2_DEPLOYER` 换了，`PREDICTED_HOOK` 就会变。即使 Hook 代码、构造参数和 salt 都不变，预测地址也会变。

所以：

- 预测时用的 `CREATE2_DEPLOYER` 必须等于真实部署 Hook 时用的 deployer。
- `HOOK_SALT` 只能和同一组构造参数、同一个 `CREATE2_DEPLOYER` 一起使用。
- 换了 deployer、合约地址、owner、adapter、预算钱包、PoolManager 或 USDC，必须重新搜索 salt。

## 3. 当前已经有的地址不是 CREATE2_DEPLOYER

目前已记录的 3 个测试钱包公开地址：

```text
HOOK_OWNER=0x6E22b2e6fFAA30Fe75B71d53d1eC469b4e97A986
PROTOCOL_BUDGET_ADDRESS=0x277ba3Cf597CdAaF958C301db3cF6a631F793039
DEPLOYER_ADDRESS=0x2F6E887c6058deE520f9468a1022E3480A6334D3
```

它们的用途分别是：

- `HOOK_OWNER`：测试管理员。
- `PROTOCOL_BUDGET_ADDRESS`：测试预算接收钱包。
- `DEPLOYER_ADDRESS`：未来测试网广播时发交易的钱包公开地址。

这些地址不能自动当成 `CREATE2_DEPLOYER`。如果未来由某个 CREATE2 工厂合约部署 Hook，那么 `CREATE2_DEPLOYER` 应该是那个工厂合约地址，而不是发交易的钱包地址。

## 4. 可选方案

| 方案 | 做法 | 优点 | 风险/限制 | 当前建议 |
| --- | --- | --- | --- | --- |
| A. 本地模拟 deployer | 只在本地或脚本里用示例地址搜索 salt | 最安全，不上链 | 不能作为真实测试网部署地址 | 继续保留 |
| B. 项目自控测试版 CREATE2 工厂 | 先部署一个最小测试版 CREATE2 工厂，再用它部署 Hook | 可控、可复核、适合演练 | 需要额外一次测试网广播，工厂地址也要记录 | 已采用，Base Sepolia 已部署 |
| C. 公共 CREATE2 deployer | 使用公开部署器地址部署 Hook | 可能少部署一个工厂 | 必须确认 Base Sepolia 上存在、代码可信、调用方式匹配 | 暂不默认采用 |
| D. 直接用普通钱包部署 Hook | 不用 CREATE2，只用普通 `new`/CREATE | 简单 | 无法提前挖 Hook 权限 bit，通常不适合 v4 Hook | 不采用 |

## 5. 当前推荐

当前已按保守路线推进：

1. 不立刻选择公共 deployer。
2. 不把 `DEPLOYER_ADDRESS` 直接填成 `CREATE2_DEPLOYER`。
3. 已新增本地 `Create2HookDeployer` 草图、测试和完整预演脚本，只做本地验证。
4. 已新增 `script/PrepareBaseSepoliaCreate2Deployer.s.sol`，并加入 Base Sepolia 确认变量和 deployer 地址保护。
5. Base Sepolia RPC dry-run 已完成，模拟发送者为 `DEPLOYER_ADDRESS`。
6. 项目自控测试版 CREATE2 工厂已部署到 Base Sepolia：

```text
CREATE2_DEPLOYER=0xE5Df76A1DF2e959C70c8b7591754a3a2a542Fb6D
CREATE2_DEPLOYER_OWNER=0x6E22b2e6fFAA30Fe75B71d53d1eC469b4e97A986
CREATE2_DEPLOYER_TX=0x87c9033101907c8e24aa13714154a212431a677837027191b023c00e70909596
```

链上复核结果：代码非空，`owner()` 返回 `0x6E22b2e6fFAA30Fe75B71d53d1eC469b4e97A986`。后续再用真实测试网构造参数跑：

```powershell
forge script script/FindBaseMoonAmmFeeV4HookSalt.s.sol
forge script script/CheckBaseSepoliaDeploymentParams.s.sol
```

## 6. 不能做的事

以下情况必须停止：

- 不知道 `CREATE2_DEPLOYER` 对应什么代码。
- 预测地址用的是 A deployer，真实部署却用 B deployer。
- `HOOK_SALT` 来自旧构造参数。
- `PREDICTED_HOOK` 的低 14 位权限 bit 不是 `204`。
- 实际部署 Hook 地址和 `PREDICTED_HOOK` 不一致。
- 需要私钥、助记词或完整 RPC key 才能继续。
- 准备连接 Base 主网。

## 7. 给新手看的顺序

可以把它理解成这样：

1. 先准备测试管理员、预算钱包、部署钱包公开地址。
2. 再决定用哪台“施工机器”部署 Hook，这台机器就是 `CREATE2_DEPLOYER`。
3. 用这台机器的地址去算 Hook 未来会出现在哪里。
4. 算出来的地址权限 bit 必须正确。
5. 以后真正部署 Hook 时，必须还用同一台机器。

当前第 1 步到 Hook 小额广播已经完成：`CREATE2_DEPLOYER` 已固定为 `0xE5Df76A1DF2e959C70c8b7591754a3a2a542Fb6D`，Hook 已通过 CREATE2 部署到 `0xF612828Ba9dE01CF16Fae2D8EE187B0cA59100Cc`。adapter 授权和 `SunCurve.moonAMM` 绑定 dry-run、广播和链上复核均已通过。受控 `MOON/USDC` 测试池 `poolId` dry-run、白名单广播、初始化 dry-run、初始化广播和链上复核也已完成；极小额流动性/交换演练准备 dry-run 和资产/Permit2 授权准备 dry-run 均已通过。测试 USDC 已到账，资产/Permit2 授权和报价预检均已通过；下一步不是重新部署 Hook，而是准备真实小额流动性 + swap 广播草案和最终 dry-run。
