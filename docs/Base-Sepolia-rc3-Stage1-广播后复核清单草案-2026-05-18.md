# Base Sepolia rc3 Stage 1 广播后复核清单草案 - 2026-05-18

本文只说明：如果未来 Stage 1 真的在 Base Sepolia 测试网广播成功后，要逐项复核什么。

当前没有广播，没有部署，没有交易哈希。

固定边界：

```text
不加 --broadcast
不部署测试网合约
不部署主网合约
不使用真实资金
不索要私钥
不把预测地址当成已部署地址
```

## 1. 什么时候用这张表

只有未来 owner 单独明确批准“测试网 Stage 1 广播”，且 Stage 1 真的执行完成后，才使用这张表。

小白理解：

```text
广播前看 Stage 1 草案。
广播后用这张表核对结果。
现在只是提前准备复核方法。
```

## 2. Stage 1 交易哈希记录区

当前全部待填，因为还没有广播。

| 顺序 | 操作 | 交易哈希 |
| ---: | --- | --- |
| 1 | Deploy `SunToken` | 待填 |
| 2 | Deploy `SunCurve` | 待填 |
| 3 | Deploy `MoonToken` | 待填 |
| 4 | Deploy `MoonCurve` | 待填 |
| 5 | Deploy `Create2HookDeployer` | 待填 |
| 6 | `SunToken.setMinter(SunCurve)` | 待填 |
| 7 | `SunCurve.setMoonCurve(MoonCurve)` | 待填 |
| 8 | `MoonToken.setMinter(MoonCurve)` | 待填 |
| 9 | `SunToken.transferOwnership(admin)` | 待填 |
| 10 | `SunCurve.transferOwnership(admin)` | 待填 |
| 11 | `MoonToken.transferOwnership(admin)` | 待填 |
| 12 | `MoonCurve.transferOwnership(admin)` | 待填 |

人工复核：

- [ ] 12 笔交易都有交易哈希。
- [ ] 每笔交易 receipt status 都等于 `1`。
- [ ] 每笔交易都发生在 Base Sepolia，不是 Base 主网。

只读命令模板：

```powershell
cast receipt <TX_HASH> --rpc-url https://sepolia.base.org
cast chain-id --rpc-url https://sepolia.base.org
```

期望结果：

```text
status=1
chain-id=84532
```

## 3. 预期地址记录区

如果未来 Stage 1 广播前重新检查后地址没有变化，可继续使用下面这组预测地址。

如果部署钱包 nonce 已变化，必须停止并更新本表。

| 合约 | 当前预测地址 | 广播后实际地址 |
| --- | --- | --- |
| `SunToken` | `0xb5287fBbAD0e25B12f18497209fDac7e0ACf7293` | 待填 |
| `SunCurve` | `0xe8D048aB83727419b00F4e30F4898C6B3bB91aD4` | 待填 |
| `MoonToken` | `0x92dC3B8056cA62A7dbc5c1C339891B45463bEe71` | 待填 |
| `MoonCurve` | `0x095c91aB279121300Ac16c57D1ecebB9ceEa1cd8` | 待填 |
| `Create2HookDeployer` | `0x6E34D98e1925eaf6680941213E49741b8764DdfE` | 待填 |

人工复核：

- [ ] 实际地址与广播前最后一次预测地址一致。
- [ ] 如果任何地址不一致，停止进入 Stage 2。
- [ ] 所有地址都不是零地址。

## 4. 代码存在检查

用途：确认地址上真的有合约代码。

只读命令模板：

```powershell
cast code <CONTRACT_ADDRESS> --rpc-url https://sepolia.base.org
```

期望结果：

```text
返回值不是 0x
```

人工复核：

- [ ] `SunToken` code 不是 `0x`。
- [ ] `SunCurve` code 不是 `0x`。
- [ ] `MoonToken` code 不是 `0x`。
- [ ] `MoonCurve` code 不是 `0x`。
- [ ] `Create2HookDeployer` code 不是 `0x`。

## 5. Token 基础信息检查

### SunToken

只读命令模板：

```powershell
cast call <SUN_TOKEN> "name()(string)" --rpc-url https://sepolia.base.org
cast call <SUN_TOKEN> "symbol()(string)" --rpc-url https://sepolia.base.org
cast call <SUN_TOKEN> "decimals()(uint8)" --rpc-url https://sepolia.base.org
cast call <SUN_TOKEN> "owner()(address)" --rpc-url https://sepolia.base.org
cast call <SUN_TOKEN> "minter()(address)" --rpc-url https://sepolia.base.org
cast call <SUN_TOKEN> "minterLocked()(bool)" --rpc-url https://sepolia.base.org
```

期望结果：

```text
name=SUN
symbol=SUN
decimals=18
owner=0x6E22b2e6fFAA30Fe75B71d53d1eC469b4e97A986
minter=<SunCurve 实际地址>
minterLocked=true
```

人工复核：

- [ ] SUN name/symbol/decimals 正确。
- [ ] SUN owner 是测试网管理员钱包。
- [ ] SUN minter 是 `SunCurve`。
- [ ] SUN minterLocked 是 `true`。

### MoonToken

只读命令模板：

```powershell
cast call <MOON_TOKEN> "name()(string)" --rpc-url https://sepolia.base.org
cast call <MOON_TOKEN> "symbol()(string)" --rpc-url https://sepolia.base.org
cast call <MOON_TOKEN> "decimals()(uint8)" --rpc-url https://sepolia.base.org
cast call <MOON_TOKEN> "owner()(address)" --rpc-url https://sepolia.base.org
cast call <MOON_TOKEN> "minter()(address)" --rpc-url https://sepolia.base.org
cast call <MOON_TOKEN> "minterLocked()(bool)" --rpc-url https://sepolia.base.org
```

期望结果：

```text
name=MOON
symbol=MOON
decimals=18
owner=0x6E22b2e6fFAA30Fe75B71d53d1eC469b4e97A986
minter=<MoonCurve 实际地址>
minterLocked=true
```

人工复核：

- [ ] MOON name/symbol/decimals 正确。
- [ ] MOON owner 是测试网管理员钱包。
- [ ] MOON minter 是 `MoonCurve`。
- [ ] MOON minterLocked 是 `true`。

## 6. SunCurve 配置检查

只读命令模板：

```powershell
cast call <SUN_CURVE> "owner()(address)" --rpc-url https://sepolia.base.org
cast call <SUN_CURVE> "sunToken()(address)" --rpc-url https://sepolia.base.org
cast call <SUN_CURVE> "usdt()(address)" --rpc-url https://sepolia.base.org
cast call <SUN_CURVE> "protocolBudget()(address)" --rpc-url https://sepolia.base.org
cast call <SUN_CURVE> "maxMintUsdt()(uint256)" --rpc-url https://sepolia.base.org
cast call <SUN_CURVE> "moonCurve()(address)" --rpc-url https://sepolia.base.org
cast call <SUN_CURVE> "moonAMM()(address)" --rpc-url https://sepolia.base.org
```

期望结果：

```text
owner=0x6E22b2e6fFAA30Fe75B71d53d1eC469b4e97A986
sunToken=<SunToken 实际地址>
usdt=0x036CbD53842c5426634e7929541eC2318f3dCF7e
protocolBudget=0x277ba3Cf597CdAaF958C301db3cF6a631F793039
maxMintUsdt=10000000000
moonCurve=<MoonCurve 实际地址>
moonAMM=0x0000000000000000000000000000000000000000
```

说明：

```text
maxMintUsdt=10000000000 表示 10000 USDC，因为 Base Sepolia USDC 是 6 位小数。
Stage 1 不绑定 Hook，所以 moonAMM 应该还是零地址。
```

人工复核：

- [ ] SunCurve owner 是测试网管理员钱包。
- [ ] SunCurve 指向正确 SunToken。
- [ ] SunCurve 使用 Base Sepolia USDC。
- [ ] SunCurve 协议经费地址正确。
- [ ] SunCurve maxMintUsdt 正确。
- [ ] SunCurve moonCurve 指向 MoonCurve。
- [ ] SunCurve moonAMM 仍是零地址。

## 7. MoonCurve 配置检查

只读命令模板：

```powershell
cast call <MOON_CURVE> "owner()(address)" --rpc-url https://sepolia.base.org
cast call <MOON_CURVE> "moonToken()(address)" --rpc-url https://sepolia.base.org
cast call <MOON_CURVE> "sunToken()(address)" --rpc-url https://sepolia.base.org
cast call <MOON_CURVE> "sunCurve()(address)" --rpc-url https://sepolia.base.org
cast call <MOON_CURVE> "protocolBudget()(address)" --rpc-url https://sepolia.base.org
cast call <MOON_CURVE> "k()(uint256)" --rpc-url https://sepolia.base.org
cast call <MOON_CURVE> "s()(uint256)" --rpc-url https://sepolia.base.org
cast call <MOON_CURVE> "launchTime()(uint256)" --rpc-url https://sepolia.base.org
cast call <MOON_CURVE> "maxMintUsdtEquiv()(uint256)" --rpc-url https://sepolia.base.org
cast call <MOON_CURVE> "timeUntilLaunch()(uint256)" --rpc-url https://sepolia.base.org
```

期望结果：

```text
owner=0x6E22b2e6fFAA30Fe75B71d53d1eC469b4e97A986
moonToken=<MoonToken 实际地址>
sunToken=<SunToken 实际地址>
sunCurve=<SunCurve 实际地址>
protocolBudget=0x277ba3Cf597CdAaF958C301db3cF6a631F793039
k=5000000000000000000000000
s=1200000000000000000000000
maxMintUsdtEquiv=10000000000
timeUntilLaunch=0
```

说明：

```text
k=5000000 * 1e18
s=1200000 * 1e18
maxMintUsdtEquiv=10000 USDC，以 6 位小数记录。
测试网 moonLaunchDelay=0，所以 timeUntilLaunch 应该为 0。
```

人工复核：

- [ ] MoonCurve owner 是测试网管理员钱包。
- [ ] MoonCurve 指向正确 MoonToken。
- [ ] MoonCurve 指向正确 SunToken。
- [ ] MoonCurve 指向正确 SunCurve。
- [ ] MoonCurve 协议经费地址正确。
- [ ] MoonCurve k/s 参数正确。
- [ ] MoonCurve maxMintUsdtEquiv 正确。
- [ ] MoonCurve timeUntilLaunch 是 0。

## 8. Create2HookDeployer 检查

只读命令模板：

```powershell
cast call <CREATE2_HOOK_DEPLOYER> "owner()(address)" --rpc-url https://sepolia.base.org
```

期望结果：

```text
owner=0x6E22b2e6fFAA30Fe75B71d53d1eC469b4e97A986
```

人工复核：

- [ ] Create2HookDeployer owner 是测试网 CREATE2 deployer owner。

## 9. Stage 1 后必须保持未完成状态

Stage 1 后，以下内容必须仍然没有执行：

- [ ] 没有部署 `BaseSunMoonUsdcFeeV4Hook`。
- [ ] 没有设置 `SunCurve.moonAMM`。
- [ ] 没有白名单 `SUN/USDC` poolId。
- [ ] 没有白名单 `MOON/USDC` poolId。
- [ ] 没有初始化 `SUN/USDC` 池。
- [ ] 没有初始化 `MOON/USDC` 池。
- [ ] 没有添加流动性。
- [ ] 没有 swap。
- [ ] 没有 renounce Hook owner。

小白理解：

```text
Stage 1 结束，只能说明核心合约部署和基础绑定完成。
Stage 2 和 Stage 3 仍然必须单独批准、单独广播、单独复核。
```

## 10. 绝对停止条件

出现任一情况，立即停止：

```text
任一交易 receipt status 不是 1
任一合约地址 code 是 0x
任一 owner/minter/配置地址不符合预期
实际地址和广播前最后预测地址不一致
Stage 1 后有人要求直接跳过复核进入 Stage 2
命令或记录里出现私钥、助记词或恢复词
有人把测试网成功说成主网可直接部署
```

## 11. 下一步建议

下一步仍然不是广播。

建议下一步只做：

```text
Stage 2 测试网广播草案文档
把 Hook 部署、绑定、两个池白名单、两个池初始化拆成小白清单
继续保持不广播、不索要私钥
```
