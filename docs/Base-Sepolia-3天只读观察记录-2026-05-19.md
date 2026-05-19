# Base Sepolia 3 天只读观察记录 - 2026-05-19

本记录只用于 Base Sepolia 测试网观察。

```text
不执行 Base 主网。
不使用真实资金。
不要求或记录私钥、助记词、恢复词。
不使用 --private-key。
本次没有发送交易。
本次没有使用 --broadcast。
```

## Day 1 - 只读基线快照

执行时间：

```text
2026-05-19 12:52:17 +08:00
```

检查范围：

```text
网络: Base Sepolia
chainId: 84532
admin / rehearsal actor: 0x6E22b2e6fFAA30Fe75B71d53d1eC469b4e97A986
HOOK: 0x6c40A03313A097dDe45694dc9E769392a0f940Cc
MOON_USDC_POOL_ID: 0x710ab2d815645e13484f0aeca86b754e56f29d4c93d9623bb8f6e5a079da51e5
POSITION_TOKEN_ID: 22719
```

### 1. 网络和 nonce

| 项目 | 结果 | 结论 |
| --- | --- | --- |
| chainId | `84532` | 通过 |
| admin nonce | `29` | 通过 |

### 2. Hook 状态

| 项目 | 结果 | 结论 |
| --- | --- | --- |
| `HOOK.owner()` | `0x6E22b2e6fFAA30Fe75B71d53d1eC469b4e97A986` | 通过 |
| `HOOK.paused()` | `false` | 通过 |
| `HOOK.allowedMoonPools(MOON_USDC_POOL_ID)` | `true` | 通过 |

### 3. Adapter 和 SunCurve

| 项目 | 结果 | 结论 |
| --- | --- | --- |
| `Adapter.authorizedHook()` | `0x6c40A03313A097dDe45694dc9E769392a0f940Cc` | 通过 |
| `Adapter.paused()` | `false` | 通过 |
| `SunCurve.moonAMM()` | `0x6c40A03313A097dDe45694dc9E769392a0f940Cc` | 通过 |

### 4. MOON/USDC 池子

| 项目 | 结果 | 结论 |
| --- | --- | --- |
| `slot0.sqrtPriceX96` | `78912161789762476440367309875066997` | 通过 |
| `slot0.tick` | `276244` | 通过 |
| `slot0.protocolFee` | `0` | 通过 |
| `slot0.lpFee` | `3000` | 通过 |

说明：

```text
sqrtPriceX96 不为 0，说明池子已经初始化且能正常读取。
tick=276244 是小额 swap 后的当前池子状态。
```

### 5. Position NFT

| 项目 | 结果 | 结论 |
| --- | --- | --- |
| `PositionManager.ownerOf(22719)` | `0x6E22b2e6fFAA30Fe75B71d53d1eC469b4e97A986` | 通过 |
| `PositionManager.getPositionLiquidity(22719)` | `33796876514319` | 通过 |

### 6. 余额快照

| 项目 | raw | 显示值 |
| --- | ---: | ---: |
| admin USDC | `16800000` | `16.8 USDC` |
| admin SUN | `190000000000000000` | `0.19 SUN` |
| admin MOON | `284123473562317985` | `0.284123473562317985 MOON` |
| protocol budget USDC | `20009000` | `20.009 USDC` |
| SunCurve USDC balance | `500500` | `0.5005 USDC` |
| SunCurve `curveReserve()` | `500500` | `0.5005 USDC` |

### 7. Day 1 结论

```text
Day 1 只读基线快照通过。
所有关键地址一致。
Hook 未暂停。
Adapter 和 SunCurve 都指向当前 Hook。
MOON/USDC 池子能正常读取。
Position NFT 22719 仍归 admin 钱包。
仓位 liquidity 大于 0。
余额快照已记录。
本次没有发送交易。
本次没有使用真实资金。
本次没有使用私钥、助记词、恢复词或 --private-key。
```

下一步：

```text
等待 Day 2，再做只读稳定性复查。
不要重复 Stage 3 小额流动性交易。
不要重复 Stage 3 小额 swap 交易。
不要进入 Base 主网。
```
