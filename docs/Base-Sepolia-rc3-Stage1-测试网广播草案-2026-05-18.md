# Base Sepolia rc3 Stage 1 测试网广播草案 - 2026-05-18

本文只整理 Stage 1 的测试网广播草案，方便人工理解和复核。

这不是广播批准，也不是主网计划。

固定边界：

```text
不加 --broadcast
当前不部署测试网合约
不部署主网合约
不使用真实资金
不索要私钥
不把预测地址当成已部署地址
```

## 1. Stage 1 是什么

Stage 1 只做测试版核心合约部署和基础配置。

它会准备：

```text
SunToken
SunCurve
MoonToken
MoonCurve
Create2HookDeployer
```

它不会做：

```text
不会部署 Hook
不会创建 SUN/USDC 池
不会创建 MOON/USDC 池
不会添加流动性
不会 swap
不会 renounce Hook owner
不会碰 Base 主网
```

小白理解：

```text
Stage 1 只是把测试版 SUN/MOON 核心零件放到 Base Sepolia 测试网。
Stage 1 结束后，还没有项目支持的 v4 Hook 池。
Stage 1 结束后，仍不能认为 rc3 完整测试网演练完成。
```

## 2. 当前 Stage 1 公开参数

这些都是公开地址，可以写进文档。

| 项目 | 地址 |
| --- | --- |
| 测试网部署钱包 | `0x2F6E887c6058deE520f9468a1022E3480A6334D3` |
| 测试网临时管理员钱包 | `0x6E22b2e6fFAA30Fe75B71d53d1eC469b4e97A986` |
| 测试网协议经费收款钱包 | `0x277ba3Cf597CdAaF958C301db3cF6a631F793039` |
| 测试网 CREATE2 deployer owner | `0x6E22b2e6fFAA30Fe75B71d53d1eC469b4e97A986` |
| Base Sepolia USDC | `0x036CbD53842c5426634e7929541eC2318f3dCF7e` |

重要区别：

```text
这些是 Base Sepolia 测试网地址。
它们不是 Base 主网地址。
```

## 3. Stage 1 的 12 笔交易

当前草案里，Stage 1 预计 12 笔交易。

| 顺序 | 操作 | 谁执行 | 小白解释 |
| ---: | --- | --- | --- |
| 1 | Deploy `SunToken` | 测试网部署钱包 | 部署 SUN 测试版代币合约 |
| 2 | Deploy `SunCurve` | 测试网部署钱包 | 部署 SUN 曲线合约 |
| 3 | Deploy `MoonToken` | 测试网部署钱包 | 部署 MOON 测试版代币合约 |
| 4 | Deploy `MoonCurve` | 测试网部署钱包 | 部署 MOON 曲线合约 |
| 5 | Deploy `Create2HookDeployer` | 测试网部署钱包 | 部署以后用来部署 Hook 的工具合约 |
| 6 | `SunToken.setMinter(SunCurve)` | 测试网部署钱包 | 允许 SunCurve 铸造 SUN |
| 7 | `SunCurve.setMoonCurve(MoonCurve)` | 测试网部署钱包 | 让 SunCurve 认识 MoonCurve |
| 8 | `MoonToken.setMinter(MoonCurve)` | 测试网部署钱包 | 允许 MoonCurve 铸造 MOON |
| 9 | `SunToken.transferOwnership(admin)` | 测试网部署钱包 | 把 SUN 管理权交给测试网管理员 |
| 10 | `SunCurve.transferOwnership(admin)` | 测试网部署钱包 | 把 SunCurve 管理权交给测试网管理员 |
| 11 | `MoonToken.transferOwnership(admin)` | 测试网部署钱包 | 把 MOON 管理权交给测试网管理员 |
| 12 | `MoonCurve.transferOwnership(admin)` | 测试网部署钱包 | 把 MoonCurve 管理权交给测试网管理员 |

Stage 1 完成后，应该看到：

```text
SUN owner = 测试网管理员钱包
SunCurve owner = 测试网管理员钱包
MOON owner = 测试网管理员钱包
MoonCurve owner = 测试网管理员钱包
Create2HookDeployer owner = 测试网 CREATE2 deployer owner
```

## 4. 当前预测地址

这些地址来自 2026-05-18 Base Sepolia fork 只读检查。

它们不是已经部署地址。

| 合约 | 预测地址 |
| --- | --- |
| `SunToken` | `0xb5287fBbAD0e25B12f18497209fDac7e0ACf7293` |
| `SunCurve` | `0xe8D048aB83727419b00F4e30F4898C6B3bB91aD4` |
| `MoonToken` | `0x92dC3B8056cA62A7dbc5c1C339891B45463bEe71` |
| `MoonCurve` | `0x095c91aB279121300Ac16c57D1ecebB9ceEa1cd8` |
| `Create2HookDeployer` | `0x6E34D98e1925eaf6680941213E49741b8764DdfE` |

预测前提：

```text
测试网部署钱包 nonce=16
Stage 1 第一笔交易之前，部署钱包不能先发其他交易
如果 nonce 变化，以上预测地址可能全部变化
```

人工复核：

- [ ] 确认这些只是预测地址。
- [ ] 确认 Stage 1 前需要再次检查部署钱包 nonce。
- [ ] 确认如果预测地址变化，必须停止并更新文档。

## 5. 构造参数复核

### SunToken

```text
name=SUN
symbol=SUN
initialOwner=测试网部署钱包
```

### SunCurve

```text
sunToken=预测 SunToken
usdt/USDC=Base Sepolia USDC
protocolBudget=测试网协议经费收款钱包
maxMintUSDT=10000 USDC
initialOwner=测试网部署钱包
```

### MoonToken

```text
name=MOON
symbol=MOON
initialOwner=测试网部署钱包
```

### MoonCurve

```text
moonToken=预测 MoonToken
sunToken=预测 SunToken
sunCurve=预测 SunCurve
protocolBudget=测试网协议经费收款钱包
K=5000000 MOON
S=1200000 MOON
moonLaunchDelay=0
maxMintUsdtEquivalent=10000 USDC
initialOwner=测试网部署钱包
```

说明：

```text
moonLaunchDelay=0 表示测试网不额外延迟。
实际 moonLaunchTime 会按广播所在区块时间计算。
```

### Create2HookDeployer

```text
owner=测试网 CREATE2 deployer owner
```

## 6. Stage 1 完成后仍未完成的事

Stage 1 不包含这些内容：

```text
Hook 部署
SunCurve.moonAMM 绑定
SUN/USDC poolId 白名单
MOON/USDC poolId 白名单
SUN/USDC 池初始化
MOON/USDC 池初始化
Hook owner renounce
任何流动性添加
任何 swap
```

这些属于 Stage 2 或 Stage 3，必须后续再单独复核。

## 7. Stage 1 前必须重新检查

任何真实 Base Sepolia Stage 1 广播前，必须重新做：

- [ ] 重新跑 Base Sepolia fork 只读分阶段草案检查。
- [ ] 确认 `chainId=84532`。
- [ ] 确认 `stage1AddressCollision=false`。
- [ ] 确认部署钱包 nonce 没变，或者接受并记录新的预测地址。
- [ ] 确认命令没有 `--broadcast`，除非 owner 单独明确批准测试网 Stage 1 广播。
- [ ] 确认没有把任何私钥、助记词、恢复词写进聊天或文档。
- [ ] 确认只使用 Base Sepolia 测试网，不触碰 Base 主网。

## 8. 绝对停止条件

出现任一情况，立即停止：

```text
命令指向 Base 主网
命令出现 --broadcast 但 owner 没有明确批准测试网 Stage 1 广播
有人要求提供私钥、助记词或恢复词
有人要求使用真实 ETH 或真实 USDC
部署钱包 nonce 已变化但文档没有更新
预测地址被说成已经部署地址
有人要求跳过 Stage 1 后复核，直接进入 Stage 2 或 Stage 3
```

## 9. 下一步建议

下一步仍然不是广播。

建议下一步只做：

```text
Stage 1 后复核清单草案
列出如果未来 Stage 1 真的广播成功后，要用 cast/code/owner/minter 查询哪些结果
继续保持不广播、不索要私钥
```
