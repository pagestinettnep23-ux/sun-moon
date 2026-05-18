# Base Sepolia rc3 Stage 2 广播后复核清单草案 - 2026-05-18

本文只说明：如果未来 Stage 2 真的在 Base Sepolia 测试网广播成功后，要逐项复核什么。

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

只有未来 owner 单独明确批准“测试网 Stage 2 广播”，且 Stage 2 真的执行完成后，才使用这张表。

小白理解：

```text
Stage 2 前必须先完成 Stage 1 后复核。
Stage 2 广播前看 Stage 2 草案。
Stage 2 广播后用这张表核对 Hook、白名单和两个池初始化。
现在只是提前准备复核方法。
```

## 2. Stage 2 交易哈希记录区

当前全部待填，因为还没有广播。

| 顺序 | 操作 | 交易哈希 |
| ---: | --- | --- |
| 1 | `Create2HookDeployer.deployHook(...)` | 待填 |
| 2 | `SunCurve.setMoonAMM(Hook)` | 待填 |
| 3 | `Hook.setAllowedSunUsdcPool(poolId, true)` | 待填 |
| 4 | `Hook.setAllowedMoonUsdcPool(poolId, true)` | 待填 |
| 5 | `PoolManager.initialize(SUN/USDC, sqrtPriceX96)` | 待填 |
| 6 | `PoolManager.initialize(MOON/USDC, sqrtPriceX96)` | 待填 |

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

- [ ] 6 笔交易都有交易哈希。
- [ ] 每笔交易 receipt status 都等于 `1`。
- [ ] 每笔交易都发生在 Base Sepolia，不是 Base 主网。

## 3. 预期地址记录区

如果未来 Stage 2 广播前重新检查后地址没有变化，可继续使用下面这组预测地址。

如果 Stage 1 实际地址或 Hook 预测地址变化，必须停止并更新本表。

| 项目 | 当前预测地址或 ID | 广播后实际结果 |
| --- | --- | --- |
| `BaseSunMoonUsdcFeeV4Hook` | `0x675D7a468d4d3b8d02d530539867F9e5feEFc0cc` | 待填 |
| `SUN_USDC_POOL_ID` | `0xdbf2bf05916b4f79d43e3ee74fa48b36301e8e8c13805335e186648b792451dc` | 待填 |
| `MOON_USDC_POOL_ID` | `0x5b2a79878be8e421c919a9acb8d853731d6d61b8053aa25bd32e0c994130bdfd` | 待填 |

人工复核：

- [ ] Hook 实际地址与广播前最后预测地址一致。
- [ ] 两个 poolId 与广播前最后计算结果一致。
- [ ] 如果任何地址或 poolId 不一致，停止进入 Stage 3。

## 4. Hook 代码和配置检查

用途：确认 Hook 已部署，并且构造参数正确。

只读命令模板：

```powershell
cast code <HOOK_ADDRESS> --rpc-url https://sepolia.base.org
cast call <HOOK_ADDRESS> "owner()(address)" --rpc-url https://sepolia.base.org
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
code 不是 0x
owner=0x6E22b2e6fFAA30Fe75B71d53d1eC469b4e97A986
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

- [ ] Hook code 不是 `0x`。
- [ ] Hook owner 仍是测试网管理员钱包。
- [ ] Hook 还没有 renounce。
- [ ] Hook poolManager 是 Base Sepolia 官方 PoolManager。
- [ ] Hook token/USDC/SunCurve 地址都正确。
- [ ] Hook protocolBudget 正确。
- [ ] Hook paused 是 `false`。
- [ ] Hook expectedHookMask 是 `204`。

## 5. SunCurve 绑定检查

用途：确认 Stage 2 已把 `SunCurve.moonAMM` 绑定到 Hook。

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

## 6. Hook 白名单检查

用途：确认两个项目支持池已经被 Hook 允许。

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

- [ ] SUN/USDC poolId 白名单是 `true`。
- [ ] MOON/USDC poolId 白名单是 `true`。
- [ ] 没有把其他未知池误写成项目支持池。

## 7. SUN/USDC 池初始化检查

用途：确认 SUN/USDC v4 池已初始化到目标初始价格。

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

说明：

```text
liquidity=0 是正常的。
Stage 2 只初始化池价格，不添加流动性。
```

人工复核：

- [ ] SUN/USDC `sqrtPriceX96` 正确。
- [ ] SUN/USDC `tick` 正确。
- [ ] SUN/USDC `protocolFee=0`。
- [ ] SUN/USDC `lpFee=3000`。
- [ ] SUN/USDC `liquidity=0`。

## 8. MOON/USDC 池初始化检查

用途：确认 MOON/USDC v4 池已初始化到目标初始价格。

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

说明：

```text
liquidity=0 是正常的。
Stage 2 只初始化池价格，不添加流动性。
```

人工复核：

- [ ] MOON/USDC `sqrtPriceX96` 正确。
- [ ] MOON/USDC `tick` 正确。
- [ ] MOON/USDC `protocolFee=0`。
- [ ] MOON/USDC `lpFee=3000`。
- [ ] MOON/USDC `liquidity=0`。

## 9. Stage 2 后必须保持未完成状态

Stage 2 后，以下内容必须仍然没有执行：

- [ ] 没有添加 `SUN/USDC` 流动性。
- [ ] 没有添加 `MOON/USDC` 流动性。
- [ ] 没有执行 swap。
- [ ] 没有 renounce Hook owner。
- [ ] 没有任何 Base 主网动作。

小白理解：

```text
Stage 2 结束，只能说明 Hook、白名单、两个池初始化完成。
池子虽然被初始化了，但还没有流动性。
Stage 3 renounce 仍然必须单独批准、单独广播、单独复核。
```

## 10. 绝对停止条件

出现任一情况，立即停止：

```text
任一交易 receipt status 不是 1
Hook 地址 code 是 0x
Hook owner/config 地址不符合预期
SunCurve.moonAMM 不是 Hook
任一白名单不是 true
任一池 slot0.sqrtPriceX96 不符合预期
任一池 liquidity 不是 0
Stage 2 后有人要求直接跳过复核进入 Stage 3
命令或记录里出现私钥、助记词或恢复词
有人把测试网成功说成主网可直接部署
```

## 11. 下一步建议

下一步仍然不是广播。

建议下一步只做：

```text
Stage 3 测试网广播草案文档
把 renounce Hook owner 拆成小白清单
继续保持不广播、不索要私钥
```

Stage 3 草案文档：

```text
docs/Base-Sepolia-rc3-Stage3-测试网广播草案-2026-05-18.md
```
