# Base Sepolia rc3 Stage 3 广播后复核清单草案 - 2026-05-18

本文只说明：如果未来 Stage 3 真的在 Base Sepolia 测试网广播成功后，要怎么做只读复核。

当前没有广播，没有交易哈希，没有部署新合约。

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

只有未来 owner 单独明确批准“测试网 Stage 3 广播”，并且 Stage 3 的 1 笔交易真的执行成功后，才使用这张表。

小白理解：

```text
Stage 3 前看 Stage 3 广播草案。
Stage 3 真执行后看这张复核表。
现在只是提前准备复核方法，不是批准广播。
```

## 2. Stage 3 交易哈希记录区

当前全部待填，因为还没有广播。

| 顺序 | 操作 | 交易哈希 |
| ---: | --- | --- |
| 1 | `Hook.renounceOwnership()` | 待填 |

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

人工复核：

- [ ] Stage 3 有且只有 1 笔交易哈希。
- [ ] 交易 receipt status 等于 `1`。
- [ ] 交易发生在 Base Sepolia，chain-id 是 `84532`。
- [ ] 没有任何 Base 主网交易。

## 3. 预期地址和 ID 记录区

如果未来 Stage 3 广播前重新检查后地址没有变化，可继续使用下面这组预测值。
如果 Stage 1 或 Stage 2 实际地址变化，必须停止并更新本表。

| 项目 | 当前预测地址或 ID | 广播后实际结果 |
| --- | --- | --- |
| `BaseSunMoonUsdcFeeV4Hook` | `0x675D7a468d4d3b8d02d530539867F9e5feEFc0cc` | 待填 |
| `SUN_USDC_POOL_ID` | `0xdbf2bf05916b4f79d43e3ee74fa48b36301e8e8c13805335e186648b792451dc` | 待填 |
| `MOON_USDC_POOL_ID` | `0x5b2a79878be8e421c919a9acb8d853731d6d61b8053aa25bd32e0c994130bdfd` | 待填 |

人工复核：

- [ ] Hook 实际地址与广播前最后一次复核地址一致。
- [ ] 两个 poolId 与广播前最后一次复核结果一致。
- [ ] 如果任何地址或 poolId 不一致，停止后续动作。

## 4. Hook owner 是否已放弃

用途：确认 Stage 3 的核心目标已经完成。

只读命令模板：

```powershell
cast code <HOOK_ADDRESS> --rpc-url https://sepolia.base.org
cast call <HOOK_ADDRESS> "owner()(address)" --rpc-url https://sepolia.base.org
```

期望结果：

```text
code 不是 0x
owner=0x0000000000000000000000000000000000000000
```

人工复核：

- [ ] Hook code 不是 `0x`。
- [ ] Hook owner 已变成零地址。
- [ ] Stage 3 后不能再把 owner 转回普通钱包。

## 5. Hook 关键配置是否保持不变

用途：确认 renounce 只放弃管理权，没有把关键配置改坏。

只读命令模板：

```powershell
cast call <HOOK_ADDRESS> "poolManager()(address)" --rpc-url https://sepolia.base.org
cast call <HOOK_ADDRESS> "sunToken()(address)" --rpc-url https://sepolia.base.org
cast call <HOOK_ADDRESS> "moonToken()(address)" --rpc-url https://sepolia.base.org
cast call <HOOK_ADDRESS> "usdc()(address)" --rpc-url https://sepolia.base.org
cast call <HOOK_ADDRESS> "sunCurve()(address)" --rpc-url https://sepolia.base.org
cast call <HOOK_ADDRESS> "protocolBudget()(address)" --rpc-url https://sepolia.base.org
cast call <HOOK_ADDRESS> "paused()(bool)" --rpc-url https://sepolia.base.org
cast call <HOOK_ADDRESS> "expectedHookMask()(uint160)" --rpc-url https://sepolia.base.org
```

期望结果：

```text
poolManager=0x05E73354cFDd6745C338b50BcFDfA3Aa6fA03408
sunToken=<Stage 1 SunToken 实际地址>
moonToken=<Stage 1 MoonToken 实际地址>
usdc=0x036CbD53842c5426634e7929541eC2318f3dCF7e
sunCurve=<Stage 1 SunCurve 实际地址>
protocolBudget=0x277ba3Cf597CdAaF958C301db3cF6a631F793039
paused=false
expectedHookMask=204
```

人工复核：

- [ ] Hook poolManager 是 Base Sepolia 官方 PoolManager。
- [ ] Hook token / USDC / SunCurve 地址都正确。
- [ ] Hook protocolBudget 仍是测试网协议经费地址。
- [ ] Hook paused 仍是 `false`。
- [ ] Hook expectedHookMask 仍是 `204`。

## 6. SunCurve 绑定是否保持不变

用途：确认 `SunCurve.moonAMM` 仍然指向 Hook。

只读命令模板：

```powershell
cast call <SUN_CURVE> "moonAMM()(address)" --rpc-url https://sepolia.base.org
```

期望结果：

```text
moonAMM=<HOOK_ADDRESS>
```

人工复核：

- [ ] `SunCurve.moonAMM` 等于 Hook 地址。

## 7. Hook 白名单是否保持不变

用途：确认项目支持的两个 v4 Hook 池仍然被允许。

只读命令模板：

```powershell
cast call <HOOK_ADDRESS> "allowedSunUsdcPools(bytes32)(bool)" <SUN_USDC_POOL_ID> --rpc-url https://sepolia.base.org
cast call <HOOK_ADDRESS> "allowedMoonUsdcPools(bytes32)(bool)" <MOON_USDC_POOL_ID> --rpc-url https://sepolia.base.org
```

期望结果：

```text
allowedSunUsdcPools(SUN_USDC_POOL_ID)=true
allowedMoonUsdcPools(MOON_USDC_POOL_ID)=true
```

人工复核：

- [ ] SUN/USDC poolId 白名单仍是 `true`。
- [ ] MOON/USDC poolId 白名单仍是 `true`。
- [ ] 没有把其他未知池写成项目支持池。

## 8. SUN/USDC 池状态是否保持不变

用途：确认 Stage 3 没有添加流动性，也没有改池价格。

只读命令模板：

```powershell
cast call 0x571291b572ed32ce6751a2Cb2486EbEe8DEfB9B4 "getSlot0(bytes32)(uint160,int24,uint24,uint24)" <SUN_USDC_POOL_ID> --rpc-url https://sepolia.base.org
cast call 0x571291b572ed32ce6751a2Cb2486EbEe8DEfB9B4 "getLiquidity(bytes32)(uint128)" <SUN_USDC_POOL_ID> --rpc-url https://sepolia.base.org
```

期望结果：

```text
sqrtPriceX96=79228162514264337593543950336000000
tick=276324
protocolFee=0
lpFee=3000
liquidity=0
```

人工复核：

- [ ] SUN/USDC `sqrtPriceX96` 正确。
- [ ] SUN/USDC `tick` 正确。
- [ ] SUN/USDC `protocolFee=0`。
- [ ] SUN/USDC `lpFee=3000`。
- [ ] SUN/USDC `liquidity=0`。

## 9. MOON/USDC 池状态是否保持不变

用途：确认 Stage 3 没有添加流动性，也没有改池价格。

只读命令模板：

```powershell
cast call 0x571291b572ed32ce6751a2Cb2486EbEe8DEfB9B4 "getSlot0(bytes32)(uint160,int24,uint24,uint24)" <MOON_USDC_POOL_ID> --rpc-url https://sepolia.base.org
cast call 0x571291b572ed32ce6751a2Cb2486EbEe8DEfB9B4 "getLiquidity(bytes32)(uint128)" <MOON_USDC_POOL_ID> --rpc-url https://sepolia.base.org
```

期望结果：

```text
sqrtPriceX96=161723809515207654377831473576838109
tick=290595
protocolFee=0
lpFee=3000
liquidity=0
```

人工复核：

- [ ] MOON/USDC `sqrtPriceX96` 正确。
- [ ] MOON/USDC `tick` 正确。
- [ ] MOON/USDC `protocolFee=0`。
- [ ] MOON/USDC `lpFee=3000`。
- [ ] MOON/USDC `liquidity=0`。

## 10. 管理员函数是否已经锁死

用途：确认 renounce 后，原测试网管理员也不能再修改 Hook。

下面是可选只读模拟，不是交易，不会改链上状态。
只能用 `cast call`，不能用 `cast send`。

```powershell
cast call <HOOK_ADDRESS> "setAllowedSunUsdcPool(bytes32,bool)" 0x1111111111111111111111111111111111111111111111111111111111111111 true --from 0x6E22b2e6fFAA30Fe75B71d53d1eC469b4e97A986 --rpc-url https://sepolia.base.org
cast call <HOOK_ADDRESS> "setAllowedMoonUsdcPool(bytes32,bool)" 0x2222222222222222222222222222222222222222222222222222222222222222 true --from 0x6E22b2e6fFAA30Fe75B71d53d1eC469b4e97A986 --rpc-url https://sepolia.base.org
cast call <HOOK_ADDRESS> "setProtocolBudget(address)" 0x277ba3Cf597CdAaF958C301db3cF6a631F793039 --from 0x6E22b2e6fFAA30Fe75B71d53d1eC469b4e97A986 --rpc-url https://sepolia.base.org
cast call <HOOK_ADDRESS> "setPaused(bool)" true --from 0x6E22b2e6fFAA30Fe75B71d53d1eC469b4e97A986 --rpc-url https://sepolia.base.org
```

期望结果：

```text
全部 revert 或 fail
链上状态没有变化
```

人工复核：

- [ ] 不能再新增 SUN/USDC 白名单。
- [ ] 不能再新增 MOON/USDC 白名单。
- [ ] 不能再修改 protocolBudget。
- [ ] 不能再暂停 Hook。
- [ ] 如果任何一个管理员函数看起来成功，立即停止。

## 11. Stage 3 后必须保持的状态

Stage 3 完成后，应该同时满足：

```text
Hook.owner=0x0000000000000000000000000000000000000000
allowedSunUsdcPools(SUN_USDC_POOL_ID)=true
allowedMoonUsdcPools(MOON_USDC_POOL_ID)=true
protocolBudget=0x277ba3Cf597CdAaF958C301db3cF6a631F793039
paused=false
SUN/USDC liquidity=0
MOON/USDC liquidity=0
```

小白理解：

```text
Stage 3 成功不是“能继续改参数”。
Stage 3 成功是“该保留的配置还在，但管理员已经不能改了”。
```

## 12. 绝对停止条件

出现任一情况，立即停止：

```text
Stage 3 交易 receipt status 不是 1
chain-id 不是 84532
Hook code 是 0x
Hook owner 不是零地址
任何白名单不是 true
protocolBudget 不符合预期
paused 不是 false
SunCurve.moonAMM 不是 Hook
任何池 slot0 不符合预期
任何池 liquidity 不是 0
renounce 后任何 owner-only 函数看起来可以成功
有人要求使用私钥、助记词或恢复词
有人要求使用真实资金
有人把测试网成功说成主网可以直接部署
```

## 13. 下一步建议

下一步仍然不是广播。

建议下一步只做：

```text
rc3 测试网 Stage 1/2/3 总闸门清单已经准备完成：
docs/Base-Sepolia-rc3-Stage1-2-3-总闸门清单-2026-05-18.md

下一步只建议 owner 人工阅读总闸门清单
如需继续，也应先重新跑 Base Sepolia fork 只读检查
再单独讨论是否允许测试网 Stage 1 广播
```
